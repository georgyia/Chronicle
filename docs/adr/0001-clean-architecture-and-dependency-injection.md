# 0001. Clean architecture with manual dependency injection

- Status: Accepted
- Date: 2026-07-06

## Context

Chronicle has several concerns that evolve at different rates and must be independently testable:
capturing OS events, enriching and persisting them, querying, and presenting via a CLI. The
requirements are explicit: collectors must not know about storage, storage must not know about
the CLI, and everything communicates through interfaces.

## Decision

Adopt Clean/Hexagonal architecture with dependencies pointing inward:

- A dependency-free **kernel** (`ChronicleModels`, `ChronicleCore`) defines value types and the
  protocol boundaries (`EventCollector`, `EventRepository`, `EventProcessor`, `WallClock`,
  `IdentifierFactory`, `Redactor`).
- **Infrastructure** and **domain** modules implement those protocols.
- Concrete types are wired together only in the executable **composition roots**
  (`Sources/chronicle`, `Sources/chronicled`) using plain constructor injection. No DI framework
  or service locator is used, and there are no singletons.

## Consequences

- Each layer is unit-testable with fakes (`ChronicleTestSupport`) and has no hidden global state.
- A small amount of explicit wiring lives in the composition roots — an acceptable, visible cost.
- Swapping an implementation (e.g. an in-memory repository in tests) requires no changes to callers.

## Alternatives considered

- A DI container: rejected as unnecessary machinery that hides the object graph and complicates
  Swift concurrency reasoning.
- Global singletons for storage/logging: rejected; they defeat testability and encourage coupling.
