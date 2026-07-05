import Foundation
import Testing
@testable import ChronicleModels

@Suite("Event & attribute coding")
struct EventCodingTests {
    @Test("JSONValue decodes each scalar and container type")
    func jsonValueRoundTrip() throws {
        let value: JSONValue = [
            "s": "text",
            "i": 7,
            "d": 1.5,
            "b": true,
            "arr": [1, 2, 3],
            "obj": ["k": "v"],
        ]
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        #expect(decoded == value)
    }

    @Test("Booleans do not decode as integers")
    func boolNotInt() throws {
        let data = Data("true".utf8)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        #expect(decoded == .bool(true))
    }

    @Test("EventKind splits namespace and action")
    func eventKindNamespace() {
        #expect(EventKind.fileCreated.namespace == "file")
        #expect(EventKind.fileCreated.action == "created")
        #expect(EventKind.windowTitleChanged.namespace == "window")
    }

    @Test("Event survives a Codable round-trip")
    func eventRoundTrip() throws {
        let event = EventFixture.sample
        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(Event.self, from: data)
        #expect(decoded == event)
    }

    @Test("Attribute accessors read typed values")
    func attributeAccessors() {
        let attributes: EventAttributes = [.path: "/tmp/x", .pid: 42, .title: "Doc"]
        #expect(attributes.string(.path) == "/tmp/x")
        #expect(attributes.int(.pid) == 42)
        #expect(attributes.string(.title) == "Doc")
        #expect(attributes.string(.appName) == nil)
    }

    @Test("EventDigest round-trips through hex")
    func digestHex() throws {
        let digest = EventDigest(bytes: Data([0xDE, 0xAD, 0xBE, 0xEF]))
        #expect(digest.description == "deadbeef")
        let data = try JSONEncoder().encode(digest)
        let decoded = try JSONDecoder().decode(EventDigest.self, from: data)
        #expect(decoded == digest)
    }
}

private enum EventFixture {
    static let sample = Event(
        id: EventID(rawValue: UUID()),
        timestamp: Date(timeIntervalSince1970: 1_700_000_000),
        kind: .appLaunched,
        source: .application,
        sessionID: SessionID(rawValue: UUID()),
        attributes: [.appName: "Safari", .bundleID: "com.apple.Safari"],
        dedupeDigest: EventDigest(bytes: Data([1, 2, 3]))
    )
}
