import Foundation
import SQLite3

/// How a browser encodes visit timestamps.
enum BrowserTimeBase {
    /// Chromium: microseconds since 1601-01-01.
    case chrome
    /// Safari/WebKit: `CFAbsoluteTime` seconds since 2001-01-01.
    case safari

    private static let chromeEpochOffset: Double = 11_644_473_600
    private static let cfAbsoluteOffset: Double = 978_307_200

    /// Converts a native column value to Unix seconds.
    func toUnix(_ value: Double) -> Double {
        switch self {
        case .chrome: value / 1_000_000 - Self.chromeEpochOffset
        case .safari: value + Self.cfAbsoluteOffset
        }
    }

    /// Converts Unix seconds to the browser's native units (for query thresholds).
    func fromUnix(_ unix: Double) -> Double {
        switch self {
        case .chrome: (unix + Self.chromeEpochOffset) * 1_000_000
        case .safari: unix - Self.cfAbsoluteOffset
        }
    }
}

/// A browser history source: where its database lives and how to read it.
struct BrowserProfile {
    let id: String
    let historyPath: String
    let sql: String
    let timeBase: BrowserTimeBase
}

/// A single browser visit.
struct BrowserVisit: Equatable {
    let url: String
    let title: String?
    let unixTime: Double
}

/// Reads new visits from browser history SQLite databases.
///
/// The database is copied to a temp location before reading to avoid contending
/// with the running browser's locks. Reading Safari history requires Full Disk
/// Access; Chromium histories are readable without it.
enum BrowserHistoryReader {
    /// Returns the known profiles for the requested browser names.
    static func profiles(for names: [String]) -> [BrowserProfile] {
        let home = NSHomeDirectory()
        return names.compactMap { name in
            switch name.lowercased() {
            case "chrome":
                BrowserProfile(
                    id: "chrome",
                    historyPath: "\(home)/Library/Application Support/Google/Chrome/Default/History",
                    sql: chromeSQL,
                    timeBase: .chrome
                )
            case "arc":
                BrowserProfile(
                    id: "arc",
                    historyPath: "\(home)/Library/Application Support/Arc/User Data/Default/History",
                    sql: chromeSQL,
                    timeBase: .chrome
                )
            case "safari":
                BrowserProfile(
                    id: "safari",
                    historyPath: "\(home)/Library/Safari/History.db",
                    sql: safariSQL,
                    timeBase: .safari
                )
            default:
                nil
            }
        }
    }

    private static let chromeSQL = """
    SELECT urls.url, urls.title, visits.visit_time
    FROM visits JOIN urls ON urls.id = visits.url
    WHERE visits.visit_time > ? ORDER BY visits.visit_time ASC LIMIT 500
    """

    private static let safariSQL = """
    SELECT history_items.url, history_visits.title, history_visits.visit_time
    FROM history_visits JOIN history_items ON history_items.id = history_visits.history_item
    WHERE history_visits.visit_time > ? ORDER BY history_visits.visit_time ASC LIMIT 500
    """

    /// Reads visits newer than `sinceUnix` from a profile's database.
    static func readVisits(_ profile: BrowserProfile, sinceUnix: Double) -> [BrowserVisit] {
        guard FileManager.default.fileExists(atPath: profile.historyPath) else { return [] }
        guard let copy = copyToTemp(profile.historyPath) else { return [] }
        defer { try? FileManager.default.removeItem(at: copy.deletingLastPathComponent()) }

        var handle: OpaquePointer?
        guard sqlite3_open_v2(copy.path, &handle, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            sqlite3_close(handle)
            return []
        }
        defer { sqlite3_close(handle) }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, profile.sql, -1, &statement, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_double(statement, 1, profile.timeBase.fromUnix(sinceUnix))

        var visits: [BrowserVisit] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let urlPointer = sqlite3_column_text(statement, 0) else { continue }
            let url = String(cString: urlPointer)
            let title = sqlite3_column_text(statement, 1).map { String(cString: $0) }
            let nativeTime = sqlite3_column_double(statement, 2)
            visits.append(BrowserVisit(url: url, title: title, unixTime: profile.timeBase.toUnix(nativeTime)))
        }
        return visits
    }

    private static func copyToTemp(_ path: String) -> URL? {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("chr-browser-\(UUID().uuidString)")
        guard (try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)) != nil else {
            return nil
        }
        let destination = directory.appendingPathComponent("history.db")
        for suffix in ["", "-wal", "-shm"] {
            let source = path + suffix
            guard FileManager.default.fileExists(atPath: source) else { continue }
            try? FileManager.default.copyItem(atPath: source, toPath: destination.path + suffix)
        }
        return FileManager.default.fileExists(atPath: destination.path) ? destination : nil
    }
}
