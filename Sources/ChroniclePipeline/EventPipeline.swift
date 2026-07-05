import ChronicleCore
import ChronicleModels
import Foundation
import Logging

/// The ingestion pipeline: the single entry point through which all raw events
/// flow on their way to storage.
///
/// An actor so its buffer, metrics, and deduplicator are protected without locks.
/// Each submitted ``RawEvent`` is converted to an ``Event``, run through the
/// validation and enrichment stages, deduplicated, buffered, and flushed to the
/// repository in batches (by count or on a timer). Submitting is naturally
/// back-pressured because the actor serializes work and awaits flushes.
public actor EventPipeline: EventSink {
    private let identifierFactory: any IdentifierFactory
    private let repository: any EventRepository
    private let processors: [any EventProcessor]
    private let deduplicator: Deduplicator
    private let settings: PipelineSettings
    private let logger: Logger

    private var buffer: [Event] = []
    private var metrics = PipelineMetrics()
    private var flushTask: Task<Void, Never>?
    private var isRunning = false

    /// Creates a pipeline.
    /// - Parameters:
    ///   - repository: The destination for persisted events.
    ///   - identifierFactory: Mints event identifiers from timestamps.
    ///   - processors: Ordered stages (typically validation then enrichment).
    ///   - settings: Batch, flush, and deduplication tuning.
    ///   - logger: Structured logger.
    public init(
        repository: any EventRepository,
        identifierFactory: any IdentifierFactory,
        processors: [any EventProcessor],
        settings: PipelineSettings = PipelineSettings(),
        logger: Logger = Logger(label: "chronicle.pipeline")
    ) {
        self.repository = repository
        self.identifierFactory = identifierFactory
        self.processors = processors
        self.settings = settings
        self.logger = logger
        deduplicator = Deduplicator(window: settings.dedupeWindow, capacity: settings.dedupeCacheSize)
    }

    /// Starts the pipeline and its periodic flush timer.
    public func start() {
        guard !isRunning else { return }
        isRunning = true
        scheduleFlushLoop()
    }

    /// Submits a raw event for processing. Silently ignored before ``start()``.
    public func submit(_ event: RawEvent) async {
        guard isRunning else { return }
        metrics.ingested += 1

        var current = Event(
            id: identifierFactory.makeEventID(at: event.timestamp),
            timestamp: event.timestamp,
            kind: event.kind,
            source: event.source,
            attributes: event.attributes
        )

        for processor in processors {
            do {
                guard let next = try await processor.process(current) else {
                    metrics.rejected += 1
                    return
                }
                current = next
            } catch {
                metrics.failed += 1
                logger.warning("pipeline stage failed", metadata: ["error": .string("\(error)")])
                return
            }
        }

        guard let admitted = deduplicator.admit(current) else {
            metrics.deduplicated += 1
            return
        }

        buffer.append(admitted)
        metrics.buffered = buffer.count
        if buffer.count >= settings.batchSize {
            await flush()
        }
    }

    /// Flushes buffered events to storage now.
    public func flush() async {
        guard !buffer.isEmpty else { return }
        let batch = buffer
        buffer.removeAll(keepingCapacity: true)
        metrics.buffered = 0
        do {
            let inserted = try await repository.insert(batch)
            metrics.persisted += inserted
        } catch {
            metrics.failed += batch.count
            logger.error("failed to persist batch", metadata: [
                "count": .stringConvertible(batch.count),
                "error": .string("\(error)"),
            ])
        }
    }

    /// Stops the flush timer and flushes any remaining events (graceful shutdown).
    public func shutdown() async {
        isRunning = false
        flushTask?.cancel()
        flushTask = nil
        await flush()
    }

    /// A snapshot of the current pipeline counters.
    public func snapshot() -> PipelineMetrics {
        var current = metrics
        current.buffered = buffer.count
        return current
    }

    private func scheduleFlushLoop() {
        flushTask = Task { [weak self, interval = settings.flushInterval] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard let self else { return }
                await flush()
            }
        }
    }
}
