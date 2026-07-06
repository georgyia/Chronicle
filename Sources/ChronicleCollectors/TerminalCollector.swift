import ChronicleConfig
import ChronicleCore
import ChronicleModels
import Darwin
import Foundation

/// The JSON payload written by the shell integration for each command.
struct ShellCommandPayload: Codable {
    var command: String
    var cwd: String?
    var exit: Int?
}

/// Records shell commands received from the zsh integration over a FIFO.
///
/// Off by default and privacy-sensitive. The `chronicle shell-integration install`
/// command adds a zsh hook that writes one JSON line per command to the FIFO.
public struct TerminalCollector: EventCollector {
    public let descriptor = CollectorDescriptor(
        id: "terminal",
        source: .terminal,
        displayName: "Terminal",
        summary: "Records shell commands via the zsh integration.",
        enabledByDefault: false,
        isSensitive: true
    )

    private let fifoPath: String
    private let clock: any WallClock

    /// Creates a terminal collector.
    /// - Parameters:
    ///   - fifoPath: The FIFO the shell hook writes to (defaults under the data dir).
    ///   - clock: Time source for event timestamps.
    public init(fifoPath: String? = nil, clock: any WallClock = SystemWallClock()) {
        self.fifoPath = fifoPath
            ?? ChroniclePaths.resolve().dataDirectory.appendingPathComponent("terminal.fifo").path
        self.clock = clock
    }

    public func events() -> AsyncStream<RawEvent> {
        let clock = clock
        let fifoPath = fifoPath
        return AsyncStream { continuation in
            let reader = FIFOReader(path: fifoPath) { line in
                guard let event = Self.parse(line, clock: clock) else { return }
                continuation.yield(event)
            }
            reader.start()
            continuation.onTermination = { _ in reader.stop() }
        }
    }

    /// Parses a JSON command line into a shell event.
    static func parse(_ line: String, clock: any WallClock) -> RawEvent? {
        guard let data = line.data(using: .utf8),
              let payload = try? JSONDecoder().decode(ShellCommandPayload.self, from: data),
              !payload.command.isEmpty
        else { return nil }

        var attributes: EventAttributes = [.command: .string(payload.command)]
        if let cwd = payload.cwd { attributes[.cwd] = .string(cwd) }
        if let exit = payload.exit { attributes[.exitCode] = .int(Int64(exit)) }
        return RawEvent(timestamp: clock.now(), kind: .shellCommand, source: .terminal, attributes: attributes)
    }
}

/// Reads newline-delimited text from a FIFO, reopening as writers come and go.
final class FIFOReader: @unchecked Sendable {
    private let path: String
    private let handler: @Sendable (String) -> Void
    private let lock = NSLock()
    private var running = false
    private var thread: Thread?

    init(path: String, handler: @escaping @Sendable (String) -> Void) {
        self.path = path
        self.handler = handler
    }

    func start() {
        try? FileManager.default.createDirectory(
            at: URL(fileURLWithPath: path).deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if !FileManager.default.fileExists(atPath: path) {
            mkfifo(path, 0o600)
        }
        lock.lock()
        running = true
        lock.unlock()
        let thread = Thread { [weak self] in self?.loop() }
        thread.name = "chronicle.terminal.fifo"
        self.thread = thread
        thread.start()
    }

    func stop() {
        lock.lock()
        running = false
        lock.unlock()
    }

    private func isRunning() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return running
    }

    private func loop() {
        var buffer = Data()
        var descriptor = open(path, O_RDONLY | O_NONBLOCK)
        defer { if descriptor >= 0 { close(descriptor) } }

        var chunk = [UInt8](repeating: 0, count: 4096)
        while isRunning() {
            if descriptor < 0 {
                descriptor = open(path, O_RDONLY | O_NONBLOCK)
                if descriptor < 0 { usleep(200_000)
                    continue
                }
            }
            let count = read(descriptor, &chunk, chunk.count)
            if count > 0 {
                buffer.append(contentsOf: chunk[0..<count])
                emitLines(from: &buffer)
            } else {
                usleep(150_000)
            }
        }
    }

    private func emitLines(from buffer: inout Data) {
        while let newline = buffer.firstIndex(of: 0x0A) {
            let lineData = buffer[buffer.startIndex..<newline]
            buffer.removeSubrange(buffer.startIndex...newline)
            let line = (String(bytes: lineData, encoding: .utf8) ?? "").trimmingCharacters(in: .whitespaces)
            if !line.isEmpty { handler(line) }
        }
    }
}
