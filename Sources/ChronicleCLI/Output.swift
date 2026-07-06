import ChronicleModels
import Foundation

/// ANSI styling helpers that no-op when color is disabled.
enum Style {
    static func bold(_ text: String, _ enabled: Bool) -> String {
        wrap(text, "1", enabled)
    }

    static func dim(_ text: String, _ enabled: Bool) -> String {
        wrap(text, "2", enabled)
    }

    static func color(_ text: String, _ code: Int, _ enabled: Bool) -> String {
        wrap(text, "\(code)", enabled)
    }

    private static func wrap(_ text: String, _ code: String, _ enabled: Bool) -> String {
        enabled ? "\u{1B}[\(code)m\(text)\u{1B}[0m" : text
    }

    /// Whether ANSI color should be emitted for the current invocation.
    static func shouldUseColor(json: Bool) -> Bool {
        guard !json else { return false }
        guard ProcessInfo.processInfo.environment["NO_COLOR"] == nil else { return false }
        return isatty(fileno(stdout)) == 1
    }
}

/// A simple left-aligned text table.
struct Table {
    let headers: [String]
    var rows: [[String]] = []

    /// Renders the table, optionally with bold headers.
    func render(color: Bool) -> String {
        let columnCount = headers.count
        var widths = headers.map(\.count)
        for row in rows {
            for index in 0..<min(columnCount, row.count) {
                widths[index] = max(widths[index], row[index].count)
            }
        }

        func format(_ cells: [String], bold: Bool) -> String {
            let padded = (0..<columnCount).map { index -> String in
                let value = index < cells.count ? cells[index] : ""
                let cell = value.padding(toLength: widths[index], withPad: " ", startingAt: 0)
                return bold ? Style.bold(cell, color) : cell
            }
            return padded.joined(separator: "  ")
        }

        var lines = [format(headers, bold: true)]
        lines.append(contentsOf: rows.map { format($0, bold: false) })
        return lines.joined(separator: "\n")
    }
}

/// Formats events for human-readable output.
enum EventFormatter {
    private static let home = NSHomeDirectory()

    /// A one-line timeline entry for an event.
    static func line(for event: Event, color: Bool) -> String {
        let time = timeFormatter.string(from: event.timestamp)
        let kind = event.kind.rawValue.padding(toLength: 20, withPad: " ", startingAt: 0)
        let coloredKind = Style.color(kind, colorCode(for: event.kind), color)
        return "\(Style.dim(time, color))  \(coloredKind)  \(detail(for: event))"
    }

    /// The salient detail for an event, home-abbreviated.
    static func detail(for event: Event) -> String {
        let attributes = event.attributes
        if let title = attributes.string(.title), !title.isEmpty {
            if let app = attributes.string(.appName) { return "\(app) — \(title)" }
            return title
        }
        if let command = attributes.string(.command) { return command }
        if let path = attributes.string(.path) { return abbreviate(path) }
        if let url = attributes.string(.url) { return url }
        if let app = attributes.string(.appName) { return app }
        return ""
    }

    /// Replaces the home directory prefix with `~`.
    static func abbreviate(_ path: String) -> String {
        path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }

    private static func colorCode(for kind: EventKind) -> Int {
        switch kind.namespace {
        case "file": 34 // blue
        case "app", "window": 32 // green
        case "power", "session": 35 // magenta
        case "browser": 36 // cyan
        case "shell", "git": 33 // yellow
        default: 37 // white
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d HH:mm:ss"
        return formatter
    }()
}
