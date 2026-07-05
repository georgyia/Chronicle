# 0007. Naming: `chronicle` and `chronicled`

- Status: Accepted
- Date: 2026-07-06

## Context

The tool needs a CLI name and an agent name. An early idea was to name the CLI `history`, but
`history` is a shell builtin in zsh and bash; a binary named `history` would be shadowed in
interactive shells and effectively uninvocable without a path prefix.

## Decision

Name the CLI `chronicle` and the agent `chronicled` (following the Unix `d`-suffix convention).
The project itself is **Chronicle**.

## Consequences

- No collision with shell builtins; commands like `chronicle search "invoice"` work everywhere.
- Clear, memorable branding consistent across the CLI, agent, LaunchAgent label
  (`dev.chronicle.agent`), and data directories.

## Alternatives considered

- `history`: rejected due to the shell-builtin collision.
- `hist`/`histd`: viable but less descriptive; `chronicle` reads better and matches the project
  name.
