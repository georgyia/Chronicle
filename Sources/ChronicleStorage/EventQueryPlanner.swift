import ChronicleCore
import Foundation
import GRDB

/// Translates an ``EventQuery`` into SQL fragments and arguments.
///
/// All user-controlled values are bound as statement arguments; no query text is
/// built by string interpolation of user input.
struct EventQueryPlanner {
    typealias Argument = any(DatabaseValueConvertible & Sendable)

    /// A composed `WHERE` clause and its bound arguments.
    struct Clause {
        var sql: String
        var arguments: [Argument]
    }

    /// Builds the `WHERE` clause for the filters in a query (excluding pagination).
    /// - Parameter includeText: When `false`, the `text` filter is omitted (used by
    ///   full-text search, which applies the term via FTS5 `MATCH` instead).
    func filterClause(for query: EventQuery, includeText: Bool = true) -> Clause {
        var conditions: [String] = []
        var arguments: [Argument] = []

        if let range = query.range {
            conditions.append("ts_ms >= ? AND ts_ms < ?")
            arguments.append(range.start.millisecondsSince1970)
            arguments.append(range.end.millisecondsSince1970)
        }
        if !query.kinds.isEmpty {
            let kinds = query.kinds.map(\.rawValue).sorted()
            conditions.append("kind IN (\(placeholders(kinds.count)))")
            arguments.append(contentsOf: kinds)
        }
        if !query.sources.isEmpty {
            let sources = query.sources.map(\.rawValue).sorted()
            conditions.append("source IN (\(placeholders(sources.count)))")
            arguments.append(contentsOf: sources)
        }
        if let prefix = query.pathPrefix {
            conditions.append("json_extract(attrs, '$.path') LIKE ? ESCAPE '\\'")
            arguments.append(escapeLike(prefix) + "%")
        }
        if let app = query.appName {
            conditions.append("json_extract(attrs, '$.app_name') = ? COLLATE NOCASE")
            arguments.append(app)
        }
        if includeText, let text = query.text, !text.isEmpty {
            conditions.append("search_text LIKE ? ESCAPE '\\'")
            arguments.append("%" + escapeLike(text) + "%")
        }

        let sql = conditions.isEmpty ? "" : "WHERE " + conditions.joined(separator: " AND ")
        return Clause(sql: sql, arguments: arguments)
    }

    /// The `ORDER BY` clause for the query's sort order.
    func orderClause(for order: EventSortOrder) -> String {
        let direction = order == .ascending ? "ASC" : "DESC"
        return "ORDER BY ts_ms \(direction), id \(direction)"
    }

    /// Builds a keyset pagination predicate, if the query has a cursor.
    func paginationClause(for query: EventQuery) -> Clause? {
        guard let cursor = query.pageAfter else { return nil }
        let comparison = query.order == .ascending ? ">" : "<"
        let sql = "(ts_ms, id) \(comparison) (SELECT ts_ms, id FROM events WHERE id = ?)"
        return Clause(sql: sql, arguments: [cursor.description])
    }

    /// Combines the filter and pagination clauses into a single `WHERE`.
    func combinedClause(for query: EventQuery, includePagination: Bool) -> Clause {
        var clause = filterClause(for: query)
        guard includePagination, let pagination = paginationClause(for: query) else { return clause }

        if clause.sql.isEmpty {
            clause.sql = "WHERE " + pagination.sql
        } else {
            clause.sql += " AND " + pagination.sql
        }
        clause.arguments.append(contentsOf: pagination.arguments)
        return clause
    }

    private func placeholders(_ count: Int) -> String {
        Array(repeating: "?", count: count).joined(separator: ", ")
    }

    private func escapeLike(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
    }
}
