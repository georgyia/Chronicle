import ChronicleCore
import Foundation

/// Errors raised while loading, decoding, or validating configuration.
public enum ConfigError: ChronicleError, Equatable {
    /// The configuration file could not be read.
    case unreadable(path: String, reason: String)
    /// The configuration file was not valid TOML or did not match the schema.
    case malformed(reason: String)
    /// The configuration decoded but failed one or more validation checks.
    case validation([String])
    /// The configuration file could not be written.
    case unwritable(path: String, reason: String)

    public var code: String {
        switch self {
        case .unreadable: "config.unreadable"
        case .malformed: "config.malformed"
        case .validation: "config.validation"
        case .unwritable: "config.unwritable"
        }
    }

    public var message: String {
        switch self {
        case let .unreadable(path, reason): "Cannot read config at \(path): \(reason)"
        case let .malformed(reason): "Malformed configuration: \(reason)"
        case let .validation(issues): "Invalid configuration:\n  - " + issues.joined(separator: "\n  - ")
        case let .unwritable(path, reason): "Cannot write config at \(path): \(reason)"
        }
    }
}
