import ChronicleModels
import Foundation

/// The persistence boundary for events (Repository Pattern).
///
/// Storage implements this protocol; the pipeline and query layers depend only on
/// it. No SQL, GRDB, or SQLite type ever crosses this boundary.
public protocol EventRepository: Sendable {
    /// Inserts a batch of events in a single transaction.
    ///
    /// Implementations deduplicate on ``Event/dedupeDigest`` and ignore rows that
    /// collide with an existing digest.
    /// - Returns: The number of rows actually inserted (excluding ignored duplicates).
    @discardableResult
    func insert(_ events: [Event]) async throws -> Int

    /// Fetches events matching a query.
    func events(matching query: EventQuery) async throws -> [Event]

    /// Counts events matching a query (ignoring `limit` and pagination).
    func count(matching query: EventQuery) async throws -> Int

    /// Fetches a single event by identifier.
    func event(id: EventID) async throws -> Event?

    /// Deletes events older than the given date.
    /// - Returns: The number of rows deleted.
    @discardableResult
    func deleteEvents(before date: Date) async throws -> Int

    /// Deletes events matching a query.
    /// - Returns: The number of rows deleted.
    @discardableResult
    func deleteEvents(matching query: EventQuery) async throws -> Int

    /// The total number of stored events.
    func totalCount() async throws -> Int
}

/// The full-text search boundary.
public protocol SearchRepository: Sendable {
    /// Runs a full-text search described by `query.text`, applying the same
    /// filters as ``EventRepository``.
    func search(matching query: EventQuery) async throws -> [SearchHit]
}

/// Persistence for per-event embedding vectors (used by AI semantic search).
public protocol EmbeddingRepository: Sendable {
    /// Stores (or replaces) the embedding vector for an event under a model.
    func storeEmbedding(id: EventID, model: String, vector: [Float]) async throws

    /// Fetches the embedding vector for an event under a model, if present.
    func embedding(id: EventID, model: String) async throws -> [Float]?

    /// Returns ids of the most recent events lacking an embedding for a model.
    func idsMissingEmbeddings(model: String, limit: Int) async throws -> [EventID]

    /// Returns all embeddings for a model (for in-memory nearest-neighbour search).
    func allEmbeddings(model: String) async throws -> [(id: EventID, vector: [Float])]

    /// The number of stored embeddings for a model.
    func embeddingCount(model: String) async throws -> Int
}

/// Aggregate statistics over the event store, computed in SQL for efficiency.
public protocol StatisticsRepository: Sendable {
    /// Event counts grouped by kind within an optional range.
    func countByKind(in range: DateInterval?) async throws -> [EventKind: Int]

    /// Event counts grouped by source within an optional range.
    func countBySource(in range: DateInterval?) async throws -> [CollectorSource: Int]

    /// Event counts grouped by application name within an optional range.
    func countByApp(in range: DateInterval?, limit: Int) async throws -> [(app: String, count: Int)]

    /// Event counts bucketed by hour of day (0...23) within an optional range.
    func hourHistogram(in range: DateInterval?) async throws -> [Int: Int]
}
