import Foundation

public struct TimeRange: Equatable, Sendable {
    public var start: Date
    public var end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }

    public func overlaps(_ other: TimeRange) -> Bool {
        start < other.end && other.start < end
    }
}

public struct SlotRequest: Equatable, Sendable {
    public var firstDay: DayKey
    public var lastDay: DayKey
    /// Length of the meeting.
    public var minutes: Int
    public var dayStartHour: Int
    public var dayEndHour: Int
    public var weekdaysOnly: Bool
    /// Candidate start times are aligned to this step.
    public var stepMinutes: Int
    public var limitPerDay: Int

    public init(firstDay: DayKey, lastDay: DayKey, minutes: Int = 60, dayStartHour: Int = 10, dayEndHour: Int = 18,
                weekdaysOnly: Bool = true, stepMinutes: Int = 30, limitPerDay: Int = 2) {
        self.firstDay = firstDay
        self.lastDay = lastDay
        self.minutes = minutes
        self.dayStartHour = dayStartHour
        self.dayEndHour = dayEndHour
        self.weekdaysOnly = weekdaysOnly
        self.stepMinutes = stepMinutes
        self.limitPerDay = limitPerDay
    }
}

/// Finds free time between busy events and writes the message to send. No AI involved.
public enum SlotFinder {
    public static func freeSlots(_ request: SlotRequest, busy: [TimeRange], calendar: Calendar) -> [TimeRange] {
        guard request.minutes > 0, request.stepMinutes > 0, request.dayEndHour > request.dayStartHour,
              var day = request.firstDay.date(calendar: calendar),
              let last = request.lastDay.date(calendar: calendar) else { return [] }
        var result: [TimeRange] = []
        var guardCount = 0
        while day <= last && guardCount < 370 {
            guardCount += 1
            let weekday = calendar.component(.weekday, from: day)
            let isWeekend = weekday == 1 || weekday == 7
            if !(request.weekdaysOnly && isWeekend),
               let open = calendar.date(byAdding: .hour, value: request.dayStartHour, to: day),
               let close = calendar.date(byAdding: .hour, value: request.dayEndHour, to: day) {
                var cursor = open
                var found = 0
                while found < request.limitPerDay {
                    let end = cursor.addingTimeInterval(TimeInterval(request.minutes * 60))
                    if end > close { break }
                    let slot = TimeRange(start: cursor, end: end)
                    if busy.contains(where: { $0.overlaps(slot) }) {
                        cursor = cursor.addingTimeInterval(TimeInterval(request.stepMinutes * 60))
                    } else {
                        result.append(slot)
                        found += 1
                        cursor = end
                    }
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }

    /// "11/17（火） 10:00〜11:00"
    public static func line(for slot: TimeRange, calendar: Calendar) -> String {
        let s = calendar.dateComponents([.month, .day, .weekday, .hour, .minute], from: slot.start)
        let e = calendar.dateComponents([.hour, .minute], from: slot.end)
        let weekday = DayKey.weekdaySymbolsJa[((s.weekday ?? 1) - 1) % 7]
        return "\(s.month ?? 1)/\(s.day ?? 1)（\(weekday)） \(clock(s.hour, s.minute))〜\(clock(e.hour, e.minute))"
    }

    public static func message(for slots: [TimeRange], calendar: Calendar) -> String {
        var lines = ["以下の日程はいかがでしょうか。"]
        lines.append(contentsOf: slots.map { "・" + line(for: $0, calendar: calendar) })
        lines.append("ご都合をお知らせください。")
        return lines.joined(separator: "\n")
    }

    static func clock(_ hour: Int?, _ minute: Int?) -> String {
        let m = minute ?? 0
        return "\(hour ?? 0):" + (m < 10 ? "0" : "") + "\(m)"
    }
}
