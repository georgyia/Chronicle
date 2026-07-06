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
            // `page_size` only takes effect on a fresh database, before tables exist.
            try db.execute(sql: "PRAGMA page_size = 4096")
            try db.execute(sql: "PRAGMA foreign_keys = ON")
            try db.execute(sql: "PRAGMA synchronous = NORMAL")
            try db.execute(sql: "PRAGMA temp_store = MEMORY")
            // Memory-map up to 256 MiB and keep an ~8 MiB page cache for read speed.
            try db.execute(sql: "PRAGMA mmap_size = 268435456")
            try db.execute(sql: "PRAGMA cache_size = -8000")
        }
        return configuration
    }
}
