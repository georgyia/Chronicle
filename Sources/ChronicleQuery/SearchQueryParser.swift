import ChronicleCore
import ChronicleModels
import Foundation

/// A structured search request parsed from a query string.
public struct ParsedSearchQuery: Sendable, Equatable {
    /// Free-text terms (everything not a recognized `key:value` token).
    public var text: String?
    /// `kind:` filters.
    public var kinds: Set<EventKind>
    /// `source:` filters.
    public var sources: Set<CollectorSource>
    /// `app:` filter.
    public var appName: String?
    /// `path:` prefix filter.
    public var pathPrefix: String?
    /// `before:`/`after:` derived range.
    public var range: DateInterval?

    /// Creates a parsed search query.
    public init(
        text: String? = nil,
        kinds: Set<EventKind> = [],
        sources: Set<CollectorSource> = [],
        appName: String? = nil,
        pathPrefix: String? = nil,
        range: DateInterval? = nil
    ) {
        self.text = text
        self.kinds = kinds
        self.sources = sources
        self.appName = appName
        self.pathPrefix = pathPrefix
        self.range = range
    }
}

/// Parses a search expression such as
/// `kind:file.created app:Safari path:~/Projects before:2026-07-01 "invoice"`.
///
/// Recognized keys: `kind`, `source`, `app`, `path`, `before`, `after`. Anything
/// else becomes free-text. Pure and unit-tested.
public enum SearchQueryParser {
    /// Parses an input string into a ``ParsedSearchQuery``.
    public static func parse(_ input: String, now: Date = Date(), calendar: Calendar = .current) -> ParsedSearchQuery {
        var result = ParsedSearchQuery()
        var textTerms: [String] = []
        var after: Date?
        var before: Date?

        for token in tokenize(input) {
            guard let separator = token.firstIndex(of: ":"),
                  let key = SearchKey(rawValue: String(token[token.startIndex..<separator]))
            else {
                textTerms.append(token)
                continue
            }
            let value = String(token[token.index(after: separator)...])
            apply(key: key, value: value, into: &result, after: &after, before: &before, calendar: calendar)
        }

        if !textTerms.isEmpty { result.text = textTerms.joined(separator: " ") }
        if after != nil || before != nil {
            result.range = DateInterval(start: after ?? .distantPast, end: before ?? .distantFuture)
        }
        return result
    }

    /// Converts a parsed query into an ``EventQuery``.
    public static func makeEventQuery(
        _ parsed: ParsedSearchQuery,
        limit: Int,
        order: EventSortOrder = .descending
    ) -> EventQuery {
        EventQuery(
            range: parsed.range,
            kinds: parsed.kinds,
            sources: parsed.sources,
            text: parsed.text,
            pathPrefix: parsed.pathPrefix,
            appName: parsed.appName,
            order: order,
            limit: limit
        )
    }

    private enum SearchKey: String {
        case kind, source, app, path, before, after
    }

    private static func apply(
        key: SearchKey,
        value: String,
        into result: inout ParsedSearchQuery,
        after: inout Date?,
        before: inout Date?,
        calendar: Calendar
    ) {
        switch key {
        case .kind: result.kinds.insert(EventKind(rawValue: value))
        case .source: result.sources.insert(CollectorSource(rawValue: value))
        case .app: result.appName = value
        case .path: result.pathPrefix = (value as NSString).expandingTildeInPath
        case .after: after = TimeRangeParser.parse(value, calendar: calendar)?.start
        case .before: before = TimeRangeParser.parse(value, calendar: calendar)?.end
        }
    }

    /// Splits input on whitespace while keeping double-quoted spans together.
    private static func tokenize(_ input: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var inQuotes = false
        for character in input {
            switch character {
            case "\"":
                inQuotes.toggle()
            case " " where !inQuotes:
                if !current.isEmpty { tokens.append(current)
                    current = ""
                }
            default:
                current.append(character)
            }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }
}
