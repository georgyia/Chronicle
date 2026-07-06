import Foundation
import Testing
@testable import ChronicleIPC

@Suite("IPC round trips", .serialized)
struct IPCRoundTripTests {
    private func socketPath() -> String {
        "/tmp/chr-\(UUID().uuidString.prefix(8)).sock"
    }

    private func sampleStatus() -> DaemonStatus {
        DaemonStatus(
            pid: 1234,
            startedAtEpoch: 1_700_000_000,
            paused: false,
            totalEvents: 7,
            ingested: 10,
            persisted: 7,
            deduplicated: 2,
            rejected: 1,
            buffered: 0,
            enabledModules: ["filesystem", "application"],
            databasePath: "/tmp/chronicle.sqlite"
        )
    }

    @Test("Ping returns pong")
    func ping() throws {
        let path = socketPath()
        let server = IPCServer(path: path) { _ in .pong }
        try server.start()
        defer { server.stop() }

        let client = IPCClient(path: path)
        let response = try client.send(.ping)
        #expect(response == .pong)
    }

    @Test("Status is carried across the socket")
    func status() throws {
        let path = socketPath()
        let expected = sampleStatus()
        let server = IPCServer(path: path) { request in
            request == .status ? .status(expected) : .failure("unexpected")
        }
        try server.start()
        defer { server.stop() }

        let client = IPCClient(path: path)
        let response = try client.send(.status)
        guard case let .status(received) = response else {
            Issue.record("expected status response, got \(response)")
            return
        }
        #expect(received == expected)
    }

    @Test("Multiple sequential requests succeed")
    func sequential() throws {
        let path = socketPath()
        let server = IPCServer(path: path) { request in
            switch request {
            case .flush: .ok("flushed")
            case .pause: .ok("paused")
            default: .pong
            }
        }
        try server.start()
        defer { server.stop() }

        let client = IPCClient(path: path)
        #expect(try client.send(.flush) == .ok("flushed"))
        #expect(try client.send(.pause) == .ok("paused"))
        #expect(try client.send(.ping) == .pong)
    }

    @Test("Client reports unreachable when no server is listening")
    func unreachable() {
        let client = IPCClient(path: socketPath(), timeout: 1)
        #expect(!client.isReachable())
        #expect(throws: IPCError.self) { try client.send(.ping) }
    }
}
