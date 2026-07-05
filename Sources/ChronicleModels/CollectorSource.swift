import Foundation

/// Identifies the collector module that produced an event, e.g. `filesystem`.
///
/// Stored alongside every event so queries can attribute activity to a source and
/// so a single misbehaving collector's data can be isolated or pruned.
public struct CollectorSource: Sendable, Hashable, RawRepresentable, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String {
        rawValue
    }

    /// The filesystem collector.
    public static let filesystem = CollectorSource(rawValue: "filesystem")
    /// The application lifecycle collector.
    public static let application = CollectorSource(rawValue: "application")
    /// The window title collector.
    public static let window = CollectorSource(rawValue: "window")
    /// The power and session collector.
    public static let power = CollectorSource(rawValue: "power")
    /// The downloads collector.
    public static let downloads = CollectorSource(rawValue: "downloads")
    /// The terminal / shell collector.
    public static let terminal = CollectorSource(rawValue: "terminal")
    /// The browser history collector.
    public static let browser = CollectorSource(rawValue: "browser")
    /// The clipboard collector.
    public static let clipboard = CollectorSource(rawValue: "clipboard")
    /// The git collector.
    public static let git = CollectorSource(rawValue: "git")
    /// A synthetic source used by the daemon heartbeat.
    public static let heartbeat = CollectorSource(rawValue: "heartbeat")
}

extension CollectorSource: Codable {
    public init(from decoder: any Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
