import ChronicleCore
import Foundation

/// Errors from LaunchAgent management.
public enum LaunchAgentError: ChronicleError {
    /// Writing or removing the plist failed.
    case fileOperation(String)
    /// A `launchctl` invocation failed.
    case launchctl(String)

    public var code: String {
        switch self {
        case .fileOperation: "daemon.launchagent_file"
        case .launchctl: "daemon.launchctl"
        }
    }

    public var message: String {
        switch self {
        case let .fileOperation(detail): "LaunchAgent file operation failed: \(detail)"
        case let .launchctl(detail): "launchctl failed: \(detail)"
        }
    }
}

/// Installs, loads, and removes Chronicle's per-user LaunchAgent.
///
/// Plist generation is pure and unit-tested; the `launchctl` calls are only
/// invoked by explicit CLI commands, never by automated tests.
public struct LaunchAgentController: Sendable {
    private let label: String
    private let plistURL: URL
    private let executablePath: String
    private let standardOutPath: String
    private let standardErrorPath: String

    /// Creates a controller.
    /// - Parameters:
    ///   - label: The LaunchAgent label (reverse-DNS).
    ///   - plistURL: Where the plist lives (`~/Library/LaunchAgents/<label>.plist`).
    ///   - executablePath: Absolute path to the `chronicled` binary.
    ///   - logPath: Where to redirect the agent's stdout/stderr.
    public init(label: String, plistURL: URL, executablePath: String, logPath: String) {
        self.label = label
        self.plistURL = plistURL
        self.executablePath = executablePath
        standardOutPath = logPath
        standardErrorPath = logPath
    }

    /// The XML property list describing the LaunchAgent.
    public func plistContents() -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(label)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(executablePath)</string>
                <string>run</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <dict>
                <key>Crashed</key>
                <true/>
                <key>SuccessfulExit</key>
                <false/>
            </dict>
            <key>ThrottleInterval</key>
            <integer>10</integer>
            <key>ProcessType</key>
            <string>Background</string>
            <key>StandardOutPath</key>
            <string>\(standardOutPath)</string>
            <key>StandardErrorPath</key>
            <string>\(standardErrorPath)</string>
        </dict>
        </plist>
        """
    }

    /// Writes the plist to disk (does not load it).
    public func writePlist() throws {
        do {
            try FileManager.default.createDirectory(
                at: plistURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try plistContents().write(to: plistURL, atomically: true, encoding: .utf8)
        } catch {
            throw LaunchAgentError.fileOperation(error.localizedDescription)
        }
    }

    /// Removes the plist from disk.
    public func removePlist() throws {
        do {
            if FileManager.default.fileExists(atPath: plistURL.path) {
                try FileManager.default.removeItem(at: plistURL)
            }
        } catch {
            throw LaunchAgentError.fileOperation(error.localizedDescription)
        }
    }

    /// Writes the plist and loads the agent via `launchctl`.
    public func install() throws {
        try writePlist()
        try runLaunchctl(["load", "-w", plistURL.path])
    }

    /// Unloads the agent and removes its plist.
    public func uninstall() throws {
        _ = try? runLaunchctl(["unload", "-w", plistURL.path])
        try removePlist()
    }

    /// Starts the loaded agent.
    public func start() throws {
        try runLaunchctl(["start", label])
    }

    /// Stops the running agent (it may be relaunched by KeepAlive).
    public func stop() throws {
        try runLaunchctl(["stop", label])
    }

    /// Whether the agent is currently loaded in launchd.
    public func isLoaded() -> Bool {
        (try? runLaunchctl(["list", label])) != nil
    }

    @discardableResult
    private func runLaunchctl(_ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
        } catch {
            throw LaunchAgentError.launchctl(error.localizedDescription)
        }
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(bytes: data, encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw LaunchAgentError.launchctl("exit \(process.terminationStatus): \(output)")
        }
        return output
    }
}
