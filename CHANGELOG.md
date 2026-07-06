# Changelog

All notable changes to Chronicle are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
The public API and CLI surface become subject to SemVer guarantees at 1.0.0.

## [0.0.2](https://github.com/georgyia/Chronicle/compare/v0.0.1...v0.0.2) (2026-07-06)


### Features

* **ai:** add local-first semantic search and summaries (Phase 8) ([82aba21](https://github.com/georgyia/Chronicle/commit/82aba2151cee2652650ab1d51db7caa12a97f4a0))
* **cli:** add the full chronicle command surface (Phase 6) ([c87453a](https://github.com/georgyia/Chronicle/commit/c87453a09b145b667d628a51ef9f18a2dccfcb55))
* **collectors:** add nine collector modules (Phase 5) ([f1ba379](https://github.com/georgyia/Chronicle/commit/f1ba37903981c1b99d4dffb23c24f5e7e3716736))
* **daemon:** add agent, collector supervisor, and IPC control (Phase 4) ([6b4d794](https://github.com/georgyia/Chronicle/commit/6b4d7946f875bcd987289b8017baca6ba3f1f9f8))
* establish project foundation and kernel (Phase 1) ([d065433](https://github.com/georgyia/Chronicle/commit/d0654333016c5a0ac8586a74060d5135e251945a))
* **pipeline:** add ingestion pipeline with validate/enrich/dedupe stages (Phase 3) ([e25687f](https://github.com/georgyia/Chronicle/commit/e25687fbce89b03c030cd8cc5c0f0fb0d6bc094a))
* **query:** add search grammar, relevance ranking, and sessions (Phase 7) ([12e7d6b](https://github.com/georgyia/Chronicle/commit/12e7d6b0f39eb29a10d2372448df68d481ed26a7))
* **storage:** add SQLite event store with FTS5 and migrations (Phase 2) ([d298708](https://github.com/georgyia/Chronicle/commit/d29870898fecd545d2ef191c9a58e9f7168bc5f5))


### Performance Improvements

* add tuning, storm hardening, and benchmark gates (Phase 9) ([1d355e3](https://github.com/georgyia/Chronicle/commit/1d355e31e9d25c3d0bb9cdcc19d8f4e1de492e0a))

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
- `ChronicleAI`: local-first AI. `EmbeddingProvider` (Apple `NLEmbedding` with a
  hashing fallback), a persisted embedding store (`embeddings` table, schema v2)
  with resumable backfill, `SemanticSearchService` with Reciprocal Rank Fusion for
  `search --semantic`, a `Summarizer` with OpenAI-compatible and Ollama providers
  behind a `TextRedactor` egress gate (Keychain-stored keys), and the `summarize`
  command with an offline rule-based fallback. AI is off by default with no network
  egress unless a remote provider is explicitly enabled.
- `ChronicleQuery`: the storage-agnostic `QueryService` (built on the kernel
  repository protocols), a `TimeRangeParser` (today/yesterday/`last week`/`3d`/ISO/
  all), a rule-based `NarrativeBuilder` for `explain`, a `SearchQueryParser` filter
  grammar (`kind: source: app: path: before: after: "text"`), a `RelevanceRanker`
  (bm25 relevance with a recency boost), and a `SessionReconstructor` powering
  `timeline --sessions`. Query-plan audit tests ensure hot paths use indexes.
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
- Performance hardening: SQLite tuning (page size, mmap, cache, WAL,
  `synchronous=NORMAL`), a pipeline bounded-buffer safety valve with an
  `overflowed` metric, a storm/flood test, a benchmark regression gate
  (`scripts/bench-check.sh` + baseline + on-demand workflow), and a soak harness
  (`scripts/soak.sh`). Startup opens the store in ~10ms.

[Unreleased]: https://github.com/chronicle-dev/chronicle/commits/main
