import ChronicleCore
import ChronicleModels
import ChronicleTestSupport
import Foundation
import Testing
@testable import ChronicleQuery

@Suite("Search grammar")
struct SearchQueryParserTests {
    @Test("Parses filters and free text")
    func parse() {
        let parsed = SearchQueryParser.parse("kind:file.created app:Safari path:~/Projects \"quarterly invoice\"")
        #expect(parsed.kinds.contains(.fileCreated))
        #expect(parsed.appName == "Safari")
        #expect(parsed.pathPrefix?.hasSuffix("/Projects") == true)
        #expect(parsed.text == "quarterly invoice")
    }

    @Test("before/after produce a range")
    func dateRange() {
        let calendar = Calendar(identifier: .gregorian)
        let parsed = SearchQueryParser.parse("after:2026-07-01 before:2026-07-05 report", calendar: calendar)
        #expect(parsed.range != nil)
        #expect(parsed.text == "report")
    }

    @Test("Plain text has no filters")
    func plainText() {
        let parsed = SearchQueryParser.parse("just some words")
        #expect(parsed.text == "just some words")
        #expect(parsed.kinds.isEmpty)
        #expect(parsed.range == nil)
    }
}

@Suite("Relevance ranking")
struct RelevanceRankerTests {
    @Test("Newer events win when relevance is equal")
    func recencyBreaksTies() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let older = SearchHit(
            event: EventFactory.event(timestamp: now.addingTimeInterval(-10 * 86400)),
            snippet: nil,
            score: 1
        )
        let newer = SearchHit(
            event: EventFactory.event(timestamp: now.addingTimeInterval(-1 * 3600)),
            snippet: nil,
            score: 1
        )
        let ranked = RelevanceRanker.rank([older, newer], now: now)
        #expect(ranked.first?.event.id == newer.event.id)
    }

    @Test("Strong relevance still beats recency")
    func relevanceDominates() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let relevant = SearchHit(
            event: EventFactory.event(timestamp: now.addingTimeInterval(-30 * 86400)),
            snippet: nil,
            score: 5
        )
        let recent = SearchHit(event: EventFactory.event(timestamp: now), snippet: nil, score: 0)
        let ranked = RelevanceRanker.rank([recent, relevant], now: now)
        #expect(ranked.first?.event.id == relevant.event.id)
    }
}

@Suite("Session reconstruction")
struct SessionReconstructorTests {
    @Test("Splits events on idle gaps")
    func splits() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let events = [
            EventFactory.event(timestamp: base),
            EventFactory.event(timestamp: base.addingTimeInterval(60)),
            EventFactory.event(timestamp: base.addingTimeInterval(3600)), // > 15m gap
            EventFactory.event(timestamp: base.addingTimeInterval(3660)),
        ]
        let sessions = SessionReconstructor.sessions(from: events)
        #expect(sessions.count == 2)
        #expect(sessions.first?.eventCount == 2)
    }

    @Test("Summarizes top apps")
    func topApps() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let events = [
            EventFactory.event(
                timestamp: base,
                kind: .appActivated,
                source: .application,
                attributes: [.appName: "Xcode"]
            ),
            EventFactory.event(
                timestamp: base.addingTimeInterval(30),
                kind: .appActivated,
                source: .application,
                attributes: [.appName: "Xcode"]
            ),
            EventFactory.event(
                timestamp: base.addingTimeInterval(60),
                kind: .appActivated,
                source: .application,
                attributes: [.appName: "Safari"]
            ),
        ]
        let sessions = SessionReconstructor.sessions(from: events)
        #expect(sessions.first?.topApps.first == "Xcode")
    }

    @Test("Empty input yields no sessions")
    func empty() {
        #expect(SessionReconstructor.sessions(from: []).isEmpty)
    }
}
