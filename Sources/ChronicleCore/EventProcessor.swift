import ChronicleModels

/// A single composable stage in the ingestion pipeline.
///
/// Stages are chained (validate -> enrich -> deduplicate). Returning `nil` drops
/// the event from the pipeline (e.g. a duplicate or an invalid observation).
public protocol EventProcessor: Sendable {
    /// Transforms an event, or returns `nil` to drop it.
    /// - Parameter event: The event to process.
    /// - Returns: The transformed event, or `nil` to discard it.
    func process(_ event: Event) async throws -> Event?
}
