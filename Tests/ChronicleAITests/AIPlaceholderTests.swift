import Testing
@testable import ChronicleAI

@Suite("AI skeleton")
struct AIPlaceholderTests {
    @Test("Module is linkable")
    func linkable() {
        _ = ChronicleAI.self
        #expect(Bool(true))
    }
}
