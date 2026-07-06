import ChronicleCore
import ChronicleModels
import Foundation

/// Records web page visits by polling browser history databases incrementally.
///
/// Off by default. Safari support requires Full Disk Access; Chromium-based
/// browsers do not. A per-browser cursor (max visit time) advances each poll so
/// only new visits are recorded. Private-browsing visits are never written to the
/// history databases, so they are never recorded.
public struct BrowserHistoryCollector: EventCollector {
    public let descriptor = CollectorDescriptor(
        id: "browser",
        source: .browser,
        displayName: "Browser History",
        summary: "Records the pages you visit (excludes private browsing).",
        enabledByDefault: false,
        isSensitive: true,
        requiresFullDiskAccess: true
    )

    private let browsers: [String]
    private let clock: any WallClock
    private let interval: Duration

    /// Creates a browser history collector.
    public init(browsers: [String], clock: any WallClock = SystemWallClock(), interval: Duration = .seconds(10)) {
        self.browsers = browsers
        self.clock = clock
        self.interval = interval
    }

    public func events() -> AsyncStream<RawEvent> {
        let profiles = BrowserHistoryReader.profiles(for: browsers)
        let clock = clock
        let interval = interval
        return AsyncStream { continuation in
            let task = Task {
                var cursors = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, Date().timeIntervalSince1970) })
                while !Task.isCancelled {
                    try? await Task.sleep(for: interval)
                    if Task.isCancelled { break }
                    for profile in profiles {
                        let since = cursors[profile.id] ?? Date().timeIntervalSince1970
                        let visits = BrowserHistoryReader.readVisits(profile, sinceUnix: since)
                        for visit in visits {
                            cursors[profile.id] = max(cursors[profile.id] ?? since, visit.unixTime)
                            continuation.yield(Self.event(from: visit, browser: profile.id, clock: clock))
                        }
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func event(from visit: BrowserVisit, browser: String, clock: any WallClock) -> RawEvent {
        var attributes: EventAttributes = [.url: .string(visit.url), .appName: .string(browser)]
        if let title = visit.title, !title.isEmpty { attributes[.title] = .string(title) }
        return RawEvent(
            timestamp: Date(timeIntervalSince1970: visit.unixTime),
            kind: .browserVisit,
            source: .browser,
            attributes: attributes
        )
    }
}
