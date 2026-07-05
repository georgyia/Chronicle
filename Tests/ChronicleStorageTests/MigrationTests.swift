import ChronicleTestSupport
import Foundation
import GRDB
import Testing
@testable import ChronicleStorage

@Suite("Schema migration")
struct MigrationTests {
    @Test("Fresh open creates the expected schema")
    func freshSchema() async throws {
        try await withTemporaryDirectory { directory in
            let store = try SQLiteEventStore.open(at: directory.file("chronicle.sqlite"))
            let tables = try await store.writer.read { db in
                try String.fetchAll(
                    db,
                    sql: "SELECT name FROM sqlite_master WHERE type IN ('table','trigger') ORDER BY name"
                )
            }
            #expect(tables.contains("events"))
            #expect(tables.contains("events_fts"))
            #expect(tables.contains("collector_state"))
            #expect(tables.contains("meta"))
            #expect(tables.contains("events_after_insert"))
        }
    }

    @Test("Reopening an existing database is idempotent")
    func reopenIdempotent() async throws {
        try await withTemporaryDirectory { directory in
            let url = directory.file("chronicle.sqlite")
            let first = try SQLiteEventStore.open(at: url)
            try await first.insert([EventFactory.event()])
            try await first.checkpoint()

            let second = try SQLiteEventStore.open(at: url)
            #expect(try await second.totalCount() == 1)
        }
    }

    @Test("Database file is created with owner-only permissions")
    func filePermissions() async throws {
        try await withTemporaryDirectory { directory in
            let url = directory.file("chronicle.sqlite")
            _ = try SQLiteEventStore.open(at: url)
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let permissions = (attributes[.posixPermissions] as? NSNumber)?.intValue
            #expect(permissions == 0o600)
        }
    }
}
