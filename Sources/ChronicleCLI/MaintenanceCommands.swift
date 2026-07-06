import ApplicationServices
import ArgumentParser
import ChronicleConfig
import ChronicleCore
import ChronicleModels
import ChronicleQuery
import Foundation

/// `chronicle doctor` — diagnose common problems.
struct DoctorCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "doctor",
        abstract: "Diagnose configuration, storage, permissions, and the daemon."
    )

    @OptionGroup var options: GlobalOptions

    private struct Check {
        let name: String
        let passed: Bool
        let detail: String
    }

    func run() async throws {
        let context = try CLIContext.make(options)
        var checks: [Check] = []
        checks.append(configurationCheck(context))

        let integrity = await (try? context.store.checkIntegrity()) ?? false
        checks.append(Check(
            name: "Database integrity",
            passed: integrity,
            detail: integrity ? "ok" : "run `chronicle export` and rebuild if this persists"
        ))

        let reachable = await context.sendIPC(.ping)
        let running = if case .success(.pong) = reachable { true } else { false }
        checks.append(Check(
            name: "Daemon reachable",
            passed: running,
            detail: running ? "ok" : "start it with `chronicle daemon start`"
        ))

        let trusted = AXIsProcessTrusted()
        checks.append(Check(
            name: "Accessibility permission",
            passed: trusted,
            detail: trusted ? "granted" : "grant in System Settings > Privacy > Accessibility for window titles"
        ))

        emit(checks)
        if checks.contains(where: { !$0.passed }) { throw CLIExit.doctorFailed }
    }

    private func configurationCheck(_ context: CLIContext) -> Check {
        do {
            try ConfigurationLoader().validate(context.configuration)
            return Check(name: "Configuration", passed: true, detail: "valid")
        } catch {
            return Check(name: "Configuration", passed: false, detail: "\(error)")
        }
    }

    private func emit(_ checks: [Check]) {
        let color = Style.shouldUseColor(json: options.json)
        for check in checks {
            let mark = check.passed ? Style.color("✓", 32, color) : Style.color("✗", 31, color)
            print("\(mark) \(check.name): \(check.detail)")
        }
    }
}

/// The output format for `chronicle export`.
enum ExportFormat: String, ExpressibleByArgument {
    case json, csv, markdown
}

/// `chronicle export` — export events to JSONL, CSV, or Markdown.
struct ExportCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "export",
        abstract: "Export events to json (JSONL), csv, or markdown."
    )

    @OptionGroup var options: GlobalOptions
    @Argument(help: "Format: json, csv, or markdown.") var format: ExportFormat
    @Option(name: .long, help: "Time range (default: all).") var range: String = "all"
    @Option(name: .long, help: "Output file (default: stdout).") var output: String?

    func run() async throws {
        let context = try CLIContext.make(options)
        let interval = TimeRangeParser.parse(range)
        let events = try await context.query.timeline(EventQuery(range: interval, order: .ascending, limit: nil))
        let text = try render(events)
        if let output {
            try text.write(toFile: output, atomically: true, encoding: .utf8)
            print("Exported \(events.count) events to \(output)")
        } else {
            print(text)
        }
    }

    private func render(_ events: [Event]) throws -> String {
        switch format {
        case .json:
            let encoder = chronicleJSONEncoder(pretty: false)
            return try events.map { try utf8String(encoder.encode($0)) }.joined(separator: "\n")
        case .csv:
            return ExportRenderer.csv(events)
        case .markdown:
            return ExportRenderer.markdown(events)
        }
    }
}

/// `chronicle import` — import events from a JSONL file.
struct ImportCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "import",
        abstract: "Import events from a JSONL file (deduplicated on insert)."
    )

    @OptionGroup var options: GlobalOptions
    @Argument(help: "Path to a JSONL file produced by `chronicle export json`.") var file: String

    func run() async throws {
        let context = try CLIContext.make(options)
        let contents = try String(contentsOfFile: file, encoding: .utf8)
        let decoder = chronicleJSONDecoder()
        var events: [Event] = []
        for line in contents.split(separator: "\n") where !line.isEmpty {
            if let event = try? decoder.decode(Event.self, from: Data(line.utf8)) {
                events.append(event)
            }
        }
        let inserted = try await context.store.insert(events)
        print("Imported \(inserted) new events (\(events.count - inserted) duplicates skipped).")
    }
}

/// `chronicle delete` — remove events by age or match.
struct DeleteCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "delete",
        abstract: "Delete events older than a date or matching text."
    )

    @OptionGroup var options: GlobalOptions
    @Option(name: .long, help: "Delete events before this ISO date (yyyy-MM-dd).") var before: String?
    @Option(name: .long, help: "Delete events matching this text.") var matching: String?
    @Flag(name: .long, help: "Skip the confirmation prompt.") var yes = false

    func run() async throws {
        let context = try CLIContext.make(options)
        guard before != nil || matching != nil else {
            printError("Specify --before <date> or --matching <text>.")
            throw CLIExit.failure
        }
        if !yes {
            print("This permanently deletes events. Re-run with --yes to confirm.")
            return
        }
        var deleted = 0
        if let before, let interval = TimeRangeParser.parse(before) {
            deleted += try await context.store.deleteEvents(before: interval.start)
        }
        if let matching {
            deleted += try await context.store.deleteEvents(matching: EventQuery(text: matching))
        }
        print("Deleted \(deleted) events.")
    }
}
