import ArgumentParser
import ChronicleModels
import ChronicleQuery
import Foundation

/// `chronicle stats` — aggregate counts over a time range.
struct StatsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "stats",
        abstract: "Show activity statistics."
    )

    @OptionGroup var options: GlobalOptions

    @Option(name: .long, help: "Time range (default: today).")
    var range: String = "today"

    func run() async throws {
        let context = try CLIContext.make(options)
        let interval = TimeRangeParser.parse(range)
        let report = try await context.query.report(range: interval)

        if options.json {
            try emitJSON(report)
        } else {
            emitText(report)
        }
    }

    private func emitText(_ report: StatisticsReport) {
        let color = Style.shouldUseColor(json: options.json)
        print(Style.bold("Total events: \(report.total)", color))
        print("")

        printTable(title: "By kind", pairs: report.byKind.map { ($0.key.rawValue, $0.value) }, color: color)
        printTable(title: "By source", pairs: report.bySource.map { ($0.key.rawValue, $0.value) }, color: color)
        printTable(title: "Top apps", pairs: report.topApps.map { ($0.app, $0.count) }, color: color)
        printHistogram(report.hourHistogram, color: color)
    }

    private func printTable(title: String, pairs: [(String, Int)], color: Bool) {
        guard !pairs.isEmpty else { return }
        print(Style.bold(title, color))
        var table = Table(headers: ["Name", "Count"])
        table.rows = pairs.sorted { $0.1 > $1.1 }.map { [$0.0, String($0.1)] }
        print(table.render(color: color))
        print("")
    }

    private func printHistogram(_ histogram: [Int: Int], color: Bool) {
        guard let peak = histogram.values.max(), peak > 0 else { return }
        print(Style.bold("By hour", color))
        for hour in 0..<24 {
            let count = histogram[hour] ?? 0
            let barLength = Int((Double(count) / Double(peak) * 30).rounded())
            let bar = String(repeating: "█", count: barLength)
            print(String(format: "%02d  %@ %d", hour, bar, count))
        }
    }

    private func emitJSON(_ report: StatisticsReport) throws {
        var object: [String: Any] = ["total": report.total]
        object["by_kind"] = Dictionary(
            report.byKind.map { ($0.key.rawValue, $0.value) },
            uniquingKeysWith: { first, _ in first }
        )
        object["by_source"] = Dictionary(
            report.bySource.map { ($0.key.rawValue, $0.value) },
            uniquingKeysWith: { first, _ in first }
        )
        object["top_apps"] = report.topApps.map { ["app": $0.app, "count": $0.count] }
        object["by_hour"] = Dictionary(
            report.hourHistogram.map { (String($0.key), $0.value) },
            uniquingKeysWith: { first, _ in first }
        )
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        print(utf8String(data))
    }
}

/// `chronicle explain` — a rule-based narrative of a period's activity.
struct ExplainCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "explain",
        abstract: "Describe your activity for a period in plain language."
    )

    @OptionGroup var options: GlobalOptions

    @Option(name: .long, help: "Time range (default: today).")
    var range: String = "today"

    func run() async throws {
        let context = try CLIContext.make(options)
        let interval = TimeRangeParser.parse(range)
        let report = try await context.query.report(range: interval)
        let narrative = NarrativeBuilder.narrative(from: report)

        if options.json {
            let data = try JSONSerialization.data(withJSONObject: ["narrative": narrative], options: [.prettyPrinted])
            print(utf8String(data))
        } else {
            print(narrative)
        }
    }
}
