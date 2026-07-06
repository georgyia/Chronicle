import Foundation
import NaturalLanguage

/// Produces embedding vectors for text.
public protocol EmbeddingProvider: Sendable {
    /// A stable model identifier stored alongside vectors.
    var model: String { get }
    /// Embeds text, or returns `nil` if it cannot be embedded.
    func embed(_ text: String) -> [Float]?
}

/// A deterministic, dependency-free embedding via feature hashing.
///
/// Serves as an offline fallback (and a stable test double) when a neural
/// embedding model is unavailable. Quality is modest but it is fully local.
public struct HashingEmbeddingProvider: EmbeddingProvider {
    public let model: String
    private let dimensions: Int

    /// Creates a hashing embedding provider.
    public init(dimensions: Int = 128) {
        self.dimensions = dimensions
        model = "hashing-\(dimensions)"
    }

    public func embed(_ text: String) -> [Float]? {
        let tokens = text.lowercased().split { !$0.isLetter && !$0.isNumber }
        guard !tokens.isEmpty else { return nil }
        var vector = [Float](repeating: 0, count: dimensions)
        for token in tokens {
            let bucket = abs(stableHash(String(token))) % dimensions
            vector[bucket] += 1
        }
        return VectorMath.normalized(vector)
    }

    private func stableHash(_ string: String) -> Int {
        var hash = 5381
        for byte in string.utf8 {
            hash = (hash &* 33) &+ Int(byte)
        }
        return hash
    }
}

/// A neural embedding provider backed by Apple's `NLEmbedding` (offline).
///
/// `@unchecked Sendable` is justified: `NLEmbedding` is an immutable, read-only
/// model that is only ever queried (never mutated), so sharing it across
/// concurrency domains is safe.
public struct NLEmbeddingProvider: EmbeddingProvider, @unchecked Sendable {
    public let model = "nl-english"
    private let embedding: NLEmbedding?

    /// Creates a provider using the English word embedding, if available.
    public init() {
        embedding = NLEmbedding.wordEmbedding(for: .english)
    }

    /// Whether the underlying embedding model is available on this system.
    public var isAvailable: Bool {
        embedding != nil
    }

    public func embed(_ text: String) -> [Float]? {
        guard let embedding else { return nil }
        let tokens = text.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
        guard !tokens.isEmpty else { return nil }

        var sum = [Double](repeating: 0, count: embedding.dimension)
        var counted = 0
        for token in tokens {
            guard let vector = embedding.vector(for: token) else { continue }
            for index in vector.indices {
                sum[index] += vector[index]
            }
            counted += 1
        }
        guard counted > 0 else { return nil }
        return VectorMath.normalized(sum.map { Float($0 / Double(counted)) })
    }
}

/// Selects the best available local embedding provider.
public enum EmbeddingProviders {
    /// Returns the neural provider when available, else the hashing fallback.
    public static func makeDefault() -> any EmbeddingProvider {
        let neural = NLEmbeddingProvider()
        return neural.isAvailable ? neural : HashingEmbeddingProvider()
    }
}
