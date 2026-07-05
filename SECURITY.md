# Security Policy

## Reporting a vulnerability

Please **do not** open a public issue for security vulnerabilities.

Instead, report privately via GitHub Security Advisories
("Report a vulnerability" on the repository's Security tab) or email `security@chronicle.dev`.
We aim to acknowledge reports within 72 hours and to provide a remediation timeline after triage.

## Supported versions

Until 1.0.0, only the latest `main` receives security fixes. After 1.0.0, the latest minor
release is supported.

## Threat model summary

Chronicle records behavioral data, so the on-disk database is high-value and treated as
sensitive by design:

- **Local by default.** No telemetry is ever collected. There is no network egress unless the
  user explicitly enables a remote AI provider, and then only through a redaction gate.
- **Filesystem permissions.** The data directory is created `0700`; the database and control
  socket are `0600`. The IPC socket verifies the connecting peer's uid.
- **Secrets.** AI provider credentials live in the macOS Keychain, never in the config file or
  the database. Redaction patterns are applied to shell and clipboard content before it is
  persisted.
- **Supply chain.** Runtime dependencies are pinned (`Package.resolved` is committed) and kept
  minimal. Release binaries are signed and notarized with a hardened runtime.

The full threat model is maintained as an Architecture Decision Record in
[`docs/adr`](docs/adr).
