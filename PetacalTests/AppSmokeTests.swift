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

    @Test func sampleStoreOffersCalendarsAndSkipsSaving() async throws {
        let item = EventItem(id: "e3|0", eventIdentifier: "e3", title: "打ち合わせ",
                             start: Date(timeIntervalSince1970: 0), end: Date(timeIntervalSince1970: 3600),
                             isAllDay: false, calendarID: "c1", calendarTitle: "仕事",
                             calendarColor: RGB(red: 0, green: 0.5, blue: 1), location: nil)
        let store = CalendarStore(sample: [item])
        #expect(store.writableCalendars.map(\.title) == ["仕事"])
        #expect(store.defaultCalendarID == "c1")
        let draft = QuickDraft(title: "新しい予定", start: Date(), end: Date(), isAllDay: true, calendarID: "c1")
        let saved = try await store.add(draft)
        #expect(saved == nil)   // sample stores never write to the device
        #expect(store.google == nil)
    }

    @Test func quickDraftsBecomeGoogleDraftsWithAnExclusiveEnd() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 9 * 3600)!
        let day = calendar.date(from: DateComponents(year: 2026, month: 11, day: 20))!
        let last = calendar.date(byAdding: .day, value: 2, to: day)!
        let draft = QuickDraft(title: "合宿", start: day, end: last, isAllDay: true, calendarID: "google:a@example.com|c")
        let google = GoogleEventDraft(draft, calendar: calendar)
        #expect(google.end == calendar.date(byAdding: .day, value: 3, to: day))
        let timed = QuickDraft(title: "打ち合わせ", start: day, end: day.addingTimeInterval(3600), isAllDay: false, calendarID: nil)
        #expect(GoogleEventDraft(timed, calendar: calendar).end == day.addingTimeInterval(3600))
    }

    @Test func hidingACalendarHidesItsEvents() {
        func item(_ id: String, _ calendarID: String) -> EventItem {
            EventItem(id: "\(id)|0", eventIdentifier: id, title: id, start: Date(timeIntervalSince1970: 0),
                      end: Date(timeIntervalSince1970: 3600), isAllDay: false, calendarID: calendarID,
                      calendarTitle: calendarID, calendarColor: RGB(red: 0, green: 0.5, blue: 1), location: nil)
        }
        let store = CalendarStore(sample: [item("a", "仕事"), item("b", "家族")])
        #expect(store.events.count == 2)
        store.setVisible("家族", false)
        #expect(store.events.map(\.eventIdentifier) == ["a"])
        #expect(store.writableCalendars.map(\.id) == ["仕事"])
        #expect(store.calendars.count == 2)      // still listed, so it can be switched back on
        store.setVisible("家族", true)
        #expect(store.events.count == 2)
    }

    @Test func recordKindsHaveDefaultColoursThatCanChange() {
        let defaults = UserDefaults(suiteName: "petacal-tests-kinds")!
        defaults.removePersistentDomain(forName: "petacal-tests-kinds")
        let colors = ColorStore(defaults: defaults)
        #expect(colors.preset(for: .oshi).name == "ピンク・あざやか")
        colors.setKind(.oshi, preset: 25)
        #expect(colors.preset(for: .oshi).id == 25)
        colors.setKind(.oshi, preset: nil)
        #expect(colors.preset(for: .oshi).id == 35)
    }

    @Test func undoRunsOnceAndClears() {
        let center = UndoCenter()
        var count = 0
        center.show("追加しました") { count += 1 }
        #expect(center.message == "追加しました")
        center.undo()
        center.undo()
        #expect(count == 1)
        #expect(center.message == nil)
    }

    @Test func recordsAddUpByDay() {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000))
        let records = [
            Record(day: day, kind: .balance, title: "入金", amount: 5400),
            Record(day: day, kind: .oshi, title: "買い物", amount: -1200),
            Record(day: day, kind: .free, title: "メモ", amount: 999),   // memo-only records never count
        ]
        #expect(records.totalsByDay(calendar: calendar) == [DayKey(date: day, calendar: calendar): 4200])
        #expect(records[2].countedAmount == nil)
        #expect(Record(day: day, kind: .balance, category: "食費").displayTitle == "食費")
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
