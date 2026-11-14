import Foundation

/// A colour as three 0...1 components.
public struct RGB: Hashable, Sendable, Codable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// From hue (0...1), lightness and saturation — the same formula the design mocks use.
    public init(hue: Double, lightness l: Double, saturation s: Double) {
        if s == 0 {
            self.init(red: l, green: l, blue: l)
            return
        }
        let m2 = l <= 0.5 ? l * (1 + s) : l + s - l * s
        let m1 = 2 * l - m2
        func channel(_ h: Double) -> Double {
            var hue = h.truncatingRemainder(dividingBy: 1)
            if hue < 0 { hue += 1 }
            if hue < 1.0 / 6 { return m1 + (m2 - m1) * hue * 6 }
            if hue < 0.5 { return m2 }
            if hue < 2.0 / 3 { return m1 + (m2 - m1) * (2.0 / 3 - hue) * 6 }
            return m1
        }
        self.init(red: channel(hue + 1.0 / 3), green: channel(hue), blue: channel(hue - 1.0 / 3))
    }

    /// "#RRGGBB"
    public var hex: String {
        func byte(_ v: Double) -> Int { min(255, max(0, Int((v * 255).rounded()))) }
        return String(format: "#%02X%02X%02X", byte(red), byte(green), byte(blue))
    }

    /// Relative luminance (WCAG), used to pick a black or white mark on top of the colour.
    public var luminance: Double {
        func linear(_ v: Double) -> Double { v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }
}

/// One of the 50 colours people can pick for a calendar, a record type or a single event.
public struct ColorPreset: Equatable, Sendable, Identifiable {
    /// 0...49 = family * 5 + tone. This number is what gets saved.
    public let id: Int
    public let family: Int
    public let tone: Int
    /// For example "ピンク・あざやか" (read aloud by VoiceOver).
    public let name: String
    public let light: RGB
    public let dark: RGB
}

/// 10 families x 5 tones. The values match design/build.py `preset()`.
public enum ColorPalette {
    public static let familyNames = ["赤", "オレンジ", "黄", "緑", "青緑", "青", "紫", "ピンク", "茶", "グレー"]
    public static let toneNames = ["あざやか", "明るい", "うすい", "こい", "くすみ"]

    private static let families: [(hue: Double, strength: Double)] = [
        (355, 1.0), (25, 1.0), (46, 1.0), (135, 0.85), (176, 0.9),
        (212, 1.0), (268, 0.85), (328, 0.95), (24, 0.5), (215, 0.1),
    ]
    private static let tones: [(saturation: Double, light: Double, dark: Double)] = [
        (0.78, 0.48, 0.56), (0.85, 0.62, 0.68), (0.70, 0.78, 0.80), (0.75, 0.33, 0.44), (0.32, 0.52, 0.58),
    ]

    public static let presets: [ColorPreset] = (0..<50).map { id in
        let family = id / 5
        let tone = id % 5
        var hue = families[family].hue
        var strength = families[family].strength
        var light = tones[tone].light
        var dark = tones[tone].dark
        if family == 8 {            // brown: a little darker
            light *= 0.85
            dark *= 0.9
        }
        if family == 9 && tone == 4 {   // warm grey
            hue = 40
            strength = 0.4
        }
        let saturation = tones[tone].saturation * strength
        return ColorPreset(
            id: id, family: family, tone: tone,
            name: "\(familyNames[family])・\(toneNames[tone])",
            light: RGB(hue: hue / 360, lightness: light, saturation: saturation),
            dark: RGB(hue: hue / 360, lightness: dark, saturation: saturation))
    }

    public static func preset(_ id: Int) -> ColorPreset? {
        presets.indices.contains(id) ? presets[id] : nil
    }
}
