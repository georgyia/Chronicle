import ArgumentParser

/// The root `chronicle` command.
///
/// The command tree is grown in Phase 6; this root wires global options and the
/// `version` subcommand so the executable is runnable from the M0 skeleton.
public struct ChronicleCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "chronicle",
        abstract: "A privacy-first activity journal for macOS.",
        version: ChronicleVersion.current,
        subcommands: [
            StatusCommand.self,
            DaemonCommand.self,
            TimelineCommand.self,
            TodayCommand.self,
            YesterdayCommand.self,
            SearchCommand.self,
            StatsCommand.self,
            ExplainCommand.self,
            SummarizeCommand.self,
            InspectCommand.self,
            ConfigCommand.self,
            ModuleCommand.self,
            DoctorCommand.self,
            ExportCommand.self,
            ImportCommand.self,
            DeleteCommand.self,
            ShellIntegrationCommand.self,
            VersionCommand.self,
        ]
    )

    /// Creates the root command.
    public init() {}
}

/// Prints detailed version information.
struct VersionCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "version",
        abstract: "Print Chronicle version information."
    )

    func run() async throws {
        print("chronicle \(ChronicleVersion.current)")
    }
}
