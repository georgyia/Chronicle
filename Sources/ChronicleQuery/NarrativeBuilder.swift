import ChronicleModels
import Foundation

/// Produces a rule-based, human-readable narrative from a ``StatisticsReport``.
///
/// This is the offline `explain` engine; Phase 8 layers optional AI summaries on
/// top, falling back to this when AI is disabled. Pure and unit-tested.
public enum NarrativeBuilder {
    /// Builds a short paragraph describing the activity in a report.
    public static func narrative(from report: StatisticsReport) -> String {
        guard report.total > 0 else {
            return "No recorded activity for this period."
        }

        var sentences = ["Chronicle recorded \(report.total) events."]

        if !report.topApps.isEmpty {
            let apps = report.topApps.prefix(3).map(\.app).joined(separator: ", ")
            sentences.append("You spent the most time in \(apps).")
        }

        let fileEvents = report.byKind
            .filter { $0.key.namespace == "file" }
            .map(\.value)
            .reduce(0, +)
        if fileEvents > 0 {
            let created = report.byKind[.fileCreated] ?? 0
            let modified = report.byKind[.fileModified] ?? 0
            sentences.append("You touched \(fileEvents) files (\(created) created, \(modified) modified).")
        }

        if let peak = report.hourHistogram.max(by: { $0.value < $1.value })?.key {
            sentences.append("Your most active hour was around \(String(format: "%02d:00", peak)).")
        }

        return sentences.joined(separator: " ")
    }
}
