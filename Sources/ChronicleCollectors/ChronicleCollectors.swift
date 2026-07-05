/// The Chronicle collectors.
///
/// Each collector is an independent, self-describing ``EventCollector`` that emits
/// raw events and knows nothing about storage, the pipeline, or the CLI. A
/// registry enumerates them so the daemon can start the enabled set.
///
/// Implemented in Phase 5.
public enum ChronicleCollectors {}
