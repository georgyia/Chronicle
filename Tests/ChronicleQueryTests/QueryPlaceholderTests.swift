import Testing
@testable import ChronicleQuery

@Suite("Query skeleton")
struct QueryPlaceholderTests {
    @Test("Module is linkable")
    func linkable() {
        _ = ChronicleQuery.self
        #expect(Bool(true))
    }
}
