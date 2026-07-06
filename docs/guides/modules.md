# Collector modules

Each collector is an independent module that can be enabled or disabled in
`config.toml` under `[modules]` (or with `chronicle module enable|disable`). Core
modules are on by default; sensitive modules are off by default and opt-in.

## Core modules (on by default)

| Module | Records | Notes |
|--------|---------|-------|
| `filesystem` | Files created, modified, moved, renamed, deleted, trashed | Uses FSEvents; honors `[filesystem]` include/exclude settings. Ignores Chronicle's own writes. |
| `application` | Apps launching, quitting, and coming to the foreground | Via NSWorkspace. |
| `window` | The title of the focused window | Requires the **Accessibility** permission; degrades gracefully without it. |
| `power` | Sleep, wake, screen lock/unlock, login, logout | Via NSWorkspace and distributed notifications. |
| `downloads` | Files downloaded from the internet, with origin URL | Reads `kMDItemWhereFroms`; only records files that carry download metadata. |

## Optional modules (off by default, privacy-sensitive)

| Module | Records | Notes |
|--------|---------|-------|
| `terminal` | Shell commands (command, cwd, exit code) | Requires `chronicle shell-integration install` (zsh hook writing to a FIFO). |
| `browser` | Pages you visit (URL, title) | Reads browser history databases incrementally. Safari requires **Full Disk Access**. Private browsing is never recorded. |
| `clipboard` | When you copy text | **Hash-only by default** (stores a digest, not the text). Honors concealed pasteboard types and an app ignore-list. |
| `git` | Commits in your repositories | Tails `.git/logs/HEAD` under the configured roots. |

## Permissions

- **Accessibility** (window titles) and **Full Disk Access** (Safari history) are
  requested lazily and only when the relevant module is enabled. `chronicle doctor`
  reports what is missing.
- No module sends data off your device. See [`SECURITY.md`](../../SECURITY.md) and
  the privacy notes in each module above.
