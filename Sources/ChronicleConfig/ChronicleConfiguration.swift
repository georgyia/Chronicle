import Foundation

/// The fully-resolved Chronicle configuration.
///
/// Every field has a default, and decoding tolerates partial files (missing keys
/// fall back to defaults), so a hand-edited config never needs to be exhaustive.
/// Validation is a separate, explicit step (see `ConfigurationLoader`).
public struct ChronicleConfiguration: Sendable, Equatable, Codable {
    /// Storage and retention settings.
    public var storage: StorageConfiguration
    /// Logging settings.
    public var logging: LoggingConfiguration
    /// Daemon runtime settings.
    public var daemon: DaemonConfiguration
    /// Ingestion pipeline settings.
    public var pipeline: PipelineConfiguration
    /// Per-module enable/disable toggles keyed by module id.
    public var modules: [String: Bool]
    /// Filesystem collector settings.
    public var filesystem: FilesystemConfiguration
    /// Clipboard collector settings.
    public var clipboard: ClipboardConfiguration
    /// Browser collector settings.
    public var browser: BrowserConfiguration
    /// Git collector settings.
    public var git: GitConfiguration
    /// AI settings.
    public var ai: AIConfiguration

    /// Creates a configuration, defaulting every section.
    public init(
        storage: StorageConfiguration = .init(),
        logging: LoggingConfiguration = .init(),
        daemon: DaemonConfiguration = .init(),
        pipeline: PipelineConfiguration = .init(),
        modules: [String: Bool] = [:],
        filesystem: FilesystemConfiguration = .init(),
        clipboard: ClipboardConfiguration = .init(),
        browser: BrowserConfiguration = .init(),
        git: GitConfiguration = .init(),
        ai: AIConfiguration = .init()
    ) {
        self.storage = storage
        self.logging = logging
        self.daemon = daemon
        self.pipeline = pipeline
        self.modules = modules
        self.filesystem = filesystem
        self.clipboard = clipboard
        self.browser = browser
        self.git = git
        self.ai = ai
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        storage = try container.decodeIfPresent(StorageConfiguration.self, forKey: .storage) ?? .init()
        logging = try container.decodeIfPresent(LoggingConfiguration.self, forKey: .logging) ?? .init()
        daemon = try container.decodeIfPresent(DaemonConfiguration.self, forKey: .daemon) ?? .init()
        pipeline = try container.decodeIfPresent(PipelineConfiguration.self, forKey: .pipeline) ?? .init()
        modules = try container.decodeIfPresent([String: Bool].self, forKey: .modules) ?? [:]
        filesystem = try container.decodeIfPresent(FilesystemConfiguration.self, forKey: .filesystem) ?? .init()
        clipboard = try container.decodeIfPresent(ClipboardConfiguration.self, forKey: .clipboard) ?? .init()
        browser = try container.decodeIfPresent(BrowserConfiguration.self, forKey: .browser) ?? .init()
        git = try container.decodeIfPresent(GitConfiguration.self, forKey: .git) ?? .init()
        ai = try container.decodeIfPresent(AIConfiguration.self, forKey: .ai) ?? .init()
    }

    /// Returns whether a module is enabled, falling back to `defaultEnabled`
    /// when the config does not mention it.
    public func isModuleEnabled(_ id: String, defaultEnabled: Bool) -> Bool {
        modules[id] ?? defaultEnabled
    }
}

/// Storage and retention settings.
public struct StorageConfiguration: Sendable, Equatable, Codable {
    /// How many days of history to retain (0 means keep forever).
    public var retentionDays: Int
    /// Optional absolute override for the database path.
    public var databasePath: String?

    public init(retentionDays: Int = 365, databasePath: String? = nil) {
        self.retentionDays = retentionDays
        self.databasePath = databasePath
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        retentionDays = try container.decodeIfPresent(Int.self, forKey: .retentionDays) ?? 365
        databasePath = try container.decodeIfPresent(String.self, forKey: .databasePath)
    }
}

/// Logging settings.
public struct LoggingConfiguration: Sendable, Equatable, Codable {
    /// Minimum log level: `trace|debug|info|notice|warning|error|critical`.
    public var level: String
    /// Output destination: `console|file|both`.
    public var destination: String

    public init(level: String = "info", destination: String = "file") {
        self.level = level
        self.destination = destination
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        level = try container.decodeIfPresent(String.self, forKey: .level) ?? "info"
        destination = try container.decodeIfPresent(String.self, forKey: .destination) ?? "file"
    }
}

/// Daemon runtime settings.
public struct DaemonConfiguration: Sendable, Equatable, Codable {
    /// Maximum events written per transaction.
    public var batchSize: Int
    /// Maximum time to buffer events before flushing, in milliseconds.
    public var flushIntervalMilliseconds: Int

    public init(batchSize: Int = 128, flushIntervalMilliseconds: Int = 1000) {
        self.batchSize = batchSize
        self.flushIntervalMilliseconds = flushIntervalMilliseconds
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        batchSize = try container.decodeIfPresent(Int.self, forKey: .batchSize) ?? 128
        flushIntervalMilliseconds = try container.decodeIfPresent(Int.self, forKey: .flushIntervalMilliseconds) ?? 1000
    }
}

