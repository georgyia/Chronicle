import Foundation

/// Watches a configuration file for changes and invokes a callback.
///
/// This is the hot-reload primitive the daemon builds on. It tolerates the
/// atomic-rename save pattern used by most editors (and by ``ConfigurationLoader``
/// itself) by re-arming the underlying source when the watched file is replaced.
public final class ConfigurationFileWatcher: @unchecked Sendable {
    private let url: URL
    private let onChange: @Sendable () -> Void
    private let queue = DispatchQueue(label: "dev.chronicle.config-watcher")
    private var source: (any DispatchSourceFileSystemObject)?
    private var descriptor: Int32 = -1
    private var isRunning = false

    /// Creates a watcher for `url` that calls `onChange` after each modification.
    public init(url: URL, onChange: @escaping @Sendable () -> Void) {
        self.url = url
        self.onChange = onChange
    }

    deinit {
        stop()
    }

    /// Begins watching. Safe to call once; subsequent calls are ignored until ``stop()``.
    public func start() {
        queue.sync {
            guard !isRunning else { return }
            isRunning = true
            arm()
        }
    }

    /// Stops watching and releases the underlying file descriptor.
    public func stop() {
        queue.sync {
            isRunning = false
            source?.cancel()
            source = nil
        }
    }

    private func arm() {
        guard isRunning else { return }
        descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else {
            // File may not exist yet; retry shortly so first-write is caught.
            queue.asyncAfter(deadline: .now() + 1) { [weak self] in self?.arm() }
            return
        }

        let newSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .extend, .rename, .delete, .attrib],
            queue: queue
        )

        newSource.setEventHandler { [weak self] in
            guard let self else { return }
            let events = newSource.data
            onChange()
            if events.contains(.rename) || events.contains(.delete) {
                // File was replaced; rebuild the source against the new inode.
                source?.cancel()
                source = nil
                arm()
            }
        }

        newSource.setCancelHandler { [descriptor] in
            if descriptor >= 0 { close(descriptor) }
        }

        source = newSource
        newSource.resume()
    }
}
