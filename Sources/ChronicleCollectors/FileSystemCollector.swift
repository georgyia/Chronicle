import ChronicleCore
import ChronicleModels
import CoreServices
import Foundation

/// Records file activity (create, modify, move, rename, delete, trash) under the
/// configured watch paths using FSEvents.
///
/// The OS integration is a thin adapter; the recording decision (``PathFilter``)
/// and event classification (``FileSystemEventClassifier``) are pure and unit
/// tested. Watching a user's own files requires no special permission.
public struct FileSystemCollector: EventCollector {
    public let descriptor = CollectorDescriptor(
        id: "filesystem",
        source: .filesystem,
        displayName: "File System",
        summary: "Records files you create, edit, move, rename, and delete.",
        enabledByDefault: true
    )

    private let paths: [String]
    private let filter: PathFilter
    private let classifier = FileSystemEventClassifier()
    private let clock: any WallClock
    private let latency: TimeInterval

    /// Creates a filesystem collector.
    /// - Parameters:
    ///   - watchPaths: Directories to watch (tilde is expanded).
    ///   - excludePatterns: Noise substrings to skip.
    ///   - includeHidden: Whether to record dotfiles.
    ///   - clock: Time source for event timestamps.
    ///   - latency: FSEvents coalescing latency in seconds.
    public init(
        watchPaths: [String],
        excludePatterns: [String],
        includeHidden: Bool,
        clock: any WallClock = SystemWallClock(),
        latency: TimeInterval = 0.3
    ) {
        paths = watchPaths.map { ($0 as NSString).expandingTildeInPath }
        filter = PathFilter(excludePatterns: excludePatterns, includeHidden: includeHidden)
        self.clock = clock
        self.latency = latency
    }

    public func events() -> AsyncStream<RawEvent> {
        let paths = paths
        let filter = filter
        let classifier = classifier
        let clock = clock
        let latency = latency
        let transform: @Sendable (String, UInt32) -> RawEvent? = { path, flags in
            guard filter.shouldInclude(path) else { return nil }
            guard let kind = classifier.classify(flags: flags, path: path) else { return nil }
            return RawEvent(
                timestamp: clock.now(),
                kind: kind,
                source: .filesystem,
                attributes: [.path: .string(path)]
            )
        }
        return AsyncStream { continuation in
            let session = FSEventSession(continuation: continuation, transform: transform)
            session.start(paths: paths, latency: latency)
            continuation.onTermination = { _ in session.stop() }
        }
    }
}

/// Owns the FSEvents stream lifecycle for one subscription and yields ``RawEvent``s
/// produced by a caller-supplied transform.
final class FSEventSession: @unchecked Sendable {
    private let continuation: AsyncStream<RawEvent>.Continuation
    private let transform: @Sendable (String, UInt32) -> RawEvent?
    private let queue = DispatchQueue(label: "chronicle.fsevents")
    private var streamRef: FSEventStreamRef?

    init(
        continuation: AsyncStream<RawEvent>.Continuation,
        transform: @escaping @Sendable (String, UInt32) -> RawEvent?
    ) {
        self.continuation = continuation
        self.transform = transform
    }

    func start(paths: [String], latency: TimeInterval) {
        queue.async { [weak self] in self?.startOnQueue(paths: paths, latency: latency) }
    }

    func stop() {
        queue.async { [weak self] in self?.stopOnQueue() }
    }

    /// Called from the FSEvents callback for each reported path.
    func handle(path: String, flags: UInt32) {
        guard let event = transform(path, flags) else { return }
        continuation.yield(event)
    }

    private func startOnQueue(paths: [String], latency: TimeInterval) {
        guard !paths.isEmpty else { continuation.finish()
            return
        }
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let flags = UInt32(
            kFSEventStreamCreateFlagFileEvents
                | kFSEventStreamCreateFlagUseCFTypes
                | kFSEventStreamCreateFlagNoDefer
                | kFSEventStreamCreateFlagIgnoreSelf
        )
        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            fsEventsCallback,
            &context,
            paths as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            latency,
            flags
        ) else {
            continuation.finish()
            return
        }
        streamRef = stream
        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
    }

    private func stopOnQueue() {
        if let stream = streamRef {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            streamRef = nil
        }
        continuation.finish()
    }
}

private func fsEventsCallback(
    streamRef _: ConstFSEventStreamRef,
    clientInfo: UnsafeMutableRawPointer?,
    numEvents: Int,
    eventPaths: UnsafeMutableRawPointer,
    eventFlags: UnsafePointer<FSEventStreamEventFlags>,
    eventIds _: UnsafePointer<FSEventStreamEventId>
) {
    guard let clientInfo else { return }
    let session = Unmanaged<FSEventSession>.fromOpaque(clientInfo).takeUnretainedValue()
    let cfPaths = unsafeBitCast(eventPaths, to: CFArray.self)
    for index in 0..<numEvents {
        guard let raw = CFArrayGetValueAtIndex(cfPaths, index) else { continue }
        let path = unsafeBitCast(raw, to: CFString.self) as String
        session.handle(path: path, flags: eventFlags[index])
    }
}
