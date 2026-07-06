import ChronicleCore
import ChronicleIPC
import ChroniclePipeline
import ChronicleStorage
import Dispatch
import Foundation
import Logging

/// The Chronicle agent: orchestrates the pipeline, collector supervisor, IPC
/// control server, health reporting, and graceful shutdown.
///
/// An actor so its lifecycle state is race-free. `run()` starts every subsystem,
/// installs POSIX signal handlers, and suspends until a shutdown is requested
/// (via SIGTERM/SIGINT or an IPC `shutdown`), then drains and checkpoints.
public actor ChronicleAgent {
    private let store: SQLiteEventStore
    private let pipeline: EventPipeline
    private let supervisor: CollectorSupervisor
    private let socketPath: String
    private let databasePath: String
    private let healthReporter: HealthReporter
    private let onReload: @Sendable () async -> Void
    private let logger: Logger

    private let startedAt = Date()
    private var paused = false
    private var ipcServer: IPCServer?
    private var signalSources: [any DispatchSourceSignal] = []
    private var shutdownContinuation: CheckedContinuation<Void, Never>?
    private var didRequestShutdown = false

    /// Creates an agent.
    public init(
        store: SQLiteEventStore,
        pipeline: EventPipeline,
        supervisor: CollectorSupervisor,
        socketPath: String,
        databasePath: String,
        healthReporter: HealthReporter,
        onReload: @escaping @Sendable () async -> Void,
        logger: Logger = Logger(label: "chronicle.agent")
    ) {
        self.store = store
        self.pipeline = pipeline
        self.supervisor = supervisor
        self.socketPath = socketPath
        self.databasePath = databasePath
        self.healthReporter = healthReporter
        self.onReload = onReload
        self.logger = logger
    }

    /// Starts all subsystems and runs until shutdown is requested.
    public func run() async throws {
        logger.notice("chronicled starting", metadata: [
            "pid": .stringConvertible(getpid()),
            "database": .string(databasePath),
            "socket": .string(socketPath),
        ])

        await pipeline.start()
        await supervisor.start()
        try startIPCServer()
        installSignalHandlers()
        healthReporter.start(pid: getpid(), startedAt: startedAt)

        await waitForShutdown()
        await teardown()
    }

    /// Dispatches an IPC request to the appropriate subsystem.
    public func handle(_ request: IPCRequest) async -> IPCResponse {
        switch request {
        case .ping:
            return .pong
        case .status:
            return await .status(makeStatus())
        case .reload:
            await onReload()
            return .ok("configuration reloaded")
        case .pause:
            await supervisor.stop()
            paused = true
            return .ok("collection paused")
        case .resume:
            await supervisor.start()
            paused = false
            return .ok("collection resumed")
        case .flush:
            await pipeline.flush()
            return .ok("buffer flushed")
        case .shutdown:
            requestShutdown()
            return .ok("shutting down")
        }
    }

    /// Reloads configuration (invoked by the config-file watcher).
    public func reload() async {
        await onReload()
    }

    /// Requests a graceful shutdown (idempotent).
    public func requestShutdown() {
        guard !didRequestShutdown else { return }
        didRequestShutdown = true
        shutdownContinuation?.resume()
        shutdownContinuation = nil
    }

    // MARK: - Lifecycle helpers

    private func startIPCServer() throws {
        let server = IPCServer(path: socketPath) { [weak self] request in
            guard let self else { return .failure("agent unavailable") }
            return await handle(request)
        }
        try server.start()
        ipcServer = server
        logger.info("ipc server listening", metadata: ["socket": .string(socketPath)])
    }

    private func waitForShutdown() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            if didRequestShutdown {
                continuation.resume()
            } else {
                shutdownContinuation = continuation
            }
        }
    }

    private func teardown() async {
        logger.notice("chronicled stopping")
        ipcServer?.stop()
        ipcServer = nil
        for source in signalSources {
            source.cancel()
        }
        signalSources.removeAll()
        await supervisor.stop()
        await pipeline.shutdown()
        try? await store.checkpoint()
        healthReporter.stop()
        logger.notice("chronicled stopped")
    }

    private func makeStatus() async -> DaemonStatus {
        let total = await (try? store.totalCount()) ?? -1
        let metrics = await pipeline.snapshot()
        let modules = await supervisor.activeModuleIDs()
        return DaemonStatus(
            pid: getpid(),
            startedAtEpoch: startedAt.timeIntervalSince1970,
            paused: paused,
            totalEvents: total,
            ingested: metrics.ingested,
            persisted: metrics.persisted,
            deduplicated: metrics.deduplicated,
            rejected: metrics.rejected,
            buffered: metrics.buffered,
            enabledModules: modules,
            databasePath: databasePath
        )
    }

    private func installSignalHandlers() {
        for signalNumber in [SIGTERM, SIGINT] {
            signal(signalNumber, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: .global())
            source.setEventHandler { [agent = self] in
                Task { await agent.requestShutdown() }
            }
            source.resume()
            signalSources.append(source)
        }

        signal(SIGHUP, SIG_IGN)
        let hup = DispatchSource.makeSignalSource(signal: SIGHUP, queue: .global())
        hup.setEventHandler { [agent = self] in
            Task { await agent.onReloadRequested() }
        }
        hup.resume()
        signalSources.append(hup)
    }

    private func onReloadRequested() async {
        logger.info("reload requested (SIGHUP)")
        await onReload()
    }
}
