import ChronicleCollectors
import ChronicleConfig
import ChronicleCore
import ChronicleDaemon
import ChronicleLogging
import ChronicleStorage
import Foundation
import Logging

// Composition root for the Chronicle agent (`chronicled run`).
// Resolves paths, loads configuration, bootstraps logging, opens storage, and
// assembles and runs the agent. Concrete types meet only here.

let paths = ChroniclePaths.resolve()
let loader = ConfigurationLoader()
_ = try? loader.writeDefaultIfMissing(to: paths.configFile)
let configuration = (try? loader.loadOrDefault(from: paths.configFile)) ?? ChronicleConfiguration()

let level = Logger.Level(rawValue: configuration.logging.level) ?? .info
ChronicleLogging.bootstrap(destination: .both(paths.logFile), level: level)
let logger = Logger(label: ChronicleConstants.launchAgentLabel)

do {
    let store = try SQLiteEventStore.open(at: paths.databaseFile)

    // Build the enabled collector set from configuration; the heartbeat module
    // remains available as an opt-in diagnostic.
    let collectorFactory: @Sendable (ChronicleConfiguration) -> [any EventCollector] = { config in
        var collectors = CollectorFactory.makeCollectors(configuration: config)
        if config.isModuleEnabled("heartbeat", defaultEnabled: false) {
            collectors.append(HeartbeatCollector())
        }
        return collectors
    }

    let agent = AgentAssembly.makeAgent(AgentInputs(
        store: store,
        configuration: configuration,
        configFile: paths.configFile,
        socketPath: paths.socketFile.path,
        databasePath: paths.databaseFile.path,
        healthFileURL: paths.dataDirectory.appendingPathComponent("agent.health"),
        collectorFactory: collectorFactory,
        logger: logger
    ))

    // Hot-reload configuration when the file changes on disk (D5).
    let configWatcher = ConfigurationFileWatcher(url: paths.configFile) {
        Task { await agent.reload() }
    }
    configWatcher.start()
    defer { configWatcher.stop() }

    try await agent.run()
} catch {
    logger.critical("chronicled failed to start", metadata: ["error": .string("\(error)")])
    exit(1)
}
