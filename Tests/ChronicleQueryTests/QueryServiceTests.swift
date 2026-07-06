import ChronicleCore
import ChronicleModels
import ChronicleTestSupport
import Foundation
import Testing
@testable import ChronicleQuery

@Suite("Query service & narrative")
struct QueryServiceTests {
    private func makeService(_ repository: InMemoryEventRepository) -> QueryService {
        QueryService(events: repository, search: repository, statistics: repository)
    }

    @Test("Report aggregates totals, kinds, and top apps")
    func report() async throws {
        let repository = InMemoryEventRepository()
        try await repository.insert([
            EventFactory.event(kind: .fileCreated, source: .filesystem),
            EventFactory.event(kind: .fileModified, source: .filesystem, attributes: [.path: "/tmp/b"]),
            EventFactory.event(kind: .appActivated, source: .application, attributes: [.appName: "Safari"]),
            EventFactory.event(kind: .appActivated, source: .application, attributes: [.appName: "Safari"]),
        ])
        let service = makeService(repository)
        let report = try await service.report(range: nil)

        #expect(report.total == 4)
        #expect(report.byKind[.fileCreated] == 1)
        #expect(report.bySource[.filesystem] == 2)
        #expect(report.topApps.first?.app == "Safari")
        #expect(report.topApps.first?.count == 2)
    }

    @Test("Timeline honors ordering and limit")
    func timeline() async throws {
        let repository = InMemoryEventRepository()
        try await repository.insert(EventFactory.sequence(count: 10))
        let service = makeService(repository)
        let events = try await service.timeline(EventQuery(order: .descending, limit: 3))
        #expect(events.count == 3)
    }

    @Test("Narrative summarizes a report")
    func narrative() async throws {
        let repository = InMemoryEventRepository()
        try await repository.insert([
            EventFactory.event(kind: .fileCreated),
            EventFactory.event(kind: .appActivated, source: .application, attributes: [.appName: "Xcode"]),
        ])
        let report = try await makeService(repository).report(range: nil)
        let narrative = NarrativeBuilder.narrative(from: report)
        #expect(narrative.contains("2 events"))
        #expect(narrative.contains("Xcode"))
    }

    @Test("Empty narrative is graceful")
    func emptyNarrative() {
        let report = StatisticsReport(range: nil, total: 0, byKind: [:], bySource: [:], topApps: [], hourHistogram: [:])
        #expect(NarrativeBuilder.narrative(from: report) == "No recorded activity for this period.")
    }
}
