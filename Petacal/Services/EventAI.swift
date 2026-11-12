import Foundation
import FoundationModels
import PetaCore

/// The on-device model (Apple's Foundation Models). It only tidies a title and finds the place.
/// Dates, times and amounts are worked out by PetaCore, never by the model, and nothing leaves the device.
enum EventAI {
    /// False on devices without Apple Intelligence, while the model is still downloading, and on simulators.
    static var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    private static let instructions = """
        あなたは、予定の連絡文から「題名」と「場所」を抜き出す係です。
        必ず次の2行だけで答えます。ほかの文は書きません。
        題名: （15文字以内。日付・時刻・あいさつ・お願いの言葉は入れない）
        場所: （文章に書かれている場所をそのまま。書かれていなければ「なし」）
        """

    private static let recordInstructions = """
        あなたは、レシートや払い戻しの画面の文字から、家計簿の「題名」と「種目」を考える係です。
        必ず次の2行だけで答えます。ほかの文は書きません。
        題名: （15文字以内。お店や中身が分かる短い名前。金額・日付・時刻は入れない）
        種目: （食費、日用品、交通費、趣味、ライブ・音楽、副収入 などの短い分類。分からなければ「なし」）
        """

    /// A title and a 種目 for a record, from the text read off a photo. nil when unavailable or unusable.
    static func recordDraft(text: String, known: [String]) async -> RecordAIReply? {
        guard isAvailable, !text.isEmpty else { return nil }
        let session = LanguageModelSession(instructions: recordInstructions)
        var prompt = "写真の文字:\n\(text.prefix(1500))"
        if !known.isEmpty { prompt += "\n\nこれまでに使った種目: " + known.prefix(12).joined(separator: "、") }
        guard let response = try? await session.respond(to: prompt) else { return nil }
        let checked = RecordAIReply.checked(RecordAIReply.parse(response.content), known: known)
        return checked.title == nil && checked.category == nil ? nil : checked
    }

    /// A better title and the place for one event, or nil when the model is unavailable or gave nothing usable.
    static func details(sentence: String, fullText: String, fallbackTitle: String) async -> (title: String, place: String)? {
        guard isAvailable else { return nil }
        // A fresh session each time: the events are independent and the context stays small.
        let session = LanguageModelSession(instructions: instructions)
        let prompt = "文章全体:\n\(fullText.prefix(1500))\n\n対象の文:\n\(sentence)"
        guard let response = try? await session.respond(to: prompt) else { return nil }
        let reply = AIReply.parse(response.content)
        guard reply.title != nil || reply.place != nil else { return nil }
        return AIReply.checked(reply, fallbackTitle: fallbackTitle, fullText: fullText)
    }
}
