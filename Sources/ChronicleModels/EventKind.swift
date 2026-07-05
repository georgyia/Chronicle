import Foundation

/// The category of a recorded event, expressed as a dot-namespaced identifier
/// such as `file.created` or `app.launched`.
///
/// Modelled as a `RawRepresentable` over `String` rather than a closed `enum` so
/// that importing data produced by a newer Chronicle version (with kinds this
/// build does not yet know about) degrades gracefully instead of failing to
/// decode. Known kinds are exposed as static constants.
public struct EventKind: Sendable, Hashable, RawRepresentable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// The namespace portion of the kind (before the first dot), e.g. `file`.
    public var namespace: String {
        guard let dot = rawValue.firstIndex(of: ".") else { return rawValue }
        return String(rawValue[rawValue.startIndex..<dot])
    }

    /// The action portion of the kind (after the first dot), e.g. `created`.
    public var action: String {
        guard let dot = rawValue.firstIndex(of: ".") else { return "" }
        return String(rawValue[rawValue.index(after: dot)...])
    }
}

extension EventKind: CustomStringConvertible {
    public var description: String {
        rawValue
    }
}

extension EventKind: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        rawValue = value
    }
}

extension EventKind: Codable {
    public init(from decoder: any Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public extension EventKind {
    /// A file was created.
    static let fileCreated: EventKind = "file.created"
    /// A file's contents changed.
    static let fileModified: EventKind = "file.modified"
    /// A file was moved to a different directory.
    static let fileMoved: EventKind = "file.moved"
    /// A file was renamed within its directory.
    static let fileRenamed: EventKind = "file.renamed"
    /// A file was deleted.
    static let fileDeleted: EventKind = "file.deleted"
    /// A file was moved to the Trash.
    static let fileTrashed: EventKind = "file.trashed"
    /// A file was downloaded from the network.
    static let fileDownloaded: EventKind = "file.downloaded"

    /// An application was launched.
    static let appLaunched: EventKind = "app.launched"
    /// An application quit.
    static let appTerminated: EventKind = "app.terminated"
    /// An application became frontmost.
    static let appActivated: EventKind = "app.activated"

    /// The frontmost window's title changed.
    static let windowTitleChanged: EventKind = "window.titleChanged"

    /// The system went to sleep.
    static let powerSleep: EventKind = "power.sleep"
    /// The system woke from sleep.
    static let powerWake: EventKind = "power.wake"
    /// The screen was locked.
    static let screenLocked: EventKind = "power.screenLocked"
    /// The screen was unlocked.
    static let screenUnlocked: EventKind = "power.screenUnlocked"

    /// The user session began.
    static let sessionLogin: EventKind = "session.login"
    /// The user session ended.
    static let sessionLogout: EventKind = "session.logout"

    /// A shell command was executed (optional module).
    static let shellCommand: EventKind = "shell.command"
    /// A web page was visited (optional module).
    static let browserVisit: EventKind = "browser.visit"
    /// Content was copied to the clipboard (optional module).
    static let clipboardCopy: EventKind = "clipboard.copy"
    /// A git commit was made (optional module).
    static let gitCommit: EventKind = "git.commit"

    /// The set of kinds enabled by Chronicle's default (core) collectors.
    static let coreKinds: Set<EventKind> = [
        .fileCreated, .fileModified, .fileMoved, .fileRenamed, .fileDeleted,
        .fileTrashed, .fileDownloaded,
        .appLaunched, .appTerminated, .appActivated,
        .windowTitleChanged,
        .powerSleep, .powerWake, .screenLocked, .screenUnlocked,
        .sessionLogin, .sessionLogout,
    ]
}
