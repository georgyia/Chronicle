import ChronicleModels
import CoreServices
import Foundation

/// Maps FSEvents file-level flags to a Chronicle ``EventKind``.
///
/// Pure and unit-tested. A single coalesced FSEvent may carry several flags; the
/// classifier applies a fixed priority (removed > created > renamed > modified)
/// and distinguishes deletions into the Trash.
public struct FileSystemEventClassifier: Sendable {
    /// Creates a classifier.
    public init() {}

    /// Classifies a file event, or returns `nil` for directory-only or
    /// uninteresting events.
    /// - Parameters:
    ///   - flags: The raw `FSEventStreamEventFlags` bitmask.
    ///   - path: The affected path (used to detect Trash deletions).
    public func classify(flags: UInt32, path: String) -> EventKind? {
        let isFile = flags & UInt32(kFSEventStreamEventFlagItemIsFile) != 0
        guard isFile else { return nil }

        if flags & UInt32(kFSEventStreamEventFlagItemRemoved) != 0 {
            return path.contains("/.Trash/") ? .fileTrashed : .fileDeleted
        }
        if flags & UInt32(kFSEventStreamEventFlagItemCreated) != 0 {
            return path.contains("/.Trash/") ? .fileTrashed : .fileCreated
        }
        if flags & UInt32(kFSEventStreamEventFlagItemRenamed) != 0 {
            return .fileMoved
        }
        let modified = flags & UInt32(kFSEventStreamEventFlagItemModified) != 0
        let metadataChanged = flags & UInt32(kFSEventStreamEventFlagItemInodeMetaMod) != 0
        if modified || metadataChanged {
            return .fileModified
        }
        return nil
    }
}
