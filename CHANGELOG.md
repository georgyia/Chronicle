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
- `ChroniclePipeline`: the `EventPipeline` actor and its composable stages —
  validation (timestamp/attribute checks), enrichment (session stamping, path
  classification, frontmost-app context), and SHA-256 sliding-window deduplication —
  plus a batching persister with count/interval flush and graceful shutdown, and
  `PipelineMetrics`. Sustains ~9.5k events/s in the throughput benchmark.
- `ChronicleIPC`: a versioned, length-prefixed JSON control protocol over a Unix
  domain socket, with a POSIX `IPCServer`/`IPCClient` (ping, status, reload, pause,
  resume, flush, shutdown).
- `ChronicleDaemon`: the `ChronicleAgent` actor orchestrating the pipeline, a
  fault-isolating `CollectorSupervisor` with live reconfiguration, the IPC server,
  config hot-reload (file watch + SIGHUP), graceful signal-driven shutdown with DB
  checkpoint, a `HealthReporter`, and a `LaunchAgentController`. The `chronicled`
  executable now runs a full agent, verified end-to-end by `DaemonTestHarness`.
- `ChronicleQuery`: the storage-agnostic `QueryService` (built on the kernel
  repository protocols), a `TimeRangeParser` (today/yesterday/`last week`/`3d`/ISO/
  all), and a rule-based `NarrativeBuilder` for `explain`.
- `ChronicleCLI` / `chronicle`: the full command surface — `status`, `daemon`
  (install/start/stop/run), `timeline`/`today`/`yesterday`, `search`, `stats`,
  `explain`, `inspect`, `config`, `module` (with live IPC reload), `doctor`,
  `export` (json/csv/markdown), `import`, `delete`, and `shell-integration` — with a
  table/JSON output engine (TTY + `NO_COLOR`), documented exit codes, and shell
  completion generation.
- `ChronicleCollectors`: nine collector modules discovered via `CollectorFactory` —
  filesystem (FSEvents), application (NSWorkspace), window titles (Accessibility,
  degrades gracefully), power/session, and downloads as core; and terminal (zsh
  FIFO), browser history (sqlite3), clipboard (hash-only default), and git (reflog)
  as opt-in sensitive modules. Pure logic (path filtering, event classification,
  reflog and browser-time parsing) is unit-tested, and the filesystem collector is
  verified with a real FSEvents integration test.
- Tooling and governance: SwiftLint, SwiftFormat, Makefile, CI, ADRs, and the
  living roadmap.

[Unreleased]: https://github.com/chronicle-dev/chronicle/commits/main
