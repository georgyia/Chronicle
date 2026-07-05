/// The Chronicle storage layer.
///
/// Implements the persistence protocols declared in `ChronicleCore`
/// (``EventRepository``, ``SearchRepository``, ``StatisticsRepository``) on top of
/// SQLite via GRDB. Nothing outside this module references GRDB or SQL.
///
/// Implemented in Phase 2.
public enum ChronicleStorage {
    /// The storage schema version this build manages.
    public static let schemaVersion = 1
}
