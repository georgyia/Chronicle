/// A point-in-time snapshot of pipeline counters.
///
/// Surfaced over IPC for `chronicle status` and used in tests to assert flow.
public struct PipelineMetrics: Sendable, Equatable, Codable {
    /// Raw events received by the pipeline.
    public var ingested: Int
    /// Events dropped by validation.
    public var rejected: Int
    /// Events dropped as duplicates.
    public var deduplicated: Int
    /// Events successfully persisted.
    public var persisted: Int
    /// Events dropped because a stage threw.
    public var failed: Int
    /// Events currently buffered awaiting a flush.
    public var buffered: Int

    /// Creates a zeroed metrics value.
    public init(
        ingested: Int = 0,
        rejected: Int = 0,
        deduplicated: Int = 0,
        persisted: Int = 0,
        failed: Int = 0,
        buffered: Int = 0
    ) {
        self.ingested = ingested
        self.rejected = rejected
        self.deduplicated = deduplicated
        self.persisted = persisted
        self.failed = failed
        self.buffered = buffered
    }
}
