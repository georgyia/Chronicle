import Danger

let danger = Danger()

// Encourage small, reviewable PRs. Production code (excluding tests) over ~500
// lines should be justified; this warns rather than fails.
let editedFiles = danger.git.modifiedFiles + danger.git.createdFiles
let productionChanges = danger.git.createdFiles.filter { $0.hasPrefix("Sources/") }
    + danger.git.modifiedFiles.filter { $0.hasPrefix("Sources/") }
let additions = danger.github.pullRequest.additions ?? 0
if !productionChanges.isEmpty, additions > 500 {
    warn("This PR adds \(additions) lines. Consider splitting it, or note the justification.")
}

// The PR title should be a Conventional Commit.
let title = danger.github.pullRequest.title
let conventional = "^(feat|fix|docs|refactor|perf|test|build|ci|chore)(\\([a-z0-9-]+\\))?!?: .+"
if title.range(of: conventional, options: .regularExpression) == nil {
    fail("PR title should follow Conventional Commits, e.g. `feat(storage): add FTS5 index`.")
}

// Roadmap progress should be kept current.
if !productionChanges.isEmpty, !editedFiles.contains("docs/ROADMAP.md") {
    warn("Production code changed but `docs/ROADMAP.md` was not updated.")
}

// Keep the changelog current.
if !productionChanges.isEmpty, !editedFiles.contains("CHANGELOG.md") {
    warn("Consider adding a `CHANGELOG.md` entry under Unreleased.")
}

/// Nudge for tests alongside source changes.
let changedTests = editedFiles.contains { $0.hasPrefix("Tests/") }
if !productionChanges.isEmpty, !changedTests {
    warn("Source changed but no tests were touched. Is this covered?")
}
