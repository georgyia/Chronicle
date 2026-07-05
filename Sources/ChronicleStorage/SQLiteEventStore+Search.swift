import ChronicleCore
import ChronicleModels
import Foundation
import GRDB

// MARK: - SearchRepository

public extension SQLiteEventStore {
    /// Runs a full-text search using FTS5, applying the query's other filters.
    func search(matching query: EventQuery) async throws -> [SearchHit] {
        guard let text = query.text, !text.isEmpty else {
            return try await events(matching: query).map { SearchHit(event: $0, snippet: nil, score: 0) }
        }

        let tokens = Self.ftsTokens(from: text)
        guard !tokens.isEmpty else {
            return try await events(matching: query).map { SearchHit(event: $0, snippet: nil, score: 0) }
        }

        let filter = planner.filterClause(for: query, includeText: false)
        var conditions = "events_fts MATCH ?"
        var values: [EventQueryPlanner.Argument] = [tokens.joined(separator: " ")]
        if !filter.sql.isEmpty {
            conditions += " AND " + String(filter.sql.dropFirst("WHERE ".count))
            values.append(contentsOf: filter.arguments)
        }
        let limit = query.limit ?? 100
        values.append(Int64(limit))

        let sql = """
        SELECT events.*, bm25(events_fts) AS rank,
               snippet(events_fts, 0, '⟦', '⟧', '…', 12) AS snip
        FROM events_fts
        JOIN events ON events.seq = events_fts.rowid
        WHERE \(conditions)
        ORDER BY rank
        LIMIT ?
        """
        let arguments = statementArguments(values)

        return try await writer.read { db in
            try Row.fetchAll(db, sql: sql, arguments: arguments).map { row in
                let event = try mapper.event(from: row)
                let snippet: String? = row["snip"]
                let rank: Double = row["rank"] ?? 0
                return SearchHit(event: event, snippet: snippet, score: -rank)
            }
        }
    }

    /// Builds FTS5 prefix tokens from free text.
    ///
    /// The `unicode61` tokenizer splits on punctuation and lowercases, so we split
    /// on non-alphanumeric characters and add a `*` prefix wildcard per term. This
    /// keeps the query free of FTS5 metacharacters supplied by the user.
    internal static func ftsTokens(from text: String) -> [String] {
        text
            .split { !$0.isLetter && !$0.isNumber }
            .map { "\($0.lowercased())*" }
    }
}
