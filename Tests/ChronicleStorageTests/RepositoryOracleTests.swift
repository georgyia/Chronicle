import ChronicleCore
import ChronicleModels
import ChronicleTestSupport
import Foundation
import Testing
@testable import ChronicleStorage

/// Property-style tests: the SQLite repository must agree with the obviously-correct
/// in-memory reference implementation across a variety of queries.
@Suite("Repository oracle agreement")
struct RepositoryOracleTests {
    private static let kinds: [EventKind] = [.fileCreated, .fileModified, .appLaunched, .appActivated, .browserVisit]
    private static let sources: [CollectorSource] = [.filesystem, .application, .browser]

    private func makeEvents(count: Int, seed: UInt64) -> [Event] {
        var generator = SeededRandomNumberGenerator(seed: seed)
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let factory = DeterministicIdentifierFactory(seed: seed)
        return (0..<count).map { index in
            let timestamp = base.addingTimeInterval(Double(index) * 37) // unique, ordered
            let kind = Self.kinds[Int(generator.next() % UInt64(Self.kinds.count))]
            let source = Self.sources[Int(generator.next() % UInt64(Self.sources.count))]
            return Event(
                id: factory.makeEventID(at: timestamp),
                timestamp: timestamp,
                kind: kind,
                source: source,
                attributes: [.path: .string("/tmp/file-\(index).txt")]
            )
        }
    }

    private func assertAgreement(_ query: EventQuery, on events: [Event]) async throws {
        let sqlite = try SQLiteEventStore.inMemory()
        let oracle = InMemoryEventRepository()
        try await sqlite.insert(events)
        try await oracle.insert(events)

        let sqliteResult = try await sqlite.events(matching: query).map(\.id)
        let oracleResult = try await oracle.events(matching: query).map(\.id)
        #expect(sqliteResult == oracleResult)

        let sqliteCount = try await sqlite.count(matching: query)
        let oracleCount = try await oracle.count(matching: query)
        #expect(sqliteCount == oracleCount)
    }

    @Test("Agreement across filter and ordering combinations")
    func agreement() async throws {
        let events = makeEvents(count: 200, seed: 0xC0FFEE)
        let base = Date(timeIntervalSince1970: 1_700_000_000)

        try await assertAgreement(EventQuery(), on: events)
        try await assertAgreement(EventQuery(order: .ascending), on: events)
        try await assertAgreement(EventQuery(kinds: [.fileCreated, .appLaunched]), on: events)
        try await assertAgreement(EventQuery(sources: [.browser]), on: events)
        try await assertAgreement(EventQuery(limit: 25), on: events)
        try await assertAgreement(
            EventQuery(range: DateInterval(start: base, duration: 2000), order: .ascending),
            on: events
        )
        try await assertAgreement(
            EventQuery(kinds: [.appActivated], sources: [.application], order: .descending, limit: 10),
            on: events
        )
    }
}
