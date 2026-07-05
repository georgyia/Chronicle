import ChronicleCore
import ChronicleModels
import Foundation

/// Rejects malformed observations before they are enriched or persisted.
///
/// Drops events whose timestamp is implausible (far future, or before Chronicle
/// could plausibly exist) or that are missing attributes required by their kind.
public struct ValidationProcessor: EventProcessor {
    private let clock: any WallClock
    private let futureTolerance: TimeInterval
    private static let earliestPlausible = Date(timeIntervalSince1970: 946_684_800) // 2000-01-01

    /// Creates a validator.
    /// - Parameters:
    ///   - clock: The clock used to bound future timestamps.
    ///   - futureTolerance: How far ahead of now a timestamp may be (default 1 day).
    public init(clock: any WallClock, futureTolerance: TimeInterval = 86400) {
        self.clock = clock
        self.futureTolerance = futureTolerance
    }

    public func process(_ event: Event) async throws -> Event? {
        guard event.timestamp >= Self.earliestPlausible else { return nil }
        guard event.timestamp <= clock.now().addingTimeInterval(futureTolerance) else { return nil }
        guard hasRequiredAttributes(event) else { return nil }
        return event
    }

    private func hasRequiredAttributes(_ event: Event) -> Bool {
        switch event.kind.namespace {
        case "file":
            event.attributes.string(.path)?.isEmpty == false
        case "app":
            event.attributes.string(.bundleID) != nil || event.attributes.string(.appName) != nil
        case "shell":
            event.attributes.string(.command)?.isEmpty == false
        case "browser":
            event.attributes.string(.url) != nil || event.attributes.string(.title) != nil
        default:
            true
        }
    }
}
