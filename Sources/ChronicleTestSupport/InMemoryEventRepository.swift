import ChronicleCore
import ChronicleModels
import Foundation

/// A reference `EventRepository` implementation backed by an in-memory array.
///
/// Serves as a fast fake for unit tests and as an oracle for property tests that
/// compare the SQLite repository's behaviour against a simple, obviously-correct
/// model.
public actor InMemoryEventRepository: EventRepository, SearchRepository, StatisticsRepository {
    private var events: [Event] = []
    private var digests: Set<EventDigest> = []

    /// Creates an empty repository.
    public init() {}

    @discardableResult
    public func insert(_ newEvents: [Event]) async throws -> Int {
        var inserted = 0
        for event in newEvents {
            if let digest = event.dedupeDigest, digests.contains(digest) { continue }
            if let digest = event.dedupeDigest { digests.insert(digest) }
            events.append(event)
            inserted += 1
        }
        return inserted
    }

    public func events(matching query: EventQuery) async throws -> [Event] {
        var results = events.filter { matches($0, query) }
        results.sort(by: ordering(query.order))
        results = applyPagination(results, query: query)
        if let limit = query.limit { results = Array(results.prefix(limit)) }
        return results
    }

    public func count(matching query: EventQuery) async throws -> Int {
        events.count(where: { matches($0, query) })
    }

    public func event(id: EventID) async throws -> Event? {
        events.first { $0.id == id }
    }

    @discardableResult
    public func deleteEvents(before date: Date) async throws -> Int {
        let before = events.count
        events.removeAll { $0.timestamp < date }
        return before - events.count
    }

    @discardableResult
    public func deleteEvents(matching query: EventQuery) async throws -> Int {
        let before = events.count
        events.removeAll { matches($0, query) }
        return before - events.count
    }

    public func totalCount() async throws -> Int {
        events.count
    }

    // MARK: - SearchRepository

    public func search(matching query: EventQuery) async throws -> [SearchHit] {
        let matched = try await events(matching: query)
        return matched.map { SearchHit(event: $0, snippet: nil, score: 1) }
    }

    // MARK: - StatisticsRepository

    public func countByKind(in range: DateInterval?) async throws -> [EventKind: Int] {
        aggregate(range) { $0.kind }
    }

    public func countBySource(in range: DateInterval?) async throws -> [CollectorSource: Int] {
        aggregate(range) { $0.source }
    }

    public func countByApp(in range: DateInterval?, limit: Int) async throws -> [(app: String, count: Int)] {
        let counts = aggregate(range) { $0.attributes.string(.appName) ?? "" }
            .filter { !$0.key.isEmpty }
        return counts
            .sorted { $0.value > $1.value || ($0.value == $1.value && $0.key < $1.key) }
            .prefix(limit)
            .map { (app: $0.key, count: $0.value) }
    }

    public func hourHistogram(in range: DateInterval?) async throws -> [Int: Int] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return aggregate(range) { calendar.component(.hour, from: $0.timestamp) }
    }

    // MARK: - Helpers

    private func aggregate<Key: Hashable>(_ range: DateInterval?, _ key: (Event) -> Key) -> [Key: Int] {
        events
            .filter { event in range.map { $0.contains(event.timestamp) } ?? true }
            .reduce(into: [:]) { $0[key($1), default: 0] += 1 }
    }

    private func matches(_ event: Event, _ query: EventQuery) -> Bool {
        if let range = query.range, !range.contains(event.timestamp) { return false }
        if !query.kinds.isEmpty, !query.kinds.contains(event.kind) { return false }
        if !query.sources.isEmpty, !query.sources.contains(event.source) { return false }
        if let prefix = query.pathPrefix,
           !(event.attributes.string(.path)?.hasPrefix(prefix) ?? false) { return false }
        if let app = query.appName,
           event.attributes.string(.appName)?.caseInsensitiveCompare(app) != .orderedSame { return false }
        if let text = query.text, !text.isEmpty, !containsText(event, text) { return false }
        return true
    }

    private func containsText(_ event: Event, _ needle: String) -> Bool {
        let haystacks = [
            event.attributes.string(.path),
            event.attributes.string(.title),
            event.attributes.string(.appName),
            event.attributes.string(.command),
            event.attributes.string(.url),
        ].compactMap(\.self)
        return haystacks.contains { $0.range(of: needle, options: .caseInsensitive) != nil }
    }

    private func ordering(_ order: EventSortOrder) -> (Event, Event) -> Bool {
        { lhs, rhs in
            if lhs.timestamp == rhs.timestamp {
                return order == .ascending ? lhs.id < rhs.id : rhs.id < lhs.id
            }
            return order == .ascending ? lhs.timestamp < rhs.timestamp : lhs.timestamp > rhs.timestamp
        }
    }

    private func applyPagination(_ events: [Event], query: EventQuery) -> [Event] {
        guard let cursor = query.pageAfter else { return events }
        let ordering = ordering(query.order)
        let anchor = self.events.first { $0.id == cursor }
        guard let anchor else { return events }
        return events.filter { ordering(anchor, $0) }
    }
}
