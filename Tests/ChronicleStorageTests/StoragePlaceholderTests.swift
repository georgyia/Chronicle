import Testing
@testable import ChronicleStorage

@Suite("Storage skeleton")
struct StoragePlaceholderTests {
    @Test("Schema version is defined")
    func schemaVersion() {
        #expect(ChronicleStorage.schemaVersion == 1)
    }
}
