import Foundation

/// The free plan's monthly allowance of AI captures. Resets when the month changes.
public struct MonthlyQuota: Equatable, Sendable, Codable {
    public static let freeLimit = 5

    public var monthKey: String
    public var used: Int

    public init(monthKey: String = "", used: Int = 0) {
        self.monthKey = monthKey
        self.used = used
    }

    /// "2026-11"
    public static func key(for date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month], from: date)
        let month = c.month ?? 1
        return "\(c.year ?? 1970)-" + (month < 10 ? "0" : "") + "\(month)"
    }

    public func remaining(monthKey key: String, limit: Int = MonthlyQuota.freeLimit) -> Int {
        max(0, limit - (key == monthKey ? used : 0))
    }

    /// Uses one capture. Returns false (and changes nothing) when none are left.
    public mutating func consume(monthKey key: String, limit: Int = MonthlyQuota.freeLimit) -> Bool {
        if key != monthKey {
            monthKey = key
            used = 0
        }
        guard used < limit else { return false }
        used += 1
        return true
    }
}
