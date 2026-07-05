import ChronicleConfig
import ChronicleLogging
import Foundation
import Logging

// Composition root for the Chronicle agent.
// The full supervisor/pipeline/IPC wiring lands in Phase 4; this M0 entry point
// resolves paths, loads configuration, and bootstraps structured logging so the
// executable is runnable and observable from day one.

let paths = ChroniclePaths.resolve()
let loader = ConfigurationLoader()
let configuration = (try? loader.loadOrDefault(from: paths.configFile)) ?? ChronicleConfiguration()

let level = Logger.Level(rawValue: configuration.logging.level) ?? .info
ChronicleLogging.bootstrap(destination: .both(paths.logFile), level: level)

let log = Logger(label: ChronicleConstants.launchAgentLabel)
log.info("chronicled starting", metadata: [
    "database": .string(paths.databaseFile.path),
    "socket": .string(paths.socketFile.path),
])
log.notice("Phase 4 wiring not yet enabled; exiting cleanly.")
