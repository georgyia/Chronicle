import ChronicleModels

/// Static metadata describing a collector module.
///
/// The daemon uses descriptors to enumerate available modules, decide which are
/// enabled, surface permission requirements, and render `chronicle module list`
/// without instantiating the collectors themselves.
public struct CollectorDescriptor: Sendable, Hashable {
    /// Stable module identifier used in configuration and the CLI, e.g. `filesystem`.
    public let id: String
    /// The source stamped onto events this collector produces.
    public let source: CollectorSource
    /// Human-readable name for display.
    public let displayName: String
    /// One-line description of what the module records.
    public let summary: String
    /// Whether the module is part of the default (core) set.
    public let enabledByDefault: Bool
    /// Whether the module is privacy-sensitive and therefore opt-in.
    public let isSensitive: Bool
    /// Whether the module requires the Accessibility permission (TCC).
    public let requiresAccessibility: Bool
    /// Whether the module requires Full Disk Access (TCC).
    public let requiresFullDiskAccess: Bool

    /// Creates a collector descriptor.
    public init(
        id: String,
        source: CollectorSource,
        displayName: String,
        summary: String,
        enabledByDefault: Bool,
        isSensitive: Bool = false,
        requiresAccessibility: Bool = false,
        requiresFullDiskAccess: Bool = false
    ) {
        self.id = id
        self.source = source
        self.displayName = displayName
        self.summary = summary
        self.enabledByDefault = enabledByDefault
        self.isSensitive = isSensitive
        self.requiresAccessibility = requiresAccessibility
        self.requiresFullDiskAccess = requiresFullDiskAccess
    }
}

/// A source of raw activity observations.
///
/// Collectors are deliberately ignorant of storage, pipeline, and CLI concerns:
/// they only describe themselves and emit an asynchronous stream of ``RawEvent``
/// values. Lifecycle and supervision are owned by the daemon.
public protocol EventCollector: Sendable {
    /// Static metadata describing this collector.
    var descriptor: CollectorDescriptor { get }

    /// Produces the stream of raw events.
    ///
    /// Implementations should begin observing lazily when the returned stream is
    /// first iterated and stop when it is cancelled or terminated.
    func events() -> AsyncStream<RawEvent>
}

/// A push-based destination for raw events (the pipeline's input boundary).
///
/// Used by producers that push rather than expose a stream — for example the
/// terminal collector, which receives shell hooks over IPC.
public protocol EventSink: Sendable {
    /// Submits a raw event for processing.
    func submit(_ event: RawEvent) async
}

/// Removes or masks sensitive content from raw events before they are persisted.
///
/// Applied to privacy-sensitive sources (shell, clipboard) so secrets never reach
/// the on-disk store.
public protocol Redactor: Sendable {
    /// Returns a redacted copy of the event.
    func redact(_ event: RawEvent) -> RawEvent
}
