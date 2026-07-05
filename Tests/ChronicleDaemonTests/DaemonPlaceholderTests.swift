import Testing
@testable import ChronicleDaemon

@Suite("Daemon skeleton")
struct DaemonPlaceholderTests {
    @Test("Module is linkable")
    func linkable() {
        _ = ChronicleDaemon.self
        #expect(Bool(true))
    }
}
