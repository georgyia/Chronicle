import ChronicleCore
import ChronicleModels
import Foundation
import GRDB

/// Translates between domain ``Event`` values and database rows.
///
/// Confined to the storage module: it owns the JSON encoding of attributes and the
/// construction of the denormalized `search_text` column that backs FTS5.
struct EventMapper {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        decoder = JSONDecoder()
    }

    /// The ordered column names for an event insert.
    static let insertColumns = [
        "id", "ts_ms", "kind", "source", "session_id",
        "dedupe_hash", "search_text", "attrs", "schema_version",
    ]

    /// Builds positional statement arguments for inserting an event.
    func insertArguments(for event: Event) throws -> StatementArguments {
        let attributesJSON = try encodeAttributes(event.attributes)
        return [
            event.id.description,
            event.timestamp.millisecondsSince1970,
            event.kind.rawValue,
            event.source.rawValue,
            event.sessionID?.description,
            event.dedupeDigest?.description,
            searchText(for: event),
            attributesJSON,
            ChronicleStorage.schemaVersion,
        ]
    }

    /// Reconstructs an ``Event`` from a fetched row.
    func event(from row: Row) throws -> Event {
        let idString: String = row["id"]
        guard let uuid = UUID(uuidString: idString) else {
            throw StorageError.corruptedRow("invalid event id '\(idString)'")
        }
        let tsMs: Int64 = row["ts_ms"]
        let attrsJSON: String = row["attrs"]
        let attributes = try decodeAttributes(attrsJSON)

        let sessionID: SessionID? = (row["session_id"] as String?)
            .flatMap(UUID.init(uuidString:))
            .map(SessionID.init(rawValue:))
        let digest: EventDigest? = (row["dedupe_hash"] as String?)
            .flatMap(EventDigest.init(hexEncoded:))

        return Event(
            id: EventID(rawValue: uuid),
            timestamp: Date(millisecondsSince1970: tsMs),
            kind: EventKind(rawValue: row["kind"]),
            source: CollectorSource(rawValue: row["source"]),
            sessionID: sessionID,
            attributes: attributes,
            dedupeDigest: digest
        )
    }

    /// Builds the denormalized text indexed for full-text search.
    func searchText(for event: Event) -> String {
        var parts: [String] = [event.kind.action]
        let attributes = event.attributes
        if let path = attributes.string(.path) {
            parts.append(path)
            parts.append((path as NSString).lastPathComponent)
        }
        for key: AttributeKey in [.title, .appName, .command, .url, .fromPath] {
            if let value = attributes.string(key) { parts.append(value) }
        }
        return parts.filter { !$0.isEmpty }.joined(separator: " ")
    }

    // MARK: - Attribute JSON

    private func encodeAttributes(_ attributes: EventAttributes) throws -> String {
        let data = try encoder.encode(attributes)
        return String(bytes: data, encoding: .utf8) ?? "{}"
    }

    private func decodeAttributes(_ json: String) throws -> EventAttributes {
        guard !json.isEmpty else { return EventAttributes() }
        do {
            return try decoder.decode(EventAttributes.self, from: Data(json.utf8))
        } catch {
            throw StorageError.corruptedRow("invalid attributes JSON: \(error.localizedDescription)")
        }
    }
}
