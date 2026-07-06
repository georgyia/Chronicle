import ChronicleConfig
import Testing
@testable import ChronicleCollectors

@Suite("Collector factory")
struct CollectorFactoryTests {
    @Test("Default configuration enables the five core collectors")
    func defaults() {
        let collectors = CollectorFactory.makeCollectors(configuration: ChronicleConfiguration())
        let ids = Set(collectors.map(\.descriptor.id))
        #expect(ids == ["filesystem", "application", "window", "power", "downloads"])
    }

    @Test("Enabling an optional module adds it")
    func optional() {
        var configuration = ChronicleConfiguration()
        configuration.modules["clipboard"] = true
        let ids = Set(CollectorFactory.makeCollectors(configuration: configuration).map(\.descriptor.id))
        #expect(ids.contains("clipboard"))
    }

    @Test("Disabling a core module removes it")
    func disableCore() {
        var configuration = ChronicleConfiguration()
        configuration.modules["window"] = false
        let ids = Set(CollectorFactory.makeCollectors(configuration: configuration).map(\.descriptor.id))
        #expect(!ids.contains("window"))
    }

    @Test("All descriptors enumerate every module")
    func allDescriptors() {
        let ids = Set(CollectorFactory.allDescriptors().map(\.id))
        #expect(ids == [
            "filesystem", "application", "window", "power", "downloads",
            "clipboard", "git", "terminal", "browser",
        ])
    }

    @Test("Sensitive modules are marked and off by default")
    func sensitivity() {
        let descriptors = CollectorFactory.allDescriptors()
        let clipboard = descriptors.first { $0.id == "clipboard" }
        #expect(clipboard?.isSensitive == true)
        #expect(clipboard?.enabledByDefault == false)
    }
}
