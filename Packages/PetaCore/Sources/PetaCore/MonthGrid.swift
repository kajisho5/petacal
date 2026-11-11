import Foundation

/// The day numbers of one month laid out in weeks. Empty cells are nil.
public struct MonthGrid: Equatable, Sendable {
    public let year: Int
    public let month: Int
    /// Each week has exactly 7 cells.
    public let weeks: [[Int?]]
    /// Weekday symbols in display order, starting at the calendar's first weekday.
    public let weekdaySymbols: [String]

    public init(year: Int, month: Int, calendar: Calendar) {
        self.year = year
        self.month = month
        let first = DayKey(year: year, month: month, day: 1)
        let firstDate = first.date(calendar: calendar) ?? Date(timeIntervalSince1970: 0)
        let dayCount = calendar.range(of: .day, in: .month, for: firstDate)?.count ?? 30
        let weekday = calendar.component(.weekday, from: firstDate)
        let leading = (weekday - calendar.firstWeekday + 7) % 7

        var cells: [Int?] = Array(repeating: nil, count: leading)
        cells.append(contentsOf: (1...dayCount).map { Optional($0) })
        while cells.count % 7 != 0 { cells.append(nil) }
        weeks = stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<($0 + 7)]) }

        let start = calendar.firstWeekday - 1
        weekdaySymbols = (0..<7).map { DayKey.weekdaySymbolsJa[(start + $0) % 7] }
    }

    public var dayCount: Int { weeks.joined().compactMap { $0 }.count }

    /// The month `offset` months away (negative goes back).
    public static func shifted(year: Int, month: Int, by offset: Int) -> (year: Int, month: Int) {
        let index = year * 12 + (month - 1) + offset
        let y = Int((Double(index) / 12).rounded(.down))
        return (y, index - y * 12 + 1)
    }
}
