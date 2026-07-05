import Foundation
import GRDB

enum SchemaMigrator {
    /// The migrator for the Chronicle schema.
    ///
    /// Migrations are numbered, immutable, and applied in order. Once released, a
    /// migration is never edited; schema changes are additive new migrations with
    /// golden-fixture upgrade tests.
    static func make() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()
        registerV1(in: &migrator)
        return migrator
    }

    private static func registerV1(in migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v1.events") { db in
            try db.execute(sql: """
            CREATE TABLE events (
                seq            INTEGER PRIMARY KEY AUTOINCREMENT,
                id             TEXT NOT NULL UNIQUE,
                ts_ms          INTEGER NOT NULL,
                kind           TEXT NOT NULL,
                source         TEXT NOT NULL,
                session_id     TEXT,
                dedupe_hash    TEXT UNIQUE,
                search_text    TEXT NOT NULL DEFAULT '',
                attrs          TEXT NOT NULL DEFAULT '{}',
                schema_version INTEGER NOT NULL
            )
            """)

            try db.execute(sql: "CREATE INDEX idx_events_ts ON events(ts_ms)")
            try db.execute(sql: "CREATE INDEX idx_events_kind_ts ON events(kind, ts_ms)")
            try db.execute(sql: "CREATE INDEX idx_events_source_ts ON events(source, ts_ms)")

            try db.execute(sql: """
            CREATE TABLE collector_state (
                source TEXT PRIMARY KEY,
                cursor TEXT NOT NULL
            )
            """)

            try db.execute(sql: """
            CREATE TABLE meta (
                key   TEXT PRIMARY KEY,
                value TEXT NOT NULL
            )
            """)
        }

        migrator.registerMigration("v1.fts") { db in
            try db.execute(sql: """
            CREATE VIRTUAL TABLE events_fts USING fts5(
                search_text,
                content='events',
                content_rowid='seq',
                tokenize='unicode61'
            )
            """)

            try db.execute(sql: """
            CREATE TRIGGER events_after_insert AFTER INSERT ON events BEGIN
                INSERT INTO events_fts(rowid, search_text) VALUES (new.seq, new.search_text);
            END
            """)

            try db.execute(sql: """
            CREATE TRIGGER events_after_delete AFTER DELETE ON events BEGIN
                INSERT INTO events_fts(events_fts, rowid, search_text)
                VALUES ('delete', old.seq, old.search_text);
            END
            """)

            try db.execute(sql: """
            CREATE TRIGGER events_after_update AFTER UPDATE ON events BEGIN
                INSERT INTO events_fts(events_fts, rowid, search_text)
                VALUES ('delete', old.seq, old.search_text);
                INSERT INTO events_fts(rowid, search_text) VALUES (new.seq, new.search_text);
            END
            """)
        }
    }
}
