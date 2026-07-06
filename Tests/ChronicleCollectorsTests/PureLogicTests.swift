import ChronicleModels
import ChronicleTestSupport
import CoreServices
import Foundation
import Testing
@testable import ChronicleCollectors

@Suite("Path filter")
struct PathFilterTests {
    @Test("Excludes noise directories")
    func excludes() {
        let filter = PathFilter(excludePatterns: ["/.git/", "/node_modules/"], includeHidden: true)
        #expect(!filter.shouldInclude("/Users/me/proj/.git/index"))
        #expect(!filter.shouldInclude("/Users/me/proj/node_modules/x.js"))
        #expect(filter.shouldInclude("/Users/me/proj/src/main.swift"))
    }

    @Test("Excludes hidden files unless configured")
    func hidden() {
        let strict = PathFilter(excludePatterns: [], includeHidden: false)
        #expect(!strict.shouldInclude("/Users/me/.zshrc"))
        let lenient = PathFilter(excludePatterns: [], includeHidden: true)
        #expect(lenient.shouldInclude("/Users/me/.zshrc"))
    }
}

@Suite("FSEvents classification")
struct FileSystemEventClassifierTests {
    private let classifier = FileSystemEventClassifier()
    private let fileFlag = UInt32(kFSEventStreamEventFlagItemIsFile)

    @Test("Maps flags to kinds by priority")
    func classify() {
        #expect(classifier
            .classify(flags: fileFlag | UInt32(kFSEventStreamEventFlagItemCreated), path: "/tmp/a") == .fileCreated)
        #expect(classifier
            .classify(flags: fileFlag | UInt32(kFSEventStreamEventFlagItemRemoved), path: "/tmp/a") == .fileDeleted)
        #expect(classifier
            .classify(flags: fileFlag | UInt32(kFSEventStreamEventFlagItemModified), path: "/tmp/a") == .fileModified)
        #expect(classifier
            .classify(flags: fileFlag | UInt32(kFSEventStreamEventFlagItemRenamed), path: "/tmp/a") == .fileMoved)
    }

    @Test("Detects Trash deletions")
    func trash() {
        let flags = fileFlag | UInt32(kFSEventStreamEventFlagItemRemoved)
        #expect(classifier.classify(flags: flags, path: "/Users/me/.Trash/a") == .fileTrashed)
    }

    @Test("Ignores directory-only events")
    func directories() {
        let flags = UInt32(kFSEventStreamEventFlagItemIsDir | kFSEventStreamEventFlagItemCreated)
        #expect(classifier.classify(flags: flags, path: "/tmp/dir") == nil)
    }
}

@Suite("Reflog parsing")
struct GitReflogParserTests {
    @Test("Parses a commit line")
    func commit() {
        let line = "0000000000000000000000000000000000000000 a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2 " +
            "Jane <jane@example.com> 1700000000 +0000\tcommit: Add feature"
        let parsed = GitReflogParser.parse(line)
        #expect(parsed?.sha == "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2")
        #expect(parsed?.message == "Add feature")
    }

    @Test("Ignores non-commit reflog entries")
    func nonCommit() {
        let line = "old new Jane <j@e.com> 1700000000 +0000\tcheckout: moving from main to dev"
        #expect(GitReflogParser.parse(line) == nil)
    }
}

@Suite("Browser time conversion")
struct BrowserTimeBaseTests {
    @Test("Chrome time round-trips through Unix")
    func chrome() {
        let unix = 1_700_000_000.0
        let native = BrowserTimeBase.chrome.fromUnix(unix)
        #expect(abs(BrowserTimeBase.chrome.toUnix(native) - unix) < 0.001)
    }

    @Test("Safari time round-trips through Unix")
    func safari() {
        let unix = 1_700_000_000.0
        let native = BrowserTimeBase.safari.fromUnix(unix)
        #expect(BrowserTimeBase.safari.toUnix(native) == unix)
    }
}

@Suite("Clipboard & terminal parsing")
struct MiscCollectorTests {
    @Test("Hash-only mode digests content")
    func clipboardHash() {
        let hashed = ClipboardCollector.clipboardContent("secret", hashOnly: true)
        #expect(hashed.stringValue?.hasPrefix("sha256:") == true)
        let plain = ClipboardCollector.clipboardContent("hello", hashOnly: false)
        #expect(plain.stringValue == "hello")
    }

    @Test("Terminal parses a command payload")
    func terminalParse() {
        let clock = FixedWallClock(Date(timeIntervalSince1970: 1_700_000_000))
        let event = TerminalCollector.parse(#"{"command":"ls -la","cwd":"/tmp","exit":0}"#, clock: clock)
        #expect(event?.kind == .shellCommand)
        #expect(event?.attributes.string(.command) == "ls -la")
        #expect(event?.attributes.int(.exitCode) == 0)
    }

    @Test("Terminal rejects malformed lines")
    func terminalReject() {
        let clock = FixedWallClock()
        #expect(TerminalCollector.parse("not json", clock: clock) == nil)
    }

    @Test("WhereFroms reads download origin from xattr")
    func whereFroms() throws {
        let directory = try TemporaryDirectory()
        defer { directory.remove() }
        let file = directory.file("download.pdf")
        try Data("pdf".utf8).write(to: file)

        let origins = ["https://example.com/download.pdf", "https://example.com/"]
        let plist = try PropertyListSerialization.data(fromPropertyList: origins, format: .binary, options: 0)
        _ = plist.withUnsafeBytes { buffer in
            setxattr(file.path, "com.apple.metadata:kMDItemWhereFroms", buffer.baseAddress, buffer.count, 0, 0)
        }

        #expect(WhereFroms.origins(ofFileAt: file.path)?.first == "https://example.com/download.pdf")
    }
}
