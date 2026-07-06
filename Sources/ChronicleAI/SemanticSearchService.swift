import ChronicleCore
import ChronicleModels
import Foundation

/// Fuses ranked result lists using Reciprocal Rank Fusion. Pure and testable.
enum ReciprocalRankFusion {
    static func fuse(_ lists: [[SearchHit]], rankConstant: Double = 60, limit: Int) -> [SearchHit] {
        var scores: [EventID: Double] = [:]
        var events: [EventID: Event] = [:]
        for list in lists {
            for (rank, hit) in list.enumerated() {
                scores[hit.event.id, default: 0] += 1 / (rankConstant + Double(rank + 1))
                events[hit.event.id] = hit.event
            }
        }
        return scores
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .compactMap { pair in events[pair.key].map { SearchHit(event: $0, snippet: nil, score: pair.value) } }
    }
}

/// Local-first semantic search: embeds events, indexes them, and answers queries
/// by nearest-neighbour cosine similarity, optionally fused with lexical results.
public struct SemanticSearchService: Sendable {
    private let provider: any EmbeddingProvider
    private let embeddings: any EmbeddingRepository
    private let events: any EventRepository

    /// Creates a semantic search service.
    public init(
        provider: any EmbeddingProvider,
        embeddings: any EmbeddingRepository,
        events: any EventRepository
    ) {
        self.provider = provider
        self.embeddings = embeddings
        self.events = events
    }

    /// Embeds recent events that lack an embedding for the current model.
    /// - Returns: The number of events embedded.
    @discardableResult
    public func backfill(limit: Int = 500) async throws -> Int {
        let ids = try await embeddings.idsMissingEmbeddings(model: provider.model, limit: limit)
        var embedded = 0
        for id in ids {
            guard let event = try await events.event(id: id) else { continue }
            guard let vector = provider.embed(Self.text(for: event)) else { continue }
            try await embeddings.storeEmbedding(id: id, model: provider.model, vector: vector)
            embedded += 1
        }
        return embedded
    }

    /// Returns the events most semantically similar to `text`.
    public func semanticSearch(_ text: String, limit: Int) async throws -> [SearchHit] {
        guard let queryVector = provider.embed(text) else { return [] }
        let indexed = try await embeddings.allEmbeddings(model: provider.model)
        let ranked = indexed
            .map { (id: $0.id, score: VectorMath.cosineSimilarity(queryVector, $0.vector)) }
            .sorted { $0.score > $1.score }
            .prefix(limit)

        var hits: [SearchHit] = []
        for entry in ranked {
            if let event = try await events.event(id: entry.id) {
                hits.append(SearchHit(event: event, snippet: nil, score: entry.score))
            }
        }
        return hits
    }

    /// Fuses lexical results with semantic results via Reciprocal Rank Fusion.
    public func hybrid(_ text: String, lexical: [SearchHit], limit: Int) async throws -> [SearchHit] {
        let semantic = try await semanticSearch(text, limit: max(limit, 50))
        return ReciprocalRankFusion.fuse([lexical, semantic], limit: limit)
    }

    /// The text embedded for an event (kind action plus salient attributes).
    static func text(for event: Event) -> String {
        var parts = [event.kind.action]
        for key: AttributeKey in [.title, .appName, .command, .url, .path] {
            if let value = event.attributes.string(key) { parts.append(value) }
        }
        return parts.filter { !$0.isEmpty }.joined(separator: " ")
    }
}
