import Foundation

/// Groups photos by the day they were taken. Photos without a date go to `today`.
public enum PhotoGrouper {
    public struct Group: Equatable, Sendable {
        public var day: DayKey
        /// Indices into the input array, in input order.
        public var indices: [Int]
    }

    public static func group(takenAt: [Date?], today: Date, calendar: Calendar) -> [Group] {
        var byDay: [DayKey: [Int]] = [:]
        for (index, date) in takenAt.enumerated() {
            byDay[DayKey(date: date ?? today, calendar: calendar), default: []].append(index)
        }
        return byDay.keys.sorted().map { Group(day: $0, indices: byDay[$0] ?? []) }
    }
}
