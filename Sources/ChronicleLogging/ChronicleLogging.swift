import Foundation
import Logging

/// Where log output should be delivered.
public enum LogDestination: Sendable {
    /// Human-readable lines to standard error.
    case console
    /// Structured JSON lines to a rotating file at the given URL.
    case file(URL)
    /// Both console and rotating file.
    case both(URL)
}

/// Factory and bootstrap helpers for Chronicle's logging stack.
///
/// Chronicle uses swift-log as a facade. The daemon logs structured JSON to a
/// rotating file; the CLI logs human-readable lines to stderr. Bootstrapping is
/// explicit (no global singletons beyond swift-log's own registry, which is
/// process-wide by design).
public enum ChronicleLogging {
    /// Builds a logger factory closure for the given destination and level.
    ///
    /// - Parameters:
    ///   - destination: Where to send output.
    ///   - level: The minimum level to emit.
    /// - Returns: A factory suitable for `LoggingSystem.bootstrap`.
    public static func handlerFactory(
        destination: LogDestination,
        level: Logger.Level
    ) -> @Sendable (String) -> any LogHandler {
        switch destination {
        case .console:
            return { label in ConsoleLogHandler(label: label, level: level) }
        case let .file(url):
            let writer = RotatingFileWriter(fileURL: url)
            return { label in RotatingFileLogHandler(label: label, writer: writer, level: level) }
        case let .both(url):
            let writer = RotatingFileWriter(fileURL: url)
            return { label in
                MultiplexLogHandler([
                    ConsoleLogHandler(label: label, level: level),
                    RotatingFileLogHandler(label: label, writer: writer, level: level),
                ])
            }
        }
    }

    /// Bootstraps the process-wide swift-log system exactly once.
    ///
    /// - Parameters:
    ///   - destination: Where to send output.
    ///   - level: The minimum level to emit.
    public static func bootstrap(destination: LogDestination, level: Logger.Level = .info) {
        let factory = handlerFactory(destination: destination, level: level)
        LoggingSystem.bootstrap(factory)
    }

    /// Creates a labelled logger without touching the global system, for tests
    /// and library callers that prefer explicit injection.
    public static func makeLogger(
        label: String,
        destination: LogDestination,
        level: Logger.Level = .info
    ) -> Logger {
        let factory = handlerFactory(destination: destination, level: level)
        return Logger(label: label, factory: factory)
    }
}
