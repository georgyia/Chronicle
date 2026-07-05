import Foundation

/// A fully-formed, persistable record of a single unit of user activity.
///
/// `Event` is the central domain entity. It is an immutable value type with a
/// time-ordered ``EventID``, a timestamp, a ``EventKind``, the originating
/// ``CollectorSource``, an optional ``SessionID`` assigned during enrichment, a
/// typed ``EventAttributes`` bag, and an optional ``EventDigest`` used for
/// deduplication at the storage boundary.
public struct Event: Sendable, Hashable, Codable, Identifiable {
    /// The unique, time-ordered identifier.
    public let id: EventID
    /// When the underlying activity occurred.
    public let timestamp: Date
    /// The category of the event.
    public let kind: EventKind
    /// The collector that produced the event.
    public let source: CollectorSource
    /// The session this event belongs to, assigned during enrichment.
    public var sessionID: SessionID?
    /// Typed attributes describing the event.
    public var attributes: EventAttributes
    /// The content digest used to deduplicate identical events.
    public var dedupeDigest: EventDigest?

    /// Creates an event.
    /// - Parameters:
    ///   - id: The unique, time-ordered identifier.
    ///   - timestamp: When the activity occurred.
    ///   - kind: The category of the event.
    ///   - source: The producing collector.
    ///   - sessionID: The session this event belongs to, if known.
    ///   - attributes: Typed attributes describing the event.
    ///   - dedupeDigest: The content digest used for deduplication, if computed.
    public init(
        id: EventID,
        timestamp: Date,
        kind: EventKind,
        source: CollectorSource,
        sessionID: SessionID? = nil,
        attributes: EventAttributes = EventAttributes(),
        dedupeDigest: EventDigest? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.kind = kind
        self.source = source
        self.sessionID = sessionID
        self.attributes = attributes
        self.dedupeDigest = dedupeDigest
    }
}
