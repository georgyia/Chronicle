import Foundation

/// Redacts likely secrets from text before it leaves the device.
///
/// Applied to prompts sent to remote AI providers when
/// `ai.redact_before_egress` is enabled. Pattern-based and unit-tested; it errs
/// toward over-redaction.
public struct TextRedactor: Sendable {
    private let patterns: [NSRegularExpression]
    private let replacement = "[REDACTED]"

    /// Creates a redactor with the default secret patterns.
    public init() {
        let sources = [
            "sk-[A-Za-z0-9]{20,}", // OpenAI-style keys
            "gh[pousr]_[A-Za-z0-9]{20,}", // GitHub tokens
            "AKIA[0-9A-Z]{16}", // AWS access key ids
            "xox[baprs]-[A-Za-z0-9-]{10,}", // Slack tokens
            "eyJ[A-Za-z0-9_-]{10,}\\.[A-Za-z0-9_-]{10,}\\.[A-Za-z0-9_-]{10,}", // JWTs
            "(?i)(password|passwd|secret|api[_-]?key|token)\\s*[:=]\\s*\\S+", // key=value secrets
            "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}", // emails
        ]
        patterns = sources.compactMap { try? NSRegularExpression(pattern: $0) }
    }

    /// Returns `text` with any matched secrets replaced.
    public func redact(_ text: String) -> String {
        var result = text
        for pattern in patterns {
            let range = NSRange(result.startIndex..., in: result)
            result = pattern.stringByReplacingMatches(in: result, range: range, withTemplate: replacement)
        }
        return result
    }
}
