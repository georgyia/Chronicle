import ChronicleCore
import ChronicleModels
import Foundation
import Logging

/// Supervises the set of running collectors, isolating failures and restarting
/// finished streams with exponential backoff.
///
/// Each collector runs in its own task draining its ``EventCollector/events()``
/// stream into the pipeline sink. One collector ending or misbehaving never
/// affects the others. The active set can be reconfigured live (for module
/// enable/disable) without restarting the daemon.
public actor CollectorSupervisor {
    private let sink: any EventSink
    private let logger: Logger
    private var collectors: [String: any EventCollector]
    private var tasks: [String: Task<Void, Never>] = [:]

    /// Creates a supervisor for `collectors` feeding `sink`.
    public init(
        collectors: [any EventCollector],
        sink: any EventSink,
        logger: Logger = Logger(label: "chronicle.supervisor")
    ) {
        self.sink = sink
        self.logger = logger
        self.collectors = Dictionary(collectors.map { ($0.descriptor.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// Starts every configured collector that is not already running.
    public func start() {
        for (id, collector) in collectors where tasks[id] == nil {
            tasks[id] = makeTask(for: collector)
        }
    }

    /// Cancels all running collectors.
    public func stop() {
        for task in tasks.values {
            task.cancel()
        }
        tasks.removeAll()
    }

    /// Replaces the active collector set, starting new ones and stopping removed
    /// ones without disturbing the collectors common to both sets.
    public func reconfigure(_ newCollectors: [any EventCollector]) {
        let updated = Dictionary(newCollectors.map { ($0.descriptor.id, $0) }, uniquingKeysWith: { first, _ in first })

        for (id, task) in tasks where updated[id] == nil {
            task.cancel()
            tasks[id] = nil
            logger.info("collector stopped", metadata: ["collector": .string(id)])
        }
        for (id, collector) in updated where tasks[id] == nil {
            tasks[id] = makeTask(for: collector)
            logger.info("collector started", metadata: ["collector": .string(id)])
        }
        collectors = updated
    }

    /// The ids of the currently running collectors.
    public func activeModuleIDs() -> [String] {
        tasks.keys.sorted()
    }

    private func makeTask(for collector: any EventCollector) -> Task<Void, Never> {
        let sink = sink
        let logger = logger
        let id = collector.descriptor.id
        return Task {
            var backoffSeconds = 1.0
            while !Task.isCancelled {
                for await event in collector.events() {
                    await sink.submit(event)
                    backoffSeconds = 1.0
                }
                if Task.isCancelled { break }
                logger.warning("collector stream ended; restarting", metadata: [
                    "collector": .string(id),
                    "backoff_s": .stringConvertible(backoffSeconds),
                ])
                try? await Task.sleep(for: .seconds(backoffSeconds))
                backoffSeconds = min(backoffSeconds * 2, 30)
            }
        }
    }
}
