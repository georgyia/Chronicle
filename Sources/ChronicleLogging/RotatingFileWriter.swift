import Foundation

/// A thread-safe, size-based rotating log file writer.
///
/// When appending a line would exceed ``maxByteCount``, the current file is
/// rotated (`chronicle.log` -> `chronicle.log.1` -> ... up to ``maxFileCount``)
/// and the oldest file is discarded. All mutation happens under a lock, so the
/// type is safe to share across the concurrent log handlers swift-log copies.
public final class RotatingFileWriter: @unchecked Sendable {
    private let fileURL: URL
    private let maxByteCount: Int
    private let maxFileCount: Int
    private let lock = NSLock()
    private let formatter: ISO8601DateFormatter
    private var handle: FileHandle?
    private var currentByteCount: Int

    /// Creates a rotating file writer.
    /// - Parameters:
    ///   - fileURL: The active log file location.
    ///   - maxByteCount: The size threshold that triggers rotation.
    ///   - maxFileCount: The number of rotated files to retain (excluding the active file).
    public init(fileURL: URL, maxByteCount: Int = 5 * 1024 * 1024, maxFileCount: Int = 5) {
        self.fileURL = fileURL
        self.maxByteCount = maxByteCount
        self.maxFileCount = maxFileCount
        formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        currentByteCount = 0
        openFile()
    }

    deinit {
        try? handle?.close()
    }

    /// Serializes and appends a log record as a single JSON line.
    public func append(_ record: LogRecord) {
        lock.lock()
        defer { lock.unlock() }

        let line = serialize(record)
        guard let data = (line + "\n").data(using: .utf8) else { return }

        if currentByteCount + data.count > maxByteCount, currentByteCount > 0 {
            rotate()
        }

        do {
            try handle?.write(contentsOf: data)
            currentByteCount += data.count
        } catch {
            // Logging must never crash the host process; drop on write failure.
        }
    }

    /// Flushes any buffered bytes to disk.
    public func flush() {
        lock.lock()
        defer { lock.unlock() }
        try? handle?.synchronize()
    }

    // MARK: - Private

    private func serialize(_ record: LogRecord) -> String {
        var object: [String: Any] = [
            "ts": formatter.string(from: record.timestamp),
            "level": record.level.rawValue,
            "label": record.label,
            "message": record.message,
        ]
        if !record.source.isEmpty { object["source"] = record.source }
        if !record.metadata.isEmpty { object["metadata"] = record.metadata }

        guard
            let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
            let string = String(data: data, encoding: .utf8)
        else {
            return "{\"level\":\"\(record.level.rawValue)\",\"message\":\"<unserializable>\"}"
        }
        return string
    }

    private func openFile() {
        let manager = FileManager.default
        let directory = fileURL.deletingLastPathComponent()
        try? manager.createDirectory(at: directory, withIntermediateDirectories: true)
        if !manager.fileExists(atPath: fileURL.path) {
            manager.createFile(atPath: fileURL.path, contents: nil)
        }
        handle = try? FileHandle(forWritingTo: fileURL)
        let size = (try? handle?.seekToEnd()).flatMap { Int($0) } ?? 0
        currentByteCount = size
    }

    private func rotate() {
        let manager = FileManager.default
        try? handle?.close()
        handle = nil

        let basePath = fileURL.path
        if maxFileCount > 0 {
            let oldest = "\(basePath).\(maxFileCount)"
            try? manager.removeItem(atPath: oldest)
            for index in stride(from: maxFileCount - 1, through: 1, by: -1) {
                let source = "\(basePath).\(index)"
                let destination = "\(basePath).\(index + 1)"
                if manager.fileExists(atPath: source) {
                    try? manager.moveItem(atPath: source, toPath: destination)
                }
            }
            try? manager.moveItem(atPath: basePath, toPath: "\(basePath).1")
        } else {
            try? manager.removeItem(atPath: basePath)
        }

        manager.createFile(atPath: basePath, contents: nil)
        handle = try? FileHandle(forWritingTo: fileURL)
        currentByteCount = 0
    }
}
