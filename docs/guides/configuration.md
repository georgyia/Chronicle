# Configuration

Chronicle reads its configuration from `~/.config/chronicle/config.toml`. A commented default
file is written on first run. Edit it with `chronicle config edit` (Phase 6); the daemon
hot-reloads on save.

Values resolve in layers, lowest to highest precedence:

1. Built-in defaults.
2. The TOML file (partial files are fine — missing keys use defaults).
3. `CHRONICLE_*` environment overrides.

## Sections

### `[storage]`

| Key | Type | Default | Meaning |
|-----|------|---------|---------|
| `retention_days` | int | `365` | Days of history to keep; `0` keeps forever. |
| `database_path` | string | — | Absolute override for the database location. |

### `[logging]`

| Key | Type | Default | Meaning |
|-----|------|---------|---------|
| `level` | string | `info` | `trace|debug|info|notice|warning|error|critical`. |
| `destination` | string | `file` | `console|file|both`. |

### `[daemon]`

| Key | Type | Default | Meaning |
|-----|------|---------|---------|
| `batch_size` | int | `128` | Events per write transaction. |
| `flush_interval_milliseconds` | int | `1000` | Max buffering delay before a flush. |

### `[pipeline]`

| Key | Type | Default | Meaning |
|-----|------|---------|---------|
| `dedupe_window_milliseconds` | int | `2000` | Coalescing window for duplicate suppression. |
| `dedupe_cache_size` | int | `4096` | Recent digests retained for dedupe. |

### `[modules]`

Boolean toggles keyed by module id. Core modules default on; sensitive modules default off.

```toml
[modules]
filesystem = true
application = true
window = true
power = true
downloads = true
terminal = false
browser = false
clipboard = false
git = false
```

### Module settings

`[filesystem]` (`watch_paths`, `exclude_patterns`, `include_hidden`), `[clipboard]`
(`hash_only`, `ignore_apps`), `[browser]` (`browsers`), `[git]` (`repository_roots`), and
`[ai]` (`enabled`, `provider`, `model`, `endpoint`, `redact_before_egress`). AI is disabled by
default and never sends data off-device unless explicitly enabled.

## Environment overrides

| Variable | Effect |
|----------|--------|
| `CHRONICLE_HOME` | Sandbox root for all paths (used in tests). |
| `CHRONICLE_CONFIG` | Override the config file path. |
| `CHRONICLE_DB_PATH` | Override the database path. |
| `CHRONICLE_SOCKET` | Override the control socket path. |
| `CHRONICLE_LOG_LEVEL` | Override `logging.level`. |
| `CHRONICLE_RETENTION_DAYS` | Override `storage.retention_days`. |
| `CHRONICLE_AI_ENABLED` | Override `ai.enabled`. |
| `CHRONICLE_MODULE_<ID>` | Enable/disable a module (e.g. `CHRONICLE_MODULE_CLIPBOARD=on`). |
