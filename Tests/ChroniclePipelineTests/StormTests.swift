import ChronicleCore
import ChronicleModels
import ChronicleTestSupport
import Foundation
import Testing
@testable import ChroniclePipeline

@Suite("Storm hardening")
struct StormTests {
    @Test("A flood of identical events coalesces to a few persisted rows")
    func floodCoalesces() async throws {
        let repository = InMemoryEventRepository()
        let clock = FixedWallClock(Date(timeIntervalSince1970: 1_700_100_000))
        let session = FixedSessionProvider(sessionID: SessionID(rawValue: UUID()))
        let pipeline = EventPipeline(
            repository: repository,
            identifierFactory: DeterministicIdentifierFactory(),
            processors: [ValidationProcessor(clock: clock), EnrichmentProcessor(session: session)],
            settings: PipelineSettings(batchSize: 256, flushInterval: .seconds(60), dedupeWindow: .seconds(2))
        )
        await pipeline.start()

        let base = Date(timeIntervalSince1970: 1_700_000_000)
        for _ in 0..<5000 {
            await pipeline.submit(RawEvent(
                timestamp: base,
                kind: .fileModified,
                source: .filesystem,
                attributes: [.path: "/tmp/hot.txt"]
            ))
        }
        await pipeline.shutdown()

        let metrics = await pipeline.snapshot()
        #expect(metrics.ingested == 5000)
        #expect(metrics.deduplicated >= 4990)
        // Same content in the same dedupe window collapses to a single row.
        #expect(try await repository.totalCount() <= 2)
    }

    @Test("Buffer safety valve drops under extreme overload")
    func bufferOverflow() async {
        // A repository that never returns lets the buffer grow past the cap.
        let repository = BlockingRepository()
        let clock = FixedWallClock(Date(timeIntervalSince1970: 1_700_100_000))
        let session = FixedSessionProvider(sessionID: SessionID(rawValue: UUID()))
        let pipeline = EventPipeline(
            repository: repository,
            identifierFactory: DeterministicIdentifierFactory(),
            processors: [ValidationProcessor(clock: clock), EnrichmentProcessor(session: session)],
            settings: PipelineSettings(batchSize: 1_000_000, flushInterval: .seconds(60), maxBufferedEvents: 100)
        )
        await pipeline.start()

        for index in 0..<300 {
            await pipeline.submit(RawEvent(
                timestamp: Date(timeIntervalSince1970: 1_700_000_000 + Double(index)),
                kind: .fileModified,
                source: .filesystem,
                attributes: [.path: .string("/tmp/file-\(index).txt")]
            ))
        }

        let metrics = await pipeline.snapshot()
        #expect(metrics.overflowed > 0)
        #expect(metrics.buffered <= 100)
    }
}

/// A repository whose inserts never complete (for overflow testing).
private actor BlockingRepository: EventRepository {
    func insert(_: [Event]) async throws -> Int {
        try await Task.sleep(for: .seconds(3600))
        return 0
    }

    func events(matching _: EventQuery) async throws -> [Event] {
        []
    }

    func count(matching _: EventQuery) async throws -> Int {
        0
    }

    func event(id _: EventID) async throws -> Event? {
        nil
    }

    func deleteEvents(before _: Date) async throws -> Int {
        0
    }

    func deleteEvents(matching _: EventQuery) async throws -> Int {
        0
    }

    func totalCount() async throws -> Int {
        0
    }
}
