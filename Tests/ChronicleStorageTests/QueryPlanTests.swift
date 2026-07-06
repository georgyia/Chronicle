import ChronicleCore
import ChronicleModels
import ChronicleTestSupport
import Foundation
import GRDB
import Testing
@testable import ChronicleStorage

/// Audits that hot query paths use indexes rather than full table scans (Q4).
@Suite("Query plan audit")
struct QueryPlanTests {
    private func plan(_ store: SQLiteEventStore, sql: String, arguments: StatementArguments) async throws -> String {
        try await store.writer.read { db in
            try Row.fetchAll(db, sql: "EXPLAIN QUERY PLAN \(sql)", arguments: arguments)
                .map { row -> String in row["detail"] }
                .joined(separator: " | ")
        }
    }

    @Test("Kind + time query uses an index")
    func kindTimeIndex() async throws {
        let store = try SQLiteEventStore.inMemory()
        try await store.insert(EventFactory.sequence(count: 500))
        let detail = try await plan(
            store,
            sql: "SELECT * FROM events WHERE kind = ? ORDER BY ts_ms DESC, id DESC LIMIT 100",
            arguments: ["file.modified"]
        )
        #expect(detail.contains("USING INDEX"))
        #expect(!detail.contains("SCAN events") || detail.contains("USING INDEX"))
    }

    @Test("Time-range query uses the timestamp index")
    func rangeIndex() async throws {
        let store = try SQLiteEventStore.inMemory()
        try await store.insert(EventFactory.sequence(count: 500))
        let detail = try await plan(
            store,
            sql: "SELECT COUNT(*) FROM events WHERE ts_ms >= ? AND ts_ms < ?",
            arguments: [0, Int64.max]
        )
        #expect(detail.contains("idx_events_ts") || detail.contains("USING INDEX"))
    }
}
