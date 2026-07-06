import Foundation
import Testing
@testable import ChronicleQuery

@Suite("Time range parsing")
struct TimeRangeParserTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }

    /// 2026-07-06 12:00:00 UTC
    private let now = Date(timeIntervalSince1970: 1_783_339_200)

    @Test("All-time expressions return nil")
    func allTime() {
        #expect(TimeRangeParser.parse("all", now: now, calendar: calendar) == nil)
        #expect(TimeRangeParser.parse("", now: now, calendar: calendar) == nil)
    }

    @Test("Today spans the current day")
    func today() throws {
        let interval = try #require(TimeRangeParser.parse("today", now: now, calendar: calendar))
        #expect(calendar.startOfDay(for: now) == interval.start)
        #expect(interval.duration == 86400)
    }

    @Test("Yesterday is the day before")
    func yesterday() throws {
        let interval = try #require(TimeRangeParser.parse("yesterday", now: now, calendar: calendar))
        #expect(interval.end == calendar.startOfDay(for: now))
    }

    @Test("Relative spans subtract from now")
    func relative() throws {
        let threeDays = try #require(TimeRangeParser.parse("3d", now: now, calendar: calendar))
        #expect(threeDays.end == now)
        #expect(threeDays.duration == 3 * 86400)

        let hours = try #require(TimeRangeParser.parse("6h", now: now, calendar: calendar))
        #expect(hours.duration == 6 * 3600)
    }

    @Test("ISO dates resolve to that day")
    func isoDate() throws {
        let interval = try #require(TimeRangeParser.parse("2026-07-01", now: now, calendar: calendar))
        #expect(interval.duration == 86400)
    }

    @Test("Unrecognized text returns nil")
    func unrecognized() {
        #expect(TimeRangeParser.parse("whenever", now: now, calendar: calendar) == nil)
    }
}
