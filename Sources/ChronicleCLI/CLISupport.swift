import ArgumentParser
import Foundation

/// Global options shared by every `chronicle` subcommand.
public struct GlobalOptions: ParsableArguments {
    /// Emit machine-readable JSON instead of human output.
    @Flag(name: .long, help: "Output JSON instead of formatted text.")
    public var json = false

    /// Override the configuration file path.
    @Option(name: .long, help: "Path to an alternate config file.")
    public var config: String?

    /// Increase verbosity.
    @Flag(name: [.short, .long], help: "Verbose output.")
    public var verbose = false

    /// Suppress non-essential output.
    @Flag(name: [.short, .long], help: "Quiet output.")
    public var quiet = false

    /// Creates default options (required by ArgumentParser).
    public init() {}
}

/// Documented process exit codes.
enum CLIExit {
    /// A generic failure.
    static let failure = ExitCode(1)
    /// The daemon control socket was unreachable.
    static let daemonUnreachable = ExitCode(3)
    /// Configuration was invalid.
    static let invalidConfig = ExitCode(4)
    /// A requested entity was not found.
    static let notFound = ExitCode(5)
    /// A `doctor` check failed.
    static let doctorFailed = ExitCode(6)
}

/// Writes a line to standard error.
func printError(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
}

/// Decodes UTF-8 bytes to a string, substituting empty on invalid input.
func utf8String(_ data: Data) -> String {
    String(bytes: data, encoding: .utf8) ?? ""
}

/// A JSON encoder configured for Chronicle's canonical output (millisecond epochs).
func chronicleJSONEncoder(pretty: Bool = true) -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .millisecondsSince1970
    encoder.outputFormatting = pretty ? [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes] : [
        .sortedKeys,
        .withoutEscapingSlashes,
    ]
    return encoder
}

/// A JSON decoder matching ``chronicleJSONEncoder``.
func chronicleJSONDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .millisecondsSince1970
    return decoder
}
