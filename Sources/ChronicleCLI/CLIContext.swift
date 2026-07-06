import ChronicleConfig
import ChronicleCore
import ChronicleIPC
import ChronicleQuery
import ChronicleStorage
import Foundation

/// Resolves shared dependencies for a CLI invocation.
///
/// Opens the same database the daemon writes (WAL permits concurrent readers) and
/// builds the storage-agnostic ``QueryService`` and an IPC client for control.
struct CLIContext {
    let paths: ChroniclePaths
    let configuration: ChronicleConfiguration
    let store: SQLiteEventStore
    let query: QueryService
    let ipc: IPCClient

    /// Builds a context from global options.
    static func make(_ options: GlobalOptions) throws -> CLIContext {
        var environment = ProcessInfo.processInfo.environment
        if let configOverride = options.config {
            environment["CHRONICLE_CONFIG"] = configOverride
        }
        let paths = ChroniclePaths.resolve(environment: environment)

        let loader = ConfigurationLoader()
        let configuration: ChronicleConfiguration
        do {
            configuration = try loader.loadOrDefault(from: paths.configFile, environment: environment)
        } catch {
            printError("\(error)")
            throw CLIExit.invalidConfig
        }

        let store = try SQLiteEventStore.open(at: paths.databaseFile)
        return CLIContext(
            paths: paths,
            configuration: configuration,
            store: store,
            query: QueryService(events: store, search: store, statistics: store),
            ipc: IPCClient(path: paths.socketFile.path)
        )
    }

    /// Sends an IPC request off the cooperative pool.
    func sendIPC(_ request: IPCRequest) async -> Result<IPCResponse, any Error> {
        let ipc = ipc
        return await Task.detached {
            do {
                return try .success(ipc.send(request))
            } catch {
                return .failure(error)
            }
        }.value
    }
}
