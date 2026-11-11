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
