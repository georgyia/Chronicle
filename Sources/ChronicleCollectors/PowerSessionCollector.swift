import AppKit
import ChronicleCore
import ChronicleModels
import Foundation

/// Records power and session transitions: sleep/wake, screen lock/unlock, and
/// user-session activation (login/logout).
public struct PowerSessionCollector: EventCollector {
    public let descriptor = CollectorDescriptor(
        id: "power",
        source: .power,
        displayName: "Power & Session",
        summary: "Records sleep, wake, screen lock/unlock, and login/logout.",
        enabledByDefault: true
    )

    private let clock: any WallClock

    /// Creates a power/session collector.
    public init(clock: any WallClock = SystemWallClock()) {
        self.clock = clock
    }

    public func events() -> AsyncStream<RawEvent> {
        let clock = clock
        return AsyncStream { continuation in
            let workspace = NotificationSubscription(center: NSWorkspace.shared.notificationCenter)
            let distributed = NotificationSubscription(center: DistributedNotificationCenter.default())

            let yield: @Sendable (EventKind) -> Void = { kind in
                continuation.yield(RawEvent(timestamp: clock.now(), kind: kind, source: .power))
            }

            let workspaceMapping: [(Notification.Name, EventKind)] = [
                (NSWorkspace.willSleepNotification, .powerSleep),
                (NSWorkspace.didWakeNotification, .powerWake),
                (NSWorkspace.sessionDidBecomeActiveNotification, .sessionLogin),
                (NSWorkspace.sessionDidResignActiveNotification, .sessionLogout),
            ]
            for (name, kind) in workspaceMapping {
                workspace.observe(name) { _ in yield(kind) }
            }

            distributed.observe(Notification.Name("com.apple.screenIsLocked")) { _ in yield(.screenLocked) }
            distributed.observe(Notification.Name("com.apple.screenIsUnlocked")) { _ in yield(.screenUnlocked) }

            continuation.onTermination = { _ in
                workspace.cancel()
                distributed.cancel()
            }
        }
    }
}
