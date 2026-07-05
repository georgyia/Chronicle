# Contributing to Chronicle

Thanks for your interest in improving Chronicle. This project is built to a high engineering
bar; the guidelines below keep the codebase clean, tested, and reviewable.

## Ground rules

- **One feature at a time.** Each PR should implement a single, focused change and stay under
  ~500 lines of production code unless there is a clear justification (call it out in the PR).
- **Everything through interfaces.** Respect the architecture: collectors never import storage,
  storage never imports the CLI, and cross-layer communication goes through the protocols in
  `ChronicleCore`. See [`docs/adr`](docs/adr).
- **No global mutable state, no singletons** (composition roots own object lifetimes).

## Development workflow

Each feature follows this loop:

1. Create a branch: `feat|fix|docs|refactor|perf|test|build|ci|chore/<area>-<slug>`.
2. Implement the change.
3. `make format` — SwiftFormat is the single formatting authority.
4. `make lint` — SwiftLint runs in `--strict` mode (warnings fail).
5. `make test` — all tests must pass.
6. Update documentation (DocC comments and any affected guide).
7. Tick the relevant task in [`docs/ROADMAP.md`](docs/ROADMAP.md).
8. Commit using [Conventional Commits](https://www.conventionalcommits.org/), then push and open
   a PR (draft is fine).

```console
$ make precommit   # format + lint + build + test
```

## Coding standards

- Swift 6 language mode, complete strict concurrency. Prefer actors for shared mutable state;
  audit `Sendable`. Do not use `@unchecked Sendable` without an inline comment justifying the
  synchronization strategy.
- Follow the Swift API Design Guidelines. Value types first; composition over inheritance.
- Keep functions short (≤ 60 lines), files focused (≤ 400 lines), and cyclomatic complexity low
  (≤ 10). No force-unwraps or force-`try` outside tests. No magic numbers — name them.
- Every public declaration must have a documentation comment (enforced by SwiftLint
  `missing_docs`).

## Commit messages

Conventional Commits, with the scope set to the package name where useful:

```
feat(storage): add FTS5 full-text index
fix(pipeline): flush buffered events on SIGTERM
docs(adr): record the LaunchAgent decision
```

`feat` means a wholly new capability, `fix` a bug fix, `refactor` a behavior-preserving change,
`perf` a performance change, and so on.

## Tests

- Unit tests (Swift Testing) for every library target, using the fakes in
  `ChronicleTestSupport`.
- Integration tests for daemon/storage/IPC behavior.
- Snapshot tests for CLI output.
- Add or update benchmarks for performance-relevant changes.

## Reporting bugs and requesting features

Use the issue templates. For security issues, follow [`SECURITY.md`](SECURITY.md) instead of
opening a public issue.
