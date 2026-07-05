import Foundation

/// A self-cleaning temporary directory for filesystem-touching tests.
public struct TemporaryDirectory: Sendable {
    /// The directory URL.
    public let url: URL

    /// Creates a uniquely-named temporary directory.
    public init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("chronicle-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    /// Removes the directory and its contents.
    public func remove() {
        try? FileManager.default.removeItem(at: url)
    }

    /// Returns a child URL within the directory.
    public func file(_ name: String) -> URL {
        url.appendingPathComponent(name)
    }
}

/// Runs `body` with a temporary directory that is removed afterwards.
public func withTemporaryDirectory<T>(_ body: (TemporaryDirectory) async throws -> T) async throws -> T {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    return try await body(directory)
}
