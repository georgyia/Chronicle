import ChronicleTestSupport
import Foundation
import Logging
import Testing
@testable import ChronicleLogging

@Suite("Rotating file logging")
struct RotatingFileWriterTests {
    @Test("Writes one JSON line per record")
    func writesJSONLines() throws {
        let directory = try TemporaryDirectory()
        defer { directory.remove() }
        let url = directory.file("chronicle.log")
        let writer = RotatingFileWriter(fileURL: url)

        writer.append(record(level: .info, message: "hello"))
        writer.append(record(level: .error, message: "boom"))
        writer.flush()

        let lines = try String(contentsOf: url, encoding: .utf8)
            .split(separator: "\n")
            .map(String.init)
        #expect(lines.count == 2)

        let first = try JSONSerialization.jsonObject(with: Data(lines[0].utf8)) as? [String: Any]
        #expect(first?["level"] as? String == "info")
        #expect(first?["message"] as? String == "hello")
    }

    @Test("Rotates when the size threshold is exceeded")
    func rotates() throws {
        let directory = try TemporaryDirectory()
        defer { directory.remove() }
        let url = directory.file("chronicle.log")
        let writer = RotatingFileWriter(fileURL: url, maxByteCount: 200, maxFileCount: 2)

        for index in 0..<50 {
            writer.append(record(level: .info, message: "message number \(index) with padding"))
        }
        writer.flush()

        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(FileManager.default.fileExists(atPath: url.path + ".1"))
        // Oldest beyond maxFileCount must not exist.
        #expect(!FileManager.default.fileExists(atPath: url.path + ".3"))
    }

    @Test("Bootstrap-free logger writes through the file handler")
    func loggerFactory() throws {
        let directory = try TemporaryDirectory()
        defer { directory.remove() }
        let url = directory.file("app.log")
        let logger = ChronicleLogging.makeLogger(label: "test", destination: .file(url), level: .debug)
        logger.debug("structured", metadata: ["k": "v"])

        let contents = try String(contentsOf: url, encoding: .utf8)
        #expect(contents.contains("\"message\":\"structured\""))
        #expect(contents.contains("\"k\":\"v\""))
    }

    private func record(level: Logger.Level, message: String) -> LogRecord {
        LogRecord(
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            level: level,
            label: "test",
            message: message,
            metadata: [:],
            source: "ChronicleLoggingTests"
        )
    }
}
