# 0002. Single SwiftPM package, multiple targets

- Status: Accepted
- Date: 2026-07-06

## Context

The project is split into many modules (Models, Core, Storage, Pipeline, Collectors, IPC,
Daemon, Query, AI, CLI, Logging, Config). These could live in one package with many targets, or
be spread across multiple packages/repositories.

## Decision

Use a single SwiftPM package with one target per module and two executable products
(`chronicle`, `chronicled`). Module boundaries are enforced by target dependencies in
`Package.swift`.

## Consequences

- Atomic changes across modules are simple; one `swift build`/`swift test` covers everything.
- Boundaries are still enforced (a target can only use what it depends on), giving most of the
  benefit of separate packages without the versioning overhead.
- If a module later needs independent release, it can be extracted into its own package.

## Alternatives considered

- Multi-repo/multi-package: rejected for now due to cross-cutting churn during early development
  and the friction of synchronized versioning.
