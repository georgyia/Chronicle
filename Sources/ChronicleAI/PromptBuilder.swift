import ChronicleModels
import Foundation

/// Builds prompts for AI summarization from recorded events.
public enum PromptBuilder {
    /// Builds a daily-summary prompt from events and a baseline narrative.
    /// - Parameters:
    ///   - events: The events to summarize (a bounded sample is used).
    ///   - baseline: A rule-based narrative to ground the model.
    ///   - maxEvents: The maximum number of event lines to include.
    public static func dailySummary(events: [Event], baseline: String, maxEvents: Int = 120) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        let lines = events.prefix(maxEvents).map { event -> String in
            let detail = detail(for: event)
            return "- \(formatter.string(from: event.timestamp)) \(event.kind.rawValue) \(detail)"
        }

        return """
        You are summarizing a person's computer activity for a day. Be concise and \
        factual, grouping related work into a few sentences. Do not invent details.

        Baseline facts: \(baseline)

        Activity log:
        \(lines.joined(separator: "\n"))

        Write a 2-4 sentence summary of what the person worked on.
        """
    }

    private static func detail(for event: Event) -> String {
        let attributes = event.attributes
        return attributes.string(.title)
            ?? attributes.string(.command)
            ?? attributes.string(.path)
            ?? attributes.string(.appName)
            ?? attributes.string(.url)
            ?? ""
    }
}
