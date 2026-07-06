import Foundation

/// Tuning parameters for the ingestion pipeline.
///
/// A plain value type so the composition root can build it from configuration and
/// tests can construct it directly.
public struct PipelineSettings: Sendable, Equatable {
    /// Maximum events written per transaction / flush.
    public var batchSize: Int
    /// Maximum time to buffer events before flushing.
    public var flushInterval: Duration
    /// Sliding window within which identical events are treated as duplicates.
    public var dedupeWindow: Duration
    /// Number of recent digests retained for deduplication.
    public var dedupeCacheSize: Int
    /// Hard cap on buffered-but-unflushed events; a safety valve against storms
    /// where persistence cannot keep up. Oldest events are dropped past this.
    public var maxBufferedEvents: Int

    /// Creates pipeline settings.
    public init(
        batchSize: Int = 128,
        flushInterval: Duration = .seconds(1),
        dedupeWindow: Duration = .milliseconds(2000),
        dedupeCacheSize: Int = 4096,
        maxBufferedEvents: Int = 8192
    ) {
        self.batchSize = batchSize
        self.flushInterval = flushInterval
        self.dedupeWindow = dedupeWindow
        self.dedupeCacheSize = dedupeCacheSize
        self.maxBufferedEvents = maxBufferedEvents
    }
}
