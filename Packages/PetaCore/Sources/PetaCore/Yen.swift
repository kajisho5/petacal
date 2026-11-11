import Foundation

/// Yen amounts as text. Signed amounts always carry a sign so that colour is never the only cue.
public enum Yen {
    /// 12100 -> "12,100"
    public static func grouped(_ value: Int) -> String {
        let digits = String(value.magnitude)
        var out = ""
        for (i, ch) in digits.enumerated() {
            if i > 0 && (digits.count - i) % 3 == 0 { out.append(",") }
            out.append(ch)
        }
        return out
    }

    /// 5400 -> "+5,400円", -2000 -> "−2,000円" (U+2212), 0 -> "0円"
    public static func signed(_ value: Int, unit: Bool = true) -> String {
        let sign = value > 0 ? "+" : (value < 0 ? "\u{2212}" : "")
        return sign + grouped(value) + (unit ? "円" : "")
    }

    /// 12100 -> "12,100円" (the sign is dropped; use for spending totals)
    public static func plain(_ value: Int) -> String {
        grouped(value) + "円"
    }
}
