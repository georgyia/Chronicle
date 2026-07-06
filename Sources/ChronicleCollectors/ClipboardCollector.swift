import AppKit
import ChronicleCore
import ChronicleModels
import CryptoKit
import Foundation

/// Records clipboard copies by polling the pasteboard change count.
///
/// Privacy-sensitive and off by default. Honors concealed pasteboard types (e.g.
/// password managers), an app ignore-list, and a hash-only mode that stores a
/// digest of the content rather than the content itself.
public struct ClipboardCollector: EventCollector {
    public let descriptor = CollectorDescriptor(
        id: "clipboard",
        source: .clipboard,
        displayName: "Clipboard",
        summary: "Records when you copy text (hash-only by default).",
        enabledByDefault: false,
        isSensitive: true
    )

    private let hashOnly: Bool
    private let ignoreApps: Set<String>
    private let clock: any WallClock
    private let interval: Duration

    /// Creates a clipboard collector.
    public init(
        hashOnly: Bool,
        ignoreApps: [String],
        clock: any WallClock = SystemWallClock(),
        interval: Duration = .milliseconds(500)
    ) {
        self.hashOnly = hashOnly
        self.ignoreApps = Set(ignoreApps)
        self.clock = clock
        self.interval = interval
    }

    public func events() -> AsyncStream<RawEvent> {
        let hashOnly = hashOnly
        let ignoreApps = ignoreApps
        let clock = clock
        let interval = interval
        return AsyncStream { continuation in
            let task = Task {
                let pasteboard = NSPasteboard.general
                var lastChangeCount = pasteboard.changeCount
                while !Task.isCancelled {
                    try? await Task.sleep(for: interval)
                    if Task.isCancelled { break }
                    let changeCount = pasteboard.changeCount
                    guard changeCount != lastChangeCount else { continue }
                    lastChangeCount = changeCount
                    if let event = Self.read(pasteboard, hashOnly: hashOnly, ignoreApps: ignoreApps, clock: clock) {
                        continuation.yield(event)
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func read(
        _ pasteboard: NSPasteboard,
        hashOnly: Bool,
        ignoreApps: Set<String>,
        clock: any WallClock
    ) -> RawEvent? {
        let concealed = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
        if pasteboard.types?.contains(concealed) == true { return nil }

        let frontApp = NSWorkspace.shared.frontmostApplication
        if let bundleID = frontApp?.bundleIdentifier, ignoreApps.contains(bundleID) { return nil }

        guard let text = pasteboard.string(forType: .string), !text.isEmpty else { return nil }

        var attributes = EventAttributes()
        attributes["length"] = .int(Int64(text.count))
        if let bundleID = frontApp?.bundleIdentifier { attributes[.bundleID] = .string(bundleID) }
        if let name = frontApp?.localizedName { attributes[.appName] = .string(name) }
        attributes["content"] = clipboardContent(text, hashOnly: hashOnly)

        return RawEvent(timestamp: clock.now(), kind: .clipboardCopy, source: .clipboard, attributes: attributes)
    }

    /// Renders clipboard content for storage: a SHA-256 digest or truncated text.
    static func clipboardContent(_ text: String, hashOnly: Bool) -> JSONValue {
        guard hashOnly else { return .string(String(text.prefix(1000))) }
        let digest = SHA256.hash(data: Data(text.utf8))
        return .string("sha256:" + digest.map { String(format: "%02x", $0) }.joined())
    }
}
