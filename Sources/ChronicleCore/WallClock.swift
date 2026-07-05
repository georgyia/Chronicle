import Foundation

/// Abstraction over "what time is it now", enabling deterministic tests.
///
/// Named `WallClock` to avoid colliding with the Swift standard library `Clock`
/// protocol, which models monotonic scheduling rather than wall-clock dates.
public protocol WallClock: Sendable {
    /// The current wall-clock instant.
    func now() -> Date
}

/// A `WallClock` backed by the system clock.
public struct SystemWallClock: WallClock {
    /// Creates a system-backed clock.
    public init() {}

    public func now() -> Date {
        Date()
    }
}
