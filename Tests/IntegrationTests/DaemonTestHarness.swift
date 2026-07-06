import ChronicleConfig
import ChronicleCore
import ChronicleDaemon
import ChronicleIPC
import ChronicleModels
import ChronicleStorage
import Foundation

/// A sandboxed, in-process Chronicle agent for integration tests.
///
/// Runs a real agent — real pipeline, supervisor, storage, and IPC socket — in a
/// throwaway temp directory with a short socket path, driven by a fast heartbeat
/// collector. This is the foundation the collector integration tests build on.
final class DaemonTestHarness: @unchecked Sendable {
    let store: SQLiteEventStore
    private let agent: ChronicleAgent
    private let client: IPCClient
    private let sandbox: URL
    private let socketPath: String
    private var runTask: Task<Void, any Error>?

    private init(store: SQLiteEventStore, agent: ChronicleAgent, client: IPCClient, sandbox: URL, socketPath: String) {
        self.store = store
        self.agent = agent
        self.client = client
        self.sandbox = sandbox
        self.socketPath = socketPath
    }

    /// Builds a harness with a fast heartbeat collector and eager flushing.
    static func make() throws -> DaemonTestHarness {
        let sandbox = FileManager.default.temporaryDirectory
            .appendingPathComponent("chronicle-it-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: sandbox, withIntermediateDirectories: true)

        let store = try SQLiteEventStore.open(at: sandbox.appendingPathComponent("chronicle.sqlite"))
        let socketPath = "/tmp/chr-\(UUID().uuidString.prefix(8)).sock"

        var configuration = ChronicleConfiguration()
        configuration.daemon.batchSize = 1
        configuration.daemon.flushIntervalMilliseconds = 100
        configuration.pipeline.dedupeWindowMilliseconds = 50
        configuration.modules["heartbeat"] = true

        let collectorFactory: @Sendable (ChronicleConfiguration) -> [any EventCollector] = { config in
            config.isModuleEnabled("heartbeat", defaultEnabled: false)
                ? [HeartbeatCollector(interval: .milliseconds(20))]
                : []
        }

        let agent = AgentAssembly.makeAgent(AgentInputs(
            store: store,
            configuration: configuration,
            configFile: sandbox.appendingPathComponent("config.toml"),
            socketPath: socketPath,
            databasePath: sandbox.appendingPathComponent("chronicle.sqlite").path,
            healthFileURL: sandbox.appendingPathComponent("agent.health"),
            collectorFactory: collectorFactory,
            logger: .init(label: "chronicle.test")
        ))

        return DaemonTestHarness(
            store: store,
            agent: agent,
            client: IPCClient(path: socketPath, timeout: 2),
            sandbox: sandbox,
            socketPath: socketPath
        )
    }

    /// Starts the agent and waits until its control socket is reachable.
    func start() async throws {
        let agent = agent
        runTask = Task { try await agent.run() }
        try await waitUntilReachable()
    }

    /// Sends a request over IPC, off the cooperative pool.
    func send(_ request: IPCRequest) async throws -> IPCResponse {
        let client = client
        return try await Task.detached { try client.send(request) }.value
    }

    /// Fetches the current daemon status.
    func status() async throws -> DaemonStatus {
        guard case let .status(status) = try await send(.status) else {
            throw HarnessError.unexpectedResponse
        }
        return status
    }

    /// Polls status until `predicate` holds or the timeout elapses.
    func waitForStatus(timeout: Duration = .seconds(5), _ predicate: @Sendable (DaemonStatus) -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while ContinuousClock.now < deadline {
            if let status = try? await status(), predicate(status) { return }
            try await Task.sleep(for: .milliseconds(25))
        }
        throw HarnessError.timedOut
    }

    /// Requests shutdown and awaits full teardown.
    func shutdown() async {
        await agent.requestShutdown()
        _ = try? await runTask?.value
    }

    /// Removes the sandbox directory.
    func cleanup() {
        try? FileManager.default.removeItem(at: sandbox)
    }

    private func waitUntilReachable(timeout: Duration = .seconds(5)) async throws {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while ContinuousClock.now < deadline {
            if case .pong = try? await send(.ping) { return }
            try await Task.sleep(for: .milliseconds(25))
        }
        throw HarnessError.timedOut
    }

    enum HarnessError: Error {
        case timedOut
        case unexpectedResponse
    }
}
