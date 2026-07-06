import ChronicleCore
import ChronicleModels
import Foundation

/// Records git commits by tailing the `HEAD` reflog of repositories discovered
/// under the configured roots.
///
/// Off by default. Repositories are discovered once at start; each repo's
/// `.git/logs/HEAD` is polled for appended commit entries.
public struct GitCollector: EventCollector {
    public let descriptor = CollectorDescriptor(
        id: "git",
        source: .git,
        displayName: "Git",
        summary: "Records commits in your repositories.",
        enabledByDefault: false
    )

    private let repositoryRoots: [String]
    private let clock: any WallClock
    private let interval: Duration

    /// Creates a git collector.
    public init(repositoryRoots: [String], clock: any WallClock = SystemWallClock(), interval: Duration = .seconds(3)) {
        self.repositoryRoots = repositoryRoots.map { ($0 as NSString).expandingTildeInPath }
        self.clock = clock
        self.interval = interval
    }

    public func events() -> AsyncStream<RawEvent> {
        let roots = repositoryRoots
        let clock = clock
        let interval = interval
        return AsyncStream { continuation in
            let task = Task {
                let logs = Self.discoverReflogs(under: roots)
                var offsets = Self.initialOffsets(for: logs)
                while !Task.isCancelled {
                    try? await Task.sleep(for: interval)
                    if Task.isCancelled { break }
                    for (repo, logPath) in logs {
                        Self.drain(repo: repo, logPath: logPath, offsets: &offsets, clock: clock) { event in
                            continuation.yield(event)
                        }
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Discovers `(repositoryPath, reflogPath)` pairs one level under each root.
    static func discoverReflogs(under roots: [String]) -> [(repo: String, log: String)] {
        var result: [(repo: String, log: String)] = []
        let manager = FileManager.default
        for root in roots {
            guard let entries = try? manager.contentsOfDirectory(atPath: root) else { continue }
            for entry in entries {
                let repo = (root as NSString).appendingPathComponent(entry)
                let log = (repo as NSString).appendingPathComponent(".git/logs/HEAD")
                if manager.fileExists(atPath: log) { result.append((repo: repo, log: log)) }
            }
        }
        return result
    }

    private static func initialOffsets(for logs: [(repo: String, log: String)]) -> [String: UInt64] {
        var offsets: [String: UInt64] = [:]
        for entry in logs {
            let attributes = try? FileManager.default.attributesOfItem(atPath: entry.log)
            offsets[entry.log] = (attributes?[.size] as? NSNumber)?.uint64Value ?? 0
        }
        return offsets
    }

    private static func drain(
        repo: String,
        logPath: String,
        offsets: inout [String: UInt64],
        clock: any WallClock,
        yield: (RawEvent) -> Void
    ) {
        guard let handle = try? FileHandle(forReadingFrom: URL(fileURLWithPath: logPath)) else { return }
        defer { try? handle.close() }
        let start = offsets[logPath] ?? 0
        try? handle.seek(toOffset: start)
        guard let data = try? handle.readToEnd(), !data.isEmpty else { return }
        offsets[logPath] = start + UInt64(data.count)

        let text = String(bytes: data, encoding: .utf8) ?? ""
        for line in text.split(separator: "\n") {
            guard let commit = GitReflogParser.parse(String(line)) else { continue }
            let attributes: EventAttributes = [
                .repository: .string(repo),
                .commit: .string(commit.sha),
                .title: .string(commit.message),
            ]
            yield(RawEvent(timestamp: clock.now(), kind: .gitCommit, source: .git, attributes: attributes))
        }
    }
}
