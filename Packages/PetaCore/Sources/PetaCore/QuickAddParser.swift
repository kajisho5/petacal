import Foundation

/// Reads a one-line entry such as "明日15時 打ち合わせ": pulls out the date and time words and
/// leaves the rest as the title. Plain pattern matching, no AI.
public enum QuickAddParser {
    public struct Time: Equatable, Sendable {
        public var hour: Int
        public var minute: Int
        public init(hour: Int, minute: Int) {
            self.hour = hour
            self.minute = minute
        }
        /// Minutes from midnight.
        public var minutes: Int { hour * 60 + minute }
    }

    public struct Result: Equatable, Sendable {
        /// The entry without the date and time words.
        public var title: String
        public var day: DayKey?
        public var start: Time?
        /// Only when the entry had a range such as "15時〜17時".
        public var end: Time?
        /// The words that were read as date and time, in order (shown back to the person).
        public var matched: [String]
    }

    private static let weekdayTail = #"(?:\s*[(（][月火水木金土日][)）])?"#
    private static let datePatterns = [
        #"\d{4}年\s*\d{1,2}月\s*\d{1,2}日"#,
        #"\d{1,2}月\s*\d{1,2}日"#,
        #"(?<![\d/.])\d{1,2}/\d{1,2}(?![\d/])"#,
        #"(?<![\d月])\d{1,2}日(?!間)"#,
        "明後日|あさって|明日|あした|今日|本日",
    ]
    private static let timePattern = #"(?:(?:午前|午後|朝|夜)\s*)?\d{1,2}時(?:\d{1,2}分|半)?|(?<!\d)\d{1,2}:\d{2}(?!\d)"#

    public static func parse(_ rawText: String, now: Date, calendar: Calendar) -> Result {
        var text = JapaneseDateParser.normalize(rawText)
        var matched: [String] = []
        var day: DayKey?
        var start: Time?
        var end: Time?

        // The earliest date expression.
        var best: NSRange?
        for pattern in datePatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern + weekdayTail + "(?:の|に|は)?") else { continue }
            let all = NSRange(location: 0, length: (text as NSString).length)
            if let match = regex.firstMatch(in: text, range: all),
               best == nil || match.range.location < best!.location {
                best = match.range
            }
        }
        if let range = best {
            let words = (text as NSString).substring(with: range)
            if let found = JapaneseDateParser.parse(words, now: now, calendar: calendar).first?.day {
                day = found
                matched.append(trimParticle(words))
                text = (text as NSString).replacingCharacters(in: range, with: " ")
            }
        }

        // The first time, and an end time when it follows a range mark.
        if let regex = try? NSRegularExpression(
            pattern: "(\(timePattern))(?:\\s*[〜~ー－-]\\s*(\(timePattern)))?(?:から|より|に)?") {
            let ns = text as NSString
            if let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
               let first = JapaneseDateParser.firstTime(in: ns.substring(with: match.range(at: 1))) {
                start = Time(hour: first.hour, minute: first.minute)
                var words = ns.substring(with: match.range(at: 1))
                if match.range(at: 2).location != NSNotFound,
                   let second = JapaneseDateParser.firstTime(in: ns.substring(with: match.range(at: 2))) {
                    var candidate = Time(hour: second.hour, minute: second.minute)
                    // "3時〜5時" after "午後": carry the afternoon over when the end would be before the start.
                    if candidate.minutes <= start!.minutes && candidate.hour < 12 { candidate.hour += 12 }
                    if candidate.minutes > start!.minutes && candidate.hour <= 24 {
                        end = candidate
                        words = ns.substring(with: NSRange(location: match.range(at: 1).location,
                                                           length: NSMaxRange(match.range(at: 2)) - match.range(at: 1).location))
                    }
                }
                matched.append(words)
                text = ns.replacingCharacters(in: match.range, with: " ")
            }
        }

        let title = text
            .split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" })
            .joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: "、,。 "))
        return Result(title: title, day: day, start: start, end: end, matched: matched)
    }

    private static func trimParticle(_ words: String) -> String {
        var out = words.trimmingCharacters(in: .whitespaces)
        for particle in ["の", "に", "は"] where out.hasSuffix(particle) && out.count > 1 {
            out.removeLast()
            break
        }
        return out
    }
}
