import Foundation

/// Small vector helpers for embedding similarity. Pure and unit-tested.
enum VectorMath {
    /// Cosine similarity in `[-1, 1]`, or `0` for mismatched or zero vectors.
    static func cosineSimilarity(_ lhs: [Float], _ rhs: [Float]) -> Double {
        guard lhs.count == rhs.count, !lhs.isEmpty else { return 0 }
        var dot = 0.0
        var lhsMagnitude = 0.0
        var rhsMagnitude = 0.0
        for index in lhs.indices {
            let left = Double(lhs[index])
            let right = Double(rhs[index])
            dot += left * right
            lhsMagnitude += left * left
            rhsMagnitude += right * right
        }
        let denominator = (lhsMagnitude.squareRoot() * rhsMagnitude.squareRoot())
        return denominator == 0 ? 0 : dot / denominator
    }

    /// Returns the vector scaled to unit length (or unchanged if zero).
    static func normalized(_ vector: [Float]) -> [Float] {
        let magnitude = vector.reduce(0) { $0 + Double($1 * $1) }.squareRoot()
        guard magnitude > 0 else { return vector }
        return vector.map { Float(Double($0) / magnitude) }
    }
}
