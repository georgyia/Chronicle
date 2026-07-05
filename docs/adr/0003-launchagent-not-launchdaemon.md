# 0003. Run as a per-user LaunchAgent, not a LaunchDaemon

- Status: Accepted
- Date: 2026-07-06

## Context

Chronicle observes user-session activity: the frontmost application (NSWorkspace), window titles
(Accessibility), and files in the user's home directory. These APIs require a logged-in user
session and per-user TCC permissions. A system-wide LaunchDaemon runs in a non-user context
where these APIs are unavailable or meaningless.

## Decision

Ship `chronicled` as a per-user **LaunchAgent** (`~/Library/LaunchAgents/dev.chronicle.agent.plist`),
loaded in the user's GUI session. We keep the colloquial term "daemon" for the process, but it is
technically an agent.

## Consequences

- Full access to session-scoped APIs and correctly-scoped TCC permission prompts.
- Data and permissions are naturally per-user, matching the privacy model.
- The agent starts at login and stops at logout; there is no capture while logged out (by design).

## Alternatives considered

- LaunchDaemon (system context): rejected — cannot access the window server, NSWorkspace, or
  per-user Accessibility, and would blur the per-user privacy boundary.
