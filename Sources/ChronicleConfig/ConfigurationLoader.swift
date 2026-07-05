import Foundation
import TOMLKit

/// Loads, validates, encodes, and persists ``ChronicleConfiguration``.
///
/// Resolution order (lowest to highest precedence): built-in defaults, the TOML
/// file, then `CHRONICLE_*` environment overrides. Validation is explicit so the
/// CLI can surface actionable errors before the daemon starts.
public struct ConfigurationLoader: Sendable {
    /// Creates a configuration loader.
    public init() {}

    // MARK: - Loading

    /// Loads and validates configuration from a file, applying environment overrides.
    /// - Throws: ``ConfigError`` if the file is unreadable, malformed, or invalid.
    public func load(
        from url: URL,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> ChronicleConfiguration {
        let string: String
        do {
            string = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw ConfigError.unreadable(path: url.path, reason: error.localizedDescription)
        }
        var config = try decode(string)
        config = applyEnvironmentOverrides(to: config, environment: environment)
        try validate(config)
        return config
    }

    /// Loads configuration if the file exists, otherwise returns validated defaults.
    public func loadOrDefault(
        from url: URL,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> ChronicleConfiguration {
        if FileManager.default.fileExists(atPath: url.path) {
            return try load(from: url, environment: environment)
        }
        let config = applyEnvironmentOverrides(to: ChronicleConfiguration(), environment: environment)
        try validate(config)
        return config
    }

    /// Decodes a configuration from a TOML string (no environment overlay).
    public func decode(_ toml: String) throws -> ChronicleConfiguration {
        do {
            return try TOMLDecoder().decode(ChronicleConfiguration.self, from: toml)
        } catch {
            throw ConfigError.malformed(reason: error.localizedDescription)
        }
    }

    /// Encodes a configuration to a TOML string.
    public func encode(_ config: ChronicleConfiguration) throws -> String {
        do {
            return try TOMLEncoder().encode(config)
        } catch {
            throw ConfigError.malformed(reason: error.localizedDescription)
        }
    }

    // MARK: - Persisting

    /// Writes a configuration atomically with owner-only permissions, creating
    /// the parent directory if needed.
    public func save(_ config: ChronicleConfiguration, to url: URL) throws {
        let toml = try encode(config)
        try write(toml, to: url)
    }

    /// Writes a commented default configuration if none exists yet.
    /// - Returns: `true` if a file was written, `false` if one already existed.
    @discardableResult
    public func writeDefaultIfMissing(to url: URL) throws -> Bool {
        guard !FileManager.default.fileExists(atPath: url.path) else { return false }
        try write(Self.defaultTemplate, to: url)
        return true
    }

    private func write(_ contents: String, to url: URL) throws {
        let directory = url.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try contents.write(to: url, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } catch {
            throw ConfigError.unwritable(path: url.path, reason: error.localizedDescription)
        }
    }

    // MARK: - Validation

    private static let validLevels: Set<String> = ["trace", "debug", "info", "notice", "warning", "error", "critical"]
    private static let validDestinations: Set<String> = ["console", "file", "both"]
    private static let validProviders: Set<String> = ["local", "openai", "ollama"]

    /// Validates a configuration, collecting all issues into a single error.
    public func validate(_ config: ChronicleConfiguration) throws {
        var issues: [String] = []

        if !Self.validLevels.contains(config.logging.level) {
            issues.append("logging.level '\(config.logging.level)' is not one of \(Self.validLevels.sorted())")
        }
        if !Self.validDestinations.contains(config.logging.destination) {
            let destination = config.logging.destination
            issues.append("logging.destination '\(destination)' is not one of \(Self.validDestinations.sorted())")
        }
        if config.storage.retentionDays < 0 {
            issues.append("storage.retention_days must be >= 0")
        }
        if config.daemon.batchSize <= 0 {
            issues.append("daemon.batch_size must be > 0")
        }
        if config.daemon.flushIntervalMilliseconds <= 0 {
            issues.append("daemon.flush_interval_milliseconds must be > 0")
        }
        if config.pipeline.dedupeCacheSize <= 0 {
            issues.append("pipeline.dedupe_cache_size must be > 0")
        }
        if config.pipeline.dedupeWindowMilliseconds < 0 {
            issues.append("pipeline.dedupe_window_milliseconds must be >= 0")
        }
        if config.ai.enabled, !Self.validProviders.contains(config.ai.provider) {
            issues.append("ai.provider '\(config.ai.provider)' is not one of \(Self.validProviders.sorted())")
        }

        guard issues.isEmpty else { throw ConfigError.validation(issues) }
    }

    // MARK: - Environment overrides

    private func applyEnvironmentOverrides(
        to config: ChronicleConfiguration,
        environment: [String: String]
    ) -> ChronicleConfiguration {
        var result = config

        if let level = environment["CHRONICLE_LOG_LEVEL"] {
            result.logging.level = level
        }
        if let retention = environment["CHRONICLE_RETENTION_DAYS"], let value = Int(retention) {
            result.storage.retentionDays = value
        }
        if let enabled = environment["CHRONICLE_AI_ENABLED"] {
            result.ai.enabled = Self.parseBool(enabled) ?? result.ai.enabled
        }

        let modulePrefix = "CHRONICLE_MODULE_"
        for (key, value) in environment where key.hasPrefix(modulePrefix) {
            let moduleID = key.dropFirst(modulePrefix.count).lowercased()
            if let flag = Self.parseBool(value), !moduleID.isEmpty {
                result.modules[String(moduleID)] = flag
            }
        }

        return result
    }

    private static func parseBool(_ raw: String) -> Bool? {
        switch raw.lowercased() {
        case "1", "true", "on", "yes", "enabled": true
        case "0", "false", "off", "no", "disabled": false
        default: nil
        }
    }
}
