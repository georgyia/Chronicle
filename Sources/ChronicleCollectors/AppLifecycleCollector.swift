import AppKit
import ChronicleCore
import ChronicleModels
import Foundation

/// Records application launch, quit, and activation via NSWorkspace.
public struct AppLifecycleCollector: EventCollector {
    public let descriptor = CollectorDescriptor(
        id: "application",
        source: .application,
        displayName: "Applications",
        summary: "Records apps launching, quitting, and coming to the foreground.",
        enabledByDefault: true
    )

    private let clock: any WallClock

    /// Creates an application lifecycle collector.
    public init(clock: any WallClock = SystemWallClock()) {
        self.clock = clock
    }

    public func events() -> AsyncStream<RawEvent> {
        let clock = clock
        return AsyncStream { continuation in
            let subscription = NotificationSubscription(center: NSWorkspace.shared.notificationCenter)
            let mapping: [(Notification.Name, EventKind)] = [
                (NSWorkspace.didLaunchApplicationNotification, .appLaunched),
                (NSWorkspace.didTerminateApplicationNotification, .appTerminated),
                (NSWorkspace.didActivateApplicationNotification, .appActivated),
            ]
            for (name, kind) in mapping {
                subscription.observe(name) { notification in
                    guard let event = Self.makeEvent(notification, kind: kind, clock: clock) else { return }
                    continuation.yield(event)
                }
            }
            continuation.onTermination = { _ in subscription.cancel() }
        }
    }

    private static func makeEvent(_ notification: Notification, kind: EventKind, clock: any WallClock) -> RawEvent? {
        guard
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        else { return nil }

        var attributes = EventAttributes()
        attributes[.appName] = app.localizedName.map(JSONValue.string)
        attributes[.bundleID] = app.bundleIdentifier.map(JSONValue.string)
        attributes[.pid] = .int(Int64(app.processIdentifier))
        return RawEvent(timestamp: clock.now(), kind: kind, source: .application, attributes: attributes)
    }
}
