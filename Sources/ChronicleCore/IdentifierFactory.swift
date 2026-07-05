import ChronicleModels
import Foundation

/// Produces the identifiers used across the domain.
///
/// Injected wherever ids are minted so tests can supply deterministic values
/// instead of relying on ambient randomness.
public protocol IdentifierFactory: Sendable {
    /// Creates a time-ordered event identifier for the given instant.
    /// - Parameter date: The event timestamp; encoded into the UUIDv7 prefix.
    func makeEventID(at date: Date) -> EventID

    /// Creates a fresh session identifier.
    func makeSessionID() -> SessionID
}

/// An `IdentifierFactory` backed by the system random number generator.
public struct SystemIdentifierFactory: IdentifierFactory {
    /// Creates a system-backed identifier factory.
    public init() {}

    public func makeEventID(at date: Date) -> EventID {
        var generator = SystemRandomNumberGenerator()
        let milliseconds = Int64((date.timeIntervalSince1970 * 1000).rounded())
        return EventID(rawValue: UUIDv7.make(millisecondsSince1970: milliseconds, using: &generator))
    }

    public func makeSessionID() -> SessionID {
        SessionID(rawValue: UUID())
    }
}
