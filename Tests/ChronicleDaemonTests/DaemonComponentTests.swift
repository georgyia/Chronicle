import ChronicleCore
import ChronicleModels
import ChronicleTestSupport
import Foundation
import Testing
@testable import ChronicleDaemon

@Suite("Collector supervisor")
struct CollectorSupervisorTests {
    @Test("Drains collector events into the sink")
    func drains() async throws {
        let sink = RecordingSink()
        let collector = ScriptedCollector(id: "test", events: [
            EventFactory.rawEvent(attributes: [.path: "/tmp/a"]),
            EventFactory.rawEvent(attributes: [.path: "/tmp/b"]),
        ])
        let supervisor = CollectorSupervisor(collectors: [collector], sink: sink)
        await supervisor.start()
        try await sink.waitForCount(2)
        await supervisor.stop()
        #expect(await sink.count() == 2)
    }

    @Test("Reconfigure stops removed and starts added collectors")
    func reconfigure() async {
        let sink = RecordingSink()
        let first = ScriptedCollector(id: "first", events: [EventFactory.rawEvent()])
        let supervisor = CollectorSupervisor(collectors: [first], sink: sink)
        await supervisor.start()
        #expect(await supervisor.activeModuleIDs() == ["first"])

        let second = ScriptedCollector(id: "second", events: [EventFactory.rawEvent()])
        await supervisor.reconfigure([second])
        #expect(await supervisor.activeModuleIDs() == ["second"])
        await supervisor.stop()
    }
}

@Suite("Heartbeat collector")
struct HeartbeatCollectorTests {
    @Test("Emits heartbeat events")
    func emits() async {
        let collector = HeartbeatCollector(interval: .milliseconds(10))
        var received = 0
        for await event in collector.events() {
            #expect(event.kind == .heartbeat)
            received += 1
            if received == 2 { break }
        }
        #expect(received == 2)
    }
}

@Suite("LaunchAgent plist")
struct LaunchAgentControllerTests {
    @Test("Generates a valid plist referencing the executable")
    func plist() {
        let controller = LaunchAgentController(
            label: "dev.chronicle.agent",
            plistURL: URL(fileURLWithPath: "/tmp/dev.chronicle.agent.plist"),
            executablePath: "/usr/local/bin/chronicled",
            logPath: "/tmp/chronicle.log"
        )
        let plist = controller.plistContents()
        #expect(plist.contains("<string>dev.chronicle.agent</string>"))
        #expect(plist.contains("<string>/usr/local/bin/chronicled</string>"))
        #expect(plist.contains("<string>run</string>"))
        #expect(plist.contains("<key>RunAtLoad</key>"))
    }

    @Test("Writes and removes the plist")
    func writeRemove() throws {
        try withTemporaryDirectorySync { directory in
            let url = directory.appendingPathComponent("agent.plist")
            let controller = LaunchAgentController(
                label: "dev.chronicle.agent",
                plistURL: url,
                executablePath: "/usr/local/bin/chronicled",
                logPath: "/tmp/chronicle.log"
            )
            try controller.writePlist()
            #expect(FileManager.default.fileExists(atPath: url.path))
            try controller.removePlist()
            #expect(!FileManager.default.fileExists(atPath: url.path))
        }
    }
}

// MARK: - Test doubles

private actor RecordingSink: EventSink {
    private var events: [RawEvent] = []

    func submit(_ event: RawEvent) async {
        events.append(event)
    }

    func count() -> Int {
        events.count
    }

    func waitForCount(_ target: Int, timeout: Duration = .seconds(2)) async throws {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while events.count < target, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(5))
        }
    }
}

private struct ScriptedCollector: EventCollector {
    let descriptor: CollectorDescriptor
    let scriptedEvents: [RawEvent]

    init(id: String, events: [RawEvent]) {
        descriptor = CollectorDescriptor(
            id: id,
            source: .heartbeat,
            displayName: id,
            summary: "scripted",
            enabledByDefault: false
        )
        scriptedEvents = events
    }

    func events() -> AsyncStream<RawEvent> {
        let events = scriptedEvents
        return AsyncStream { continuation in
            for event in events {
                continuation.yield(event)
            }
            // Keep the stream open so the supervisor does not busy-restart.
            let task = Task {
                try? await Task.sleep(for: .seconds(3600))
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

func withTemporaryDirectorySync(_ body: (URL) throws -> Void) throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: url) }
    try body(url)
}
