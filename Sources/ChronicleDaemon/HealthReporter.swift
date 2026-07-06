import Foundation

/// Periodically writes a small JSON health file so `chronicle doctor` can detect a
/// running (and recently-alive) agent even when the control socket is busy.
public final class HealthReporter: @unchecked Sendable {
    private let url: URL
    private let interval: Duration
    private let lock = NSLock()
    private var task: Task<Void, Never>?

    /// Creates a health reporter writing to `url`.
    public init(url: URL, interval: Duration = .seconds(15)) {
        self.url = url
        self.interval = interval
    }

    /// Writes the initial health file and begins beating.
    public func start(pid: Int32, startedAt: Date) {
        write(pid: pid, startedAt: startedAt)
        let url = url
        let interval = interval
        lock.lock()
        task = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard !Task.isCancelled else { break }
                self?.write(pid: pid, startedAt: startedAt)
            }
            _ = url
        }
        lock.unlock()
    }

    /// Stops beating and removes the health file.
    public func stop() {
        lock.lock()
        task?.cancel()
        task = nil
        lock.unlock()
        try? FileManager.default.removeItem(at: url)
    }

    private func write(pid: Int32, startedAt: Date) {
        let payload: [String: Any] = [
            "pid": Int(pid),
            "started_at": startedAt.timeIntervalSince1970,
            "beat_at": Date().timeIntervalSince1970,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]) else { return }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: url, options: .atomic)
    }
}
