/// The Chronicle storage layer.
///
/// Implements the persistence protocols declared in `ChronicleCore`
/// (``EventRepository``, ``SearchRepository``, ``StatisticsRepository``) on top of
/// SQLite via GRDB. Nothing outside this module references GRDB or SQL — callers
/// depend only on the kernel protocols and construct a ``SQLiteEventStore`` in the
/// composition root.
public enum ChronicleStorage {
    /// The storage schema version this build manages.
    public static let schemaVersion = 2
}
