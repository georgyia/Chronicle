import ChronicleModels
import ChronicleTestSupport
import Foundation
import Testing
@testable import ChronicleCore

@Suite("Kernel protocols & utilities")
struct CoreTests {
    @Test("Date millisecond conversion round-trips")
    func millisecondRoundTrip() {
        let date = Date(timeIntervalSince1970: 1_700_000_000.123)
        let millis = date.millisecondsSince1970
        #expect(millis == 1_700_000_000_123)
        #expect(Date(millisecondsSince1970: millis).millisecondsSince1970 == millis)
    }

    @Test("SystemIdentifierFactory mints ordered v7 ids")
    func systemFactory() {
        let factory = SystemIdentifierFactory()
        let early = factory.makeEventID(at: Date(timeIntervalSince1970: 1000))
        let late = factory.makeEventID(at: Date(timeIntervalSince1970: 2000))
        #expect(early < late)
    }

    @Test("DeterministicIdentifierFactory is reproducible for a fixed seed")
    func deterministicFactory() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let first = DeterministicIdentifierFactory(seed: 5).makeEventID(at: date)
        let second = DeterministicIdentifierFactory(seed: 5).makeEventID(at: date)
        #expect(first == second)
    }

    @Test("EventQuery defaults are unrestricted and descending")
    func eventQueryDefaults() {
        let query = EventQuery()
        #expect(query.range == nil)
        #expect(query.kinds.isEmpty)
        #expect(query.order == .descending)
        #expect(query.limit == nil)
    }

    @Test("CoreError carries a namespaced code")
    func coreErrorCode() {
        #expect(CoreError.validation("bad").code == "core.validation")
        #expect(CoreError.validation("bad").description == "[core.validation] bad")
    }
}
