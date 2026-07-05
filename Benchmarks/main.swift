import ChronicleCore
import ChronicleModels
import ChronicleStorage
import Foundation

// Lightweight, dependency-free benchmark harness for Chronicle.
// Kept as a plain executable (rather than a heavyweight benchmark framework) to
// keep the dependency graph small and CI reliable. Storage benchmarks land in
// Phase 2; pipeline and query benchmarks in Phases 3 and 7.

/// A single named benchmark measurement.
struct Benchmark {
    let name: String
    let body: () async throws -> Void
}

/// Runs each benchmark once and prints wall-clock timing.
func run(_ benchmarks: [Benchmark]) async {
    guard !benchmarks.isEmpty else {
        print("No benchmarks registered yet.")
        return
    }
    for benchmark in benchmarks {
        let start = DispatchTime.now()
        do {
            try await benchmark.body()
            let elapsedMs = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000
            let name = benchmark.name.padding(toLength: 40, withPad: " ", startingAt: 0)
            print("\(name) \(String(format: "%.2f", elapsedMs)) ms")
        } catch {
            print("\(benchmark.name): FAILED (\(error))")
        }
    }
}

// MARK: - Storage benchmarks

let eventCount = 50000

func makeEvents(_ count: Int) -> [Event] {
    let factory = SystemIdentifierFactory()
    let base = Date(timeIntervalSince1970: 1_700_000_000)
    return (0..<count).map { index in
        let timestamp = base.addingTimeInterval(Double(index))
        return Event(
            id: factory.makeEventID(at: timestamp),
            timestamp: timestamp,
            kind: index.isMultiple(of: 3) ? .fileModified : .appActivated,
            source: index.isMultiple(of: 3) ? .filesystem : .application,
            attributes: [.path: .string("/Users/me/Projects/module-\(index % 500)/file-\(index).swift")]
        )
    }
}

func temporaryDatabaseURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("chronicle-bench-\(UUID().uuidString)")
        .appendingPathComponent("chronicle.sqlite")
}

let benchmarks: [Benchmark] = [
    Benchmark(name: "storage.insert.\(eventCount)") {
        let url = temporaryDatabaseURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = try SQLiteEventStore.open(at: url)
        let events = makeEvents(eventCount)
        for batch in stride(from: 0, to: events.count, by: 500) {
            let slice = Array(events[batch..<min(batch + 500, events.count)])
            try await store.insert(slice)
        }
    },
    Benchmark(name: "storage.query.range") {
        let url = temporaryDatabaseURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = try SQLiteEventStore.open(at: url)
        try await store.insert(makeEvents(eventCount))
        for _ in 0..<100 {
            _ = try await store.events(matching: EventQuery(kinds: [.fileModified], limit: 100))
        }
    },
    Benchmark(name: "storage.search.fts") {
        let url = temporaryDatabaseURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = try SQLiteEventStore.open(at: url)
        try await store.insert(makeEvents(eventCount))
        for _ in 0..<100 {
            _ = try await store.search(matching: EventQuery(text: "module", limit: 50))
        }
    },
]

await run(benchmarks)
