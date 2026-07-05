import ChronicleCore
import ChronicleModels
import ChronicleTestSupport
import Foundation
import Testing
@testable import ChroniclePipeline

@Suite("Path classification")
struct PathClassifierTests {
    @Test("Classifies extension, filename, and category")
    func classify() {
        let code = PathClassifier.classify("/Users/me/Projects/app/Main.swift")
        #expect(code.filename == "Main.swift")
        #expect(code.fileExtension == "swift")
        #expect(code.category == "code")

        let download = PathClassifier.classify("/Users/me/Downloads/invoice.pdf")
        #expect(download.category == "downloads")

        let noExt = PathClassifier.classify("/Users/me/Documents/README")
        #expect(noExt.fileExtension == nil)
        #expect(noExt.category == "documents")
    }
}

@Suite("Validation stage")
struct ValidationProcessorTests {
    private let clock = FixedWallClock(Date(timeIntervalSince1970: 1_700_100_000))

    @Test("Accepts a well-formed event")
    func accepts() async throws {
        let processor = ValidationProcessor(clock: clock)
        let event = EventFactory.event(timestamp: Date(timeIntervalSince1970: 1_700_000_000))
        #expect(try await processor.process(event) != nil)
    }

    @Test("Rejects far-future timestamps")
    func rejectsFuture() async throws {
        let processor = ValidationProcessor(clock: clock)
        let event = EventFactory.event(timestamp: Date(timeIntervalSince1970: 1_800_000_000))
        #expect(try await processor.process(event) == nil)
    }

    @Test("Rejects file events without a path")
    func rejectsMissingPath() async throws {
        let processor = ValidationProcessor(clock: clock)
        let event = EventFactory.event(
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            kind: .fileCreated,
            attributes: [:]
        )
        #expect(try await processor.process(event) == nil)
    }
}

@Suite("Enrichment stage")
struct EnrichmentProcessorTests {
    private let session = FixedSessionProvider(sessionID: SessionID(rawValue: UUID()))

    @Test("Stamps a session and classifies the path")
    func enriches() async throws {
        let processor = EnrichmentProcessor(session: session)
        let event = EventFactory.event(attributes: [.path: "/Users/me/Downloads/report.pdf"])
        let enriched = try #require(try await processor.process(event))
        #expect(enriched.sessionID != nil)
        #expect(enriched.attributes.string(.filename) == "report.pdf")
        #expect(enriched.attributes.string(.category) == "downloads")
        #expect(enriched.attributes.string(.fileExtension) == "pdf")
    }

    @Test("Attaches frontmost-app context to filesystem events")
    func attachesContext() async throws {
        let context = StubContextProvider(context: ActivityContext(appName: "Xcode", bundleID: "com.apple.dt.Xcode"))
        let processor = EnrichmentProcessor(session: session, context: context)
        let event = EventFactory.event(source: .filesystem, attributes: [.path: "/tmp/a.swift"])
        let enriched = try #require(try await processor.process(event))
        #expect(enriched.attributes.string(.appName) == "Xcode")
        #expect(enriched.attributes.string(.bundleID) == "com.apple.dt.Xcode")
    }
}

private struct StubContextProvider: ActivityContextProviding {
    let context: ActivityContext?
    func currentContext() -> ActivityContext? {
        context
    }
}
