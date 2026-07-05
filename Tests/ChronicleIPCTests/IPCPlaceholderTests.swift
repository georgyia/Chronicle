import Testing
@testable import ChronicleIPC

@Suite("IPC skeleton")
struct IPCPlaceholderTests {
    @Test("Module is linkable")
    func linkable() {
        _ = ChronicleIPC.self
        #expect(Bool(true))
    }
}
