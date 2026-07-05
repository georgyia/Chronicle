import Foundation

/// A time-ordered unique identifier for a persisted ``Event``.
///
/// Backed by a UUIDv7 (RFC 9562) so that the lexicographic ordering of the raw
/// bytes matches chronological creation order. This lets storage rely on the id
/// for stable keyset pagination without a separate sequence column leaking into
/// the domain layer.
public struct EventID: Sendable, Hashable, Codable, Comparable, CustomStringConvertible {
    /// The underlying UUID value.
    public let rawValue: UUID

    /// Creates an identifier from an existing UUID value.
    /// - Parameter rawValue: The UUID to wrap. Callers are responsible for
    ///   ensuring it is a v7 UUID when time ordering is required.
    public init(rawValue: UUID) {
        self.rawValue = rawValue
    }

    /// The canonical lowercased string form, e.g. `018f...`.
    public var description: String {
        rawValue.uuidString.lowercased()
    }

    public static func < (lhs: EventID, rhs: EventID) -> Bool {
        lhs.rawValue.bytes.lexicographicallyPrecedes(rhs.rawValue.bytes)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let uuid = UUID(uuidString: string) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid EventID string: \(string)"
            )
        }
        rawValue = uuid
    }
}

/// Identifies a contiguous user session (login to logout / boot to shutdown).
///
/// Sessions group related events for timeline reconstruction and narration.
public struct SessionID: Sendable, Hashable, Codable, CustomStringConvertible {
    /// The underlying UUID value.
    public let rawValue: UUID

    /// Creates a session identifier from an existing UUID value.
    public init(rawValue: UUID) {
        self.rawValue = rawValue
    }

    /// The canonical lowercased string form.
    public var description: String {
        rawValue.uuidString.lowercased()
    }
}

/// RFC 9562 UUIDv7 generation utilities.
///
/// Pure functions with no ambient time or randomness so they remain fully
/// testable. Higher layers (see `IdentifierFactory` in `ChronicleCore`) supply a
/// clock and random source.
public enum UUIDv7 {
    /// Generates a UUIDv7 from a millisecond timestamp and a random source.
    ///
    /// - Parameters:
    ///   - millisecondsSince1970: Unix timestamp in milliseconds. Only the low
    ///     48 bits are used, matching the RFC field width.
    ///   - generator: The random number source for the 74 random bits.
    /// - Returns: A version-7, variant-10 UUID.
    public static func make(
        millisecondsSince1970: Int64,
        using generator: inout some RandomNumberGenerator
    ) -> UUID {
        let timestamp = UInt64(truncatingIfNeeded: millisecondsSince1970) & 0xFFFFFFFFFFFF
        var bytes = [UInt8](repeating: 0, count: 16)

        bytes[0] = UInt8((timestamp >> 40) & 0xFF)
        bytes[1] = UInt8((timestamp >> 32) & 0xFF)
        bytes[2] = UInt8((timestamp >> 24) & 0xFF)
        bytes[3] = UInt8((timestamp >> 16) & 0xFF)
        bytes[4] = UInt8((timestamp >> 8) & 0xFF)
        bytes[5] = UInt8(timestamp & 0xFF)

        let randA = UInt16.random(in: .min ... .max, using: &generator)
        bytes[6] = 0x70 | UInt8((randA >> 8) & 0x0F) // version 7 in the high nibble
        bytes[7] = UInt8(randA & 0xFF)

        let randB = UInt64.random(in: .min ... .max, using: &generator)
        bytes[8] = 0x80 | UInt8((randB >> 56) & 0x3F) // variant 10 in the top bits
        bytes[9] = UInt8((randB >> 48) & 0xFF)
        bytes[10] = UInt8((randB >> 40) & 0xFF)
        bytes[11] = UInt8((randB >> 32) & 0xFF)
        bytes[12] = UInt8((randB >> 24) & 0xFF)
        bytes[13] = UInt8((randB >> 16) & 0xFF)
        bytes[14] = UInt8((randB >> 8) & 0xFF)
        bytes[15] = UInt8(randB & 0xFF)

        return UUID(bytes: bytes)
    }
}

extension UUID {
    /// The 16 raw bytes of the UUID in network (big-endian) order.
    var bytes: [UInt8] {
        let uuid = uuid
        return [
            uuid.0, uuid.1, uuid.2, uuid.3,
            uuid.4, uuid.5, uuid.6, uuid.7,
            uuid.8, uuid.9, uuid.10, uuid.11,
            uuid.12, uuid.13, uuid.14, uuid.15,
        ]
    }

    /// Builds a UUID from exactly 16 bytes.
    /// - Parameter bytes: The 16 bytes; the initializer traps if fewer are given.
    init(bytes: [UInt8]) {
        precondition(bytes.count == 16, "UUID requires exactly 16 bytes")
        self.init(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
