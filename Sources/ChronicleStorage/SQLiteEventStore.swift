import ChronicleCore
import ChronicleModels
import Foundation
import GRDB

/// The SQLite-backed implementation of Chronicle's persistence protocols.
///
/// Owns a GRDB `DatabaseWriter` (a `DatabasePool` in production for WAL concurrent
/// reads, or an in-memory `DatabaseQueue` in tests). Writes are serialized by the
/// writer; reads run concurrently. This is the only type in the system that speaks
/// SQL.
public final class SQLiteEventStore: Sendable {
    let writer: any DatabaseWriter
    let mapper = EventMapper()
    let planner = EventQueryPlanner()

    init(writer: any DatabaseWriter) {
        self.writer = writer
    }

    /// Opens (creating if needed) the on-disk database at `url` and migrates it.
    ///
    /// The parent directory is created `0700` and the database file `0600`, since
    /// the event store is sensitive data.
    public static func open(at url: URL) throws -> SQLiteEventStore {
        let directory = url.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        } catch {
            throw StorageError.open(error.localizedDescription)
        }

        let pool: DatabasePool
        do {
            pool = try DatabasePool(path: url.path, configuration: DatabaseConfiguration.make())
        } catch {
            throw StorageError.open(error.localizedDescription)
        }

        do {
            try SchemaMigrator.make().migrate(pool)
        } catch {
            throw StorageError.migration(error.localizedDescription)
        }

        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        return SQLiteEventStore(writer: pool)
    }

    /// Opens an ephemeral in-memory store for tests.
    public static func inMemory() throws -> SQLiteEventStore {
        let queue: DatabaseQueue
        do {
            queue = try DatabaseQueue(configuration: DatabaseConfiguration.make())
            try SchemaMigrator.make().migrate(queue)
        } catch {
            throw StorageError.migration(error.localizedDescription)
        }
        return SQLiteEventStore(writer: queue)
    }

    func statementArguments(_ values: [EventQueryPlanner.Argument]) -> StatementArguments {
        StatementArguments(values.map { $0 as any DatabaseValueConvertible })
    }
}

/// Conformances are declared here; the requirements are satisfied in the focused
/// extensions in this module (EventRepository, Search, Statistics, Embeddings).
extension SQLiteEventStore: EventRepository, SearchRepository, StatisticsRepository, EmbeddingRepository {}

// MARK: - EventRepository

public extension SQLiteEventStore {
    /// Inserts a batch of events in one transaction, ignoring digest duplicates.
    @discardableResult
    func insert(_ events: [Event]) async throws -> Int {
        guard !events.isEmpty else { return 0 }
        let columns = EventMapper.insertColumns.joined(separator: ", ")
        let placeholders = Array(repeating: "?", count: EventMapper.insertColumns.count).joined(separator: ", ")
        let sql = "INSERT OR IGNORE INTO events (\(columns)) VALUES (\(placeholders))"

        return try await writer.write { db in
            let statement = try db.makeStatement(sql: sql)
            var inserted = 0
            for event in events {
                statement.arguments = try mapper.insertArguments(for: event)
                try statement.execute()
                inserted += db.changesCount
            }
            return inserted
        }
    }

    /// Fetches events matching a query, ordered and paginated per the query.
    func events(matching query: EventQuery) async throws -> [Event] {
        let clause = planner.combinedClause(for: query, includePagination: true)
        var sql = "SELECT * FROM events \(clause.sql) \(planner.orderClause(for: query.order))"
        var argumentValues = clause.arguments
        if let limit = query.limit {
            sql += " LIMIT ?"
            argumentValues.append(Int64(limit))
        }
        let finalSQL = sql
        let arguments = statementArguments(argumentValues)

        return try await writer.read { db in
            try Row.fetchAll(db, sql: finalSQL, arguments: arguments).map { try mapper.event(from: $0) }
        }
    }

    /// Counts events matching a query's filters (ignoring limit and pagination).
    func count(matching query: EventQuery) async throws -> Int {
        let clause = planner.combinedClause(for: query, includePagination: false)
        let sql = "SELECT COUNT(*) FROM events \(clause.sql)"
        let arguments = statementArguments(clause.arguments)
        return try await writer.read { db in
            try Int.fetchOne(db, sql: sql, arguments: arguments) ?? 0
        }
    }

    /// Fetches a single event by identifier, or `nil` if absent.
    func event(id: EventID) async throws -> Event? {
        let idString = id.description
        return try await writer.read { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM events WHERE id = ?", arguments: [idString])
            else { return nil }
            return try mapper.event(from: row)
        }
    }

    /// Deletes events older than `date`, returning the number removed.
    @discardableResult
    func deleteEvents(before date: Date) async throws -> Int {
        let cutoff = date.millisecondsSince1970
        return try await writer.write { db in
            try db.execute(sql: "DELETE FROM events WHERE ts_ms < ?", arguments: [cutoff])
            return db.changesCount
        }
    }

    /// Deletes events matching a query's filters, returning the number removed.
    @discardableResult
    func deleteEvents(matching query: EventQuery) async throws -> Int {
        let clause = planner.filterClause(for: query)
        let sql = "DELETE FROM events \(clause.sql)"
        let arguments = statementArguments(clause.arguments)
        return try await writer.write { db in
            try db.execute(sql: sql, arguments: arguments)
            return db.changesCount
        }
    }

    /// The total number of stored events.
    func totalCount() async throws -> Int {
        try await writer.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM events") ?? 0
        }
    }
}
