import ChronicleTestSupport
import Foundation
import Testing
@testable import ChronicleConfig

@Suite("Configuration loading & validation")
struct ConfigurationTests {
    private let loader = ConfigurationLoader()

    @Test("Default template decodes and validates")
    func defaultTemplateValid() throws {
        let config = try loader.decode(ConfigurationLoader.defaultTemplate)
        try loader.validate(config)
        #expect(config.storage.retentionDays == 365)
        #expect(config.isModuleEnabled("filesystem", defaultEnabled: false))
        #expect(!config.isModuleEnabled("clipboard", defaultEnabled: false))
    }

    @Test("Partial TOML fills missing sections from defaults")
    func partialMerge() throws {
        let toml = """
        [logging]
        level = "debug"
        """
        let config = try loader.decode(toml)
        #expect(config.logging.level == "debug")
        #expect(config.logging.destination == "file") // default
        #expect(config.storage.retentionDays == 365) // default
    }

    @Test("Environment overrides take precedence")
    func environmentOverrides() throws {
        let toml = "[logging]\nlevel = \"info\""
        var config = try loader.decode(toml)
        config = applyOverridesForTest(config, env: [
            "CHRONICLE_LOG_LEVEL": "warning",
            "CHRONICLE_RETENTION_DAYS": "30",
            "CHRONICLE_MODULE_CLIPBOARD": "on",
        ])
        #expect(config.logging.level == "warning")
        #expect(config.storage.retentionDays == 30)
        #expect(config.modules["clipboard"] == true)
    }

    @Test("Validation rejects an unknown log level")
    func rejectsBadLevel() {
        var config = ChronicleConfiguration()
        config.logging.level = "loud"
        #expect(throws: ConfigError.self) {
            try loader.validate(config)
        }
    }

    @Test("Save then load round-trips")
    func saveLoadRoundTrip() throws {
        let directory = try TemporaryDirectory()
        defer { directory.remove() }
        let url = directory.file("config.toml")

        var config = ChronicleConfiguration()
        config.storage.retentionDays = 90
        config.ai.enabled = true
        config.ai.provider = "ollama"
        try loader.save(config, to: url)

        let loaded = try loader.load(from: url)
        #expect(loaded.storage.retentionDays == 90)
        #expect(loaded.ai.provider == "ollama")
    }

    @Test("writeDefaultIfMissing only writes once")
    func writeDefaultOnce() throws {
        let directory = try TemporaryDirectory()
        defer { directory.remove() }
        let url = directory.file("config.toml")
        #expect(try loader.writeDefaultIfMissing(to: url))
        #expect(try loader.writeDefaultIfMissing(to: url) == false)
    }

    /// Exercises the same override path the loader uses internally.
    private func applyOverridesForTest(
        _ config: ChronicleConfiguration,
        env: [String: String]
    ) -> ChronicleConfiguration {
        let data = env.reduce(into: [String: String]()) { $0[$1.key] = $1.value }
        // Round-trip through a temp file to run the full public path.
        return (try? loadWithEnv(config, env: data)) ?? config
    }

    private func loadWithEnv(_ config: ChronicleConfiguration, env: [String: String]) throws -> ChronicleConfiguration {
        let directory = try TemporaryDirectory()
        defer { directory.remove() }
        let url = directory.file("config.toml")
        try loader.save(config, to: url)
        return try loader.load(from: url, environment: env)
    }
}

@Suite("Path resolution")
struct PathsTests {
    @Test("CHRONICLE_HOME sandboxes all paths")
    func sandbox() {
        let paths = ChroniclePaths.resolve(environment: ["CHRONICLE_HOME": "/tmp/sandbox"])
        #expect(paths.configFile.path == "/tmp/sandbox/.config/chronicle/config.toml")
        #expect(paths.databaseFile.path.hasPrefix("/tmp/sandbox/Library/Application Support/Chronicle"))
        #expect(paths.launchAgentFile.lastPathComponent == "dev.chronicle.agent.plist")
    }

    @Test("Explicit overrides win over derived paths")
    func overrides() {
        let paths = ChroniclePaths.resolve(environment: [
            "CHRONICLE_HOME": "/tmp/sandbox",
            "CHRONICLE_DB_PATH": "/tmp/custom.sqlite",
        ])
        #expect(paths.databaseFile.path == "/tmp/custom.sqlite")
    }
}
