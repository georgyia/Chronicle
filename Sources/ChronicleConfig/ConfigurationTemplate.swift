extension ConfigurationLoader {
    /// A commented default `config.toml` written on first run.
    ///
    /// Hand-authored (rather than encoded) so users get inline documentation and
    /// discover options even when they equal the defaults.
    static let defaultTemplate = """
    # Chronicle configuration.
    # Docs: https://github.com/chronicle-dev/chronicle/blob/main/docs/guides/configuration.md
    # Edit with `chronicle config edit`; the daemon hot-reloads on save.

    [storage]
    # Days of history to keep. 0 disables pruning (keep forever).
    retention_days = 365

    [logging]
    # trace | debug | info | notice | warning | error | critical
    level = "info"
    # console | file | both
    destination = "file"

    [daemon]
    # Events written per transaction and the maximum buffering delay.
    batch_size = 128
    flush_interval_milliseconds = 1000

    [pipeline]
    # Duplicate-suppression window and cache size.
    dedupe_window_milliseconds = 2000
    dedupe_cache_size = 4096

    # Core modules are on by default; optional/sensitive modules are off.
    [modules]
    filesystem = true
    application = true
    window = true
    power = true
    downloads = true
    terminal = false
    browser = false
    clipboard = false
    git = false

    [filesystem]
    watch_paths = ["~"]
    include_hidden = false
    # Substrings that exclude a path from recording.
    exclude_patterns = ["/.git/", "/node_modules/", "/.build/", "/DerivedData/", "/Library/Caches/", "/.Trash/"]

    [clipboard]
    # Store only a hash of clipboard content, never the text.
    hash_only = true
    ignore_apps = ["com.agilebits.onepassword7", "com.1password.1password"]

    [browser]
    browsers = ["safari", "chrome"]

    [git]
    repository_roots = ["~/Developer", "~/Projects"]

    [ai]
    # AI features are off by default and never send data off-device unless enabled.
    enabled = false
    provider = "local"
    model = "chronicle-local"
    redact_before_egress = true

    """
}
