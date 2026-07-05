# 0004. SQLite via GRDB with FTS5

- Status: Accepted
- Date: 2026-07-06

## Context

Chronicle needs an embedded, zero-configuration, durable local store with good write throughput,
rich queries, and full-text search over event text (paths, titles, commands, URLs). It must
support schema migrations and concurrent reads while the agent writes.

## Decision

Use SQLite through [GRDB](https://github.com/groue/GRDB.swift), with:

- WAL mode and a single writer actor; the CLI reads concurrently.
- `DatabaseMigrator` for numbered, immutable migrations.
- An FTS5 external-content table synchronized by triggers for search.

GRDB and SQL are confined to `ChronicleStorage`; the rest of the system sees only the
`EventRepository`, `SearchRepository`, and `StatisticsRepository` protocols.

## Consequences

- Mature migrations, ergonomic record mapping, and first-class FTS5 support.
- A single well-maintained dependency for the storage layer.
- The storage boundary keeps the option open to change engines without touching callers.

## Alternatives considered

- Raw `sqlite3` C API: rejected — more boilerplate and error-prone migration handling.
- Core Data / SwiftData: rejected — heavier, less transparent SQL control, and awkward for a
  headless agent plus CLI sharing one file.
