import ChronicleModels
import ChronicleTestSupport
import Foundation
import Testing
@testable import ChronicleCollectors

@Suite("FileSystem collector integration", .serialized)
struct FileSystemIntegrationTests {
    @Test("Records file creation under a watched directory", .timeLimit(.minutes(1)))
    func recordsCreation() async throws {
        let directory = try TemporaryDirectory()
        defer { directory.remove() }

        let collector = FileSystemCollector(
            watchPaths: [directory.url.path],
            excludePatterns: [],
            includeHidden: true,
            latency: 0.1
        )

        let received = ReceivedEvents()
        let consumer = Task {
            for await event in collector.events() {
                await received.append(event)
                if await received.count() >= 1 { break }
            }
        }

        // Give FSEvents a moment to begin watching before creating the file.
        // The file is created by a subprocess so it is not suppressed by the
        // collector's IgnoreSelf flag (which excludes Chronicle's own writes).
        try await Task.sleep(for: .milliseconds(300))
        let file = directory.file("note.txt")
        let touch = Process()
        touch.executableURL = URL(fileURLWithPath: "/usr/bin/touch")
        touch.arguments = [file.path]
        try touch.run()
        touch.waitUntilExit()

        try await received.waitForCount(1, timeout: .seconds(10))
        consumer.cancel()

        let events = await received.all()
        #expect(events.contains { $0.source == .filesystem })
        #expect(events.contains { $0.attributes.string(.path)?.contains("note.txt") == true })
    }
}

private actor ReceivedEvents {
    private var events: [RawEvent] = []

    func append(_ event: RawEvent) {
        events.append(event)
    }

    func count() -> Int {
        events.count
    }

    func all() -> [RawEvent] {
        events
    }

    func waitForCount(_ target: Int, timeout: Duration) async throws {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while events.count < target, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }
    }
}
