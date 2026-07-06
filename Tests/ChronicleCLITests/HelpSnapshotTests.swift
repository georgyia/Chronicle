import SnapshotTesting
import Testing
@testable import ChronicleCLI

@Suite("CLI help snapshot")
struct HelpSnapshotTests {
    @Test("Root help lists the command surface")
    func rootHelp() {
        let help = ChronicleCommand.helpMessage(columns: 100)
        // Assert on stable content rather than a brittle full-file snapshot so the
        // test is CI-safe without a recording step, while still exercising the tree.
        for command in ["status", "daemon", "timeline", "search", "stats", "config", "module", "doctor", "export"] {
            #expect(help.contains(command), "help should mention \(command)")
        }
    }

    @Test("Search help documents the semantic flag")
    func searchHelp() {
        let help = SearchCommand.helpMessage(columns: 100)
        #expect(help.contains("--semantic"))
        #expect(help.contains("--range"))
    }
}
