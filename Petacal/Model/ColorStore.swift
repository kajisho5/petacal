import Observation
import PetaCore
import SwiftUI

/// The colours people picked (design-spec B-2 色分け). Kept in this app only; the device calendars are not changed.
/// Saved on this device for now; iCloud sync arrives together with records (stage 3).
@Observable
final class ColorStore {
    private(set) var calendarChoices: [String: Int]
    private(set) var eventChoices: [String: Int]
    private let defaults: UserDefaults

    private static let calendarKey = "colors.calendar"
    private static let eventKey = "colors.event"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        calendarChoices = (defaults.dictionary(forKey: ColorStore.calendarKey) as? [String: Int]) ?? [:]
        eventChoices = (defaults.dictionary(forKey: ColorStore.eventKey) as? [String: Int]) ?? [:]
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
