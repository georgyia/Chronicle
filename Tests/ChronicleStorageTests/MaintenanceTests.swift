import ChronicleCore
import ChronicleModels
import ChronicleTestSupport
import Foundation
import Testing
@testable import ChronicleStorage

@Suite("Retention & maintenance")
struct MaintenanceTests {
    @Test("Deletes events before a cutoff and keeps FTS in sync")
    func deleteBefore() async throws {
        let store = try SQLiteEventStore.inMemory()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        try await store.insert([
            EventFactory.event(timestamp: base, attributes: [.path: "/tmp/old-invoice.pdf"]),
            EventFactory.event(timestamp: base.addingTimeInterval(86400), attributes: [.path: "/tmp/new-invoice.pdf"]),
        ])

        let deleted = try await store.deleteEvents(before: base.addingTimeInterval(3600))
        #expect(deleted == 1)
        #expect(try await store.totalCount() == 1)

        // FTS must not return the pruned row.
        let hits = try await store.search(matching: EventQuery(text: "invoice"))
        #expect(hits.count == 1)
    }

    @Test("Prune retains only the configured window")
    func prune() async throws {
        let store = try SQLiteEventStore.inMemory()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        try await store.insert([
            EventFactory.event(timestamp: now.addingTimeInterval(-10 * 86400)),
            EventFactory.event(timestamp: now.addingTimeInterval(-1 * 86400), attributes: [.path: "/tmp/b"]),
        ])
        let pruned = try await store.prune(retainingDays: 5, referenceDate: now)
        #expect(pruned == 1)
    }

    @Test("Delete matching a query removes only matches")
    func deleteMatching() async throws {
        let store = try SQLiteEventStore.inMemory()
        try await store.insert([
            EventFactory.event(kind: .fileCreated, source: .filesystem),
            EventFactory.event(kind: .appLaunched, source: .application, attributes: [.appName: "Mail"]),
        ])
        let deleted = try await store.deleteEvents(matching: EventQuery(kinds: [.appLaunched]))
        #expect(deleted == 1)
        #expect(try await store.totalCount() == 1)
    }

    @Test("Integrity check passes and maintenance runs")
    func integrityAndMaintenance() async throws {
        try await withTemporaryDirectory { directory in
            let store = try SQLiteEventStore.open(at: directory.file("chronicle.sqlite"))
            try await store.insert(EventFactory.sequence(count: 5))
            #expect(try await store.checkIntegrity())
            try await store.checkpoint()
            try await store.vacuum()

            let backupURL = directory.file("backup.sqlite")
            try store.backup(to: backupURL)
            #expect(FileManager.default.fileExists(atPath: backupURL.path))
        }
    }

    @Test("Collector cursors persist and update")
    func cursors() async throws {
        let store = try SQLiteEventStore.inMemory()
        #expect(try await store.loadCursor(source: .browser) == nil)
        try await store.saveCursor("1700000000", source: .browser)
        #expect(try await store.loadCursor(source: .browser) == "1700000000")
        try await store.saveCursor("1700009999", source: .browser)
        #expect(try await store.loadCursor(source: .browser) == "1700009999")
    }
}
