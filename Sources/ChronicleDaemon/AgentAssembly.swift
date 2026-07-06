import ChronicleConfig
import ChronicleCore
import ChronicleModels
import ChroniclePipeline
import ChronicleStorage
import Foundation
import Logging

/// The inputs required to assemble a ``ChronicleAgent``.
public struct AgentInputs: Sendable {
    /// The opened event store.
    public let store: SQLiteEventStore
    /// The current configuration.
    public let configuration: ChronicleConfiguration
    /// The config file to re-read on reload.
    public let configFile: URL
    /// The control socket path.
    public let socketPath: String
    /// The database path (for status reporting).
    public let databasePath: String
    /// Where the health file is written.
    public let healthFileURL: URL
    /// Builds the collector set for a configuration.
    public let collectorFactory: @Sendable (ChronicleConfiguration) -> [any EventCollector]
    /// Structured logger.
    public let logger: Logger

    /// Creates agent inputs.
    public init(
        store: SQLiteEventStore,
        configuration: ChronicleConfiguration,
        configFile: URL,
        socketPath: String,
        databasePath: String,
        healthFileURL: URL,
        collectorFactory: @escaping @Sendable (ChronicleConfiguration) -> [any EventCollector],
        logger: Logger
    ) {
        self.store = store
        self.configuration = configuration
        self.configFile = configFile
        self.socketPath = socketPath
        self.databasePath = databasePath
        self.healthFileURL = healthFileURL
        self.collectorFactory = collectorFactory
        self.logger = logger
    }
}

/// Builds a fully-wired ``ChronicleAgent`` from configuration and dependencies.
///
/// This is the daemon's composition helper: the only place where concrete
/// pipeline stages, the supervisor, and the agent are constructed and connected.
/// Keeping it here (rather than in `main`) makes the wiring unit-testable.
public enum AgentAssembly {
    /// Produces `PipelineSettings` from the user configuration.
    public static func pipelineSettings(from configuration: ChronicleConfiguration) -> PipelineSettings {
        PipelineSettings(
            batchSize: configuration.daemon.batchSize,
            flushInterval: .milliseconds(configuration.daemon.flushIntervalMilliseconds),
            dedupeWindow: .milliseconds(configuration.pipeline.dedupeWindowMilliseconds),
            dedupeCacheSize: configuration.pipeline.dedupeCacheSize
        )
    }

    /// Assembles an agent from its inputs.
    public static func makeAgent(_ inputs: AgentInputs) -> ChronicleAgent {
        let logger = inputs.logger
        let store = inputs.store
        let collectorFactory = inputs.collectorFactory
        let configFile = inputs.configFile
        let fallbackConfiguration = inputs.configuration

        let session = FixedSessionProvider(sessionID: SystemIdentifierFactory().makeSessionID())
        let processors: [any EventProcessor] = [
            ValidationProcessor(clock: SystemWallClock()),
            EnrichmentProcessor(session: session),
        ]
        let pipeline = EventPipeline(
            repository: store,
            identifierFactory: SystemIdentifierFactory(),
            processors: processors,
            settings: pipelineSettings(from: inputs.configuration),
            logger: logger
        )
        let supervisor = CollectorSupervisor(
            collectors: collectorFactory(inputs.configuration),
            sink: pipeline,
            logger: logger
        )
        let healthReporter = HealthReporter(url: inputs.healthFileURL)

        let onReload: @Sendable () async -> Void = {
            let loader = ConfigurationLoader()
            let reloaded = (try? loader.loadOrDefault(from: configFile)) ?? fallbackConfiguration
            await supervisor.reconfigure(collectorFactory(reloaded))
            logger.info("configuration reloaded", metadata: ["config": .string(configFile.path)])
        }

        return ChronicleAgent(
            store: store,
            pipeline: pipeline,
            supervisor: supervisor,
            socketPath: inputs.socketPath,
            databasePath: inputs.databasePath,
            healthReporter: healthReporter,
            onReload: onReload,
            logger: logger
        )
    }
}
