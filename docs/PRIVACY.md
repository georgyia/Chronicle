# Chronicle privacy & security

Chronicle records behavioral data about how you use your Mac. We treat that data as
sensitive by design. This document explains exactly what is recorded, where it
lives, and the threat model.

## Principles

- **Local-first.** All data stays on your device. There is no telemetry and no
  account.
- **No egress by default.** Chronicle makes no network requests unless you enable a
  remote AI provider, and then only a redacted summarization prompt is sent.
- **Opt-in for sensitive data.** The clipboard, browser, and terminal modules are
  off by default and each is individually enabled.

## What each module records

| Module | Records | Default |
|--------|---------|---------|
| filesystem | path + kind (create/modify/move/rename/delete/trash) | on |
| application | app name, bundle id, pid (launch/quit/activate) | on |
| window | frontmost window title + app | on (needs Accessibility) |
| power | sleep/wake, screen lock/unlock, login/logout | on |
| downloads | file path + origin URL | on |
| terminal | command, working directory, exit code | off |
| browser | visited URL + page title (never private browsing) | off (Safari needs FDA) |
| clipboard | a **hash** of copied text by default (or truncated text) | off |
| git | repository, commit sha, message | off |

## Where data lives

See the [operations guide](guides/operations.md#data-locations). The data directory
is `0700`; the database and control socket are `0600`; the IPC socket is only
reachable by your user.

## Secrets & redaction

- Remote AI provider API keys are stored in the macOS **Keychain**, never in config
  or the database.
- A redaction gate strips likely secrets (API keys, tokens, JWTs, emails,
  `password=`-style pairs) from any prompt before it is sent to a remote provider.

## Threat model (summary)

- **At rest:** the database is the primary asset. Filesystem permissions restrict it
  to your user; use FileVault for device-loss protection.
- **In motion:** nothing leaves the device except an explicitly-enabled, redacted AI
  request over HTTPS.
- **Local processes:** the control socket verifies the peer and is owner-only.
- **Supply chain:** a small set of pinned dependencies (`Package.resolved` committed),
  dependency review and CodeQL in CI, and signed + notarized release binaries.

Report vulnerabilities per [`SECURITY.md`](../SECURITY.md).

## Your controls

- Disable any module: `chronicle module disable <id>`.
- Limit retention: `storage.retention_days`.
- Delete data: `chronicle delete --before …` / `--matching …`.
- Export/import: `chronicle export` / `chronicle import`.
- Full removal: see [uninstalling](guides/operations.md#uninstalling).
