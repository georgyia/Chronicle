import ChronicleCore
import ChronicleModels
import Foundation

/// A reconstructed span of continuous activity.
public struct ActivitySession: Sendable, Equatable {
    /// When the session started.
    public let start: Date
    /// When the session ended (timestamp of its last event).
    public let end: Date
    /// Number of events in the session.
    public let eventCount: Int
    /// The most frequent application names, most frequent first.
    public let topApps: [String]
    /// The sources that contributed events.
    public let sources: Set<CollectorSource>

    /// Creates an activity session.
    public init(start: Date, end: Date, eventCount: Int, topApps: [String], sources: Set<CollectorSource>) {
        self.start = start
        self.end = end
        self.eventCount = eventCount
        self.topApps = topApps
        self.sources = sources
    }
}

/// Groups events into activity sessions separated by idle gaps.
///
/// A new session begins whenever the gap between consecutive events exceeds
/// `idleGap`. Pure and unit-tested; powers `timeline --sessions` and enriches
/// `explain`.
public enum SessionReconstructor {
    /// The default idle gap that separates sessions (15 minutes).
    public static let defaultIdleGap: TimeInterval = 15 * 60

    /// Reconstructs sessions from events (any order; sorted internally).
    public static func sessions(from events: [Event], idleGap: TimeInterval = defaultIdleGap) -> [ActivitySession] {
        let sorted = events.sorted { $0.timestamp < $1.timestamp }
        guard !sorted.isEmpty else { return [] }

        var sessions: [ActivitySession] = []
        var current: [Event] = []

        for event in sorted {
            if let last = current.last, event.timestamp.timeIntervalSince(last.timestamp) > idleGap {
                sessions.append(summarize(current))
                current = []
            }
            current.append(event)
        }
        if !current.isEmpty { sessions.append(summarize(current)) }
        return sessions
    }

    private static func summarize(_ events: [Event]) -> ActivitySession {
        let start = events.first?.timestamp ?? Date()
        let end = events.last?.timestamp ?? start

        var appCounts: [String: Int] = [:]
        var sources: Set<CollectorSource> = []
        for event in events {
            sources.insert(event.source)
            if let app = event.attributes.string(.appName) { appCounts[app, default: 0] += 1 }
        }
        let topApps = appCounts
            .sorted { $0.value > $1.value || ($0.value == $1.value && $0.key < $1.key) }
            .prefix(3)
            .map(\.key)

        return ActivitySession(
            start: start,
            end: end,
            eventCount: events.count,
            topApps: Array(topApps),
            sources: sources
        )
    }
}
