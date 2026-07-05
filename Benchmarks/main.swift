import Foundation

// Lightweight, dependency-free benchmark harness for Chronicle.
// Storage, pipeline, and query benchmarks are registered here in Phases 2, 3,
// and 7. Kept as a plain executable (rather than a heavyweight benchmark
// framework) to keep the dependency graph small and CI reliable.

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

await run([])
