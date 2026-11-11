import Foundation

public extension DayKey {
    /// The day `days` later (negative goes back).
    func adding(days: Int, calendar: Calendar) -> DayKey {
        guard let start = date(calendar: calendar),
              let moved = calendar.date(byAdding: .day, value: days, to: start) else { return self }
        return DayKey(date: moved, calendar: calendar)
    }

    /// The first day of the week this day is in (follows the calendar's first weekday).
    func startOfWeek(calendar: Calendar) -> DayKey {
        guard let weekday = weekday(calendar: calendar) else { return self }
        return adding(days: -((weekday - calendar.firstWeekday + 7) % 7), calendar: calendar)
    }

    /// The seven days of the week this day is in.
    func week(calendar: Calendar) -> [DayKey] {
        let first = startOfWeek(calendar: calendar)
        return (0..<7).map { first.adding(days: $0, calendar: calendar) }
    }
}

/// Something that covers one or more whole days in the month view.
public struct SpanItem<ID: Hashable & Sendable>: Sendable {
    public let id: ID
    public let start: DayKey
    /// Inclusive.
    public let end: DayKey
    /// Minutes from midnight on the first day; all-day items use -1 so they come first.
    public let sortKey: Int

    public init(id: ID, start: DayKey, end: DayKey, sortKey: Int) {
        self.id = id
        self.start = start
        self.end = max(start, end)
        self.sortKey = sortKey
    }
}

/// One bar in one week row of the month view.
public struct BarSegment<ID: Hashable & Sendable>: Equatable, Sendable {
    public let id: ID
    public let lane: Int
    /// 0...6
    public let startColumn: Int
    public let endColumn: Int
    /// The item started before this row (draw without a left cap).
    public let continuesBefore: Bool
    public let continuesAfter: Bool
}

public struct WeekBars<ID: Hashable & Sendable>: Equatable, Sendable {
    public let segments: [BarSegment<ID>]
    /// Per column: how many items did not fit in the lanes.
    public let hidden: [Int]
}

public enum MonthBarLayout {
    /// Places items into lanes for one week row.
    /// - Parameter days: seven cells; nil for cells outside the month.
    public static func layout<ID: Hashable & Sendable>(items: [SpanItem<ID>], days: [DayKey?], maxLanes: Int) -> WeekBars<ID> {
        var hidden = Array(repeating: 0, count: days.count)
        let columns = days.enumerated().compactMap { index, day in day.map { (index, $0) } }
        guard let first = columns.first, let last = columns.last else {
            return WeekBars(segments: [], hidden: hidden)
        }
        func column(of day: DayKey) -> Int {
            columns.first { $0.1 == day }?.0 ?? first.0
        }
        let visible = items
            .filter { $0.start <= last.1 && $0.end >= first.1 }
            .sorted { a, b in
                let sa = max(a.start, first.1), sb = max(b.start, first.1)
                if sa != sb { return sa < sb }
                let multiA = a.start != a.end, multiB = b.start != b.end
                if multiA != multiB { return multiA }
                if a.end != b.end { return a.end > b.end }
                return a.sortKey < b.sortKey
            }
        var taken: [[Bool]] = []     // lane -> column -> used
        var segments: [BarSegment<ID>] = []
        for item in visible {
            let a = column(of: max(item.start, first.1))
            let b = column(of: min(item.end, last.1))
            let from = min(a, b), to = max(a, b)
            var lane = 0
            while true {
                if lane == taken.count { taken.append(Array(repeating: false, count: days.count)) }
                if !taken[lane][from...to].contains(true) { break }
                lane += 1
            }
            for c in from...to { taken[lane][c] = true }
            if lane < maxLanes {
                segments.append(BarSegment(id: item.id, lane: lane, startColumn: from, endColumn: to,
                                           continuesBefore: item.start < first.1, continuesAfter: item.end > last.1))
            } else {
                for c in from...to { hidden[c] += 1 }
            }
        }
        return WeekBars(segments: segments, hidden: hidden)
    }
}

/// Something with a start and end time inside one day (minutes from midnight).
public struct TimedItem<ID: Hashable & Sendable>: Sendable {
    public let id: ID
    public let start: Int
    public let end: Int

    public init(id: ID, start: Int, end: Int) {
        self.id = id
        self.start = min(max(start, 0), 24 * 60)
        self.end = min(max(end, self.start), 24 * 60)
    }
}

public struct TimedPlacement<ID: Hashable & Sendable>: Equatable, Sendable {
    public let id: ID
    public let start: Int
    public let end: Int
    /// 0 ..< columnCount: items that overlap sit side by side.
    public let column: Int
    public let columnCount: Int
}

public enum TimelineLayout {
    /// Side-by-side columns for overlapping items. Short items count as `minimumMinutes` long
    /// so their blocks stay tall enough to read and tap.
    public static func layout<ID: Hashable & Sendable>(_ items: [TimedItem<ID>], minimumMinutes: Int = 30) -> [TimedPlacement<ID>] {
        let sorted = items
            .map { (item: $0, end: max($0.end, min($0.start + minimumMinutes, 24 * 60))) }
            .sorted { $0.item.start != $1.item.start ? $0.item.start < $1.item.start : $0.end > $1.end }
        var result: [TimedPlacement<ID>] = []
        var cluster: [(item: TimedItem<ID>, end: Int, column: Int)] = []
        var clusterEnd = 0

        func flush() {
            let count = (cluster.map(\.column).max() ?? 0) + 1
            for entry in cluster {
                result.append(TimedPlacement(id: entry.item.id, start: entry.item.start, end: entry.end,
                                             column: entry.column, columnCount: count))
            }
            cluster = []
        }
        for entry in sorted {
            if !cluster.isEmpty && entry.item.start >= clusterEnd { flush() }
            var column = 0
            while cluster.contains(where: { $0.column == column && $0.end > entry.item.start }) { column += 1 }
            cluster.append((entry.item, entry.end, column))
            clusterEnd = cluster.count == 1 ? entry.end : max(clusterEnd, entry.end)
        }
        flush()
        return result
    }
}
