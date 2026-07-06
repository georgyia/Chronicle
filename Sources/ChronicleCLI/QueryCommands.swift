import ArgumentParser
import ChronicleCore
import ChronicleModels
import ChronicleQuery
import Foundation

/// Shared filter options for timeline and search commands.
struct FilterOptions: ParsableArguments {
    /// Time range expression (e.g. `today`, `last week`, `3d`, `2026-07-01`).
    @Option(name: .long, help: "Time range (today, yesterday, 'last week', 3d, ISO date, all).")
    var range: String?

    /// Restrict to these event kinds (repeatable).
    @Option(name: .long, help: "Filter by event kind (e.g. file.created). Repeatable.")
    var kind: [String] = []

    /// Restrict to these sources (repeatable).
    @Option(name: .long, help: "Filter by collector source. Repeatable.")
    var source: [String] = []

    /// Restrict to an application name.
    @Option(name: .long, help: "Filter by application name.")
    var app: String?

    /// Restrict to a path prefix.
    @Option(name: .long, help: "Filter by path prefix.")
    var path: String?

    /// Maximum results.
    @Option(name: .long, help: "Maximum number of results.")
    var limit: Int = 100

    init() {}

    /// Builds an ``EventQuery`` from these filters and a resolved range.
    func makeQuery(
        range interval: DateInterval?,
        text: String? = nil,
        order: EventSortOrder = .descending
    ) -> EventQuery {
        EventQuery(
            range: interval,
            kinds: Set(kind.map { EventKind(rawValue: $0) }),
            sources: Set(source.map { CollectorSource(rawValue: $0) }),
            text: text,
            pathPrefix: path.map { ($0 as NSString).expandingTildeInPath },
            appName: app,
            order: order,
            limit: limit
        )
    }
}

/// Emits a list of events as JSON or formatted lines.
func emit(_ events: [Event], json: Bool) throws {
    if json {
        let data = try chronicleJSONEncoder().encode(events)
        print(utf8String(data))
        return
    }
    guard !events.isEmpty else {
        print("No events found.")
        return
    }
    let color = Style.shouldUseColor(json: json)
    for event in events {
        print(EventFormatter.line(for: event, color: color))
    }
}

/// `chronicle timeline` — a chronological view of activity.
struct TimelineCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "timeline",
        abstract: "Show a chronological view of your activity."
    )

    @OptionGroup var options: GlobalOptions
    @OptionGroup var filters: FilterOptions

    @Flag(name: .long, help: "Group activity into sessions instead of listing events.")
    var sessions = false

    func run() async throws {
        let context = try CLIContext.make(options)
        let interval = TimeRangeParser.parse(filters.range ?? "today")
        if sessions {
            let reconstructed = try await context.query.sessions(range: interval)
            emitSessions(reconstructed, json: options.json)
            return
        }
        let events = try await context.query.timeline(filters.makeQuery(range: interval))
        try emit(events, json: options.json)
    }
}

/// Prints reconstructed activity sessions.
func emitSessions(_ sessions: [ActivitySession], json: Bool) {
    let timeFormatter = DateFormatter()
    timeFormatter.dateFormat = "MMM d HH:mm"
    guard !sessions.isEmpty else {
        print("No sessions found.")
        return
    }
    for session in sessions {
        let duration = Int(session.end.timeIntervalSince(session.start) / 60)
        let apps = session.topApps.isEmpty ? "" : " — " + session.topApps.joined(separator: ", ")
        print("\(timeFormatter.string(from: session.start))–\(timeFormatter.string(from: session.end)) "
            + "(\(duration)m, \(session.eventCount) events)\(apps)")
    }
}

/// `chronicle today` — sugar for `timeline --range today`.
struct TodayCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "today", abstract: "Show today's activity.")

    @OptionGroup var options: GlobalOptions
    @OptionGroup var filters: FilterOptions

    func run() async throws {
        let context = try CLIContext.make(options)
        let events = try await context.query.timeline(filters.makeQuery(range: TimeRangeParser.parse("today")))
        try emit(events, json: options.json)
    }
}

/// `chronicle yesterday` — sugar for `timeline --range yesterday`.
struct YesterdayCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "yesterday", abstract: "Show yesterday's activity.")

    @OptionGroup var options: GlobalOptions
    @OptionGroup var filters: FilterOptions

    func run() async throws {
        let context = try CLIContext.make(options)
        let events = try await context.query.timeline(filters.makeQuery(range: TimeRangeParser.parse("yesterday")))
        try emit(events, json: options.json)
    }
}

/// `chronicle search` — full-text search over recorded activity.
struct SearchCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "search",
        abstract: "Search your activity by text."
    )

    @OptionGroup var options: GlobalOptions
    @OptionGroup var filters: FilterOptions

    @Flag(name: .long, help: "Use AI semantic search (requires the AI module).")
    var semantic = false

    @Argument(help: "Search text, optionally with kind:/app:/path:/before:/after: filters.")
    var query: String

    func run() async throws {
        let context = try CLIContext.make(options)
        if semantic, !context.configuration.ai.enabled {
            printError("Semantic search requires the AI module; falling back to text search.")
        }
        let parsed = SearchQueryParser.parse(query)
        var eventQuery = SearchQueryParser.makeEventQuery(parsed, limit: filters.limit)
        overlay(&eventQuery)
        let hits = try await context.query.find(eventQuery)
        try emitHits(hits, json: options.json)
    }

    /// Overlays explicit `--kind/--source/--app/--path/--range` flags onto the
    /// filters parsed from the query string.
    private func overlay(_ query: inout EventQuery) {
        query.kinds.formUnion(filters.kind.map { EventKind(rawValue: $0) })
        query.sources.formUnion(filters.source.map { CollectorSource(rawValue: $0) })
        if let app = filters.app { query.appName = app }
        if let path = filters.path { query.pathPrefix = (path as NSString).expandingTildeInPath }
        if let range = filters.range { query.range = TimeRangeParser.parse(range) }
    }

    private func emitHits(_ hits: [SearchHit], json: Bool) throws {
        if json {
            let events = hits.map(\.event)
            let data = try chronicleJSONEncoder().encode(events)
            print(utf8String(data))
            return
        }
        guard !hits.isEmpty else {
            print("No matches.")
            return
        }
        let color = Style.shouldUseColor(json: json)
        for hit in hits {
            print(EventFormatter.line(for: hit.event, color: color))
            if let snippet = hit.snippet, !snippet.isEmpty {
                print("    " + Style.dim(snippet, color))
            }
        }
    }
}

/// `chronicle inspect <id>` — show one event in full.
struct InspectCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "inspect",
        abstract: "Show the full details of a single event."
    )

    @OptionGroup var options: GlobalOptions

    @Argument(help: "The event id.")
    var id: String

    func run() async throws {
        let context = try CLIContext.make(options)
        guard let uuid = UUID(uuidString: id) else {
            printError("Invalid event id: \(id)")
            throw CLIExit.notFound
        }
        guard let event = try await context.query.inspect(id: EventID(rawValue: uuid)) else {
            printError("No event with id \(id)")
            throw CLIExit.notFound
        }

        if options.json {
            let data = try chronicleJSONEncoder().encode(event)
            print(utf8String(data))
            return
        }
        print("id:        \(event.id)")
        print("timestamp: \(event.timestamp)")
        print("kind:      \(event.kind)")
        print("source:    \(event.source)")
        if let session = event.sessionID { print("session:   \(session)") }
        print("attributes:")
        for (key, value) in event.attributes.values.sorted(by: { $0.key < $1.key }) {
            print("  \(key): \(value.stringValue ?? "\(value)")")
        }
    }
}
