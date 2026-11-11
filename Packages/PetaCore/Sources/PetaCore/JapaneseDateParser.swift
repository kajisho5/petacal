import Foundation

/// Finds dates and times written in Japanese text ("18日(水)15時から", "11/25 19:00", "明日の午後3時半").
/// This is plain pattern matching, not AI: it gives the on-device model a head start, and it is the
/// fallback on devices without Apple Intelligence.
public enum JapaneseDateParser {
    public struct Moment: Equatable, Sendable {
        public var day: DayKey
        public var hour: Int?
        public var minute: Int?
        /// UTF-16 offset of the date expression in the normalized text (used to keep the order).
        public var offset: Int

        public init(day: DayKey, hour: Int? = nil, minute: Int? = nil, offset: Int = 0) {
            self.day = day
            self.hour = hour
            self.minute = minute
            self.offset = offset
        }
    }

    /// Full-width digits and punctuation to ASCII.
    public static func normalize(_ text: String) -> String {
        var out = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0xFF10...0xFF19: out.append(Unicode.Scalar(scalar.value - 0xFF10 + 0x30)!)
            case 0xFF1A: out.append(":")
            case 0xFF0F: out.append("/")
            case 0x3000: out.append(" ")
            default: out.append(scalar)
            }
        }
        return String(out)
    }

    public static func parse(_ rawText: String, now: Date, calendar: Calendar) -> [Moment] {
        let text = normalize(rawText)
        let ns = NSString(string: text)
        let today = DayKey(date: now, calendar: calendar)

        struct Hit { var range: NSRange; var day: DayKey }
        var hits: [Hit] = []
        func taken(_ range: NSRange) -> Bool {
            hits.contains { NSIntersectionRange($0.range, range).length > 0 }
        }
        func number(_ match: NSTextCheckingResult, _ group: Int) -> Int? {
            let r = match.range(at: group)
            return r.location == NSNotFound ? nil : Int(ns.substring(with: r))
        }
        func each(_ pattern: String, _ body: (NSTextCheckingResult) -> DayKey?) {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
            for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) where !taken(match.range) {
                if let day = body(match), day.date(calendar: calendar) != nil {
                    hits.append(Hit(range: match.range, day: day))
                }
            }
        }

        // 2026年11月18日
        each(#"(\d{4})年\s*(\d{1,2})月\s*(\d{1,2})日"#) { m in
            guard let y = number(m, 1), let mo = number(m, 2), let d = number(m, 3) else { return nil }
            return DayKey(year: y, month: mo, day: d)
        }
        // 11月18日 / 11/18 (no year: this year, or next year when that is more than a month ago)
        let monthDay: (NSTextCheckingResult) -> DayKey? = { m in
            guard let mo = number(m, 1), let d = number(m, 2), (1...12).contains(mo) else { return nil }
            return resolve(month: mo, day: d, today: today, calendar: calendar)
        }
        each(#"(\d{1,2})月\s*(\d{1,2})日"#, monthDay)
        each(#"(?<![\d/.])(\d{1,2})/(\d{1,2})(?![\d/])"#, monthDay)
        // 18日 (day only: this month when it is today or later, otherwise next month)
        each(#"(?<![\d月])(\d{1,2})日(?!間)"#) { m in
            guard let d = number(m, 1), (1...31).contains(d) else { return nil }
            // Try this month first (when the day is still ahead), then the following months,
            // skipping months that have no such day (the 31st in November).
            for offset in (d >= today.day ? 0 : 1)...3 {
                let ym = MonthGrid.shifted(year: today.year, month: today.month, by: offset)
                let candidate = DayKey(year: ym.year, month: ym.month, day: d)
                if candidate.date(calendar: calendar) != nil { return candidate }
            }
            return nil
        }
        // 今日 / 明日 / 明後日
        for (word, offset) in [("明後日", 2), ("あさって", 2), ("明日", 1), ("あした", 1), ("今日", 0), ("本日", 0)] {
            each(NSRegularExpression.escapedPattern(for: word)) { _ in
                calendar.date(byAdding: .day, value: offset, to: now).map { DayKey(date: $0, calendar: calendar) }
            }
        }

        hits.sort { $0.range.location < $1.range.location }
        var moments: [Moment] = []
        for (index, hit) in hits.enumerated() {
            let from = hit.range.location + hit.range.length
            let to = index + 1 < hits.count ? hits[index + 1].range.location : ns.length
            let time = firstTime(in: ns.substring(with: NSRange(location: from, length: max(0, to - from))))
            moments.append(Moment(day: hit.day, hour: time?.hour, minute: time?.minute, offset: hit.range.location))
        }
        return moments
    }

    static func resolve(month: Int, day: Int, today: DayKey, calendar: Calendar) -> DayKey? {
        let thisYear = DayKey(year: today.year, month: month, day: day)
        guard let date = thisYear.date(calendar: calendar) else { return nil }
        guard let now = today.date(calendar: calendar) else { return thisYear }
        let daysAgo = calendar.dateComponents([.day], from: date, to: now).day ?? 0
        return daysAgo > 31 ? DayKey(year: today.year + 1, month: month, day: day) : thisYear
    }

    /// The first time of day in the text: "15時", "15時30分", "午後3時半", "19:00".
    static func firstTime(in text: String) -> (hour: Int, minute: Int)? {
        let ns = NSString(string: text)
        let all = NSRange(location: 0, length: ns.length)
        var best: (location: Int, hour: Int, minute: Int)?
        func consider(_ location: Int, _ hour: Int, _ minute: Int) {
            guard (0...24).contains(hour), (0...59).contains(minute), !(hour == 24 && minute > 0) else { return }
            if best == nil || location < best!.location { best = (location, hour, minute) }
        }
        if let regex = try? NSRegularExpression(pattern: #"(午前|午後|朝|夜)?\s*(\d{1,2})時(?:(\d{1,2})分|(半))?"#) {
            for m in regex.matches(in: text, range: all) {
                guard var hour = Int(ns.substring(with: m.range(at: 2))) else { continue }
                let prefix = m.range(at: 1).location == NSNotFound ? "" : ns.substring(with: m.range(at: 1))
                if (prefix == "午後" || prefix == "夜") && hour < 12 { hour += 12 }
                var minute = 0
                if m.range(at: 3).location != NSNotFound { minute = Int(ns.substring(with: m.range(at: 3))) ?? 0 }
                if m.range(at: 4).location != NSNotFound { minute = 30 }
                consider(m.range.location, hour, minute)
            }
        }
        if let regex = try? NSRegularExpression(pattern: #"(?<!\d)(\d{1,2}):(\d{2})(?!\d)"#) {
            for m in regex.matches(in: text, range: all) {
                guard let hour = Int(ns.substring(with: m.range(at: 1))),
                      let minute = Int(ns.substring(with: m.range(at: 2))) else { continue }
                consider(m.range.location, hour, minute)
            }
        }
        return best.map { ($0.hour, $0.minute) }
    }
}
