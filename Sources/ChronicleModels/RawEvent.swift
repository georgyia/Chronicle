import Foundation

/// An observation emitted by a collector, before enrichment and persistence.
///
/// Collectors produce `RawEvent`s and know nothing about identifiers, sessions,
/// deduplication, or storage. The pipeline is responsible for turning a
/// `RawEvent` into a fully-formed ``Event``.
public struct RawEvent: Sendable, Hashable {
    /// When the underlying activity occurred.
    public var timestamp: Date
    /// The category of the observation.
    public var kind: EventKind
    /// The collector that produced the observation.
    public var source: CollectorSource
    /// Free-form typed attributes describing the observation.
    public var attributes: EventAttributes

    /// Creates a raw event.
    /// - Parameters:
    ///   - timestamp: When the activity occurred.
    ///   - kind: The category of the observation.
    ///   - source: The producing collector.
    ///   - attributes: Typed attributes describing the observation.
    public init(
        timestamp: Date,
        kind: EventKind,
        source: CollectorSource,
        attributes: EventAttributes = EventAttributes()
    ) {
        self.timestamp = timestamp
        self.kind = kind
        self.source = source
        self.attributes = attributes
    }
}
