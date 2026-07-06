# Architecture

Chronicle follows Clean/Hexagonal architecture: dependencies point inward, and the
concrete types meet only in the executable composition roots. See
[`docs/adr`](../adr) for the decisions behind this.

## Layers

```mermaid
graph TD
    subgraph exe [Executables and composition roots]
        CliExe["chronicle (CLI)"]
        DaemonExe["chronicled (agent)"]
    end
    subgraph app [Application]
        CLI[ChronicleCLI]
        Daemon[ChronicleDaemon]
    end
    subgraph services [Domain services]
        Pipeline[ChroniclePipeline]
        Collectors[ChronicleCollectors]
        Query[ChronicleQuery]
        AI[ChronicleAI]
        IPC[ChronicleIPC]
    end
    subgraph infra [Infrastructure]
        Storage[ChronicleStorage]
        Config[ChronicleConfig]
        Logging[ChronicleLogging]
    end
    subgraph kernel [Kernel]
        Core[ChronicleCore]
        Models[ChronicleModels]
    end
    CliExe --> CLI
    DaemonExe --> Daemon
    CLI --> Query
    CLI --> IPC
    CLI --> AI
    Daemon --> Pipeline
    Daemon --> Collectors
    Daemon --> Storage
    Daemon --> IPC
    Pipeline --> Core
    Collectors --> Core
    Query --> Core
    AI --> Core
    IPC --> Core
    Storage --> Core
    Config --> Core
    Logging --> Core
    Core --> Models
```

- **Kernel** (`ChronicleModels`, `ChronicleCore`) has no external dependencies and
  defines the value types and protocol boundaries (`EventCollector`,
  `EventRepository`, `SearchRepository`, `StatisticsRepository`,
  `EmbeddingRepository`, `EventProcessor`, `WallClock`, `IdentifierFactory`).
- **Infrastructure** implements those protocols (`ChronicleStorage` on SQLite/GRDB,
  `ChronicleConfig` on TOML, `ChronicleLogging` on swift-log).
- **Domain services** hold the behaviour: the ingestion pipeline, collectors,
  query engine, AI, and IPC contract.
- **Application** wires everything in the two executables.

## Runtime data flow

```mermaid
graph LR
    OS["macOS APIs"] --> Coll[Collector actors]
    Coll --> Supervisor[CollectorSupervisor]
    Supervisor --> Pipe["EventPipeline (validate, enrich, dedupe, batch)"]
    Pipe --> Repo[EventRepository]
    Repo --> DB[("SQLite WAL + FTS5")]
    DB --> QueryEngine[ChronicleQuery]
    QueryEngine --> CliBin[chronicle]
    CliBin <-->|"unix socket"| DaemonProc[chronicled]
```

The agent (`chronicled`) is a per-user LaunchAgent. Collectors emit `RawEvent`s;
the pipeline turns them into `Event`s and batches them to storage. The CLI reads
the database directly (WAL allows concurrent readers) and controls the agent over a
Unix domain socket.

## Packages and responsibilities

| Package | Responsibility |
|---------|----------------|
| `ChronicleModels` | Value types: `Event`, `EventKind`, `JSONValue`, UUIDv7 ids. |
| `ChronicleCore` | Protocol boundaries, `EventQuery`, typed errors, `WallClock`. |
| `ChronicleLogging` | Structured, rotating JSON logging. |
| `ChronicleConfig` | Layered TOML config, paths, hot-reload watcher. |
| `ChronicleStorage` | SQLite/GRDB store, migrations, FTS5, embeddings. |
| `ChroniclePipeline` | Validate/enrich/dedupe/batch ingestion. |
| `ChronicleCollectors` | The nine collector modules + registry. |
| `ChronicleIPC` | Versioned control protocol over a Unix socket. |
| `ChronicleDaemon` | Agent orchestration, supervisor, LaunchAgent. |
| `ChronicleQuery` | Time ranges, search grammar, ranking, sessions, narrative. |
| `ChronicleAI` | Embeddings, semantic search, summarizers, redaction. |
| `ChronicleCLI` | The `chronicle` command surface and output rendering. |
