# Changelog

All notable changes to Chronicle are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
The public API and CLI surface become subject to SemVer guarantees at 1.0.0.

## [Unreleased]

### Added

- Project foundation: SwiftPM monorepo with the full modular target graph
  (kernel, infrastructure, domain, application) under Swift 6 strict concurrency.
- `ChronicleModels`: core value types — `Event`, `RawEvent`, `EventKind`,
  `EventAttributes`, `JSONValue`, `EventDigest`, and UUIDv7 identifiers.
- `ChronicleCore`: kernel protocols — `WallClock`, `IdentifierFactory`,
  `EventCollector`, `EventSink`, `EventRepository`, `SearchRepository`,
  `StatisticsRepository`, `EventProcessor`, `Redactor` — plus `EventQuery`.
- `ChronicleLogging`: structured, leveled logging with rotating JSON log files.
- `ChronicleConfig`: layered TOML configuration (defaults → file → environment),
  validation, path resolution, and a hot-reload file watcher.
- `ChronicleTestSupport`: deterministic clock/identifier fakes and an in-memory
  repository oracle.
- `ChronicleStorage`: SQLite/GRDB `SQLiteEventStore` implementing the repository,
  search, and statistics protocols — numbered migrations, WAL, batched inserts with
  digest deduplication, keyset pagination, an FTS5 external-content full-text index,
  aggregate statistics, retention/prune, and integrity/backup maintenance. Verified
  against the in-memory oracle by a property test, with a storage benchmark suite.
- Tooling and governance: SwiftLint, SwiftFormat, Makefile, CI, ADRs, and the
  living roadmap.

[Unreleased]: https://github.com/chronicle-dev/chronicle/commits/main
