/// The Chronicle daemon.
///
/// Orchestrates the collector supervisor, the ingestion pipeline, storage, config
/// hot-reload, and the IPC control server, and manages the LaunchAgent lifecycle.
/// This module contains orchestration only; behaviour lives in the domain
/// packages it wires together.
///
/// Implemented in Phase 4.
public enum ChronicleDaemon {}
