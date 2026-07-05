import Testing
@testable import ChronicleCollectors

@Suite("Collectors skeleton")
struct CollectorsPlaceholderTests {
    @Test("Module is linkable")
    func linkable() {
        _ = ChronicleCollectors.self
        #expect(Bool(true))
    }
}
