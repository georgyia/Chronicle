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
        subcommands: [VersionCommand.self]
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
