import Foundation

/// Reads the `kMDItemWhereFroms` extended attribute that macOS attaches to
/// downloaded files, recording their origin URL(s).
enum WhereFroms {
    private static let attributeName = "com.apple.metadata:kMDItemWhereFroms"

    /// Returns the origin URLs for a downloaded file, or `nil` if it has none.
    static func origins(ofFileAt path: String) -> [String]? {
        guard let data = extendedAttribute(named: attributeName, atPath: path) else { return nil }
        guard
            let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
            let strings = plist as? [String]
        else { return nil }
        let nonEmpty = strings.filter { !$0.isEmpty }
        return nonEmpty.isEmpty ? nil : nonEmpty
    }

    private static func extendedAttribute(named name: String, atPath path: String) -> Data? {
        let length = getxattr(path, name, nil, 0, 0, 0)
        guard length > 0 else { return nil }
        var data = Data(count: length)
        let result = data.withUnsafeMutableBytes { buffer in
            getxattr(path, name, buffer.baseAddress, length, 0, 0)
        }
        guard result >= 0 else { return nil }
        return data
    }
}
