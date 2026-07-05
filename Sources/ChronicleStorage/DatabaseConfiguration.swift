import Foundation
import GRDB

enum DatabaseConfiguration {
    /// Builds the GRDB configuration used for the Chronicle database.
    ///
    /// Tuned for a write-mostly background agent with concurrent CLI readers:
    /// WAL is enabled by `DatabasePool`, `synchronous=NORMAL` is the recommended
    /// durability/throughput balance under WAL, and a busy timeout avoids
    /// spurious `SQLITE_BUSY` errors when the CLI reads during a write.
    static func make() -> Configuration {
        var configuration = Configuration()
        configuration.busyMode = .timeout(5)
        configuration.prepareDatabase { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")
            try db.execute(sql: "PRAGMA synchronous = NORMAL")
            try db.execute(sql: "PRAGMA temp_store = MEMORY")
        }
        return configuration
    }
}
