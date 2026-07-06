import Foundation

/// Decides whether a filesystem path should be recorded.
///
/// Pure and fully unit-tested: excludes hidden files (unless configured
/// otherwise) and any path containing a configured noise substring (build
/// directories, caches, VCS internals, etc.).
public struct PathFilter: Sendable {
    private let excludePatterns: [String]
    private let includeHidden: Bool

    /// Creates a filter.
    /// - Parameters:
    ///   - excludePatterns: Substrings whose presence excludes a path.
    ///   - includeHidden: Whether to record dotfiles and dot-directories.
    public init(excludePatterns: [String], includeHidden: Bool) {
        self.excludePatterns = excludePatterns
        self.includeHidden = includeHidden
    }

    /// Whether the path should be recorded.
    public func shouldInclude(_ path: String) -> Bool {
        for pattern in excludePatterns where path.contains(pattern) {
            return false
        }
        if !includeHidden, hasHiddenComponent(path) {
            return false
        }
        return true
    }

    private func hasHiddenComponent(_ path: String) -> Bool {
        path.split(separator: "/").contains { component in
            component.hasPrefix(".") && component != "." && component != ".."
        }
    }
}
