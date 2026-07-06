import ArgumentParser
import ChronicleCollectors
import ChronicleConfig
import Foundation

private func loadConfigFile(at url: URL, loader: ConfigurationLoader) throws -> ChronicleConfiguration {
    guard FileManager.default.fileExists(atPath: url.path) else { return ChronicleConfiguration() }
    return try loader.decode(String(contentsOf: url, encoding: .utf8))
}

private func parseBool(_ value: String) -> Bool? {
    switch value.lowercased() {
    case "true", "on", "yes", "1", "enabled": true
    case "false", "off", "no", "0", "disabled": false
    default: nil
    }
}

/// `chronicle config` — inspect and edit configuration.
struct ConfigCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "config",
        abstract: "Get, set, edit, and validate configuration.",
        subcommands: [ConfigGet.self, ConfigSet.self, ConfigEdit.self, ConfigPath.self, ConfigValidate.self]
    )
}

struct ConfigPath: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "path", abstract: "Print the config file path.")
    @OptionGroup var options: GlobalOptions
    func run() async throws {
        try print(CLIContext.make(options).paths.configFile.path)
    }
}

struct ConfigGet: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "get", abstract: "Print the effective configuration.")
    @OptionGroup var options: GlobalOptions
    func run() async throws {
        let context = try CLIContext.make(options)
        let toml = try ConfigurationLoader().encode(context.configuration)
        print(toml)
    }
}

struct ConfigValidate: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "validate",
        abstract: "Validate the configuration file."
    )
    @OptionGroup var options: GlobalOptions
    func run() async throws {
        let context = try CLIContext.make(options)
        let loader = ConfigurationLoader()
        do {
            try loader.validate(context.configuration)
            print("Configuration is valid.")
        } catch {
            printError("\(error)")
            throw CLIExit.invalidConfig
        }
    }
}

struct ConfigEdit: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "edit", abstract: "Open the config file in $EDITOR.")
    @OptionGroup var options: GlobalOptions
    func run() async throws {
        let context = try CLIContext.make(options)
        let loader = ConfigurationLoader()
        try loader.writeDefaultIfMissing(to: context.paths.configFile)

        let editor = ProcessInfo.processInfo.environment["EDITOR"] ?? "vi"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [editor, context.paths.configFile.path]
        try process.run()
        process.waitUntilExit()

        do {
            _ = try loader.load(from: context.paths.configFile)
            print("Configuration is valid. Restart or reload the daemon to apply.")
        } catch {
            printError("Warning: \(error)")
            throw CLIExit.invalidConfig
        }
    }
}

struct ConfigSet: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "set", abstract: "Set a configuration value.")
    @OptionGroup var options: GlobalOptions

    @Argument(help: "Dotted key, e.g. storage.retention_days.")
    var key: String

    @Argument(help: "The new value.")
    var value: String

    func run() async throws {
        let context = try CLIContext.make(options)
        let loader = ConfigurationLoader()
        var config = try loadConfigFile(at: context.paths.configFile, loader: loader)
        try apply(to: &config)
        try loader.validate(config)
        try loader.save(config, to: context.paths.configFile)
        _ = await context.sendIPC(.reload)
        print("Set \(key) = \(value)")
    }

    private func apply(to config: inout ChronicleConfiguration) throws {
        switch key {
        case "storage.retention_days": config.storage.retentionDays = try intValue()
        case "logging.level": config.logging.level = value
        case "logging.destination": config.logging.destination = value
        case "daemon.batch_size": config.daemon.batchSize = try intValue()
        case "ai.enabled": config.ai.enabled = try boolValue()
        case "ai.provider": config.ai.provider = value
        case "ai.model": config.ai.model = value
        default:
            guard key.hasPrefix("modules.") else {
                printError("Unknown key: \(key)")
                throw CLIExit.invalidConfig
            }
            config.modules[String(key.dropFirst("modules.".count))] = try boolValue()
        }
    }

    private func intValue() throws -> Int {
        guard let parsed = Int(value) else {
            printError("Expected an integer for \(key)")
            throw CLIExit.invalidConfig
        }
        return parsed
    }

    private func boolValue() throws -> Bool {
        guard let parsed = parseBool(value) else {
            printError("Expected a boolean for \(key)")
            throw CLIExit.invalidConfig
        }
        return parsed
    }
}

/// `chronicle module` — manage collector modules.
struct ModuleCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "module",
        abstract: "List and toggle collector modules.",
        subcommands: [ModuleList.self, ModuleInfo.self, ModuleEnable.self, ModuleDisable.self]
    )
}

struct ModuleList: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List all modules and their state.")
    @OptionGroup var options: GlobalOptions
    func run() async throws {
        let context = try CLIContext.make(options)
        let color = Style.shouldUseColor(json: options.json)
        var table = Table(headers: ["Module", "Enabled", "Sensitive", "Description"])
        for descriptor in CollectorFactory.allDescriptors() {
            let enabled = context.configuration.isModuleEnabled(
                descriptor.id,
                defaultEnabled: descriptor.enabledByDefault
            )
            table.rows.append([
                descriptor.id,
                enabled ? "yes" : "no",
                descriptor.isSensitive ? "yes" : "no",
                descriptor.summary,
            ])
        }
        print(table.render(color: color))
    }
}

struct ModuleInfo: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "info", abstract: "Show details about a module.")
    @OptionGroup var options: GlobalOptions
    @Argument(help: "The module id.") var module: String
    func run() async throws {
        let context = try CLIContext.make(options)
        guard let descriptor = CollectorFactory.allDescriptors().first(where: { $0.id == module }) else {
            printError("Unknown module: \(module)")
            throw CLIExit.notFound
        }
        let enabled = context.configuration.isModuleEnabled(descriptor.id, defaultEnabled: descriptor.enabledByDefault)
        print("id:          \(descriptor.id)")
        print("name:        \(descriptor.displayName)")
        print("enabled:     \(enabled)")
        print("sensitive:   \(descriptor.isSensitive)")
        print("accessibility: \(descriptor.requiresAccessibility)")
        print("full disk access: \(descriptor.requiresFullDiskAccess)")
        print("summary:     \(descriptor.summary)")
    }
}

private func setModule(_ id: String, enabled: Bool, options: GlobalOptions) async throws {
    let context = try CLIContext.make(options)
    guard CollectorFactory.allDescriptors().contains(where: { $0.id == id }) else {
        printError("Unknown module: \(id)")
        throw CLIExit.notFound
    }
    let loader = ConfigurationLoader()
    var config = try loadConfigFile(at: context.paths.configFile, loader: loader)
    config.modules[id] = enabled
    try loader.save(config, to: context.paths.configFile)
    _ = await context.sendIPC(.reload)
    print("\(enabled ? "Enabled" : "Disabled") module '\(id)'.")
}

struct ModuleEnable: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "enable", abstract: "Enable a module.")
    @OptionGroup var options: GlobalOptions
    @Argument(help: "The module id.") var module: String
    func run() async throws {
        try await setModule(module, enabled: true, options: options)
    }
}

struct ModuleDisable: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "disable", abstract: "Disable a module.")
    @OptionGroup var options: GlobalOptions
    @Argument(help: "The module id.") var module: String
    func run() async throws {
        try await setModule(module, enabled: false, options: options)
    }
}
