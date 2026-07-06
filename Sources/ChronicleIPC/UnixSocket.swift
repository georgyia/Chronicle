import Darwin
import Foundation

/// Low-level POSIX helpers for `AF_UNIX` stream sockets and length-prefixed
/// framing. Kept internal to the IPC module; higher layers use the server/client.
enum UnixSocket {
    /// Creates an `AF_UNIX` stream socket.
    static func makeSocket() throws -> Int32 {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw IPCError.socketFailure("socket(): \(errnoString())") }
        return fd
    }

    /// Runs `body` with a populated `sockaddr` for the given path.
    static func withAddress<T>(
        path: String,
        _ body: (UnsafePointer<sockaddr>, socklen_t) throws -> T
    ) throws -> T {
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let capacity = MemoryLayout.size(ofValue: addr.sun_path)
        let bytes = Array(path.utf8)
        guard bytes.count < capacity else { throw IPCError.pathTooLong(path) }

        withUnsafeMutablePointer(to: &addr.sun_path) { rawPtr in
            rawPtr.withMemoryRebound(to: CChar.self, capacity: capacity) { dst in
                for (index, byte) in bytes.enumerated() {
                    dst[index] = CChar(bitPattern: byte)
                }
                dst[bytes.count] = 0
            }
        }
        let length = socklen_t(MemoryLayout<sockaddr_un>.size)
        return try withUnsafePointer(to: &addr) { addrPtr in
            try addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                try body(sockPtr, length)
            }
        }
    }

    /// Writes all bytes of `data` to `fd`, retrying on `EINTR`.
    static func writeAll(_ data: Data, to fd: Int32) throws {
        try data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            guard let base = raw.baseAddress else { return }
            var offset = 0
            while offset < data.count {
                let written = Darwin.write(fd, base + offset, data.count - offset)
                if written < 0 {
                    if errno == EINTR { continue }
                    throw IPCError.socketFailure("write(): \(errnoString())")
                }
                offset += written
            }
        }
    }

    /// Reads exactly `count` bytes from `fd`, retrying on `EINTR`.
    static func readExactly(_ count: Int, from fd: Int32) throws -> Data {
        guard count > 0 else { return Data() }
        var buffer = [UInt8](repeating: 0, count: count)
        try buffer.withUnsafeMutableBytes { (raw: UnsafeMutableRawBufferPointer) in
            guard let base = raw.baseAddress else { return }
            var offset = 0
            while offset < count {
                let read = Darwin.read(fd, base + offset, count - offset)
                if read == 0 { throw IPCError.connectionClosed }
                if read < 0 {
                    if errno == EINTR { continue }
                    throw IPCError.socketFailure("read(): \(errnoString())")
                }
                offset += read
            }
        }
        return Data(buffer)
    }

    /// Writes a length-prefixed frame (4-byte big-endian length + payload).
    static func writeFrame(_ payload: Data, to fd: Int32) throws {
        guard payload.count <= IPCProtocol.maxFrameSize else { throw IPCError.frameTooLarge(payload.count) }
        var length = UInt32(payload.count).bigEndian
        let header = withUnsafeBytes(of: &length) { Data($0) }
        try writeAll(header, to: fd)
        try writeAll(payload, to: fd)
    }

    /// Reads a length-prefixed frame.
    static func readFrame(from fd: Int32) throws -> Data {
        let header = try readExactly(4, from: fd)
        let length = header.withUnsafeBytes { $0.load(as: UInt32.self) }.bigEndian
        let count = Int(length)
        guard count <= IPCProtocol.maxFrameSize else { throw IPCError.frameTooLarge(count) }
        return try readExactly(count, from: fd)
    }

    /// Applies send/receive timeouts to a socket.
    static func setTimeout(_ seconds: TimeInterval, on fd: Int32) {
        var tv = timeval(tv_sec: Int(seconds), tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
    }

    /// A human-readable rendering of the current `errno`.
    static func errnoString() -> String {
        String(cString: strerror(errno))
    }
}
