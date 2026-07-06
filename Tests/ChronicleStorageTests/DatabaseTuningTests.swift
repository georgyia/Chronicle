import ChronicleTestSupport
import Foundation
import GRDB
import Testing
@testable import ChronicleStorage

@Suite("Database tuning (PF3)")
struct DatabaseTuningTests {
    @Test("Performance pragmas are applied")
    func pragmas() async throws {
        try await withTemporaryDirectory { directory in
            let store = try SQLiteEventStore.open(at: directory.file("chronicle.sqlite"))
            func pragma(_ name: String) async throws -> Int64 {
                try await store.writer.read { db in try Int64.fetchOne(db, sql: "PRAGMA \(name)") ?? -1 }
            }
            #expect(try await pragma("mmap_size") > 0)
            #expect(try await pragma("cache_size") == -8000)
            #expect(try await pragma("synchronous") == 1) // NORMAL
        }
    }

    @Test("WAL journal mode is active")
    func walMode() async throws {
        try await withTemporaryDirectory { directory in
            let store = try SQLiteEventStore.open(at: directory.file("chronicle.sqlite"))
            let mode = try await store.writer.read { db in
                try String.fetchOne(db, sql: "PRAGMA journal_mode") ?? ""
            }
            #expect(mode.lowercased() == "wal")
        }
    }
}
