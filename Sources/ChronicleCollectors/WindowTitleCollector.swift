import AppKit
import ApplicationServices
import ChronicleCore
import ChronicleModels
import Foundation

/// Suppresses repeat title readings, emitting only on change.
struct WindowTitleTracker {
    private var last: String?

    /// Whether the (app, title) pair differs from the previous observation.
    mutating func changed(app: String, title: String) -> Bool {
        let key = "\(app)\u{01}\(title)"
        guard key != last else { return false }
        last = key
        return true
    }
}

/// Records changes to the frontmost window's title via the Accessibility API.
///
/// Requires the Accessibility permission. When it is not granted, the collector
/// degrades gracefully: it produces an open, event-free stream rather than
/// failing, so the supervisor does not restart-loop.
public struct WindowTitleCollector: EventCollector {
    public let descriptor = CollectorDescriptor(
        id: "window",
        source: .window,
        displayName: "Window Titles",
        summary: "Records the title of the window you are focused on.",
        enabledByDefault: true,
        requiresAccessibility: true
    )

    private let clock: any WallClock
    private let interval: Duration

    /// Creates a window title collector.
    public init(clock: any WallClock = SystemWallClock(), interval: Duration = .seconds(1)) {
        self.clock = clock
        self.interval = interval
    }

    public func events() -> AsyncStream<RawEvent> {
        let clock = clock
        let interval = interval
        return AsyncStream { continuation in
            guard AXIsProcessTrusted() else {
                // Degrade gracefully: keep the stream open but emit nothing.
                continuation.onTermination = { _ in }
                return
            }
            let task = Task {
                var tracker = WindowTitleTracker()
                while !Task.isCancelled {
                    try? await Task.sleep(for: interval)
                    if Task.isCancelled { break }
                    guard
                        let window = AccessibilityReader.frontmostWindow(),
                        tracker.changed(app: window.app, title: window.title)
                    else { continue }
                    continuation.yield(RawEvent(
                        timestamp: clock.now(),
                        kind: .windowTitleChanged,
                        source: .window,
                        attributes: [.appName: .string(window.app), .title: .string(window.title)]
                    ))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

/// Thin Accessibility-API adapter for reading the frontmost window title.
enum AccessibilityReader {
    /// The frontmost application's name and focused window title, if readable.
    static func frontmostWindow() -> (app: String, title: String)? {
        guard let application = NSWorkspace.shared.frontmostApplication else { return nil }
        let axApp = AXUIElementCreateApplication(application.processIdentifier)
        guard let window = element(of: axApp, attribute: kAXFocusedWindowAttribute) else { return nil }
        guard let title = string(of: window, attribute: kAXTitleAttribute), !title.isEmpty else { return nil }
        let name = application.localizedName ?? application.bundleIdentifier ?? "Unknown"
        return (name, title)
    }

    private static func element(of element: AXUIElement, attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeDowncast(value as AnyObject, to: AXUIElement.self)
    }

    private static func string(of element: AXUIElement, attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }
}
