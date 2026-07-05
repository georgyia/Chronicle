import ChronicleCore
import ChronicleModels
import ChronicleTestSupport
import Foundation
import Testing

@Suite("In-memory repository oracle")
struct InMemoryRepositoryTests {
    @Test("Insert deduplicates on digest")
    func dedupe() async throws {
        let repository = InMemoryEventRepository()
        let digest = EventDigest(bytes: Data([9, 9, 9]))
        let first = EventFactory.event(dedupeDigest: digest)
        let second = EventFactory.event(dedupeDigest: digest)
        let inserted = try await repository.insert([first, second])
        #expect(inserted == 1)
        #expect(try await repository.totalCount() == 1)
    }

    @Test("Queries filter by kind and range")
    func filtering() async throws {
        let repository = InMemoryEventRepository()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        try await repository.insert([
            EventFactory.event(timestamp: base, kind: .fileCreated),
            EventFactory.event(timestamp: base.addingTimeInterval(3600), kind: .appLaunched),
        ])

        let files = try await repository.events(matching: EventQuery(kinds: [.fileCreated]))
        #expect(files.count == 1)
        #expect(files.first?.kind == .fileCreated)

        let window = DateInterval(start: base.addingTimeInterval(-1), duration: 10)
        let inWindow = try await repository.events(matching: EventQuery(range: window))
        #expect(inWindow.count == 1)
    }

    @Test("Descending order returns newest first")
    func ordering() async throws {
        let repository = InMemoryEventRepository()
        let events = EventFactory.sequence(count: 5)
        try await repository.insert(events)
        let result = try await repository.events(matching: EventQuery(order: .descending))
        #expect(result.first?.timestamp == events.last?.timestamp)
    }

    @Test("Statistics aggregate by kind")
    func statistics() async throws {
        let repository = InMemoryEventRepository()
        try await repository.insert([
            EventFactory.event(kind: .fileCreated),
            EventFactory.event(kind: .fileCreated, attributes: [.path: "/tmp/b"]),
            EventFactory.event(kind: .appLaunched, attributes: [.appName: "Safari"]),
        ])
        let byKind = try await repository.countByKind(in: nil)
        #expect(byKind[.fileCreated] == 2)
        #expect(byKind[.appLaunched] == 1)
    }
}
