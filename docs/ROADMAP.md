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

- [ ] **C1** FileSystem collector (FSEvents; create/modify/move/rename/delete/trash).
- [ ] **C2** App lifecycle collector (NSWorkspace).
- [ ] **C3** Window title collector (Accessibility).
- [ ] **C4** Power/session collector (sleep/wake, lock/unlock, login/logout).
- [ ] **C5** Downloads collector (`~/Downloads`, `kMDItemWhereFroms`).
- [ ] **C6** Terminal collector (optional; zsh hook over IPC).
- [ ] **C7** Browser history collector (optional; Safari/Chrome/Arc/Firefox).
- [ ] **C8** Clipboard collector (optional; hash-only default).
- [ ] **C9** Git collector (optional; reflog watch).

## Phase 6 — CLI (M3 "Query", v0.2.0)

- [ ] **L1** CLI skeleton: command tree, global flags, exit-code contract, `version`.
- [ ] **L2** Output engine: table/plain/JSON renderers, TTY + `NO_COLOR`.
- [ ] **L3** `daemon` + `status` over IPC (with direct-DB fallback).
- [ ] **L4** Time-range parser: today/yesterday/last week/3d/ISO.
- [ ] **L5** `timeline`, `today`, `yesterday`.
- [ ] **L6** `search`: FTS + filters + highlighted snippets.
- [ ] **L7** `stats`: counts by kind/app/day, hour heatmap.
- [ ] **L8** `config get|set|edit|path|validate`.
- [ ] **L9** `module list|info|enable|disable`.
- [ ] **L10** `doctor`: permissions, launchd, DB integrity, fixes.
- [ ] **L11** `export` (json/csv/markdown) + `import` (jsonl).
- [ ] **L12** `inspect` + rule-based `explain`.
- [ ] **L13** Man pages + shell completions.

## Phase 7 — Search (M4 "Find", v0.3.0)

- [ ] **Q1** Filter query grammar (`kind: app: path: before: "text"`).
- [ ] **Q2** Relevance tuning (bm25 weights, recency boost, snippets).
- [ ] **Q3** Session reconstruction for `timeline --sessions` and `explain`.
- [ ] **Q4** Search at 10M rows: query-plan audit, index fixes.

## Phase 8 — AI (M5 "Understand", v0.4.0)

- [ ] **A1** `ChronicleAI` protocols + provider registry + Keychain secrets.
- [ ] **A2** Local embeddings + vector store + incremental backfill.
- [ ] **A3** `search --semantic`: hybrid lexical+vector fusion.
- [ ] **A4** `summarize <range>` with rule-based fallback.
- [ ] **A5** Remote providers (OpenAI-compatible, Ollama) behind the redaction gate.
- [ ] **A6** AI eval harness (golden queries/summaries).

## Phase 9 — Performance (M6 "Harden", v0.9.0 RC)

- [ ] **PF1** Benchmark consolidation + CI regression gates.
- [ ] **PF2** 24h soak: memory/CPU/leaks/fd audit.
- [ ] **PF3** DB tuning: page size, mmap, checkpoint cadence.
- [ ] **PF4** Storm hardening: coalescing windows, drop policies, flood test.
- [ ] **PF5** Startup time (<500ms) + binary size.

## Phase 10 — Documentation & 1.0 (M7 "1.0")

- [ ] **DOC1** DocC coverage for all public APIs + doc-coverage gate.
- [ ] **DOC2** User guide: install, quickstart, permissions walkthrough, FAQ.
- [ ] **DOC3** Architecture guide + refreshed diagrams + ADR index.
- [ ] **DOC4** Operations guide: data locations, backup/restore, uninstall.
- [ ] **DOC5** Release engineering: universal binary, notarization, SBOM, Homebrew tap.
- [ ] **DOC6** Privacy & security whitepaper.
