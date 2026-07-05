/// The Chronicle ingestion pipeline.
///
/// Merges collector streams and runs each event through composable stages
/// (validate, enrich, deduplicate) before batching it to storage. Depends only on
/// `ChronicleCore` protocols.
///
/// Implemented in Phase 3.
public enum ChroniclePipeline {}
