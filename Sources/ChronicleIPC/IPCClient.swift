import Darwin
import Foundation

/// A synchronous client for the daemon's control socket.
///
/// Each call opens a fresh connection, sends one request, and reads one response.
/// Calls are blocking; the CLI invokes them from a background task.
public struct IPCClient: Sendable {
    private let path: String
    private let timeout: TimeInterval

    /// Creates a client for the socket at `path`.
    public init(path: String, timeout: TimeInterval = 5) {
        self.path = path
        self.timeout = timeout
    }

    /// Sends a request and returns the daemon's response.
    /// - Throws: ``IPCError/notReachable(_:)`` if the daemon is not running.
    public func send(_ request: IPCRequest) throws -> IPCResponse {
        let fd = try UnixSocket.makeSocket()
        defer { close(fd) }
        UnixSocket.setTimeout(timeout, on: fd)

        try connect(fd)

        let envelope = RequestEnvelope(protocolVersion: IPCProtocol.version, request: request)
        let requestFrame = try encode(envelope)
        try UnixSocket.writeFrame(requestFrame, to: fd)

        let responseFrame = try UnixSocket.readFrame(from: fd)
        let responseEnvelope = try decode(responseFrame)
        guard responseEnvelope.protocolVersion == IPCProtocol.version else {
            throw IPCError.versionMismatch(local: IPCProtocol.version, remote: responseEnvelope.protocolVersion)
        }
        return responseEnvelope.response
    }

    /// Whether the daemon responds to a `ping`.
    public func isReachable() -> Bool {
        if case .pong = try? send(.ping) { return true }
        return false
    }

    private func connect(_ fd: Int32) throws {
        var connectResult: Int32 = -1
        try UnixSocket.withAddress(path: path) { addr, length in
            connectResult = Darwin.connect(fd, addr, length)
        }
        guard connectResult == 0 else { throw IPCError.notReachable(path) }
    }

    private func encode(_ envelope: RequestEnvelope) throws -> Data {
        do {
            return try JSONEncoder().encode(envelope)
        } catch {
            throw IPCError.codec(error.localizedDescription)
        }
    }

    private func decode(_ frame: Data) throws -> ResponseEnvelope {
        do {
            return try JSONDecoder().decode(ResponseEnvelope.self, from: frame)
        } catch {
            throw IPCError.codec(error.localizedDescription)
        }
    }
}
