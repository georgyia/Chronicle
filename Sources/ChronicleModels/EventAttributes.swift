import Foundation

/// A keyed bag of typed attributes attached to an ``Event``.
///
/// Attributes are serialized to a single JSON column in storage. Well-known keys
/// are exposed as constants (see ``AttributeKey``) so collectors and queries share
/// a vocabulary rather than trading stringly-typed keys.
public struct EventAttributes: Sendable, Hashable, Codable {
    private var storage: [String: JSONValue]

    /// Creates an empty attribute bag.
    public init() {
        storage = [:]
    }

    /// Creates an attribute bag from a dictionary of values.
    public init(_ values: [String: JSONValue]) {
        storage = values
    }

    /// The backing dictionary of attribute values.
    public var values: [String: JSONValue] {
        storage
    }

    /// Whether any attributes are present.
    public var isEmpty: Bool {
        storage.isEmpty
    }

    /// Reads or writes the raw value for a key.
    public subscript(key: String) -> JSONValue? {
        get { storage[key] }
        set { storage[key] = newValue }
    }

    /// Reads or writes the value for a well-known attribute key.
    public subscript(key: AttributeKey) -> JSONValue? {
        get { storage[key.rawValue] }
        set { storage[key.rawValue] = newValue }
    }

    /// Returns the string value for a well-known key, if present and a string.
    public func string(_ key: AttributeKey) -> String? {
        storage[key.rawValue]?.stringValue
    }

    /// Returns the integer value for a well-known key, if present and an int.
    public func int(_ key: AttributeKey) -> Int64? {
        storage[key.rawValue]?.intValue
    }

    /// Returns the boolean value for a well-known key, if present and a bool.
    public func bool(_ key: AttributeKey) -> Bool? {
        storage[key.rawValue]?.boolValue
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(storage)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        storage = try container.decode([String: JSONValue].self)
    }
}

extension EventAttributes: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (AttributeKey, JSONValue)...) {
        storage = Dictionary(
            elements.map { ($0.0.rawValue, $0.1) },
            uniquingKeysWith: { _, last in last }
        )
    }
}

/// Well-known attribute keys shared across collectors, storage, and queries.
///
/// Using a namespaced constant set keeps the attribute vocabulary discoverable
/// and prevents subtle typos from fragmenting the event schema.
public struct AttributeKey: Sendable, Hashable, RawRepresentable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        rawValue = value
    }

    /// Absolute filesystem path.
    public static let path: AttributeKey = "path"
    /// Previous path for move/rename events.
    public static let fromPath: AttributeKey = "from_path"
    /// Human-readable title (window titles, page titles).
    public static let title: AttributeKey = "title"
    /// Application display name.
    public static let appName: AttributeKey = "app_name"
    /// Application bundle identifier.
    public static let bundleID: AttributeKey = "bundle_id"
    /// Operating-system process identifier.
    public static let pid: AttributeKey = "pid"
    /// A URL (download origin, browser visit).
    public static let url: AttributeKey = "url"
    /// A shell command line.
    public static let command: AttributeKey = "command"
    /// Working directory for a command.
    public static let cwd: AttributeKey = "cwd"
    /// Process or command exit code.
    public static let exitCode: AttributeKey = "exit_code"
    /// A git repository path.
    public static let repository: AttributeKey = "repository"
    /// A git branch name.
    public static let branch: AttributeKey = "branch"
    /// A git commit SHA.
    public static let commit: AttributeKey = "commit"
    /// A size in bytes.
    public static let byteCount: AttributeKey = "byte_count"
}
