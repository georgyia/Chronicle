import ChronicleCore
import Foundation

/// Errors raised by the IPC layer.
public enum IPCError: ChronicleError {
    /// The socket path exceeds the platform limit.
    case pathTooLong(String)
    /// A low-level socket operation failed.
    case socketFailure(String)
    /// The daemon is not reachable at the given socket.
    case notReachable(String)
    /// The peer closed the connection before a full frame was read.
    case connectionClosed
    /// A frame exceeded the maximum allowed size.
    case frameTooLarge(Int)
    /// The peer speaks an incompatible protocol version.
    case versionMismatch(local: Int, remote: Int)
    /// A frame could not be encoded or decoded.
    case codec(String)

    public var code: String {
        switch self {
        case .pathTooLong: "ipc.path_too_long"
        case .socketFailure: "ipc.socket_failure"
        case .notReachable: "ipc.not_reachable"
        case .connectionClosed: "ipc.connection_closed"
        case .frameTooLarge: "ipc.frame_too_large"
        case .versionMismatch: "ipc.version_mismatch"
        case .codec: "ipc.codec"
        }
    }

    public var message: String {
        switch self {
        case let .pathTooLong(path): "Socket path too long: \(path)"
        case let .socketFailure(detail): "Socket failure: \(detail)"
        case let .notReachable(path): "Daemon not reachable at \(path)"
        case .connectionClosed: "Connection closed by peer"
        case let .frameTooLarge(size): "Frame too large: \(size) bytes"
        case let .versionMismatch(local, remote): "Protocol mismatch (local \(local), remote \(remote))"
        case let .codec(detail): "Codec error: \(detail)"
        }
    }
}
