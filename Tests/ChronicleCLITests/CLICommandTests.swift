import Testing
@testable import ChronicleCLI

@Suite("CLI command tree")
struct CLICommandTests {
    @Test("Root command is named chronicle")
    func rootName() {
        #expect(ChronicleCommand.configuration.commandName == "chronicle")
    }

    @Test("Version constant is a semantic version")
    func semver() {
        let parts = ChronicleVersion.current.split(separator: ".")
        #expect(parts.count == 3)
    }
}
