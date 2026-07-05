import ChronicleCore
import ChronicleModels
import ChronicleTestSupport
import Foundation
import Testing
@testable import ChronicleStorage

@Suite("Full-text search")
struct SearchTests {
    @Test("Finds events by indexed text and returns a snippet")
    func basicSearch() async throws {
        let store = try SQLiteEventStore.inMemory()
        try await store.insert([
            EventFactory.event(attributes: [.path: "/Users/me/Documents/invoice-2026.pdf"]),
            EventFactory.event(attributes: [.path: "/Users/me/Documents/notes.txt"]),
            EventFactory.event(kind: .browserVisit, source: .browser, attributes: [.title: "Quarterly invoice review"]),
        ])

        let hits = try await store.search(matching: EventQuery(text: "invoice"))
        #expect(hits.count == 2)
        #expect(hits.allSatisfy { $0.snippet?.contains("⟦") ?? false })
    }

    @Test("Prefix matching finds partial terms")
    func prefixSearch() async throws {
        let store = try SQLiteEventStore.inMemory()
        try await store.insert([
            EventFactory.event(attributes: [.path: "/tmp/report.md"]),
        ])
        let hits = try await store.search(matching: EventQuery(text: "rep"))
        #expect(hits.count == 1)
    }

    @Test("Search respects additional filters")
    func filteredSearch() async throws {
        let store = try SQLiteEventStore.inMemory()
        try await store.insert([
            EventFactory.event(kind: .fileCreated, attributes: [.path: "/tmp/invoice.pdf"]),
            EventFactory.event(kind: .browserVisit, source: .browser, attributes: [.title: "invoice"]),
        ])
        let hits = try await store.search(matching: EventQuery(sources: [.browser], text: "invoice"))
        #expect(hits.count == 1)
        #expect(hits.first?.event.source == .browser)
    }
}

@Suite("Statistics")
struct StatisticsTests {
    @Test("Counts by kind and source")
    func kindAndSource() async throws {
        let store = try SQLiteEventStore.inMemory()
        try await store.insert([
            EventFactory.event(kind: .fileCreated, source: .filesystem),
            EventFactory.event(kind: .fileCreated, source: .filesystem, attributes: [.path: "/tmp/b"]),
            EventFactory.event(kind: .appLaunched, source: .application, attributes: [.appName: "Mail"]),
        ])
        let byKind = try await store.countByKind(in: nil)
        #expect(byKind[.fileCreated] == 2)
        #expect(byKind[.appLaunched] == 1)

        let bySource = try await store.countBySource(in: nil)
        #expect(bySource[.filesystem] == 2)
    }

    @Test("Top apps are ranked by frequency")
    func topApps() async throws {
        let store = try SQLiteEventStore.inMemory()
        try await store.insert([
            EventFactory.event(kind: .appActivated, source: .application, attributes: [.appName: "Safari"]),
            EventFactory.event(kind: .appActivated, source: .application, attributes: [.appName: "Safari"]),
            EventFactory.event(kind: .appActivated, source: .application, attributes: [.appName: "Xcode"]),
        ])
        let apps = try await store.countByApp(in: nil, limit: 5)
        #expect(apps.first?.app == "Safari")
        #expect(apps.first?.count == 2)
    }

    @Test("Hour histogram buckets by local hour")
    func histogram() async throws {
        let store = try SQLiteEventStore.inMemory()
        try await store.insert(EventFactory.sequence(count: 3))
        let histogram = try await store.hourHistogram(in: nil)
        #expect(histogram.values.reduce(0, +) == 3)
    }
}
