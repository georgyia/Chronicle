# FAQ

**Does Chronicle send my data anywhere?**
No. Chronicle is local-first with no telemetry. The only path off your device is a
remote AI summarizer request, and only if you explicitly set `ai.provider` to
`openai` or `ollama` — and even then the prompt is redacted first. Semantic search
runs entirely locally.

**Why is it called `chronicle` and not `history`?**
`history` is a shell builtin in zsh and bash, so a binary named `history` would be
shadowed. See [ADR-0007](../adr/0007-naming-chronicle-cli-and-daemon.md).

**Is `chronicled` a system daemon?**
No — it is a per-user LaunchAgent. It needs your logged-in session to observe apps,
windows, and files. See [ADR-0003](../adr/0003-launchagent-not-launchdaemon.md).

**How much disk does it use?**
Typically well under 10 MB/day thanks to deduplication and coalescing. Tune with
`storage.retention_days`.

**Does it record passwords or private browsing?**
The clipboard module is hash-only by default and honors concealed pasteboard types;
private browsing is never written to browser history, so it is never recorded. Shell
and clipboard content pass through a redaction gate before any AI egress.

**Will it slow down my Mac?**
The agent targets under 0.5% average CPU when idle and a small memory footprint;
file storms are coalesced rather than recorded one-by-one.

**How do I turn off a noisy module?**
`chronicle module disable <id>` (e.g. `window`). The daemon reloads live.

**Where are my files?**
See the [operations guide](operations.md#data-locations).
