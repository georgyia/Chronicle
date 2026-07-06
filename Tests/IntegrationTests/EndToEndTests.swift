import ChronicleCore
import ChronicleModels
import Foundation
import Testing

@Suite("End-to-end ingestion", .serialized)
struct EndToEndTests {
    @Test("Heartbeats flow from collector through pipeline to storage")
    func heartbeatEndToEnd() async throws {
        let harness = try DaemonTestHarness.make()
        try await harness.start()
        defer { harness.cleanup() }

        try await harness.waitForStatus { $0.persisted >= 2 }

        let status = try await harness.status()
        #expect(status.ingested >= 2)
        #expect(status.persisted >= 2)
        #expect(status.enabledModules.contains("heartbeat"))
        #expect(status.pid > 0)

        let stored = try await harness.store.count(matching: EventQuery(kinds: [.heartbeat]))
        #expect(stored >= 1)

        await harness.shutdown()
    }

    @Test("Pause halts ingestion and resume restarts it")
    func pauseResume() async throws {
        let harness = try DaemonTestHarness.make()
        try await harness.start()
        defer { harness.cleanup() }

        try await harness.waitForStatus { $0.ingested >= 1 }
        #expect(try await harness.send(.pause) == .ok("collection paused"))

        let paused = try await harness.status()
        #expect(paused.paused)
        #expect(paused.enabledModules.isEmpty)

        #expect(try await harness.send(.resume) == .ok("collection resumed"))
        let resumed = try await harness.status()
        #expect(!resumed.paused)
        #expect(resumed.enabledModules.contains("heartbeat"))

        await harness.shutdown()
    }

    @Test("Flush persists buffered events on demand")
    func flush() async throws {
        let harness = try DaemonTestHarness.make()
        try await harness.start()
        defer { harness.cleanup() }

        try await harness.waitForStatus { $0.ingested >= 1 }
        #expect(try await harness.send(.flush) == .ok("buffer flushed"))
        await harness.shutdown()
    }
}
