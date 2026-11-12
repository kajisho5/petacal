import Foundation

/// The answer of the on-device model for one event, and the checks before any of it is shown.
/// The model only suggests a title and a place. Dates, times and amounts never come from it.
public struct AIReply: Equatable, Sendable {
    public var title: String?
    public var place: String?

    public init(title: String? = nil, place: String? = nil) {
        self.title = title
        self.place = place
    }

    public static let maxLength = 40
    private static let empties: Set<String> = ["なし", "無し", "不明", "特になし", "-", "ー", "なし。", "None", "none", "N/A"]
    private static let wrappers = CharacterSet(charactersIn: " 　\t「」『』\"'“”・-*")

    /// Reads the two lines the model is asked for: 「題名: …」 and 「場所: …」. Anything else is ignored.
    public static func parse(_ text: String) -> AIReply {
        var reply = AIReply()
        for line in text.split(whereSeparator: \.isNewline) {
            guard let colon = line.firstIndex(where: { $0 == ":" || $0 == "：" }) else { continue }
            let key = line[..<colon].trimmingCharacters(in: wrappers)
            let value = line[line.index(after: colon)...].trimmingCharacters(in: wrappers)
            guard !value.isEmpty, !empties.contains(value) else { continue }
            switch key {
            case "題名", "タイトル", "件名": if reply.title == nil { reply.title = value }
            case "場所", "会場": if reply.place == nil { reply.place = value }
            default: break
            }
        }
        return reply
    }

    /// What may be shown: the model's title if it is usable (otherwise the one cut out mechanically),
    /// and a place only when those exact words are in the original text (so the model cannot invent one).
    public static func checked(_ reply: AIReply, fallbackTitle: String, fullText: String) -> (title: String, place: String) {
        var title = fallbackTitle
        if let suggested = reply.title, suggested.count <= maxLength {
            title = suggested
        }
        var place = ""
        if let suggested = reply.place, suggested.count <= maxLength {
            let haystack = JapaneseDateParser.normalize(fullText)
            if fullText.contains(suggested) || haystack.contains(JapaneseDateParser.normalize(suggested)) {
                place = suggested
            }
        }
        return (title, place)
    }
}

/// The on-device model's suggestion for a record (from the text of a receipt or a payout screen):
/// a short title and a 種目. The amount, its direction and the date never come from the model.
public struct RecordAIReply: Equatable, Sendable {
    public var title: String?
    public var category: String?

    public init(title: String? = nil, category: String? = nil) {
        self.title = title
        self.category = category
    }

    public static let maxTitle = 20
    public static let maxCategory = 12
    private static let empties: Set<String> = ["なし", "無し", "不明", "特になし", "-", "ー", "None", "none", "N/A"]
    private static let wrappers = CharacterSet(charactersIn: " 　\t「」『』\"'“”・-*")

    /// Reads 「題名: …」 and 「種目: …」. Anything else is ignored.
    public static func parse(_ text: String) -> RecordAIReply {
        var reply = RecordAIReply()
        for line in text.split(whereSeparator: \.isNewline) {
            guard let colon = line.firstIndex(where: { $0 == ":" || $0 == "：" }) else { continue }
            let key = line[..<colon].trimmingCharacters(in: wrappers)
            let value = line[line.index(after: colon)...].trimmingCharacters(in: wrappers)
            guard !value.isEmpty, !empties.contains(value) else { continue }
            switch key {
            case "題名", "タイトル", "件名": if reply.title == nil { reply.title = value }
            case "種目", "カテゴリ", "カテゴリー", "分類": if reply.category == nil { reply.category = value }
            default: break
            }
        }
        return reply
    }

    /// What may be shown. A title with money in it is dropped (amounts come from the receipt reader),
    /// and a 種目 the person already uses is written the way they wrote it.
    public static func checked(_ reply: RecordAIReply, known: [String]) -> RecordAIReply {
        var out = RecordAIReply()
        if let title = reply.title, title.count <= maxTitle,
           !title.contains("円"), !title.contains("¥"), !title.contains("￥"),
           title.filter(\.isNumber).count < 3 {
            out.title = title
        }
        if let category = reply.category, category.count <= maxCategory {
            out.category = known.first { $0 == category }
                ?? known.first { category.contains($0) || $0.contains(category) }
                ?? category
        }
        return out
    }
}
