import Darwin
import Foundation

/// A single-request-per-connection Unix domain socket server for daemon control.
///
/// The accept loop runs on a dedicated thread; each connection reads one framed
/// request, invokes the async handler, and writes one framed response. The socket
/// file is created `0600`, and connections are already restricted to the owner by
/// filesystem permissions on the data directory.
public final class IPCServer: @unchecked Sendable {
    /// Handles a request and produces a response.
    public typealias Handler = @Sendable (IPCRequest) async -> IPCResponse

    private let path: String
    private let handler: Handler
    private let stateLock = NSLock()
    private var listenFD: Int32 = -1
    private var isRunning = false
    private var acceptThread: Thread?

    /// Creates a server bound to `path` that dispatches to `handler`.
    public init(path: String, handler: @escaping Handler) {
        self.path = path
        self.handler = handler
    }

    deinit {
        stop()
    }

    /// Binds the socket and starts accepting connections.
    public func start() throws {
        let fd = try UnixSocket.makeSocket()
        unlink(path)

        try UnixSocket.withAddress(path: path) { addr, length in
            guard bind(fd, addr, length) == 0 else {
                close(fd)
                throw IPCError.socketFailure("bind(): \(UnixSocket.errnoString())")
            }
        }
        chmod(path, 0o600)

        guard listen(fd, 16) == 0 else {
            close(fd)
            throw IPCError.socketFailure("listen(): \(UnixSocket.errnoString())")
        }

        stateLock.lock()
        listenFD = fd
        isRunning = true
        stateLock.unlock()

        let thread = Thread { [weak self] in self?.acceptLoop() }
        thread.name = "chronicle.ipc.accept"
        acceptThread = thread
        thread.start()
    }

    /// Stops accepting connections and removes the socket file.
    public func stop() {
        stateLock.lock()
        let wasRunning = isRunning
        isRunning = false
        let fd = listenFD
        listenFD = -1
        stateLock.unlock()

        guard wasRunning else { return }
        if fd >= 0 { close(fd) }
        unlink(path)
    }

    private func running() -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return isRunning
    }

    private func acceptLoop() {
        while running() {
            let clientFD = accept(listenFD, nil, nil)
            if clientFD < 0 {
                if running(), errno == EINTR { continue }
                break
            }
            handleConnection(clientFD)
        }
    }

    private func handleConnection(_ fd: Int32) {
        defer { close(fd) }
        UnixSocket.setTimeout(5, on: fd)
        do {
            let requestFrame = try UnixSocket.readFrame(from: fd)
            let envelope = try JSONDecoder().decode(RequestEnvelope.self, from: requestFrame)
            let response = resolve(envelope)
            let responseEnvelope = ResponseEnvelope(protocolVersion: IPCProtocol.version, response: response)
            let responseFrame = try JSONEncoder().encode(responseEnvelope)
            try UnixSocket.writeFrame(responseFrame, to: fd)
        } catch {
            // A malformed or dropped connection must not take down the server.
        }
    }

    private func resolve(_ envelope: RequestEnvelope) -> IPCResponse {
        guard envelope.protocolVersion == IPCProtocol.version else {
            return .failure(
                "protocol version mismatch: server \(IPCProtocol.version), client \(envelope.protocolVersion)"
            )
        }
        return runBlocking { [handler] in await handler(envelope.request) }
    }

    private func runBlocking(_ operation: @escaping @Sendable () async -> IPCResponse) -> IPCResponse {
        let semaphore = DispatchSemaphore(value: 0)
        let box = ResponseBox()
        Task {
            await box.set(operation())
            semaphore.signal()
        }
        semaphore.wait()
        return box.take()
    }
}

/// A one-shot, lock-guarded container for bridging an async result to a thread.
private final class ResponseBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value: IPCResponse?

    func set(_ response: IPCResponse) {
        lock.lock()
        value = response
        lock.unlock()
    }

    func take() -> IPCResponse {
        lock.lock()
        defer { lock.unlock() }
        guard let value else {
            preconditionFailure("ResponseBox read before it was set")
        }
        return value
    }
}
