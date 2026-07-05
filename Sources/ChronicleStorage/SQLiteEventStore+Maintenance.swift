import ChronicleCore
import ChronicleModels
import Foundation
import GRDB

// MARK: - Maintenance, integrity, retention, and collector cursors

public extension SQLiteEventStore {
    /// Runs SQLite's `integrity_check` and reports whether the database is sound.
    func checkIntegrity() async throws -> Bool {
        try await writer.read { db in
            try String.fetchAll(db, sql: "PRAGMA integrity_check") == ["ok"]
        }
    }

    /// Truncates the write-ahead log by performing a checkpoint.
    func checkpoint() async throws {
        try await writer.writeWithoutTransaction { db in
            try db.execute(sql: "PRAGMA wal_checkpoint(TRUNCATE)")
        }
    }

    /// Rebuilds the database file, reclaiming space after large deletions.
    func vacuum() async throws {
        try await writer.writeWithoutTransaction { db in
            try db.execute(sql: "VACUUM")
        }
    }

    /// Creates a consistent copy of the database at `url` (used by `export`).
    func backup(to url: URL) throws {
        let destination = try DatabaseQueue(path: url.path)
        try writer.backup(to: destination)
    }

    /// Deletes events older than `days` relative to `referenceDate`.
    /// - Returns: The number of rows pruned.
    @discardableResult
    func prune(retainingDays days: Int, referenceDate: Date = Date()) async throws -> Int {
        guard days > 0 else { return 0 }
        let cutoff = referenceDate.addingTimeInterval(-Double(days) * 86400)
        return try await deleteEvents(before: cutoff)
    }

    /// Loads a collector's persisted incremental cursor, if any.
    func loadCursor(source: CollectorSource) async throws -> String? {
        let name = source.rawValue
        return try await writer.read { db in
            try String.fetchOne(
                db,
                sql: "SELECT cursor FROM collector_state WHERE source = ?",
                arguments: [name]
            )
        }
    }

    /// Persists a collector's incremental cursor.
    func saveCursor(_ cursor: String, source: CollectorSource) async throws {
        let name = source.rawValue
        try await writer.write { db in
            try db.execute(
                sql: """
                INSERT INTO collector_state (source, cursor) VALUES (?, ?)
                ON CONFLICT(source) DO UPDATE SET cursor = excluded.cursor
                """,
                arguments: [name, cursor]
            )
        }
    }
}
