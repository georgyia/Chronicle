import ChronicleCore
import ChronicleModels
import Foundation
import GRDB

// MARK: - EmbeddingRepository

public extension SQLiteEventStore {
    /// Stores or replaces an event's embedding vector for a model.
    func storeEmbedding(id: EventID, model: String, vector: [Float]) async throws {
        let idString = id.description
        let blob = FloatVectorCodec.encode(vector)
        try await writer.write { db in
            try db.execute(
                sql: """
                INSERT INTO embeddings (event_id, model, vector) VALUES (?, ?, ?)
                ON CONFLICT(event_id, model) DO UPDATE SET vector = excluded.vector
                """,
                arguments: [idString, model, blob]
            )
        }
    }

    /// Fetches an event's embedding vector for a model, if present.
    func embedding(id: EventID, model: String) async throws -> [Float]? {
        let idString = id.description
        return try await writer.read { db in
            guard let data = try Data.fetchOne(
                db,
                sql: "SELECT vector FROM embeddings WHERE event_id = ? AND model = ?",
                arguments: [idString, model]
            ) else { return nil }
            return FloatVectorCodec.decode(data)
        }
    }

    /// Returns ids of the most recent events lacking an embedding for a model.
    func idsMissingEmbeddings(model: String, limit: Int) async throws -> [EventID] {
        try await writer.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT id FROM events
                WHERE id NOT IN (SELECT event_id FROM embeddings WHERE model = ?)
                ORDER BY seq DESC LIMIT ?
                """,
                arguments: [model, limit]
            )
            return rows.compactMap { row in
                (row["id"] as String?).flatMap(UUID.init(uuidString:)).map(EventID.init(rawValue:))
            }
        }
    }

    /// Returns all embeddings for a model.
    func allEmbeddings(model: String) async throws -> [(id: EventID, vector: [Float])] {
        try await writer.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: "SELECT event_id, vector FROM embeddings WHERE model = ?",
                arguments: [model]
            )
            return rows.compactMap { row -> (id: EventID, vector: [Float])? in
                guard
                    let uuid = (row["event_id"] as String?).flatMap(UUID.init(uuidString:)),
                    let data = row["vector"] as Data?
                else { return nil }
                return (id: EventID(rawValue: uuid), vector: FloatVectorCodec.decode(data))
            }
        }
    }

    /// The number of stored embeddings for a model.
    func embeddingCount(model: String) async throws -> Int {
        try await writer.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM embeddings WHERE model = ?", arguments: [model]) ?? 0
        }
    }
}

/// Encodes and decodes `[Float]` vectors as little-endian BLOBs.
enum FloatVectorCodec {
    static func encode(_ vector: [Float]) -> Data {
        var copy = vector
        return copy.withUnsafeMutableBytes { Data($0) }
    }

    static func decode(_ data: Data) -> [Float] {
        let count = data.count / MemoryLayout<Float>.size
        guard count > 0 else { return [] }
        return data.withUnsafeBytes { raw in
            Array(raw.bindMemory(to: Float.self).prefix(count))
        }
    }
}
