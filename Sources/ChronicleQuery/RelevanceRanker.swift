import ChronicleCore
import ChronicleModels
import Foundation

/// Re-ranks lexical search hits with a gentle recency boost.
///
/// FTS5 bm25 relevance is the primary signal; a small recency term breaks ties
/// and nudges recent activity up, which matches how people recall their own
/// history. Pure and unit-tested.
public enum RelevanceRanker {
    /// The default weight of the recency term relative to lexical relevance.
    public static let defaultRecencyWeight = 0.5

    /// Returns `hits` re-ranked by combined relevance and recency.
    public static func rank(
        _ hits: [SearchHit],
        now: Date,
        recencyWeight: Double = defaultRecencyWeight
    ) -> [SearchHit] {
        hits
            .map { hit in (hit, combinedScore(hit, now: now, recencyWeight: recencyWeight)) }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }

    private static func combinedScore(_ hit: SearchHit, now: Date, recencyWeight: Double) -> Double {
        hit.score + recencyWeight * recencyFactor(hit.event.timestamp, now: now)
    }

    /// A recency factor in `(0, 1]` that decays with age (1 day half-effect).
    private static func recencyFactor(_ timestamp: Date, now: Date) -> Double {
        let ageDays = max(0, now.timeIntervalSince(timestamp)) / 86400
        return 1 / (1 + ageDays)
    }
}
