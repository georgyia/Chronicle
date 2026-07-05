# 0006. TOML configuration

- Status: Accepted
- Date: 2026-07-06

## Context

Chronicle needs a human-editable configuration file for retention, logging, module toggles, and
per-module settings, with comments, predictable typing, and a good editing experience.

## Decision

Use **TOML** (via [TOMLKit](https://github.com/LebJe/TOMLKit)) at
`~/.config/chronicle/config.toml`. Configuration resolves in layers: built-in defaults, then the
file, then `CHRONICLE_*` environment overrides. A commented default file is written on first run,
and the daemon hot-reloads on change.

## Consequences

- Comment-friendly, strongly-typed, and familiar from modern developer tools (Cargo, uv, ruff).
- Partial files are valid: missing keys fall back to defaults, so hand-edited configs stay small.
- Validation is explicit and surfaces all issues at once via `chronicle config validate`.

## Alternatives considered

- YAML: viable and popular, but whitespace-sensitivity and type ambiguities make hand-editing
  more error-prone.
- JSON: rejected — no comments and poor hand-editing ergonomics.
