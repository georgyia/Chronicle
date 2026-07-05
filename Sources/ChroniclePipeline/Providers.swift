import ChronicleModels
import Foundation

/// Supplies the session an event belongs to during enrichment.
///
/// The daemon owns session boundaries (login/logout, wake/sleep) and provides the
/// current session id; enrichment stamps it onto events.
public protocol SessionProviding: Sendable {
    /// The identifier of the currently active session.
    func currentSessionID() -> SessionID
}

/// A session provider that returns a fixed identifier for the process lifetime.
public struct FixedSessionProvider: SessionProviding {
    private let sessionID: SessionID

    /// Creates a provider bound to a single session id.
    public init(sessionID: SessionID) {
        self.sessionID = sessionID
    }

    public func currentSessionID() -> SessionID {
        sessionID
    }
}

/// The frontmost application at the time an event occurred, if known.
public struct ActivityContext: Sendable, Equatable {
    /// The application display name.
    public let appName: String
    /// The application bundle identifier.
    public let bundleID: String

    /// Creates an activity context.
    public init(appName: String, bundleID: String) {
        self.appName = appName
        self.bundleID = bundleID
    }
}

/// Supplies ambient activity context (the frontmost app) during enrichment.
///
/// The daemon updates this from the application collector; the pipeline stays free
/// of AppKit.
public protocol ActivityContextProviding: Sendable {
    /// The current frontmost application, if any is known.
    func currentContext() -> ActivityContext?
}

/// An activity-context provider that always returns `nil` (used in tests and when
/// the application collector is disabled).
public struct NullActivityContextProvider: ActivityContextProviding {
    /// Creates a null provider.
    public init() {}

    public func currentContext() -> ActivityContext? {
        nil
    }
}
