import ChronicleCore
import ChronicleModels
import Foundation
import GRDB

// MARK: - StatisticsRepository

public extension SQLiteEventStore {
    /// Event counts grouped by kind within an optional range.
    func countByKind(in range: DateInterval?) async throws -> [EventKind: Int] {
        let clause = rangeClause(range)
        let sql = "SELECT kind, COUNT(*) AS c FROM events \(clause.sql) GROUP BY kind"
        return try await writer.read { db in
            var result: [EventKind: Int] = [:]
            for row in try Row.fetchAll(db, sql: sql, arguments: clause.arguments) {
                let count: Int = row["c"]
                result[EventKind(rawValue: row["kind"])] = count
            }
            return result
        }
    }

    /// Event counts grouped by source within an optional range.
    func countBySource(in range: DateInterval?) async throws -> [CollectorSource: Int] {
        let clause = rangeClause(range)
        let sql = "SELECT source, COUNT(*) AS c FROM events \(clause.sql) GROUP BY source"
        return try await writer.read { db in
            var result: [CollectorSource: Int] = [:]
            for row in try Row.fetchAll(db, sql: sql, arguments: clause.arguments) {
                let count: Int = row["c"]
                result[CollectorSource(rawValue: row["source"])] = count
            }
            return result
        }
    }

    /// Top application names by event count within an optional range.
    func countByApp(in range: DateInterval?, limit: Int) async throws -> [(app: String, count: Int)] {
        var values: [EventQueryPlanner.Argument] = []
        var whereSQL = "WHERE json_extract(attrs, '$.app_name') IS NOT NULL"
        if let range {
            whereSQL += " AND ts_ms >= ? AND ts_ms < ?"
            values.append(range.start.millisecondsSince1970)
            values.append(range.end.millisecondsSince1970)
        }
        values.append(Int64(limit))
        let sql = """
        SELECT json_extract(attrs, '$.app_name') AS app, COUNT(*) AS c
        FROM events \(whereSQL)
        GROUP BY app ORDER BY c DESC, app ASC LIMIT ?
        """
        let arguments = statementArguments(values)
        return try await writer.read { db in
            try Row.fetchAll(db, sql: sql, arguments: arguments).map { row in
                let app: String = row["app"]
                let count: Int = row["c"]
                return (app: app, count: count)
            }
        }
    }

    /// Event counts bucketed by local hour of day (0...23) within an optional range.
    func hourHistogram(in range: DateInterval?) async throws -> [Int: Int] {
        let clause = rangeClause(range)
        let sql = """
        SELECT CAST(strftime('%H', ts_ms / 1000, 'unixepoch', 'localtime') AS INTEGER) AS hour,
               COUNT(*) AS c
        FROM events \(clause.sql)
        GROUP BY hour
        """
        return try await writer.read { db in
            var result: [Int: Int] = [:]
            for row in try Row.fetchAll(db, sql: sql, arguments: clause.arguments) {
                let hour: Int = row["hour"]
                let count: Int = row["c"]
                result[hour] = count
            }
            return result
        }
    }

    private func rangeClause(_ range: DateInterval?) -> (sql: String, arguments: StatementArguments) {
        guard let range else { return ("", StatementArguments()) }
        let arguments: StatementArguments = [
            range.start.millisecondsSince1970,
            range.end.millisecondsSince1970,
        ]
        return ("WHERE ts_ms >= ? AND ts_ms < ?", arguments)
    }
}
