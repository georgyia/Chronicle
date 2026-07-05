import Foundation
import Logging

/// A flattened, `Sendable` snapshot of a single log entry.
///
/// Handlers build a `LogRecord` and hand it to a writer; the writer owns
/// serialization and I/O under its lock, keeping formatting off the hot path and
/// thread-safe without sharing non-`Sendable` formatters.
public struct LogRecord: Sendable {
    /// When the entry was emitted.
    public let timestamp: Date
    /// The severity level.
    public let level: Logger.Level
    /// The logger label (subsystem).
    public let label: String
    /// The rendered log message.
    public let message: String
    /// Flattened metadata key/value pairs.
    public let metadata: [String: String]
    /// The source module reported by swift-log.
    public let source: String

    /// Creates a log record.
    public init(
        timestamp: Date,
        level: Logger.Level,
        label: String,
        message: String,
        metadata: [String: String],
        source: String
    ) {
        self.timestamp = timestamp
        self.level = level
        self.label = label
        self.message = message
        self.metadata = metadata
        self.source = source
    }
}

extension Logger.Metadata {
    /// Flattens structured metadata into string key/value pairs for compact logs.
    func flattened() -> [String: String] {
        reduce(into: [String: String]()) { result, pair in
            result[pair.key] = pair.value.flattenedDescription
        }
    }
}

extension Logger.MetadataValue {
    /// A stable string rendering of a metadata value.
    var flattenedDescription: String {
        switch self {
        case let .string(value): value
        case let .stringConvertible(value): value.description
        case let .dictionary(value): "{" + value.map { "\($0.key):\($0.value.flattenedDescription)" }.sorted()
            .joined(separator: ",") + "}"
        case let .array(value): "[" + value.map(\.flattenedDescription).joined(separator: ",") + "]"
        }
    }
}
