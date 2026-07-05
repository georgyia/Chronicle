# Architecture Decision Records

This directory records the significant architectural decisions made on Chronicle, using the
lightweight [ADR](https://adr.github.io/) format. Each record is immutable once accepted; to
change a decision, add a new ADR that supersedes the old one.

## How to add an ADR

1. Copy [`0000-template.md`](0000-template.md) to `NNNN-short-title.md` (next number).
2. Fill in Context, Decision, and Consequences.
3. Set the status to `Proposed`, open a PR, and flip to `Accepted` on merge.

## Index

| # | Title | Status |
|--:|-------|--------|
| [0001](0001-clean-architecture-and-dependency-injection.md) | Clean architecture with manual dependency injection | Accepted |
| [0002](0002-single-swiftpm-package-multi-target.md) | Single SwiftPM package, multiple targets | Accepted |
| [0003](0003-launchagent-not-launchdaemon.md) | Run as a per-user LaunchAgent, not a LaunchDaemon | Accepted |
| [0004](0004-sqlite-via-grdb-with-fts5.md) | SQLite via GRDB with FTS5 | Accepted |
| [0005](0005-unix-socket-json-ipc.md) | Unix domain socket JSON IPC | Accepted |
| [0006](0006-toml-configuration.md) | TOML configuration | Accepted |
| [0007](0007-naming-chronicle-cli-and-daemon.md) | Naming: `chronicle` and `chronicled` | Accepted |
| [0008](0008-uuidv7-ids-and-event-taxonomy.md) | UUIDv7 identifiers and event taxonomy | Accepted |
