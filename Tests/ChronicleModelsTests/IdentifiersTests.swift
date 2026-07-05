import Foundation
import Testing
@testable import ChronicleModels

@Suite("UUIDv7 & identifiers")
struct IdentifiersTests {
    @Test("UUIDv7 encodes version 7 and variant 10")
    func versionAndVariant() {
        var generator = SystemRandomNumberGenerator()
        let uuid = UUIDv7.make(millisecondsSince1970: 1_700_000_000_000, using: &generator)
        let bytes = uuid.bytes
        #expect(bytes[6] & 0xF0 == 0x70, "version nibble should be 7")
        #expect(bytes[8] & 0xC0 == 0x80, "variant bits should be 10")
    }

    @Test("UUIDv7 embeds the millisecond timestamp big-endian")
    func embedsTimestamp() {
        var generator = SystemRandomNumberGenerator()
        let milliseconds: Int64 = 0x0000010203040506
        let uuid = UUIDv7.make(millisecondsSince1970: milliseconds, using: &generator)
        let bytes = uuid.bytes
        #expect(bytes[0] == 0x01)
        #expect(bytes[1] == 0x02)
        #expect(bytes[2] == 0x03)
        #expect(bytes[3] == 0x04)
        #expect(bytes[4] == 0x05)
        #expect(bytes[5] == 0x06)
    }

    @Test("Later timestamps sort after earlier ones")
    func timeOrdering() {
        var generator = SeededGenerator(seed: 42)
        let early = EventID(rawValue: UUIDv7.make(millisecondsSince1970: 1000, using: &generator))
        let late = EventID(rawValue: UUIDv7.make(millisecondsSince1970: 2000, using: &generator))
        #expect(early < late)
    }

    @Test("EventID round-trips through Codable as a lowercase string")
    func codableRoundTrip() throws {
        let uuid = try #require(UUID(uuidString: "018F0000-0000-7000-8000-000000000000"))
        let id = EventID(rawValue: uuid)
        let data = try JSONEncoder().encode(id)
        #expect(String(data: data, encoding: .utf8) == "\"\(uuid.uuidString.lowercased())\"")
        let decoded = try JSONDecoder().decode(EventID.self, from: data)
        #expect(decoded == id)
    }
}

/// Minimal deterministic generator local to the test module.
private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var mixed = state
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58476D1CE4E5B9
        return mixed ^ (mixed >> 31)
    }
}
