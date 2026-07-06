# Chronicle Roadmap

This is the living roadmap. Each feature PR ticks its task here. Complexity: **S** ≤ ½ day,
**M** ≈ 1 day, **L** = 2–3 days (split across PRs, ~500 LOC per PR). Each task lists
dependencies, a completion definition, and a testing strategy in the engineering plan.

Legend: `[x]` done · `[~]` in progress · `[ ]` planned.

## Phase 1 — Foundation (M0 "Skeleton")

- [x] **F1** Repo bootstrap: LICENSE, README, `.gitignore`, `.editorconfig`.
- [x] **F2** SwiftPM skeleton: all targets/products compile under Swift 6 strict concurrency.
- [x] **F3** SwiftLint + SwiftFormat configs + Makefile task runner.
- [x] **F4** GitHub Actions CI: lint, format-check, build (debug+release), test + coverage.
- [x] **F5** Governance: CONTRIBUTING, CODE_OF_CONDUCT, SECURITY, issue/PR templates, CODEOWNERS, Danger.
- [x] **F6** ADR framework + seed ADRs 0001–0008 + this roadmap.
- [x] **F7** DocC + docs workflow (Pages publish wired; polished in Phase 10).
- [x] **F8** `ChronicleModels` + `ChronicleCore`: events, ids (UUIDv7), protocol suite, errors.
- [x] **F9** `ChronicleLogging`: rotating structured JSON logs, levels, console handler.
- [x] **F10** `ChronicleConfig`: TOML schema, layered resolution, validation, hot-reload watcher.

## Phase 2 — Storage

- [x] **S1** GRDB integration: `SQLiteEventStore` over `DatabaseWriter`, WAL, pragmas, bootstrap.
- [x] **S2** Migration system + migration 001 (schema v1: events, FTS, collector_state, meta).
- [x] **S3** `SQLiteEventStore`: batched insert, range/kind/source/app/path queries, keyset pagination.
- [x] **S4** FTS5 external-content index + triggers + `SearchRepository` (bm25, snippets).
- [x] **S5** Retention + vacuum + `delete`/`prune` support.
- [x] **S6** Integrity utilities: `integrity_check`, checkpoint, backup.
- [x] **S7** Storage benchmarks: insert throughput and query latency (baseline in `Benchmarks`).

## Phase 3 — Pipeline

- [x] **P1** `EventPipeline` actor: sink entry point, buffer, back-pressure, lifecycle.
- [x] **P2** `ValidationProcessor`: timestamp bounds and per-kind required attributes.
- [x] **P3** `EnrichmentProcessor`: session stamping, frontmost-app context, path classification.
- [x] **P4** `Deduplicator`: content-hash (SHA-256) sliding-window suppression + storage backstop.
- [x] **P5** Batch persister: flush by count/interval, graceful-shutdown flush.
- [x] **P6** `PipelineMetrics`: ingested/rejected/deduplicated/persisted counters + snapshot.
- [x] **P7** Throughput benchmark: ~9.5k events/s sustained (exceeds 5k/s target).

## Phase 4 — Daemon (M1 "Ingest")

- [x] **D1** `chronicled` executable: composition root (`AgentAssembly`), heartbeat E2E proven.
- [x] **D2** `LaunchAgentController`: plist generation + install/uninstall/start/stop via launchctl.
- [x] **D3** `CollectorSupervisor`: per-collector task isolation, backoff restart, live reconfigure.
- [x] **D4** `IPCServer`/`IPCClient`: unix socket, versioned framed protocol v1.
- [x] **D5** Config hot reload: `ConfigurationFileWatcher` + SIGHUP + IPC `reload` -> supervisor reconfigure.
- [x] **D6** Signals & graceful shutdown: SIGTERM/SIGINT drain pipeline + checkpoint DB.
- [x] **D7** Health: `HealthReporter` heartbeat file, launchd throttle, startup banner.
- [x] **D8** `DaemonTestHarness`: sandboxed in-process agent driving the full flow.

## Phase 5 — Collectors (M2 "Observe", v0.1.0)

