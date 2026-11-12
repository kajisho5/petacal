import Foundation

/// What a receipt, a payout screen or a statement says, read from its text (no AI).
/// Everything here is only a suggestion: the record editor shows it and the person confirms it.
public struct ReceiptDraft: Equatable, Sendable {
    /// The amount without its sign.
    public var amount: Int?
    /// true: money in, false: money out, nil: the text does not say.
    public var isPlus: Bool?
    public var day: DayKey?

    public init(amount: Int? = nil, isPlus: Bool? = nil, day: DayKey? = nil) {
        self.amount = amount
        self.isPlus = isPlus
        self.day = day
    }

    public var isEmpty: Bool { amount == nil && day == nil }
}

public enum ReceiptReader {
    /// Words on the line of the money that came in.
    static let plusWords = ["払戻", "払い戻し", "的中", "入金", "受取", "受け取り", "売上", "売り上げ", "収入",
                            "利益", "獲得", "還元", "振込", "給与", "精算額"]
    /// Words on the line of the money that went out.
    static let minusWords = ["合計", "お会計", "会計", "支払", "お支払", "ご利用", "利用金額", "請求", "代金",
                             "購入", "お買上", "税込", "小計", "引落", "損失"]
    static let maxAmount = 100_000_000

    private static let yenPattern = try! NSRegularExpression(
        pattern: #"([+\-−])?\s*[¥￥]\s*([0-9][0-9,]*)|([+\-−])?\s*([0-9][0-9,]*)\s*円"#)
    private static let signedPattern = try! NSRegularExpression(pattern: #"(?<![0-9,])([+\-−])\s*([0-9]{1,3}(?:,[0-9]{3})+|[0-9]+)(?![0-9,])"#)

    private struct Found {
        var value: Int
        var sign: Bool?
        var line: String
    }

    public static func read(_ rawText: String, now: Date, calendar: Calendar) -> ReceiptDraft {
        let text = JapaneseDateParser.normalize(rawText)
            .replacingOccurrences(of: "，", with: ",")
            .replacingOccurrences(of: "＋", with: "+")
            .replacingOccurrences(of: "－", with: "-")
        var found: [Found] = []
        for line in text.split(whereSeparator: \.isNewline).map(String.init) {
            let range = NSRange(line.startIndex..., in: line)
            var hit = false
            for match in yenPattern.matches(in: line, range: range) {
                let signGroup = match.range(at: 1).location != NSNotFound ? 1 : 3
                let numberGroup = match.range(at: 2).location != NSNotFound ? 2 : 4
                if let value = number(line, match.range(at: numberGroup)) {
                    found.append(Found(value: value, sign: sign(line, match.range(at: signGroup)), line: line))
                    hit = true
                }
            }
            // "+5,400" with no 円 or ¥ (trading apps).
            if !hit {
                for match in signedPattern.matches(in: line, range: range) {
                    if let value = number(line, match.range(at: 2)), value >= 100 {
                        found.append(Found(value: value, sign: sign(line, match.range(at: 1)), line: line))
                    }
                }
            }
        }
        var draft = ReceiptDraft()
        draft.day = JapaneseDateParser.parse(text, now: now, calendar: calendar).first?.day
        guard !found.isEmpty else { return draft }

        // The amount on a line that says what it is wins; among those, the largest (合計 over 小計).
        let keyed = found.filter { item in (plusWords + minusWords).contains { item.line.contains($0) } }
        let best = (keyed.isEmpty ? found : keyed).max { $0.value < $1.value }!
        draft.amount = best.value
        if let sign = best.sign {
            draft.isPlus = sign
        } else if plusWords.contains(where: { best.line.contains($0) }) {
            draft.isPlus = true
        } else if minusWords.contains(where: { best.line.contains($0) }) {
            draft.isPlus = false
        }
        return draft
    }

    private static func number(_ line: String, _ range: NSRange) -> Int? {
        guard range.location != NSNotFound, let r = Range(range, in: line) else { return nil }
        guard let value = Int(line[r].filter(\.isNumber)), value > 0, value <= maxAmount else { return nil }
        return value
    }

    private static func sign(_ line: String, _ range: NSRange) -> Bool? {
        guard range.location != NSNotFound, let r = Range(range, in: line) else { return nil }
        return line[r] == "+"
    }
}

/// Which budget notice to send now. A notice goes out once per level and month: 8 割 first, then 超過.
public enum BudgetAlert {
    public static func toSend(_ usage: BudgetUsage, alreadySent: BudgetUsage.Level?) -> BudgetUsage.Level? {
        let level = usage.level
        guard level != .ok else { return nil }
        guard let sent = alreadySent else { return level }
        return rank(level) > rank(sent) ? level : nil
    }

    static func rank(_ level: BudgetUsage.Level) -> Int {
        switch level {
        case .ok: 0
        case .near: 1
        case .over: 2
        }
    }
}
