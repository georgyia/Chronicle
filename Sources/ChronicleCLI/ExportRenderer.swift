import ChronicleModels
import Foundation

/// Renders events into CSV and Markdown export formats.
enum ExportRenderer {
    private static let columns: [AttributeKey] = [.path, .appName, .title, .url, .command]

    /// Renders events as CSV with a fixed header.
    static func csv(_ events: [Event]) -> String {
        var lines = ["id,timestamp,kind,source,path,app,title,url,command"]
        let formatter = ISO8601DateFormatter()
        for event in events {
            let fields = [
                event.id.description,
                formatter.string(from: event.timestamp),
                event.kind.rawValue,
                event.source.rawValue,
                event.attributes.string(.path) ?? "",
                event.attributes.string(.appName) ?? "",
                event.attributes.string(.title) ?? "",
                event.attributes.string(.url) ?? "",
                event.attributes.string(.command) ?? "",
            ]
            lines.append(fields.map(escape).joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    /// Renders events as a Markdown list grouped by day.
    static func markdown(_ events: [Event]) -> String {
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"

        var lines = ["# Chronicle export", ""]
        var currentDay: String?
        for event in events {
            let day = dayFormatter.string(from: event.timestamp)
            if day != currentDay {
                lines.append("## \(day)")
                currentDay = day
            }
            let detail = EventFormatter.detail(for: event)
            lines.append("- `\(timeFormatter.string(from: event.timestamp))` **\(event.kind.rawValue)** \(detail)")
        }
        return lines.joined(separator: "\n")
    }

    private static func escape(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
