import ChronicleCore
import ChronicleModels
import Foundation

/// A trivial collector that emits a periodic heartbeat event.
///
/// Used to prove the end-to-end ingestion path (collector -> pipeline -> storage)
/// and to provide a liveness signal. It is not part of the default module set.
public struct HeartbeatCollector: EventCollector {
    public let descriptor = CollectorDescriptor(
        id: "heartbeat",
        source: .heartbeat,
        displayName: "Heartbeat",
        summary: "Emits a periodic liveness event proving the ingestion path.",
        enabledByDefault: false
    )

    private let interval: Duration
    private let clock: any WallClock

    /// Creates a heartbeat collector.
    /// - Parameters:
    ///   - interval: Delay between heartbeats.
    ///   - clock: Time source for the event timestamp.
    public init(interval: Duration = .seconds(30), clock: any WallClock = SystemWallClock()) {
        self.interval = interval
        self.clock = clock
    }

    public func events() -> AsyncStream<RawEvent> {
        let interval = interval
        let clock = clock
        return AsyncStream { continuation in
            let task = Task {
                var sequence = 0
                while !Task.isCancelled {
                    try? await Task.sleep(for: interval)
                    if Task.isCancelled { break }
                    sequence += 1
                    continuation.yield(RawEvent(
                        timestamp: clock.now(),
                        kind: .heartbeat,
                        source: .heartbeat,
                        attributes: ["sequence": .int(Int64(sequence))]
                    ))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
