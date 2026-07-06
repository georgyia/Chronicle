import Foundation

/// The versioned control protocol spoken between the CLI and the daemon.
public enum IPCProtocol {
    /// The protocol version implemented by this build.
    public static let version = 1
    /// Maximum accepted frame size (guards against malformed length prefixes).
    public static let maxFrameSize = 8 * 1024 * 1024
}

/// A control command sent from the CLI to the daemon.
public enum IPCRequest: String, Codable, Sendable {
    /// Liveness probe.
    case ping
    /// Request the current daemon status.
    case status
    /// Reload configuration from disk.
    case reload
    /// Pause event collection.
    case pause
    /// Resume event collection.
    case resume
    /// Flush buffered events to storage now.
    case flush
    /// Ask the daemon to shut down gracefully.
    case shutdown
}

/// The daemon's reply to an ``IPCRequest``.
public enum IPCResponse: Codable, Sendable, Equatable {
    /// Reply to `ping`.
    case pong
    /// Reply to `status`.
    case status(DaemonStatus)
    /// A successful command with an optional human-readable message.
    case ok(String?)
    /// A failed command with an explanation.
    case failure(String)
}

/// A snapshot of the daemon's runtime state, returned by `status`.
public struct DaemonStatus: Codable, Sendable, Equatable {
    /// The daemon process identifier.
    public var pid: Int32
    /// When the daemon started (Unix epoch seconds).
    public var startedAtEpoch: Double
    /// The protocol version the daemon speaks.
    public var protocolVersion: Int
    /// Whether collection is currently paused.
    public var paused: Bool
    /// Total events stored.
    public var totalEvents: Int
    /// Events ingested since start.
    public var ingested: Int
    /// Events persisted since start.
    public var persisted: Int
    /// Events deduplicated since start.
    public var deduplicated: Int
    /// Events rejected by validation since start.
    public var rejected: Int
    /// Events currently buffered.
    public var buffered: Int
    /// Enabled collector module ids.
    public var enabledModules: [String]
    /// The database path in use.
    public var databasePath: String

    /// Creates a daemon status snapshot.
    public init(
        pid: Int32,
        startedAtEpoch: Double,
        protocolVersion: Int = IPCProtocol.version,
        paused: Bool,
        totalEvents: Int,
        ingested: Int,
        persisted: Int,
        deduplicated: Int,
        rejected: Int,
        buffered: Int,
        enabledModules: [String],
        databasePath: String
    ) {
        self.pid = pid
        self.startedAtEpoch = startedAtEpoch
        self.protocolVersion = protocolVersion
        self.paused = paused
        self.totalEvents = totalEvents
        self.ingested = ingested
        self.persisted = persisted
        self.deduplicated = deduplicated
        self.rejected = rejected
        self.buffered = buffered
        self.enabledModules = enabledModules
        self.databasePath = databasePath
    }
}

/// Envelope wrapping a request with the sender's protocol version.
struct RequestEnvelope: Codable {
    var protocolVersion: Int
    var request: IPCRequest
}

/// Envelope wrapping a response with the responder's protocol version.
struct ResponseEnvelope: Codable {
    var protocolVersion: Int
    var response: IPCResponse
}