/// Ingestion pipeline settings.
public struct PipelineConfiguration: Sendable, Equatable, Codable {
    /// Coalescing window for duplicate suppression, in milliseconds.
    public var dedupeWindowMilliseconds: Int
    /// Number of recent digests kept in the dedupe cache.
    public var dedupeCacheSize: Int

    public init(dedupeWindowMilliseconds: Int = 2000, dedupeCacheSize: Int = 4096) {
        self.dedupeWindowMilliseconds = dedupeWindowMilliseconds
        self.dedupeCacheSize = dedupeCacheSize
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dedupeWindowMilliseconds = try container.decodeIfPresent(Int.self, forKey: .dedupeWindowMilliseconds) ?? 2000
        dedupeCacheSize = try container.decodeIfPresent(Int.self, forKey: .dedupeCacheSize) ?? 4096
    }
}

/// Filesystem collector settings.
public struct FilesystemConfiguration: Sendable, Equatable, Codable {
    /// Directories to watch (tilde-expanded).
    public var watchPaths: [String]
    /// Glob fragments whose presence in a path excludes the event.
    public var excludePatterns: [String]
    /// Whether to record events for hidden files.
    public var includeHidden: Bool

    public init(
        watchPaths: [String] = ["~"],
        excludePatterns: [String] = FilesystemConfiguration.defaultExclusions,
        includeHidden: Bool = false
    ) {
        self.watchPaths = watchPaths
        self.excludePatterns = excludePatterns
        self.includeHidden = includeHidden
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        watchPaths = try container.decodeIfPresent([String].self, forKey: .watchPaths) ?? ["~"]
        excludePatterns = try container.decodeIfPresent([String].self, forKey: .excludePatterns)
            ?? FilesystemConfiguration.defaultExclusions
        includeHidden = try container.decodeIfPresent(Bool.self, forKey: .includeHidden) ?? false
    }

    /// Noise directories excluded by default.
    public static let defaultExclusions = [
        "/.git/", "/node_modules/", "/.build/", "/DerivedData/",
        "/Library/Caches/", "/.Trash/", "/.npm/", "/.cache/",
    ]
}

/// Clipboard collector settings.
public struct ClipboardConfiguration: Sendable, Equatable, Codable {
    /// Store only a hash of clipboard contents, never the text itself.
    public var hashOnly: Bool
    /// Bundle identifiers whose clipboard activity is ignored (e.g. password managers).
    public var ignoreApps: [String]

    public init(
        hashOnly: Bool = true,
        ignoreApps: [String] = ["com.agilebits.onepassword7", "com.1password.1password"]
    ) {
        self.hashOnly = hashOnly
        self.ignoreApps = ignoreApps
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hashOnly = try container.decodeIfPresent(Bool.self, forKey: .hashOnly) ?? true
        ignoreApps = try container.decodeIfPresent([String].self, forKey: .ignoreApps)
            ?? ["com.agilebits.onepassword7", "com.1password.1password"]
    }
}

/// Browser collector settings.
public struct BrowserConfiguration: Sendable, Equatable, Codable {
    /// Browsers to import history from: `safari|chrome|arc|firefox`.
    public var browsers: [String]

    public init(browsers: [String] = ["safari", "chrome"]) {
        self.browsers = browsers
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        browsers = try container.decodeIfPresent([String].self, forKey: .browsers) ?? ["safari", "chrome"]
    }
}

/// Git collector settings.
public struct GitConfiguration: Sendable, Equatable, Codable {
    /// Directories under which git repositories are discovered and watched.
    public var repositoryRoots: [String]

    public init(repositoryRoots: [String] = ["~/Developer", "~/Projects"]) {
        self.repositoryRoots = repositoryRoots
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        repositoryRoots = try container.decodeIfPresent([String].self, forKey: .repositoryRoots)
            ?? ["~/Developer", "~/Projects"]
    }
}

/// AI settings. Disabled by default; no network access unless explicitly enabled.
public struct AIConfiguration: Sendable, Equatable, Codable {
    /// Whether AI features are enabled at all.
    public var enabled: Bool
    /// Provider: `local|openai|ollama`.
    public var provider: String
    /// Model identifier for the selected provider.
    public var model: String
    /// Optional custom endpoint for self-hosted or compatible providers.
    public var endpoint: String?
    /// Whether to run the redaction gate before any content leaves the machine.
    public var redactBeforeEgress: Bool

    public init(
        enabled: Bool = false,
        provider: String = "local",
        model: String = "chronicle-local",
        endpoint: String? = nil,
        redactBeforeEgress: Bool = true
    ) {
        self.enabled = enabled
        self.provider = provider
        self.model = model
        self.endpoint = endpoint
        self.redactBeforeEgress = redactBeforeEgress
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        provider = try container.decodeIfPresent(String.self, forKey: .provider) ?? "local"
        model = try container.decodeIfPresent(String.self, forKey: .model) ?? "chronicle-local"
        endpoint = try container.decodeIfPresent(String.self, forKey: .endpoint)
        redactBeforeEgress = try container.decodeIfPresent(Bool.self, forKey: .redactBeforeEgress) ?? true
    }
}
