# Installation & quickstart

## Requirements

- macOS 14 (Sonoma) or newer.
- To build from source: a Swift 6 toolchain (Xcode 16+).

## Install

### Homebrew (recommended, once released)

```console
$ brew install chronicle-dev/tap/chronicle
```

### From source

```console
$ git clone https://github.com/chronicle-dev/chronicle.git
$ cd chronicle
$ swift build -c release
$ sudo cp .build/release/chronicle .build/release/chronicled /usr/local/bin/
```

## Quickstart

```console
# 1. Install and start the background agent (a per-user LaunchAgent).
$ chronicle daemon install

# 2. Check it is running and see live counts.
$ chronicle status

# 3. Explore your activity.
$ chronicle today
$ chronicle search "invoice"
$ chronicle timeline --range "last week" --kind app.activated
$ chronicle stats
$ chronicle explain

# 4. Manage collector modules.
$ chronicle module list
$ chronicle module enable git
```

The agent writes a commented `~/.config/chronicle/config.toml` on first run. Edit
it with `chronicle config edit`; the daemon hot-reloads on save.

## Permissions

Chronicle requests macOS permissions lazily, only for the modules you enable:

| Permission | Needed by | How to grant |
|------------|-----------|--------------|
| Accessibility | `window` (window titles) | System Settings → Privacy & Security → Accessibility → enable `chronicled`. |
| Full Disk Access | `browser` (Safari history) | System Settings → Privacy & Security → Full Disk Access → enable `chronicled`. |

Everything else works without special permission. Run `chronicle doctor` to see
what is granted and get fix suggestions. Modules degrade gracefully when a
permission is missing — they simply record nothing until it is granted.

## Uninstall

See the [operations guide](operations.md#uninstalling).
