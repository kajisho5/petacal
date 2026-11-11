import Observation
import PetaCore
import SwiftUI

/// The colours people picked (design-spec B-2 色分け). Kept in this app only; the device calendars are not changed.
/// Saved on this device for now; iCloud sync arrives together with records (stage 3).
@Observable
final class ColorStore {
    private(set) var calendarChoices: [String: Int]
    private(set) var eventChoices: [String: Int]
    /// Record kind raw value -> preset. Kinds without a choice use `kindDefaults`.
    private(set) var kindChoices: [String: Int]
    private let defaults: UserDefaults

    /// 収支: 青緑・こい / 推し活・趣味: ピンク・あざやか / メモ: グレー・あざやか
    static let kindDefaults: [RecordKind: Int] = [.balance: 23, .oshi: 35, .free: 45]
    private static let kindKey = "colors.kind"

    private static let calendarKey = "colors.calendar"
    private static let eventKey = "colors.event"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        calendarChoices = (defaults.dictionary(forKey: ColorStore.calendarKey) as? [String: Int]) ?? [:]
        eventChoices = (defaults.dictionary(forKey: ColorStore.eventKey) as? [String: Int]) ?? [:]
        kindChoices = (defaults.dictionary(forKey: ColorStore.kindKey) as? [String: Int]) ?? [:]
    }

    func setKind(_ kind: RecordKind, preset: Int?) {
        kindChoices[kind.rawValue] = preset
        defaults.set(kindChoices, forKey: ColorStore.kindKey)
    }

    func preset(for kind: RecordKind) -> ColorPreset {
        let id = kindChoices[kind.rawValue] ?? ColorStore.kindDefaults[kind] ?? 45
        return ColorPalette.preset(id) ?? ColorPalette.presets[45]
    }

    func color(for kind: RecordKind, scheme: ColorScheme) -> Color {
        Color(preset(for: kind), scheme: scheme)
    }

    func setCalendar(_ id: String, preset: Int?) {
        calendarChoices[id] = preset
        defaults.set(calendarChoices, forKey: ColorStore.calendarKey)
    }

    func setEvent(_ id: String, preset: Int?) {
        eventChoices[id] = preset
        defaults.set(eventChoices, forKey: ColorStore.eventKey)
    }

    /// The preset in effect for an event: its own, else its calendar's, else nil (the calendar's original colour).
    func preset(for item: EventItem) -> ColorPreset? {
        (eventChoices[item.eventIdentifier] ?? calendarChoices[item.calendarID]).flatMap(ColorPalette.preset)
    }

    func color(for item: EventItem, scheme: ColorScheme) -> Color {
        guard let preset = preset(for: item) else { return Color(item.calendarColor) }
        return Color(preset, scheme: scheme)
    }

    func color(for info: CalendarInfo, scheme: ColorScheme) -> Color {
        guard let preset = calendarChoices[info.id].flatMap(ColorPalette.preset) else { return Color(info.color) }
        return Color(preset, scheme: scheme)
    }
}

extension Color {
    init(_ rgb: RGB) {
        self.init(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }

    init(_ preset: ColorPreset, scheme: ColorScheme) {
        self.init(scheme == .dark ? preset.dark : preset.light)
    }
}
