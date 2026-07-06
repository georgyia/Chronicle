import ChronicleConfig
import ChronicleCore
import Foundation

/// Builds the set of collectors enabled by a configuration, and enumerates all
/// known modules for the CLI.
///
/// This is the single place that knows the full catalogue of collectors; the
/// daemon calls it to (re)build its active set on start and on config reload.
public enum CollectorFactory {
    /// Instantiates the collectors enabled by `configuration`.
    public static func makeCollectors(configuration: ChronicleConfiguration) -> [any EventCollector] {
        var collectors: [any EventCollector] = []

        if configuration.isModuleEnabled("filesystem", defaultEnabled: true) {
            collectors.append(FileSystemCollector(
                watchPaths: configuration.filesystem.watchPaths,
                excludePatterns: configuration.filesystem.excludePatterns,
                includeHidden: configuration.filesystem.includeHidden
            ))
        }
        if configuration.isModuleEnabled("application", defaultEnabled: true) {
            collectors.append(AppLifecycleCollector())
        }
        if configuration.isModuleEnabled("window", defaultEnabled: true) {
            collectors.append(WindowTitleCollector())
        }
        if configuration.isModuleEnabled("power", defaultEnabled: true) {
            collectors.append(PowerSessionCollector())
        }
        if configuration.isModuleEnabled("downloads", defaultEnabled: true) {
            collectors.append(DownloadsCollector())
        }
        if configuration.isModuleEnabled("clipboard", defaultEnabled: false) {
            collectors.append(ClipboardCollector(
                hashOnly: configuration.clipboard.hashOnly,
                ignoreApps: configuration.clipboard.ignoreApps
            ))
        }
        if configuration.isModuleEnabled("git", defaultEnabled: false) {
            collectors.append(GitCollector(repositoryRoots: configuration.git.repositoryRoots))
        }
        if configuration.isModuleEnabled("terminal", defaultEnabled: false) {
            collectors.append(TerminalCollector())
        }
        if configuration.isModuleEnabled("browser", defaultEnabled: false) {
            collectors.append(BrowserHistoryCollector(browsers: configuration.browser.browsers))
        }

        return collectors
    }

    /// Descriptors for every known module, regardless of whether it is enabled.
    public static func allDescriptors() -> [CollectorDescriptor] {
        [
            FileSystemCollector(watchPaths: [], excludePatterns: [], includeHidden: false).descriptor,
            AppLifecycleCollector().descriptor,
            WindowTitleCollector().descriptor,
            PowerSessionCollector().descriptor,
            DownloadsCollector().descriptor,
            ClipboardCollector(hashOnly: true, ignoreApps: []).descriptor,
            GitCollector(repositoryRoots: []).descriptor,
            TerminalCollector().descriptor,
            BrowserHistoryCollector(browsers: []).descriptor,
        ]
    }
}
