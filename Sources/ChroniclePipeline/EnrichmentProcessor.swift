import ChronicleCore
import ChronicleModels
import Foundation

/// Adds derived context to events: a session id, path classification, and (for
/// filesystem events) the frontmost application.
public struct EnrichmentProcessor: EventProcessor {
    private let session: any SessionProviding
    private let context: any ActivityContextProviding

    /// Creates an enrichment stage.
    /// - Parameters:
    ///   - session: Provides the session id to stamp on events.
    ///   - context: Provides the frontmost-app context, if available.
    public init(session: any SessionProviding, context: any ActivityContextProviding = NullActivityContextProvider()) {
        self.session = session
        self.context = context
    }

    public func process(_ event: Event) async throws -> Event? {
        var enriched = event
        if enriched.sessionID == nil {
            enriched.sessionID = session.currentSessionID()
        }
        classifyPath(&enriched)
        attachActivityContext(&enriched)
        return enriched
    }

    private func classifyPath(_ event: inout Event) {
        guard let path = event.attributes.string(.path) else { return }
        let classification = PathClassifier.classify(path)
        event.attributes[.filename] = .string(classification.filename)
        event.attributes[.category] = .string(classification.category)
        if let ext = classification.fileExtension {
            event.attributes[.fileExtension] = .string(ext)
        }
    }

    private func attachActivityContext(_ event: inout Event) {
        guard event.source == .filesystem, event.attributes.string(.appName) == nil else { return }
        guard let current = context.currentContext() else { return }
        event.attributes[.appName] = .string(current.appName)
        event.attributes[.bundleID] = .string(current.bundleID)
    }
}
