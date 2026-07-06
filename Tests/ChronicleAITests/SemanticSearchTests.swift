import ChronicleCore
import ChronicleModels
import ChronicleStorage
import ChronicleTestSupport
import Foundation
import Testing
@testable import ChronicleAI

/// Semantic search + eval harness (A2/A3/A6): verifies backfill, nearest-neighbour
/// ranking, and hybrid fusion against a golden set using the deterministic hashing
/// provider.
@Suite("Semantic search")
struct SemanticSearchTests {
    private func makeStore() async throws -> SQLiteEventStore {
        let store = try SQLiteEventStore.inMemory()
        try await store.insert([
            EventFactory.event(kind: .browserVisit, source: .browser, attributes: [.title: "quarterly invoice review"]),
            EventFactory.event(kind: .browserVisit, source: .browser, attributes: [.title: "vacation photos album"]),
            EventFactory.event(kind: .browserVisit, source: .browser, attributes: [.title: "swift code review guide"]),
        ])
        return store
    }

    @Test("Backfill embeds all events once")
    func backfill() async throws {
        let store = try await makeStore()
        let service = SemanticSearchService(
            provider: HashingEmbeddingProvider(dimensions: 512),
            embeddings: store,
            events: store
        )
        #expect(try await service.backfill() == 3)
        // A second backfill finds nothing missing.
        #expect(try await service.backfill() == 0)
    }

    @Test("Semantic search ranks the relevant event first")
    func semanticRanking() async throws {
        let store = try await makeStore()
        let service = SemanticSearchService(
            provider: HashingEmbeddingProvider(dimensions: 512),
            embeddings: store,
            events: store
        )
        try await service.backfill()
        let hits = try await service.semanticSearch("invoice", limit: 3)
        #expect(hits.first?.event.attributes.string(.title)?.contains("invoice") == true)
    }

    @Test("Hybrid fusion surfaces the relevant event")
    func hybrid() async throws {
        let store = try await makeStore()
        let service = SemanticSearchService(
            provider: HashingEmbeddingProvider(dimensions: 512),
            embeddings: store,
            events: store
        )
        try await service.backfill()
        let lexical = try await store.search(matching: EventQuery(text: "invoice", limit: 10))
        let fused = try await service.hybrid("invoice", lexical: lexical, limit: 3)
        #expect(fused.first?.event.attributes.string(.title)?.contains("invoice") == true)
    }
}
