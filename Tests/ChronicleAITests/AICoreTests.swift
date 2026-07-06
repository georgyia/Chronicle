import Foundation
import Testing
@testable import ChronicleAI

@Suite("Vector math")
struct VectorMathTests {
    @Test("Identical vectors have similarity 1")
    func identical() {
        #expect(abs(VectorMath.cosineSimilarity([1, 0, 1], [1, 0, 1]) - 1) < 1e-9)
    }

    @Test("Orthogonal vectors have similarity 0")
    func orthogonal() {
        #expect(VectorMath.cosineSimilarity([1, 0], [0, 1]) == 0)
    }

    @Test("Mismatched lengths are safe")
    func mismatched() {
        #expect(VectorMath.cosineSimilarity([1, 2], [1, 2, 3]) == 0)
    }

    @Test("Normalization yields unit length")
    func normalize() {
        let magnitude = VectorMath.normalized([3, 4]).reduce(0) { $0 + Double($1 * $1) }.squareRoot()
        #expect(abs(magnitude - 1) < 1e-6)
    }
}

@Suite("Redaction gate")
struct RedactionTests {
    private let redactor = TextRedactor()

    @Test("Redacts API keys, tokens, and emails")
    func redacts() {
        #expect(redactor.redact("key sk-ABCDEFGHIJKLMNOPQRSTUVWX").contains("[REDACTED]"))
        #expect(redactor.redact("ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ012345").contains("[REDACTED]"))
        #expect(redactor.redact("contact me@example.com please").contains("[REDACTED]"))
        #expect(redactor.redact("password: hunter2").contains("[REDACTED]"))
    }

    @Test("Leaves ordinary text untouched")
    func passthrough() {
        #expect(redactor.redact("I edited the invoice report today") == "I edited the invoice report today")
    }
}

@Suite("Embedding providers")
struct EmbeddingProviderTests {
    @Test("Hashing embeddings are deterministic and normalized")
    func hashing() {
        let provider = HashingEmbeddingProvider(dimensions: 64)
        let first = provider.embed("invoice report quarterly")
        let second = provider.embed("invoice report quarterly")
        #expect(first == second)
        let magnitude = (first ?? []).reduce(0) { $0 + Double($1 * $1) }.squareRoot()
        #expect(abs(magnitude - 1) < 1e-5)
    }

    @Test("Empty text yields no embedding")
    func empty() {
        #expect(HashingEmbeddingProvider().embed("   ") == nil)
    }
}

@Suite("Remote summarizer config")
struct RemoteSummarizerConfigTests {
    @Test("Provider names map correctly")
    func providers() {
        #expect(RemoteSummarizer.Provider(rawValue: "openai") == .openAI)
        #expect(RemoteSummarizer.Provider(rawValue: "ollama") == .ollama)
        #expect(RemoteSummarizer.Provider(rawValue: "local") == nil)
    }

    @Test("Default endpoints are defined")
    func endpoints() {
        #expect(RemoteSummarizer.defaultEndpoint(for: .openAI)?.host == "api.openai.com")
        #expect(RemoteSummarizer.defaultEndpoint(for: .ollama)?.port == 11434)
    }
}
