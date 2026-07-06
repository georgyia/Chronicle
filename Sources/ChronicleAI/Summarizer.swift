import ChronicleCore
import Foundation

/// Errors from the AI layer.
public enum AIError: ChronicleError {
    /// The AI feature is not enabled in configuration.
    case disabled
    /// The configured provider is not recognized.
    case unsupportedProvider(String)
    /// A required API key was missing.
    case missingAPIKey
    /// The provider request failed.
    case requestFailed(String)
    /// The provider response could not be parsed.
    case invalidResponse

    public var code: String {
        switch self {
        case .disabled: "ai.disabled"
        case .unsupportedProvider: "ai.unsupported_provider"
        case .missingAPIKey: "ai.missing_api_key"
        case .requestFailed: "ai.request_failed"
        case .invalidResponse: "ai.invalid_response"
        }
    }

    public var message: String {
        switch self {
        case .disabled: "AI features are disabled; enable with `chronicle config set ai.enabled true`"
        case let .unsupportedProvider(name): "Unsupported AI provider: \(name)"
        case .missingAPIKey: "No API key found in the Keychain for this provider"
        case let .requestFailed(detail): "AI request failed: \(detail)"
        case .invalidResponse: "The AI provider returned an unexpected response"
        }
    }
}

/// Produces a natural-language summary from a prompt.
public protocol Summarizer: Sendable {
    /// Summarizes the prompt, returning provider text.
    func summarize(_ prompt: String) async throws -> String
}

/// A summarizer backed by an OpenAI-compatible or Ollama HTTP endpoint.
///
/// The prompt is passed through the redaction gate (when provided) before any
/// bytes leave the device.
public struct RemoteSummarizer: Summarizer {
    /// The remote provider protocol dialect.
    public enum Provider: String, Sendable {
        case openAI = "openai"
        case ollama
    }

    private let provider: Provider
    private let model: String
    private let endpoint: URL
    private let apiKey: String?
    private let redactor: TextRedactor?
    private let session: URLSession

    /// Creates a remote summarizer.
    public init(
        provider: Provider,
        model: String,
        endpoint: URL,
        apiKey: String?,
        redactor: TextRedactor?,
        session: URLSession = .shared
    ) {
        self.provider = provider
        self.model = model
        self.endpoint = endpoint
        self.apiKey = apiKey
        self.redactor = redactor
        self.session = session
    }

    /// The default endpoint for a provider.
    public static func defaultEndpoint(for provider: Provider) -> URL? {
        switch provider {
        case .openAI: URL(string: "https://api.openai.com/v1/chat/completions")
        case .ollama: URL(string: "http://localhost:11434/api/generate")
        }
    }

    public func summarize(_ prompt: String) async throws -> String {
        let safePrompt = redactor?.redact(prompt) ?? prompt
        switch provider {
        case .openAI: return try await callOpenAI(safePrompt)
        case .ollama: return try await callOllama(safePrompt)
        }
    }

    private func callOpenAI(_ prompt: String) async throws -> String {
        struct Request: Encodable {
            let model: String
            let messages: [Message]
            struct Message: Encodable { let role: String
                let content: String
            }
        }
        struct Response: Decodable {
            let choices: [Choice]
            struct Choice: Decodable { let message: Message }
            struct Message: Decodable { let content: String }
        }

        guard let apiKey, !apiKey.isEmpty else { throw AIError.missingAPIKey }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(
            Request(model: model, messages: [.init(role: "user", content: prompt)])
        )

        let data = try await send(request)
        guard let decoded = try? JSONDecoder().decode(Response.self, from: data),
              let content = decoded.choices.first?.message.content
        else { throw AIError.invalidResponse }
        return content
    }

    private func callOllama(_ prompt: String) async throws -> String {
        struct Request: Encodable { let model: String
            let prompt: String
            let stream: Bool
        }
        struct Response: Decodable { let response: String }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(Request(model: model, prompt: prompt, stream: false))

        let data = try await send(request)
        guard let decoded = try? JSONDecoder().decode(Response.self, from: data) else {
            throw AIError.invalidResponse
        }
        return decoded.response
    }

    private func send(_ request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw AIError.requestFailed("HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            }
            return data
        } catch let error as AIError {
            throw error
        } catch {
            throw AIError.requestFailed(error.localizedDescription)
        }
    }
}
