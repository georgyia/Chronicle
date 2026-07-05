import ChronicleModels
import CryptoKit
import Foundation

/// Suppresses duplicate observations within a sliding time window.
///
/// FSEvents and other sources frequently emit the same logical change multiple
/// times in quick succession. The deduplicator computes a content digest that
/// includes a coarse time bucket, so identical activity in the same window
/// collapses to one event while genuinely-later activity is preserved. The digest
/// is stamped onto admitted events so storage can enforce the same invariant.
///
/// Not thread-safe by itself; it is owned and isolated by the ``EventPipeline``
/// actor.
final class Deduplicator {
    private let windowMilliseconds: Int64
    private let capacity: Int
    private var seen: Set<EventDigest> = []
    private var order: [EventDigest] = []

    init(window: Duration, capacity: Int) {
        windowMilliseconds = max(
            1,
            Int64(window.components.seconds * 1000 + window.components.attoseconds / 1_000_000_000_000_000)
        )
        self.capacity = max(1, capacity)
    }

    /// Admits an event if it is not a recent duplicate, stamping its digest.
    /// - Returns: The admitted event with its digest set, or `nil` if duplicate.
    func admit(_ event: Event) -> Event? {
        let digest = Self.digest(for: event, windowMilliseconds: windowMilliseconds)
        guard !seen.contains(digest) else { return nil }

        seen.insert(digest)
        order.append(digest)
        if order.count > capacity {
            let evicted = order.removeFirst()
            seen.remove(evicted)
        }

        var admitted = event
        admitted.dedupeDigest = digest
        return admitted
    }

    /// Computes the content digest used for deduplication.
    static func digest(for event: Event, windowMilliseconds: Int64) -> EventDigest {
        let bucket = event.timestamp.millisecondsSince1970 / windowMilliseconds
        var canonical = "\(event.kind.rawValue)\n\(event.source.rawValue)\n\(bucket)"
        let salientKeys: [AttributeKey] = [.path, .fromPath, .title, .appName, .bundleID, .command, .url, .commit]
        for key in salientKeys {
            if let value = event.attributes.string(key) {
                canonical += "\n\(key.rawValue)=\(value)"
            }
        }
        let hash = SHA256.hash(data: Data(canonical.utf8))
        return EventDigest(bytes: Data(hash))
    }
}
