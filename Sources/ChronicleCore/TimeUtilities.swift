import Foundation

public extension Date {
    /// The number of whole milliseconds between 1970 and this date.
    ///
    /// Chronicle stores timestamps as `INTEGER` millisecond epochs for compact,
    /// index-friendly, monotonic ordering.
    var millisecondsSince1970: Int64 {
        Int64((timeIntervalSince1970 * 1000).rounded())
    }

    /// Creates a date from a whole-millisecond epoch value.
    init(millisecondsSince1970 milliseconds: Int64) {
        self.init(timeIntervalSince1970: Double(milliseconds) / 1000)
    }
}
