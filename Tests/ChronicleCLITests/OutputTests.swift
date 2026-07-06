import ChronicleModels
import ChronicleTestSupport
import Foundation
import Testing
@testable import ChronicleCLI

@Suite("CLI output rendering")
struct OutputTests {
    @Test("Table aligns columns and includes headers")
    func table() {
        var table = Table(headers: ["Name", "Count"])
        table.rows = [["filesystem", "12"], ["application", "3"]]
        let rendered = table.render(color: false)
        #expect(rendered.contains("Name"))
        #expect(rendered.contains("filesystem"))
        #expect(rendered.contains("12"))
    }

    @Test("Event detail prefers title, then command, then path")
    func detail() {
        let windowEvent = EventFactory.event(
            kind: .windowTitleChanged,
            source: .window,
            attributes: [.appName: "Safari", .title: "Docs"]
        )
        #expect(EventFormatter.detail(for: windowEvent) == "Safari — Docs")

        let fileEvent = EventFactory.event(attributes: [.path: "/tmp/a.txt"])
        #expect(EventFormatter.detail(for: fileEvent) == "/tmp/a.txt")
    }

    @Test("Home directory is abbreviated to ~")
    func abbreviate() {
        let path = NSHomeDirectory() + "/Documents/report.pdf"
        #expect(EventFormatter.abbreviate(path) == "~/Documents/report.pdf")
    }

    @Test("CSV export has a header and escapes commas")
    func csv() {
        let event = EventFactory.event(kind: .fileCreated, attributes: [.path: "/tmp/a,b.txt"])
        let csv = ExportRenderer.csv([event])
        let lines = csv.split(separator: "\n")
        #expect(lines.first == "id,timestamp,kind,source,path,app,title,url,command")
        #expect(csv.contains("\"/tmp/a,b.txt\""))
    }

    @Test("Markdown export groups by day")
    func markdown() {
        let event = EventFactory.event(kind: .fileCreated, attributes: [.path: "/tmp/a.txt"])
        let markdown = ExportRenderer.markdown([event])
        #expect(markdown.contains("# Chronicle export"))
        #expect(markdown.contains("**file.created**"))
    }
}
