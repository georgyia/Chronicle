# 0008. UUIDv7 identifiers and event taxonomy

- Status: Accepted
- Date: 2026-07-06

## Context

Every event needs a unique identifier that is also useful for stable, chronological pagination.
Events also need a consistent, extensible category system that both this build and future/imported
data can share.

## Decision

- Identify events with **UUIDv7** (RFC 9562): the 48-bit millisecond timestamp prefix makes the
  raw bytes sort in creation order, so the id doubles as a keyset-pagination cursor without
  leaking a database sequence column into the domain.
- Model event categories as `EventKind`, a `RawRepresentable` string with dot-namespaced values
  (`file.created`, `app.launched`, `window.titleChanged`, ...) rather than a closed enum, so
  importing data with unknown-but-newer kinds degrades gracefully.
- Use JSONL as the canonical export format, with timestamps as millisecond epochs.

## Consequences

- Time-ordered ids simplify pagination and debugging.
- The open taxonomy tolerates forward/backward data compatibility.
- Kinds are documented constants, keeping a shared vocabulary across collectors, storage, and
  queries.

## Alternatives considered

- UUIDv4 + a separate sort key: rejected — an extra column and no intrinsic ordering.
- A closed `enum` for kinds: rejected — fails to decode unknown kinds from newer exports.
