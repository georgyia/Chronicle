import ChronicleModels
import Foundation

/// The direction in which query results are ordered by time.
public enum EventSortOrder: String, Sendable, Hashable, Codable {
    /// Oldest first.
    case ascending
    /// Newest first.
    case descending
}

/// A typed, storage-agnostic description of a set of events to retrieve.
///
/// Higher layers (the CLI, the query engine) translate user input into an
/// `EventQuery`; the repository translates it into SQL. Keeping the query as a
/// value type means it can be constructed and asserted on in tests without a
/// database.
public struct EventQuery: Sendable, Hashable {
    /// Restrict to events within this half-open time interval.
    public var range: DateInterval?
    /// Restrict to these event kinds (empty means "any").
    public var kinds: Set<EventKind>
    /// Restrict to these sources (empty means "any").
    public var sources: Set<CollectorSource>
    /// Full-text query string matched against indexed text (title/path/app/command).
    public var text: String?
    /// Restrict to events whose path attribute has this prefix.
    public var pathPrefix: String?
    /// Restrict to events whose app name matches (case-insensitive).
    public var appName: String?
    /// Ordering of results by time.
    public var order: EventSortOrder
    /// Maximum number of results to return.
    public var limit: Int?
    /// Keyset pagination cursor: return events strictly before this id (in `order`).
    public var pageAfter: EventID?

    /// Creates an event query. All filters default to unrestricted.
    public init(
        range: DateInterval? = nil,
        kinds: Set<EventKind> = [],
        sources: Set<CollectorSource> = [],
        text: String? = nil,
        pathPrefix: String? = nil,
        appName: String? = nil,
        order: EventSortOrder = .descending,
        limit: Int? = nil,
        pageAfter: EventID? = nil
    ) {
        self.range = range
        self.kinds = kinds
        self.sources = sources
        self.text = text
        self.pathPrefix = pathPrefix
        self.appName = appName
        self.order = order
        self.limit = limit
        self.pageAfter = pageAfter
    }
}

/// A single full-text search result: the matched event plus ranking metadata.
public struct SearchHit: Sendable, Hashable {
    /// The matched event.
    public let event: Event
    /// A highlighted snippet of the matching text, if available.
    public let snippet: String?
    /// The relevance score (higher is more relevant).
    public let score: Double

    /// Creates a search hit.
    public init(event: Event, snippet: String?, score: Double) {
        self.event = event
        self.snippet = snippet
        self.score = score
    }
}
