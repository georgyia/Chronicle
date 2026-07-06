# Operations

## Data locations

| What | Path |
|------|------|
| Configuration | `~/.config/chronicle/config.toml` |
| Database | `~/Library/Application Support/Chronicle/chronicle.sqlite` (+ `-wal`, `-shm`) |
| Control socket | `~/Library/Application Support/Chronicle/chronicle.sock` |
| Terminal FIFO | `~/Library/Application Support/Chronicle/terminal.fifo` |
| Health file | `~/Library/Application Support/Chronicle/agent.health` |
| Logs | `~/Library/Logs/Chronicle/chronicle.log` (rotating) |
| LaunchAgent | `~/Library/LaunchAgents/dev.chronicle.agent.plist` |

The data directory is created `0700`; the database and socket are `0600`.

## Backup & restore

Chronicle can produce a consistent snapshot even while the agent is writing:

```console
# Full, lossless export (canonical JSONL).
$ chronicle export json --output chronicle-backup.jsonl

# Restore into a fresh (or existing) database; duplicates are skipped on import.
$ chronicle import chronicle-backup.jsonl
```

For a binary copy of the database, stop the agent first (`chronicle daemon stop`)
and copy the `chronicle.sqlite*` files, or use the built-in checkpointed backup via
`chronicle export`.

## Retention

Set `storage.retention_days` in config (default 365; `0` keeps forever). The agent
prunes older events and the FTS index and embeddings are kept in sync automatically.
You can also prune on demand:

```console
$ chronicle delete --before 2025-01-01 --yes
$ chronicle delete --matching "secret-project" --yes
```

## Health & diagnostics

```console
$ chronicle status         # live counts over IPC (falls back to DB when down)
$ chronicle doctor         # config, DB integrity, daemon, permissions
$ tail -f ~/Library/Logs/Chronicle/chronicle.log
```

## Uninstalling

```console
# Stop and remove the LaunchAgent.
$ chronicle daemon uninstall

# Optionally remove all recorded data.
$ rm -rf "~/Library/Application Support/Chronicle" \
         "~/Library/Logs/Chronicle" \
         "~/.config/chronicle"

# Remove the shell hook if you installed it.
$ chronicle shell-integration uninstall
```
