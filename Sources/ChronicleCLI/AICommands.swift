import ArgumentParser
import ChronicleAI
import ChronicleCore
import ChronicleModels
import ChronicleQuery
import Foundation

/// `chronicle summarize <range>` — an AI (or rule-based) summary of a period.
///
/// Uses the configured remote provider when AI is enabled, passing the prompt
/// through the redaction gate first; otherwise (and on any failure) it falls back
/// to the offline rule-based narrative.
struct SummarizeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "summarize",
        abstract: "Summarize a period's activity (AI when enabled, else rule-based)."
    )

    @OptionGroup var options: GlobalOptions

    @Argument(help: "Time range (default: today).")
    var range: String = "today"

    func run() async throws {
        let context = try CLIContext.make(options)
        let interval = TimeRangeParser.parse(range)
        let report = try await context.query.report(range: interval)
        let sessions = try await context.query.sessions(range: interval)

        var baseline = NarrativeBuilder.narrative(from: report)
        if !sessions.isEmpty {
            baseline += " You had \(sessions.count) activity session\(sessions.count == 1 ? "" : "s")."
        }

        let ai = context.configuration.ai
        guard ai.enabled,
              let provider = RemoteSummarizer.Provider(rawValue: ai.provider),
              let endpoint = ai.endpoint.flatMap(URL.init(string:)) ?? RemoteSummarizer.defaultEndpoint(for: provider)
        else {
            print(baseline)
            return
        }

        let events = try await context.query.timeline(EventQuery(range: interval, order: .ascending, limit: 500))
        let prompt = PromptBuilder.dailySummary(events: events, baseline: baseline)
        let summarizer = RemoteSummarizer(
            provider: provider,
            model: ai.model,
            endpoint: endpoint,
            apiKey: KeychainStore().read(account: "api_key"),
            redactor: ai.redactBeforeEgress ? TextRedactor() : nil
        )

        do {
            try await print(summarizer.summarize(prompt))
        } catch {
            printError("AI summarize failed (\(error)); using rule-based summary.")
            print(baseline)
        }
    }
}
