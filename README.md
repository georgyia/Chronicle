# Chronicle

> A privacy-first activity journal for macOS.

Chronicle is a background agent that records meaningful activity on your Mac — files you
create and edit, apps you launch, windows you focus, when your machine sleeps and wakes —
into a local, queryable event database. Everything stays on your device. A fast,
professional CLI lets you explore your history, and optional AI features (off by default)
let you search it in natural language.

```console
$ chronicle today
$ chronicle search "invoice" --app Safari
$ chronicle timeline --range "last week"
$ chronicle stats
$ chronicle summarize yesterday
```

## Status

Chronicle is under active development. See [`docs/ROADMAP.md`](docs/ROADMAP.md) for the phased
plan and current progress.

| Phase | Area | Status |
|------:|------|--------|
| 1 | Foundation | In progress |
| 2 | Storage | Planned |
| 3 | Pipeline | Planned |
| 4 | Daemon | Planned |
| 5 | Collectors | Planned |
| 6 | CLI | Planned |
| 7 | Search | Planned |
| 8 | AI | Planned |
| 9 | Performance | Planned |
| 10 | Documentation & 1.0 | Planned |

## Design principles

- **Local-first & private.** No telemetry. No network egress unless you explicitly enable a
  remote AI provider, and then only through a redaction gate. Sensitive modules (clipboard,
  browser, terminal) are off by default.
- **Clean architecture.** Collectors never know about storage; storage never knows about the
  CLI; everything communicates through protocols defined in the kernel. See
  [`docs/adr`](docs/adr).
- **Modern Swift.** Swift 6 with complete strict concurrency, actors for shared state, and no
  global mutable state or singletons.
- **Production quality.** SwiftLint + SwiftFormat, unit/integration/snapshot tests, CI on every
  PR, Semantic Versioning, Conventional Commits, and Architecture Decision Records.

## Architecture at a glance

```
chronicle (CLI)  ─────────────┐            ┌───────────── chronicled (agent)
   ChronicleCLI               │            │   ChronicleDaemon
     ├─ ChronicleQuery        │            │     ├─ ChronicleCollectors
     ├─ ChronicleAI           │            │     ├─ ChroniclePipeline
     ├─ ChronicleIPC  ◀───── unix socket ──┼──▶  ├─ ChronicleIPC
     └─ ChronicleStorage ◀── SQLite (WAL) ─┼──▶  └─ ChronicleStorage
                                           │
   Kernel (no external deps): ChronicleModels · ChronicleCore
   Infrastructure: ChronicleStorage · ChronicleConfig · ChronicleLogging
```

## Building from source

Requirements: macOS 14+, Swift 6 toolchain (Xcode 16 or newer).

```console
$ git clone https://github.com/chronicle-dev/chronicle.git
$ cd chronicle
$ make build        # or: swift build
$ make test         # or: swift test
```

Optional developer tooling:

```console
$ brew install swiftlint swiftformat
$ make format lint
```

## Contributing

Chronicle is built one feature at a time, each on its own branch with tests, docs, and a
Conventional Commit. Please read [`CONTRIBUTING.md`](CONTRIBUTING.md) before opening a PR.

## Security & privacy

Chronicle records behavioral data, so we treat the database as sensitive by design. See
[`SECURITY.md`](SECURITY.md) for the threat model and vulnerability reporting, and the privacy
guide (shipping in Phase 10) for exactly what each module records.

## License

[MIT](LICENSE) © Chronicle contributors.
