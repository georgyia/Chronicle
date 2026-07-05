import ChronicleCore
import ChronicleModels
import Foundation

/// A SplitMix64 pseudo-random generator for reproducible tests.
public struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    /// Creates a generator seeded with a fixed value.
    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var mixed = state
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58476D1CE4E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D049BB133111EB
        return mixed ^ (mixed >> 31)
    }
}

/// A `WallClock` whose time can be set and advanced explicitly.
public final class FixedWallClock: WallClock, @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    /// Creates a clock fixed at `date` (defaults to the Unix epoch).
    public init(_ date: Date = Date(timeIntervalSince1970: 0)) {
        current = date
    }

    public func now() -> Date {
        lock.lock()
        defer { lock.unlock() }
        return current
    }

    /// Advances the clock by a time interval.
    public func advance(by interval: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        current = current.addingTimeInterval(interval)
    }

    /// Sets the clock to an absolute instant.
    public func set(_ date: Date) {
        lock.lock()
        defer { lock.unlock() }
        current = date
    }
}

/// An `IdentifierFactory` producing deterministic, time-ordered ids for tests.
public final class DeterministicIdentifierFactory: IdentifierFactory, @unchecked Sendable {
    private let lock = NSLock()
    private var counter: UInt64

    /// Creates a factory starting at `seed`.
    public init(seed: UInt64 = 1) {
        counter = seed
    }

    public func makeEventID(at date: Date) -> EventID {
        lock.lock()
        let value = counter
        counter &+= 1
        lock.unlock()

        var generator = SeededRandomNumberGenerator(seed: value ^ UInt64(bitPattern: date.millisecondsSince1970))
        return EventID(rawValue: UUIDv7.make(millisecondsSince1970: date.millisecondsSince1970, using: &generator))
    }

    public func makeSessionID() -> SessionID {
        lock.lock()
        let value = counter
        counter &+= 1
        lock.unlock()

        var generator = SeededRandomNumberGenerator(seed: value &* 0xD1B54A32D192ED03)
        return SessionID(rawValue: UUIDv7.make(millisecondsSince1970: 0, using: &generator))
    }
}
