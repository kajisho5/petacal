import Foundation

/// A calendar day (no time, no time zone). Records and the month grid are keyed by this.
public struct DayKey: Hashable, Comparable, Sendable, Codable {
    public var year: Int
    public var month: Int
    public var day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public init(date: Date, calendar: Calendar) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year ?? 1970, month: c.month ?? 1, day: c.day ?? 1)
    }

    /// Midnight at the start of this day, or nil when the day does not exist (for example 2/30).
    public func date(calendar: Calendar) -> Date? {
        var c = DateComponents()
        c.year = year
        c.month = month
        c.day = day
        guard let date = calendar.date(from: c) else { return nil }
        return DayKey(date: date, calendar: calendar) == self ? date : nil
    }

    public static func < (lhs: DayKey, rhs: DayKey) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    /// 1 = Sunday ... 7 = Saturday.
    public func weekday(calendar: Calendar) -> Int? {
        date(calendar: calendar).map { calendar.component(.weekday, from: $0) }
    }

    public static let weekdaySymbolsJa = ["日", "月", "火", "水", "木", "金", "土"]
}
