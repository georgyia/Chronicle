import Foundation

/// A `Sendable` box around a set of `NotificationCenter` observer tokens.
///
/// Bridges the non-`Sendable` observer API into Swift concurrency: the tokens are
/// created and removed only through this box, which the collector retains for the
/// lifetime of its event stream.
final class NotificationSubscription: @unchecked Sendable {
    private let center: NotificationCenter
    private let lock = NSLock()
    private var tokens: [any NSObjectProtocol] = []

    /// Creates a subscription against a notification center.
    init(center: NotificationCenter) {
        self.center = center
    }

    /// Registers a handler for a notification name.
    func observe(_ name: Notification.Name, handler: @escaping @Sendable (Notification) -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: nil, using: handler)
        lock.lock()
        tokens.append(token)
        lock.unlock()
    }

    /// Removes all registered observers.
    func cancel() {
        lock.lock()
        let current = tokens
        tokens.removeAll()
        lock.unlock()
        for token in current {
            center.removeObserver(token)
        }
    }
}
