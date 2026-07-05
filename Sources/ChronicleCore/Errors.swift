import Foundation

/// Common protocol for all Chronicle errors.
///
/// Every error carries a stable, machine-readable ``code`` (namespaced by module,
/// e.g. `storage.migration_failed`) that maps to a documented CLI exit code and
/// appears in structured logs, decoupling user-facing messages from control flow.
public protocol ChronicleError: Error, CustomStringConvertible {
    /// A stable, namespaced machine code for this error.
    var code: String { get }
    /// A human-readable description of what went wrong.
    var message: String { get }
}

public extension ChronicleError {
    /// A default `[code] message` rendering shared by all Chronicle errors.
    var description: String {
        "[\(code)] \(message)"
    }
}

/// Errors originating in the kernel layer.
public enum CoreError: ChronicleError, Equatable {
    /// A value failed validation with an explanation.
    case validation(String)
    /// A required precondition about the environment was not met.
    case precondition(String)

    public var code: String {
        switch self {
        case .validation: "core.validation"
        case .precondition: "core.precondition"
        }
    }

    public var message: String {
        switch self {
        case let .validation(detail): detail
        case let .precondition(detail): detail
        }
    }
}
