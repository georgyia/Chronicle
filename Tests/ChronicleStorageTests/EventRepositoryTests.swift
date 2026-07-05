import ChronicleCore
import ChronicleModels
import ChronicleTestSupport
import Foundation
import Testing
@testable import ChronicleStorage

@Suite("SQLite event repository")
struct EventRepositoryTests {
    @Test("Batch insert deduplicates on digest")
    func dedupe() async throws {
        let store = try SQLiteEventStore.inMemory()
        let digest = EventDigest(bytes: Data([1, 2, 3, 4]))
        let inserted = try await store.insert([
            EventFactory.event(dedupeDigest: digest),
            EventFactory.event(attributes: [.path: "/tmp/other"], dedupeDigest: digest),
        ])
        #expect(inserted == 1)
        #expect(try await store.totalCount() == 1)
    }

    @Test("Round-trips an event through storage")
    func roundTrip() async throws {
        let store = try SQLiteEventStore.inMemory()
        let event = EventFactory.event(
            kind: .appLaunched,
            source: .application,
            attributes: [.appName: "Safari", .bundleID: "com.apple.Safari", .pid: 42]
        )
        try await store.insert([event])
        let fetched = try await store.event(id: event.id)
        #expect(fetched == event)
    }

    @Test("Filters by kind, source, and range")
    func filters() async throws {
        let store = try SQLiteEventStore.inMemory()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        try await store.insert([
            EventFactory.event(timestamp: base, kind: .fileCreated, source: .filesystem),
            EventFactory.event(timestamp: base.addingTimeInterval(3600), kind: .appLaunched, source: .application),
            EventFactory.event(timestamp: base.addingTimeInterval(7200), kind: .fileModified, source: .filesystem),
        ])

        let files = try await store.events(matching: EventQuery(sources: [.filesystem]))
        #expect(files.count == 2)

        let apps = try await store.events(matching: EventQuery(kinds: [.appLaunched]))
        #expect(apps.count == 1)

        let window = DateInterval(start: base.addingTimeInterval(-1), duration: 10)
        #expect(try await store.count(matching: EventQuery(range: window)) == 1)
    }

    @Test("Filters by app name and path prefix")
    func appAndPath() async throws {
        let store = try SQLiteEventStore.inMemory()
        try await store.insert([
            EventFactory.event(kind: .appActivated, source: .application, attributes: [.appName: "Xcode"]),
            EventFactory.event(attributes: [.path: "/Users/me/Projects/a.swift"]),
            EventFactory.event(attributes: [.path: "/Users/me/Downloads/b.pdf"]),
        ])

        let xcode = try await store.events(matching: EventQuery(appName: "xcode"))
        #expect(xcode.count == 1)

        let projects = try await store.events(matching: EventQuery(pathPrefix: "/Users/me/Projects"))
        #expect(projects.count == 1)
    }

    @Test("Descending order returns newest first; limit applies")
    func orderingAndLimit() async throws {
        let store = try SQLiteEventStore.inMemory()
        let events = EventFactory.sequence(count: 10)
        try await store.insert(events)

        let newest = try await store.events(matching: EventQuery(order: .descending, limit: 3))
        #expect(newest.count == 3)
        #expect(newest.first?.timestamp == events.last?.timestamp)
    }

    @Test("Keyset pagination walks the full set without overlap")
    func pagination() async throws {
        let store = try SQLiteEventStore.inMemory()
        let events = EventFactory.sequence(count: 25)
        try await store.insert(events)

        var collected: [EventID] = []
        var cursor: EventID?
        while true {
            let page = try await store.events(
                matching: EventQuery(order: .descending, limit: 10, pageAfter: cursor)
            )
            if page.isEmpty { break }
            collected.append(contentsOf: page.map(\.id))
            cursor = page.last?.id
        }
        #expect(collected.count == 25)
        #expect(Set(collected).count == 25)
    }
}
