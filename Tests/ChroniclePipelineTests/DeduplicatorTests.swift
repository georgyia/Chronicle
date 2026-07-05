import ChronicleModels
import ChronicleTestSupport
import Foundation
import Testing
@testable import ChroniclePipeline

@Suite("Deduplicator")
struct DeduplicatorTests {
    @Test("Suppresses identical events within the window")
    func suppressesDuplicates() {
        let deduplicator = Deduplicator(window: .seconds(2), capacity: 100)
        let first = EventFactory.event(attributes: [.path: "/tmp/a.txt"])
        let second = EventFactory.event(attributes: [.path: "/tmp/a.txt"])
        #expect(deduplicator.admit(first) != nil)
        #expect(deduplicator.admit(second) == nil)
    }

    @Test("Admits the same content in a later time bucket")
    func admitsLaterBucket() {
        let deduplicator = Deduplicator(window: .seconds(2), capacity: 100)
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let early = EventFactory.event(timestamp: base, attributes: [.path: "/tmp/a.txt"])
        let later = EventFactory.event(timestamp: base.addingTimeInterval(10), attributes: [.path: "/tmp/a.txt"])
        #expect(deduplicator.admit(early) != nil)
        #expect(deduplicator.admit(later) != nil)
    }

    @Test("Admitted events carry a digest")
    func stampsDigest() {
        let deduplicator = Deduplicator(window: .seconds(2), capacity: 100)
        let admitted = deduplicator.admit(EventFactory.event())
        #expect(admitted?.dedupeDigest != nil)
    }

    @Test("Distinct content produces distinct digests")
    func distinctDigests() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let one = Deduplicator.digest(
            for: EventFactory.event(timestamp: base, attributes: [.path: "/a"]),
            windowMilliseconds: 2000
        )
        let two = Deduplicator.digest(
            for: EventFactory.event(timestamp: base, attributes: [.path: "/b"]),
            windowMilliseconds: 2000
        )
        #expect(one != two)
    }
}
