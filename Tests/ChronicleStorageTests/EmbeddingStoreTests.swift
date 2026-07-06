import ChronicleCore
import ChronicleModels
import ChronicleTestSupport
import Foundation
import GRDB
import Testing
@testable import ChronicleStorage

@Suite("Embedding storage (schema v2)")
struct EmbeddingStoreTests {
    @Test("Migration v2 creates the embeddings table")
    func migration() async throws {
        let store = try SQLiteEventStore.inMemory()
        let hasTable = try await store.writer.read { db in
            try Bool.fetchOne(
                db,
                sql: "SELECT count(*) > 0 FROM sqlite_master WHERE type='table' AND name='embeddings'"
            ) ?? false
        }
        #expect(hasTable)
        #expect(ChronicleStorage.schemaVersion == 2)
    }

    @Test("Embeddings round-trip and upsert")
    func roundTrip() async throws {
        let store = try SQLiteEventStore.inMemory()
        let event = EventFactory.event()
        try await store.insert([event])

        try await store.storeEmbedding(id: event.id, model: "test", vector: [0.1, 0.2, 0.3])
        #expect(try await store.embedding(id: event.id, model: "test") == [0.1, 0.2, 0.3])

        try await store.storeEmbedding(id: event.id, model: "test", vector: [0.4, 0.5])
        #expect(try await store.embedding(id: event.id, model: "test") == [0.4, 0.5])
        #expect(try await store.embeddingCount(model: "test") == 1)
    }

    @Test("Missing embeddings are reported")
    func missing() async throws {
        let store = try SQLiteEventStore.inMemory()
        let events = EventFactory.sequence(count: 3)
        try await store.insert(events)

        var missing = try await store.idsMissingEmbeddings(model: "m", limit: 10)
        #expect(missing.count == 3)

        try await store.storeEmbedding(id: events[0].id, model: "m", vector: [1])
        missing = try await store.idsMissingEmbeddings(model: "m", limit: 10)
        #expect(missing.count == 2)
    }

    @Test("Pruning events cascades to embeddings")
    func cascade() async throws {
        let store = try SQLiteEventStore.inMemory()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let event = EventFactory.event(timestamp: base)
        try await store.insert([event])
        try await store.storeEmbedding(id: event.id, model: "m", vector: [1, 2])

        _ = try await store.deleteEvents(before: base.addingTimeInterval(60))
        #expect(try await store.embeddingCount(model: "m") == 0)
    }
}
