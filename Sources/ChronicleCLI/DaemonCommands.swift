import ArgumentParser
import ChronicleDaemon
import ChronicleIPC
import Foundation

/// `chronicle status` — daemon health and event counts.
struct StatusCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show daemon status and event counts."
    )

    @OptionGroup var options: GlobalOptions

    func run() async throws {
        let context = try CLIContext.make(options)
        let result = await context.sendIPC(.status)

        if case let .success(.status(status)) = result {
            try render(status)
            return
        }
        // Daemon unreachable: fall back to reading the database directly.
        let total = try await context.store.totalCount()
        if options.json {
            let object: [String: Any] = [
                "running": false,
                "total_events": total,
                "database": context.paths.databaseFile.path,
            ]
            let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
            print(utf8String(data))
        } else {
            let color = Style.shouldUseColor(json: options.json)
            print("daemon:    \(Style.color("not running", 31, color))")
            print("events:    \(total)")
            print("database:  \(context.paths.databaseFile.path)")
        }
    }

    private func render(_ status: DaemonStatus) throws {
        if options.json {
            let data = try chronicleJSONEncoder().encode(status)
            print(utf8String(data))
            return
        }
        let color = Style.shouldUseColor(json: options.json)
        let uptime = Int(Date().timeIntervalSince1970 - status.startedAtEpoch)
        let state = Style.color(status.paused ? "paused" : "running", status.paused ? 33 : 32, color)
        print("daemon:    \(state) (pid \(status.pid))")
        print("uptime:    \(uptime)s")
        print("events:    \(status.totalEvents) total")
        let pipeline = "\(status.ingested) ingested, \(status.persisted) persisted, "
            + "\(status.deduplicated) deduped, \(status.rejected) rejected"
        print("pipeline:  \(pipeline)")
        print("modules:   \(status.enabledModules.joined(separator: ", "))")
        print("database:  \(status.databasePath)")
    }
}

/// `chronicle daemon` — manage the background agent.
struct DaemonCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "daemon",
        abstract: "Install, start, stop, and inspect the background agent.",
        subcommands: [
            DaemonInstall.self, DaemonUninstall.self, DaemonStart.self,
            DaemonStop.self, DaemonRestart.self, DaemonStatusSub.self, DaemonRun.self,
        ]
    )
}

private func makeController(_ options: GlobalOptions) throws -> LaunchAgentController {
    let context = try CLIContext.make(options)
    return LaunchAgentController(
        label: "dev.chronicle.agent",
        plistURL: context.paths.launchAgentFile,
        executablePath: chronicledExecutablePath(),
        logPath: context.paths.logFile.path
    )
}

private func chronicledExecutablePath() -> String {
    if let directory = Bundle.main.executableURL?.deletingLastPathComponent() {
        let candidate = directory.appendingPathComponent("chronicled").path
        if FileManager.default.fileExists(atPath: candidate) { return candidate }
    }
    return "/usr/local/bin/chronicled"
}

struct DaemonInstall: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "install",
        abstract: "Install and load the LaunchAgent."
    )
    @OptionGroup var options: GlobalOptions
    func run() async throws {
        try makeController(options).install()
        print("Installed and loaded the Chronicle agent.")
    }
}

struct DaemonUninstall: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "uninstall",
        abstract: "Unload and remove the LaunchAgent."
    )
    @OptionGroup var options: GlobalOptions
    func run() async throws {
        try makeController(options).uninstall()
        print("Uninstalled the Chronicle agent.")
    }
}

struct DaemonStart: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "start", abstract: "Start the agent.")
    @OptionGroup var options: GlobalOptions
    func run() async throws {
        try makeController(options).start()
        print("Started.")
    }
}

struct DaemonStop: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "stop", abstract: "Stop the agent.")
    @OptionGroup var options: GlobalOptions
    func run() async throws {
        try makeController(options).stop()
        print("Stopped.")
    }
}

struct DaemonRestart: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "restart", abstract: "Restart the agent.")
    @OptionGroup var options: GlobalOptions
    func run() async throws {
        let controller = try makeController(options)
        try? controller.stop()
        try controller.start()
        print("Restarted.")
    }
}

struct DaemonStatusSub: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show whether the agent is loaded."
    )
    @OptionGroup var options: GlobalOptions
    func run() async throws {
        let loaded = try makeController(options).isLoaded()
        print("LaunchAgent: \(loaded ? "loaded" : "not loaded")")
    }
}

struct DaemonRun: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Run the agent in the foreground (debugging)."
    )
    @OptionGroup var options: GlobalOptions
    func run() async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: chronicledExecutablePath())
        process.arguments = ["run"]
        try process.run()
        process.waitUntilExit()
        throw ExitCode(process.terminationStatus)
    }
}
