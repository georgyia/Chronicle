import Foundation

/// Resolves the on-disk locations Chronicle uses at runtime.
///
/// All paths derive from a single `home` directory so tests can run against a
/// throwaway sandbox by pointing `CHRONICLE_HOME` at a temp directory. Individual
/// locations can be overridden via environment variables for advanced setups.
public struct ChroniclePaths: Sendable, Equatable {
    /// The TOML configuration file (`~/.config/chronicle/config.toml`).
    public let configFile: URL
    /// The data directory (`~/Library/Application Support/Chronicle`).
    public let dataDirectory: URL
    /// The SQLite database file.
    public let databaseFile: URL
    /// The daemon control socket.
    public let socketFile: URL
    /// The logs directory.
    public let logsDirectory: URL
    /// The active daemon log file.
    public let logFile: URL
    /// The LaunchAgent property list.
    public let launchAgentFile: URL

    /// Derives all paths from a home directory.
    public init(home: URL) {
        configFile = home
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("chronicle", isDirectory: true)
            .appendingPathComponent("config.toml")

        dataDirectory = home
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("Chronicle", isDirectory: true)
        databaseFile = dataDirectory.appendingPathComponent("chronicle.sqlite")
        socketFile = dataDirectory.appendingPathComponent("chronicle.sock")

        logsDirectory = home
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("Chronicle", isDirectory: true)
        logFile = logsDirectory.appendingPathComponent("chronicle.log")

        launchAgentFile = home
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(ChronicleConstants.launchAgentLabel).plist")
    }

    /// Resolves paths from the process environment, honoring overrides.
    ///
    /// Recognized variables: `CHRONICLE_HOME` (sandbox root), `CHRONICLE_CONFIG`,
    /// `CHRONICLE_DB_PATH`, `CHRONICLE_SOCKET`.
    public static func resolve(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> ChroniclePaths {
        let home: URL = if let override = environment["CHRONICLE_HOME"], !override.isEmpty {
            URL(fileURLWithPath: (override as NSString).expandingTildeInPath, isDirectory: true)
        } else {
            FileManager.default.homeDirectoryForCurrentUser
        }

        var paths = ChroniclePaths(home: home)
        paths = paths.applyingOverrides(from: environment)
        return paths
    }

    private func applyingOverrides(from environment: [String: String]) -> ChroniclePaths {
        ChroniclePaths(
            configFile: environment["CHRONICLE_CONFIG"].map(Self.expand) ?? configFile,
            dataDirectory: dataDirectory,
            databaseFile: environment["CHRONICLE_DB_PATH"].map(Self.expand) ?? databaseFile,
            socketFile: environment["CHRONICLE_SOCKET"].map(Self.expand) ?? socketFile,
            logsDirectory: logsDirectory,
            logFile: logFile,
            launchAgentFile: launchAgentFile
        )
    }

    private init(
        configFile: URL,
        dataDirectory: URL,
        databaseFile: URL,
        socketFile: URL,
        logsDirectory: URL,
        logFile: URL,
        launchAgentFile: URL
    ) {
        self.configFile = configFile
        self.dataDirectory = dataDirectory
        self.databaseFile = databaseFile
        self.socketFile = socketFile
        self.logsDirectory = logsDirectory
        self.logFile = logFile
        self.launchAgentFile = launchAgentFile
    }

    private static func expand(_ path: String) -> URL {
        URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
    }
}

/// Process-wide constants that are genuinely fixed identifiers, not tunables.
public enum ChronicleConstants {
    /// The reverse-DNS label used for the LaunchAgent and logging subsystem.
    public static let launchAgentLabel = "dev.chronicle.agent"
    /// The IPC protocol version spoken by this build.
    public static let ipcProtocolVersion = 1
    /// The current storage schema version.
    public static let schemaVersion = 1
}
