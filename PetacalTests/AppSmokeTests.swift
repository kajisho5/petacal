import Foundation
import PetaCore
import Testing
@testable import Petacal

/// Checks that the app target links against PetaCore and that month navigation data is sane.
@Suite struct AppSmokeTests {
    @Test func monthRefIsComparable() {
        #expect(MonthRef(year: 2026, month: 11) == MonthRef(year: 2026, month: 11))
        #expect(MonthRef(year: 2026, month: 11) != MonthRef(year: 2026, month: 12))
    }

    @Test func coreIsLinked() {
        #expect(Yen.signed(5400) == "+5,400円")
    }

    @Test func colorChoicesFallBackInOrder() {
        let defaults = UserDefaults(suiteName: "petacal-tests-colors")!
        defaults.removePersistentDomain(forName: "petacal-tests-colors")
        let colors = ColorStore(defaults: defaults)
        let item = EventItem(id: "e1|0", eventIdentifier: "e1", title: "打ち合わせ",
                             start: Date(timeIntervalSince1970: 0), end: Date(timeIntervalSince1970: 3600),
                             isAllDay: false, calendarID: "c1", calendarTitle: "仕事",
                             calendarColor: RGB(red: 0, green: 0.5, blue: 1), location: nil)
        #expect(colors.preset(for: item) == nil)
        colors.setCalendar("c1", preset: 25)
        #expect(colors.preset(for: item)?.id == 25)
        colors.setEvent("e1", preset: 35)
        #expect(colors.preset(for: item)?.name == "ピンク・あざやか")
        colors.setEvent("e1", preset: nil)
        #expect(colors.preset(for: item)?.id == 25)
        #expect(ColorStore(defaults: defaults).calendarChoices == ["c1": 25])
    }

    @Test func eventDaysAndMinutes() {
        let store = CalendarStore()
        let calendar = store.calendar
        let day = DayKey(year: 2026, month: 11, day: 11)
        let start = calendar.date(byAdding: .hour, value: 22, to: day.date(calendar: calendar)!)!
        let item = EventItem(id: "e2|0", eventIdentifier: "e2", title: "夜の作業",
                             start: start, end: start.addingTimeInterval(2 * 3600),
                             isAllDay: false, calendarID: "c1", calendarTitle: "仕事",
                             calendarColor: RGB(red: 0, green: 0.5, blue: 1), location: nil)
        // Ends exactly at midnight: it belongs to the 11th only.
        #expect(store.days(of: item).end == day)
        #expect(store.minutes(of: item, on: day)?.start == 22 * 60)
        #expect(store.minutes(of: item, on: day)?.end == 24 * 60)
        #expect(store.timeText(item) == "22:00〜0:00")
    }
}
