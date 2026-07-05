import Foundation
import Logging

/// A swift-log `LogHandler` that emits structured JSON lines to a rotating file.
public struct RotatingFileLogHandler: LogHandler {
    private let label: String
    private let writer: RotatingFileWriter

    public var logLevel: Logger.Level
    public var metadata: Logger.Metadata

    /// Creates a file log handler for a given label writing to `writer`.
    public init(label: String, writer: RotatingFileWriter, level: Logger.Level = .info) {
        self.label = label
        self.writer = writer
        logLevel = level
        metadata = [:]
    }

    public var metadataProvider: Logger.MetadataProvider?

    public subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }

    public func log(event: LogEvent) {
        let merged = mergedMetadata(event.metadata)
        let record = LogRecord(
            timestamp: Date(),
            level: event.level,
            label: label,
            message: event.message.description,
            metadata: merged.flattened(),
            source: event.source
        )
        writer.append(record)
    }

    private func mergedMetadata(_ explicit: Logger.Metadata?) -> Logger.Metadata {
        guard let explicit, !explicit.isEmpty else { return metadata }
        return metadata.merging(explicit) { _, new in new }
    }
}

/// A swift-log `LogHandler` that renders human-readable lines to standard error.
///
/// Used for foreground runs; under launchd, standard error is redirected to the
/// daemon's log file.
public struct ConsoleLogHandler: LogHandler {
    private let label: String
    private let stream: TextOutputStreamBox

    public var logLevel: Logger.Level
    public var metadata: Logger.Metadata

    /// Creates a console handler for `label`.
    public init(label: String, level: Logger.Level = .info) {
        self.label = label
        stream = TextOutputStreamBox()
        logLevel = level
        metadata = [:]
    }

    public var metadataProvider: Logger.MetadataProvider?

    public subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }

    public func log(event: LogEvent) {
        let merged = metadata.merging(event.metadata ?? [:]) { _, new in new }
        let suffix = merged.isEmpty
            ? ""
            : " " + merged.flattened().sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
        stream.write("\(event.level.label) \(label): \(event.message)\(suffix)\n")
    }
}

/// A minimal thread-safe wrapper around standard error.
final class TextOutputStreamBox: @unchecked Sendable {
    private let lock = NSLock()

    func write(_ string: String) {
        lock.lock()
        defer { lock.unlock() }
        FileHandle.standardError.write(Data(string.utf8))
    }
}

extension Logger.Level {
    /// A fixed-width, uppercased label for console output.
    var label: String {
        switch self {
        case .trace: "TRACE"
        case .debug: "DEBUG"
        case .info: "INFO "
        case .notice: "NOTE "
        case .warning: "WARN "
        case .error: "ERROR"
        case .critical: "CRIT "
        }
    }
}
