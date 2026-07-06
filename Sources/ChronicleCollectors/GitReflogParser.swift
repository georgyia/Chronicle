import Foundation

/// Parses git `HEAD` reflog lines into commit records.
///
/// A reflog line looks like:
/// `<old-sha> <new-sha> Name <email> <unixtime> <tz>\t<action>: <message>`
/// We record only `commit`, `commit (initial)`, and `commit (amend)` actions.
enum GitReflogParser {
    /// A parsed commit from the reflog.
    struct Commit: Equatable {
        var sha: String
        var message: String
    }

    /// Parses a single reflog line, or returns `nil` if it is not a commit.
    static func parse(_ line: String) -> Commit? {
        let parts = line.components(separatedBy: "\t")
        guard parts.count == 2 else { return nil }

        let fields = parts[0].split(separator: " ", omittingEmptySubsequences: true)
        guard fields.count >= 2 else { return nil }
        let newSha = String(fields[1])
        guard newSha.count >= 7, newSha.allSatisfy(\.isHexDigit) else { return nil }

        let actionAndMessage = parts[1]
        guard let colon = actionAndMessage.firstIndex(of: ":") else { return nil }
        let action = actionAndMessage[actionAndMessage.startIndex..<colon]
        guard action.hasPrefix("commit") else { return nil }

        let message = actionAndMessage[actionAndMessage.index(after: colon)...]
            .trimmingCharacters(in: .whitespaces)
        return Commit(sha: newSha, message: message)
    }
}
