import ChronicleCore
import ChronicleModels
import CoreServices
import Foundation

/// Records completed downloads by watching a downloads directory and reading the
/// origin URL from each new file's `kMDItemWhereFroms` metadata.
///
/// Only files that actually carry download-origin metadata are recorded, which
/// naturally distinguishes downloads from other file activity in the folder.
public struct DownloadsCollector: EventCollector {
    public let descriptor = CollectorDescriptor(
        id: "downloads",
        source: .downloads,
        displayName: "Downloads",
        summary: "Records files downloaded from the internet, with their origin URL.",
        enabledByDefault: true
    )

    private let directory: String
    private let clock: any WallClock

    /// Creates a downloads collector.
    /// - Parameters:
    ///   - directory: The directory to watch (defaults to `~/Downloads`).
    ///   - clock: Time source for event timestamps.
    public init(directory: String = "~/Downloads", clock: any WallClock = SystemWallClock()) {
        self.directory = (directory as NSString).expandingTildeInPath
        self.clock = clock
    }

    public func events() -> AsyncStream<RawEvent> {
        let directory = directory
        let clock = clock
        let transform: @Sendable (String, UInt32) -> RawEvent? = { path, flags in
            let isRemoval = flags & UInt32(kFSEventStreamEventFlagItemRemoved) != 0
            guard !isRemoval else { return nil }
            guard let origins = WhereFroms.origins(ofFileAt: path) else { return nil }

            var attributes: EventAttributes = [.path: .string(path)]
            if let url = origins.first { attributes[.url] = .string(url) }
            return RawEvent(timestamp: clock.now(), kind: .fileDownloaded, source: .downloads, attributes: attributes)
        }
        return AsyncStream { continuation in
            let session = FSEventSession(continuation: continuation, transform: transform)
            session.start(paths: [directory], latency: 0.5)
            continuation.onTermination = { _ in session.stop() }
        }
    }
}
