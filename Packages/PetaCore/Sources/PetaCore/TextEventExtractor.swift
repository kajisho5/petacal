import Foundation

/// An event found in pasted text. The person checks and edits it before anything is saved.
public struct ExtractedEvent: Equatable, Sendable {
    public var title: String
    public var day: DayKey
    /// nil means an all-day event.
    public var start: QuickAddParser.Time?
    public var end: QuickAddParser.Time?

    public init(title: String, day: DayKey, start: QuickAddParser.Time? = nil, end: QuickAddParser.Time? = nil) {
        self.title = title
        self.day = day
        self.start = start
        self.end = end
    }
}

/// Finds events in a pasted message: one per sentence that has a date. Plain pattern matching, no AI,
/// so titles are rough and meant to be corrected on the confirmation screen.
public enum TextEventExtractor {
    public static let untitled = "予定"
    private static let breaks: Set<Character> = ["\n", "。", "！", "!", "？", "?"]
    private static let tails = [
        "からでお願いします", "でお願いします", "をお願いします", "お願いします", "スタートです", "開始です",
        "になります", "となります", "の予定です", "予定です", "です", "ます", "スタート", "開始", "から", "より",
    ]
    private static let edge = CharacterSet(charactersIn: " 、,：:・-—「」（）()　")

    public static func extract(_ rawText: String, now: Date, calendar: Calendar) -> [ExtractedEvent] {
        let text = JapaneseDateParser.normalize(rawText)
        var events: [ExtractedEvent] = []
        for sentence in text.split(whereSeparator: { breaks.contains($0) }) {
            let parsed = QuickAddParser.parse(String(sentence), now: now, calendar: calendar)
            guard let day = parsed.day else { continue }
            events.append(ExtractedEvent(title: clean(parsed.title), day: day, start: parsed.start, end: parsed.end))
        }
        return events
    }

    /// Drops polite endings, leftover particles and punctuation, and keeps the title short.
    static func clean(_ raw: String) -> String {
        var title = raw.trimmingCharacters(in: edge)
        var changed = true
        while changed {
            changed = false
            for tail in tails where title.hasSuffix(tail) {
                title = String(title.dropLast(tail.count)).trimmingCharacters(in: edge)
                changed = true
            }
            for particle in ["は", "に", "の", "を", "で", "が"] where title.hasSuffix(particle) {
                title = String(title.dropLast()).trimmingCharacters(in: edge)
                changed = true
            }
        }
        title = title.split(separator: " ").joined(separator: " ")
        if title.isEmpty { return untitled }
        return title.count > 40 ? String(title.prefix(40)) : title
    }
}
