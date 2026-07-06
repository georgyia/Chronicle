import Foundation

/// Parses human-friendly time-range expressions into a `DateInterval`.
///
/// Supported forms include `today`, `yesterday`, `this week`, `last week`,
/// `this month`, `last month`, relative spans like `3d`/`24h`/`2w`, an ISO date
/// (`2026-07-01`), and `all` (the whole history). Pure and fully unit-tested.
public enum TimeRangeParser {
    /// Parses `text` relative to `now`, or returns `nil` for "all time".
    public static func parse(
        _ text: String,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> DateInterval? {
        let trimmed = text.trimmingCharacters(in: .whitespaces).lowercased()
        switch trimmed {
        case "", "all", "everything":
            return nil
        case "today":
            return dayInterval(containing: now, calendar: calendar)
        case "yesterday":
            let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
            return dayInterval(containing: yesterday, calendar: calendar)
        case "this week":
            return unitInterval(.weekOfYear, containing: now, calendar: calendar)
        case "last week":
            let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
            return unitInterval(.weekOfYear, containing: lastWeek, calendar: calendar)
        case "this month":
            return unitInterval(.month, containing: now, calendar: calendar)
        case "last month":
            let lastMonth = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            return unitInterval(.month, containing: lastMonth, calendar: calendar)
        default:
            return parseRelativeOrISO(trimmed, now: now, calendar: calendar)
        }
    }

    private static func parseRelativeOrISO(_ text: String, now: Date, calendar: Calendar) -> DateInterval? {
        if let relative = parseRelative(text, now: now, calendar: calendar) { return relative }
        if let day = parseISODate(text, calendar: calendar) { return dayInterval(containing: day, calendar: calendar) }
        return nil
    }

    private static func parseRelative(_ text: String, now: Date, calendar: Calendar) -> DateInterval? {
        guard let unit = text.last, let value = Int(text.dropLast()), value > 0 else { return nil }
        let component: Calendar.Component
        switch unit {
        case "h": component = .hour
        case "d": component = .day
        case "w": component = .weekOfYear
        case "m": component = .month
        default: return nil
        }
        guard let start = calendar.date(byAdding: component, value: -value, to: now) else { return nil }
        return DateInterval(start: start, end: now)
    }

    private static func parseISODate(_ text: String, calendar: Calendar) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: text)
    }

    private static func dayInterval(containing date: Date, calendar: Calendar) -> DateInterval {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? date
        return DateInterval(start: start, end: end)
    }

    private static func unitInterval(
        _ component: Calendar.Component,
        containing date: Date,
        calendar: Calendar
    ) -> DateInterval {
        calendar.dateInterval(of: component, for: date)
            ?? dayInterval(containing: date, calendar: calendar)
    }
}
