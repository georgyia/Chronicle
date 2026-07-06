import ChronicleCore
import ChronicleModels
import Foundation

/// An application count within a statistics report.
public struct AppCount: Sendable, Equatable {
    /// The application name.
    public let app: String
    /// The number of events.
    public let count: Int

    /// Creates an app count.
    public init(app: String, count: Int) {
        self.app = app
        self.count = count
    }
}

/// Aggregated statistics over a time range.
public struct StatisticsReport: Sendable, Equatable {
    /// The range covered, or `nil` for all time.
    public let range: DateInterval?
    /// Total events in range.
    public let total: Int
    /// Counts by event kind.
    public let byKind: [EventKind: Int]
    /// Counts by collector source.
    public let bySource: [CollectorSource: Int]
    /// Top applications by event count.
    public let topApps: [AppCount]
    /// Counts bucketed by local hour of day.
    public let hourHistogram: [Int: Int]

    /// Creates a statistics report.
    public init(
        range: DateInterval?,
        total: Int,
        byKind: [EventKind: Int],
        bySource: [CollectorSource: Int],
        topApps: [AppCount],
        hourHistogram: [Int: Int]
    ) {
        self.range = range
        self.total = total
        self.byKind = byKind
        self.bySource = bySource
        self.topApps = topApps
        self.hourHistogram = hourHistogram
    }
}

/// The query engine facade the CLI depends on.
///
/// Built from the kernel repository protocols (never a concrete store), so it is
/// storage-agnostic and testable with the in-memory oracle.
public struct QueryService: Sendable {
    private let events: any EventRepository
    private let search: any SearchRepository
    private let statistics: any StatisticsRepository

    /// Creates a query service over the repository protocols.
    public init(
        events: any EventRepository,
        search: any SearchRepository,
        statistics: any StatisticsRepository
    ) {
        self.events = events
        self.search = search
        self.statistics = statistics
    }

    /// Fetches a chronological slice of events.
    public func timeline(_ query: EventQuery) async throws -> [Event] {
        try await events.events(matching: query)
    }

    /// Runs a full-text search and applies recency-aware ranking.
    public func find(_ query: EventQuery, now: Date = Date()) async throws -> [SearchHit] {
        let hits = try await search.search(matching: query)
        return RelevanceRanker.rank(hits, now: now)
    }

    /// Reconstructs activity sessions over a range.
    public func sessions(
        range: DateInterval?,
        idleGap: TimeInterval = SessionReconstructor.defaultIdleGap
    ) async throws -> [ActivitySession] {
        let events = try await events.events(matching: EventQuery(range: range, order: .ascending, limit: nil))
        return SessionReconstructor.sessions(from: events, idleGap: idleGap)
    }

    /// Looks up one event by id.
    public func inspect(id: EventID) async throws -> Event? {
        try await events.event(id: id)
    }

    /// Builds an aggregate statistics report for a range.
    public func report(range: DateInterval?, topAppLimit: Int = 10) async throws -> StatisticsReport {
        async let total = events.count(matching: EventQuery(range: range))
        async let byKind = statistics.countByKind(in: range)
        async let bySource = statistics.countBySource(in: range)
        async let topApps = statistics.countByApp(in: range, limit: topAppLimit)
        async let histogram = statistics.hourHistogram(in: range)

        return try await StatisticsReport(
            range: range,
            total: total,
            byKind: byKind,
            bySource: bySource,
            topApps: topApps.map { AppCount(app: $0.app, count: $0.count) },
            hourHistogram: histogram
        )
    }
}
