import ChronicleCore
import Foundation

/// Errors raised by the storage layer.
public enum StorageError: ChronicleError {
    /// The database could not be opened or created.
    case open(String)
    /// A migration failed to apply.
    case migration(String)
    /// A stored row could not be decoded into a domain value.
    case corruptedRow(String)
    /// An integrity check failed.
    case integrity(String)

    public var code: String {
        switch self {
        case .open: "storage.open_failed"
        case .migration: "storage.migration_failed"
        case .corruptedRow: "storage.corrupted_row"
        case .integrity: "storage.integrity_failed"
        }
    }

    public var message: String {
        switch self {
        case let .open(detail): "Failed to open database: \(detail)"
        case let .migration(detail): "Migration failed: \(detail)"
        case let .corruptedRow(detail): "Corrupted row: \(detail)"
        case let .integrity(detail): "Integrity check failed: \(detail)"
        }
    }
}
