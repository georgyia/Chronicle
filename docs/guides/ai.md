# AI features

AI is **off by default** and never sends data off your device unless you
explicitly configure a remote provider. Semantic search runs entirely locally.

## Enabling

```console
$ chronicle config set ai.enabled true
```

Configure the provider in `[ai]`:

```toml
[ai]
enabled = true
provider = "local"     # local | openai | ollama
model = "chronicle-local"
redact_before_egress = true
```

## Semantic search (local)

With AI enabled, `chronicle search --semantic "<query>"` embeds your events
locally (Apple's `NLEmbedding`, with a hashing fallback), stores the vectors in the
database (`embeddings` table, schema v2), and fuses vector similarity with lexical
FTS results via Reciprocal Rank Fusion. No network access is involved.

## Summaries

`chronicle summarize <range>` produces a natural-language summary.

- With `provider = "local"` (or AI disabled), it uses the offline rule-based
  narrative — the same engine as `chronicle explain`.
- With `provider = "openai"` or `"ollama"`, it builds a prompt from your activity,
  runs it through the **redaction gate** (when `redact_before_egress = true`) to
  strip likely secrets (API keys, tokens, emails), and calls the provider. On any
  failure it falls back to the offline summary.

## Secrets

Remote provider API keys are stored in the macOS **Keychain**, never in the config
file or the database. Chronicle reads the key from the `dev.chronicle.ai` service
under the `api_key` account.

## Threat model

The only path that leaves the device is a remote summarizer request, and only when
you enable a remote provider. That request is redacted first. Embeddings and
semantic search are always local.
