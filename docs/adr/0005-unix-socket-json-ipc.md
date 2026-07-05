# 0005. Unix domain socket JSON IPC

- Status: Accepted
- Date: 2026-07-06

## Context

The CLI must control and query the agent (status, reload, pause/resume, flush). Options on macOS
include XPC, Mach services, TCP, and Unix domain sockets. Read-heavy queries can also bypass IPC
entirely by reading the SQLite database directly (WAL allows concurrent readers).

## Decision

Use a **Unix domain socket** at `~/Library/Application Support/Chronicle/chronicle.sock`
(`0600`, peer-uid checked) with length-prefixed JSON frames and a versioned handshake. The CLI
uses IPC only for control and live status; it reads events directly from the database for
queries.

## Consequences

- No entitlements or code-signing entanglement, which keeps local development and CI simple.
- Trivially testable with an in-process client/server over a temp socket path.
- Queries stay fast and independent of agent availability by reading the DB directly.

## Alternatives considered

- XPC: rejected — code-signing/entitlement coupling and harder to exercise in unit tests.
- TCP/localhost: rejected — needs port management and is exposed beyond the filesystem
  permission model.
