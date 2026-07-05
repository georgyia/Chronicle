import Testing
@testable import ChroniclePipeline

@Suite("Pipeline skeleton")
struct PipelinePlaceholderTests {
    @Test("Module is linkable")
    func linkable() {
        _ = ChroniclePipeline.self
        #expect(Bool(true))
    }
}