- [x] **C1** FileSystem collector (FSEvents; create/modify/move/rename/delete/trash).
- [x] **C2** App lifecycle collector (NSWorkspace).
- [x] **C3** Window title collector (Accessibility, graceful degradation).
- [x] **C4** Power/session collector (sleep/wake, lock/unlock, login/logout).
- [x] **C5** Downloads collector (`~/Downloads`, `kMDItemWhereFroms`).
- [x] **C6** Terminal collector (optional; zsh hook over FIFO).
- [x] **C7** Browser history collector (optional; Safari/Chrome/Arc via sqlite3).
- [x] **C8** Clipboard collector (optional; hash-only default, concealed-type aware).
- [x] **C9** Git collector (optional; reflog tail).

## Phase 6 — CLI (M3 "Query", v0.2.0)

- [x] **L1** CLI skeleton: command tree, global flags (`--json/--config/-v/-q`), exit codes, `version`.
- [x] **L2** Output engine: `Table`/`EventFormatter` renderers, JSON, TTY + `NO_COLOR`.
- [x] **L3** `daemon` + `status` over IPC with direct-DB fallback.
- [x] **L4** `TimeRangeParser`: today/yesterday/last week/3d/ISO/all.
- [x] **L5** `timeline`, `today`, `yesterday`.
- [x] **L6** `search`: FTS + filters + highlighted snippets.
- [x] **L7** `stats`: counts by kind/source/app + hour heatmap.
- [x] **L8** `config get|set|edit|path|validate`.
- [x] **L9** `module list|info|enable|disable` (live reload via IPC).
- [x] **L10** `doctor`: config, DB integrity, daemon, permissions with fixes.
- [x] **L11** `export` (json/csv/markdown) + `import` (jsonl) + `delete`.
- [x] **L12** `inspect` + rule-based `explain` (NarrativeBuilder).
- [x] **L13** Shell completions + man-page targets; `shell-integration install`.

## Phase 7 — Search (M4 "Find", v0.3.0)

- [x] **Q1** `SearchQueryParser` grammar (`kind: source: app: path: before: after: "text"`).
- [x] **Q2** `RelevanceRanker`: bm25 relevance with a recency boost; FTS5 snippets.
- [x] **Q3** `SessionReconstructor` for `timeline --sessions` and `explain`.
- [x] **Q4** Query-plan audit tests assert hot paths use indexes (not full scans).

## Phase 8 — AI (M5 "Understand", v0.4.0)

- [x] **A1** `ChronicleAI` protocols (`EmbeddingProvider`, `Summarizer`), config gate, Keychain secrets.
- [x] **A2** Local embeddings (`NLEmbedding` + hashing fallback), `embeddings` table (schema v2), resumable backfill.
- [x] **A3** `search --semantic`: hybrid lexical+vector fusion (Reciprocal Rank Fusion).
- [x] **A4** `summarize <range>` with offline rule-based fallback.
- [x] **A5** Remote providers (OpenAI-compatible, Ollama) behind the `TextRedactor` egress gate.
- [x] **A6** AI eval harness: golden semantic-ranking and fusion tests.

## Phase 9 — Performance (M6 "Harden", v0.9.0 RC)

- [x] **PF1** Benchmark suite + regression gate (`scripts/bench-check.sh`, baseline, on-demand workflow).
- [x] **PF2** Soak harness (`scripts/soak.sh`) sampling RSS/CPU over a configurable run.
- [x] **PF3** DB tuning: page size, mmap, cache, `synchronous=NORMAL`, WAL (verified by tests).
- [x] **PF4** Storm hardening: dedup coalescing + bounded-buffer drop policy + flood test.
- [x] **PF5** Startup time (~10ms open, well under 500ms) tracked as a benchmark metric.

## Phase 10 — Documentation & 1.0 (M7 "1.0")

- [ ] **DOC1** DocC coverage for all public APIs + doc-coverage gate.
- [ ] **DOC2** User guide: install, quickstart, permissions walkthrough, FAQ.
- [ ] **DOC3** Architecture guide + refreshed diagrams + ADR index.
- [ ] **DOC4** Operations guide: data locations, backup/restore, uninstall.
- [ ] **DOC5** Release engineering: universal binary, notarization, SBOM, Homebrew tap.
- [ ] **DOC6** Privacy & security whitepaper.
