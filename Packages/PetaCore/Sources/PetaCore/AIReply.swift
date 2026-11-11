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
