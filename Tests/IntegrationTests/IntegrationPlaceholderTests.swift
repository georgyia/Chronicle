import Testing
@testable import ChronicleDaemon

@Suite("Integration skeleton")
struct IntegrationPlaceholderTests {
    @Test("Daemon module links in the integration target")
    func linkable() {
        _ = ChronicleDaemon.self
        #expect(Bool(true))
    }
}
