import Foundation

/// Derives coarse, queryable metadata from a filesystem path.
///
/// Pure and dependency-free so it is trivial to unit test.
enum PathClassifier {
    /// The classification of a path used to enrich filesystem events.
    struct Classification: Equatable {
        var filename: String
        var fileExtension: String?
        var category: String
    }

    /// Classifies an absolute path into filename, extension, and category.
    static func classify(_ path: String) -> Classification {
        let nsPath = path as NSString
        let filename = nsPath.lastPathComponent
        let ext = nsPath.pathExtension.isEmpty ? nil : nsPath.pathExtension.lowercased()
        return Classification(filename: filename, fileExtension: ext, category: category(for: path, extension: ext))
    }

    private static func category(for path: String, extension ext: String?) -> String {
        let lower = path.lowercased()
        if lower.contains("/downloads/") { return "downloads" }
        if lower.contains("/desktop/") { return "desktop" }
        if lower.contains("/documents/") { return "documents" }
        if lower.contains("/pictures/") || isImage(ext) { return "images" }
        if lower.contains("/movies/") { return "media" }
        if isCode(ext) { return "code" }
        if isDocument(ext) { return "documents" }
        return "other"
    }

    private static func isImage(_ ext: String?) -> Bool {
        guard let ext else { return false }
        return ["png", "jpg", "jpeg", "gif", "heic", "webp", "tiff", "bmp", "svg"].contains(ext)
    }

    private static func isCode(_ ext: String?) -> Bool {
        guard let ext else { return false }
        return [
            "swift", "c", "h", "cpp", "hpp", "m", "mm", "js", "ts", "tsx", "jsx",
            "py", "rb", "go", "rs", "java", "kt", "sh", "json", "yml", "yaml", "toml",
        ].contains(ext)
    }

    private static func isDocument(_ ext: String?) -> Bool {
        guard let ext else { return false }
        return ["pdf", "doc", "docx", "pages", "txt", "md", "rtf", "key", "ppt", "pptx", "xls", "xlsx", "numbers"]
            .contains(ext)
    }
}
