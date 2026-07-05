import ChronicleCore
import ChronicleModels
import ChronicleTestSupport
import Foundation
import Testing
@testable import ChroniclePipeline

@Suite("Event pipeline")
struct EventPipelineTests {
    private func makePipeline(
        repository: InMemoryEventRepository,
        settings: PipelineSettings = PipelineSettings(batchSize: 4, flushInterval: .seconds(60))
    ) -> EventPipeline {
        let clock = FixedWallClock(Date(timeIntervalSince1970: 1_700_100_000))
        let session = FixedSessionProvider(sessionID: SessionID(rawValue: UUID()))
        return EventPipeline(
            repository: repository,
            identifierFactory: DeterministicIdentifierFactory(),
            processors: [ValidationProcessor(clock: clock), EnrichmentProcessor(session: session)],
            settings: settings
        )
    }

    private func raw(_ path: String, at seconds: TimeInterval = 1_700_000_000) -> RawEvent {
        RawEvent(
            timestamp: Date(timeIntervalSince1970: seconds),
            kind: .fileModified,
            source: .filesystem,
            attributes: [.path: .string(path)]
        )
    }

    @Test("Persists submitted events on shutdown")
    func persistsOnShutdown() async throws {
        let repository = InMemoryEventRepository()
        let pipeline = makePipeline(repository: repository)
        await pipeline.start()

        await pipeline.submit(raw("/tmp/a.txt", at: 1_700_000_000))
        await pipeline.submit(raw("/tmp/b.txt", at: 1_700_000_100))
        await pipeline.shutdown()

        #expect(try await repository.totalCount() == 2)
        let metrics = await pipeline.snapshot()
        #expect(metrics.ingested == 2)
        #expect(metrics.persisted == 2)
    }

    @Test("Auto-flushes when the batch size is reached")
    func autoFlush() async throws {
        let repository = InMemoryEventRepository()
        let pipeline = makePipeline(
            repository: repository,
            settings: PipelineSettings(batchSize: 2, flushInterval: .seconds(60))
        )
        await pipeline.start()

        await pipeline.submit(raw("/tmp/a.txt", at: 1_700_000_000))
        await pipeline.submit(raw("/tmp/b.txt", at: 1_700_000_100))
        // Two events with batch size 2 should have flushed without shutdown.
        #expect(try await repository.totalCount() == 2)
        await pipeline.shutdown()
    }

    @Test("Deduplicates identical rapid events")
    func deduplicates() async throws {
        let repository = InMemoryEventRepository()
        let pipeline = makePipeline(repository: repository)
        await pipeline.start()

        await pipeline.submit(raw("/tmp/a.txt", at: 1_700_000_000))
        await pipeline.submit(raw("/tmp/a.txt", at: 1_700_000_000))
        await pipeline.shutdown()

        #expect(try await repository.totalCount() == 1)
        let metrics = await pipeline.snapshot()
        #expect(metrics.deduplicated == 1)
    }

    @Test("Rejects invalid events and counts them")
    func rejectsInvalid() async throws {
        let repository = InMemoryEventRepository()
        let pipeline = makePipeline(repository: repository)
        await pipeline.start()

        let invalid = RawEvent(
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            kind: .fileCreated,
            source: .filesystem,
            attributes: [:]
        )
        await pipeline.submit(invalid)
        await pipeline.shutdown()

        #expect(try await repository.totalCount() == 0)
        let metrics = await pipeline.snapshot()
        #expect(metrics.rejected == 1)
    }

    @Test("Ignores submissions before start")
    func ignoresBeforeStart() async throws {
        let repository = InMemoryEventRepository()
        let pipeline = makePipeline(repository: repository)
        await pipeline.submit(raw("/tmp/a.txt"))
        #expect(try await repository.totalCount() == 0)
    }
}
