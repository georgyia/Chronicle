import ArgumentParser
import ChronicleCLI

/// Executable entry point for the `chronicle` CLI.
///
/// The command tree and its behaviour live in `ChronicleCLI` (so they can be unit
/// tested); this thin `@main` wrapper simply adopts that configuration and lets
/// ArgumentParser provide the async run loop.
@main
struct Chronicle: AsyncParsableCommand {
    static let configuration = ChronicleCommand.configuration
}
