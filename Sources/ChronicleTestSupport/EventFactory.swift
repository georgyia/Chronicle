import ChronicleModels
import Foundation

/// Convenience builders for constructing events in tests.
public enum EventFactory {
    private static let factory = DeterministicIdentifierFactory()

    /// Builds a raw event with sensible defaults.
    public static func rawEvent(
        timestamp: Date = Date(timeIntervalSince1970: 1_700_000_000),
        kind: EventKind = .fileCreated,
        source: CollectorSource = .filesystem,
        attributes: EventAttributes = [.path: "/tmp/example.txt"]
    ) -> RawEvent {
        RawEvent(timestamp: timestamp, kind: kind, source: source, attributes: attributes)
    }

    /// Builds a fully-formed event with a deterministic id.
    public static func event(
        timestamp: Date = Date(timeIntervalSince1970: 1_700_000_000),
        kind: EventKind = .fileCreated,
        source: CollectorSource = .filesystem,
        sessionID: SessionID? = nil,
        attributes: EventAttributes = [.path: "/tmp/example.txt"],
        dedupeDigest: EventDigest? = nil
    ) -> Event {
        Event(
            id: factory.makeEventID(at: timestamp),
            timestamp: timestamp,
            kind: kind,
            source: source,
            sessionID: sessionID,
            attributes: attributes,
            dedupeDigest: dedupeDigest
        )
    }

    /// Builds a chronological run of events spaced `interval` apart.
    public static func sequence(
        count: Int,
        start: Date = Date(timeIntervalSince1970: 1_700_000_000),
        interval: TimeInterval = 60,
        kind: EventKind = .fileModified,
        source: CollectorSource = .filesystem
    ) -> [Event] {
        (0..<count).map { index in
            event(
                timestamp: start.addingTimeInterval(interval * Double(index)),
                kind: kind,
                source: source,
                attributes: [.path: .string("/tmp/file-\(index).txt")]
            )
        }
    }
}
