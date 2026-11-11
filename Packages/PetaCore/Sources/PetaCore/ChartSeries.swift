import Foundation

/// One day of a month for the balance chart.
public struct DayAmount: Equatable, Sendable, Identifiable {
    public var day: Int
    /// That day's plus and minus added up.
    public var total: Int
    /// Running total from the 1st up to this day.
    public var cumulative: Int
    public var id: Int { day }
}

/// One month for the trend chart.
public struct MonthAmount: Equatable, Sendable, Identifiable {
    public var year: Int
    public var month: Int
    public var total: Int
    public var id: Int { year * 12 + month }
}

/// Numbers behind the charts. The app only draws what this returns.
public enum ChartSeries {
    /// Every day of the month, including days without records (total 0).
    public static func daily(_ amounts: [(day: DayKey, amount: Int)], year: Int, month: Int, dayCount: Int) -> [DayAmount] {
        var totals = Array(repeating: 0, count: max(dayCount, 0) + 1)
        for entry in amounts where entry.day.year == year && entry.day.month == month && totals.indices.contains(entry.day.day) {
            totals[entry.day.day] += entry.amount
        }
        var running = 0
        return (1..<totals.count).map { day in
            running += totals[day]
            return DayAmount(day: day, total: totals[day], cumulative: running)
        }
    }

    /// The last `months` months ending at the given month, oldest first.
    public static func monthly(_ amounts: [(day: DayKey, amount: Int)], endYear: Int, endMonth: Int, months: Int) -> [MonthAmount] {
        guard months > 0 else { return [] }
        return (0..<months).reversed().map { back in
            let ym = MonthGrid.shifted(year: endYear, month: endMonth, by: -back)
            let total = amounts.filter { $0.day.year == ym.year && $0.day.month == ym.month }.reduce(0) { $0 + $1.amount }
            return MonthAmount(year: ym.year, month: ym.month, total: total)
        }
    }
}
