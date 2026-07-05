import Foundation

/// A strongly-typed, `Sendable` representation of a JSON value.
///
/// Chronicle stores event attributes as JSON in a single SQLite column. Modelling
/// the payload as a closed enum keeps the domain free of `Any` while still
/// allowing arbitrary, schema-flexible attributes per event kind.
public enum JSONValue: Sendable, Hashable, Codable {
    /// A string value.
    case string(String)
    /// A 64-bit integer value.
    case int(Int64)
    /// A double-precision floating point value.
    case double(Double)
    /// A boolean value.
    case bool(Bool)
    /// An ordered array of values.
    case array([JSONValue])
    /// A keyed object of values.
    case object([String: JSONValue])
    /// An explicit null.
    case null

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int64.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported JSON value"
            )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(value): try container.encode(value)
        case let .int(value): try container.encode(value)
        case let .double(value): try container.encode(value)
        case let .bool(value): try container.encode(value)
        case let .array(value): try container.encode(value)
        case let .object(value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

// MARK: - Convenience accessors

public extension JSONValue {
    /// The wrapped string, if this value is a `.string`.
    var stringValue: String? {
        if case let .string(value) = self { return value }
        return nil
    }

    /// The wrapped integer, if this value is an `.int`.
    var intValue: Int64? {
        if case let .int(value) = self { return value }
        return nil
    }

    /// The wrapped double, promoting integers to doubles when applicable.
    var doubleValue: Double? {
        switch self {
        case let .double(value): value
        case let .int(value): Double(value)
        default: nil
        }
    }

    /// The wrapped boolean, if this value is a `.bool`.
    var boolValue: Bool? {
        if case let .bool(value) = self { return value }
        return nil
    }
}

// MARK: - Ergonomic literals

extension JSONValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension JSONValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int64) {
        self = .int(value)
    }
}

extension JSONValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .double(value)
    }
}

extension JSONValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension JSONValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: JSONValue...) {
        self = .array(elements)
    }
}

extension JSONValue: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, JSONValue)...) {
        self = .object(Dictionary(elements, uniquingKeysWith: { _, last in last }))
    }
}
