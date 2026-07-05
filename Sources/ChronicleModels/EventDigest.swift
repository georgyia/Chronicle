import Foundation

/// A fixed-size content digest used to deduplicate semantically identical events.
///
/// The pipeline derives the digest from an event's salient content (kind, source,
/// key attributes, coarse timestamp) — deliberately excluding the random
/// ``EventID`` — so that repeated observations of the same underlying activity
/// collapse to a single stored row.
public struct EventDigest: Sendable, Hashable, Codable, CustomStringConvertible {
    /// The raw digest bytes.
    public let bytes: Data

    /// Creates a digest from raw bytes.
    public init(bytes: Data) {
        self.bytes = bytes
    }

    /// The lowercase hexadecimal representation of the digest.
    public var description: String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let hex = try container.decode(String.self)
        guard let data = Data(hexEncoded: hex) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid hex digest: \(hex)"
            )
        }
        bytes = data
    }
}

extension Data {
    /// Parses a hexadecimal string into raw bytes, or `nil` if malformed.
    init?(hexEncoded string: String) {
        let characters = Array(string)
        guard characters.count.isMultiple(of: 2) else { return nil }
        var data = Data(capacity: characters.count / 2)
        var index = characters.startIndex
        while index < characters.endIndex {
            guard
                let high = characters[index].hexDigitValue,
                let low = characters[characters.index(after: index)].hexDigitValue
            else { return nil }
            data.append(UInt8(high << 4 | low))
            index = characters.index(index, offsetBy: 2)
        }
        self = data
    }
}
