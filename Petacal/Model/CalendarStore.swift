import EventKit
import Observation
import PetaCore
import SwiftUI
import UIKit

/// One occurrence of an event, copied out of EventKit so views do not hold EventKit objects.
struct EventItem: Identifiable, Hashable {
    /// Unique per occurrence (repeating events share `eventIdentifier`).
    let id: String
    let eventIdentifier: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let calendarID: String
    let calendarTitle: String
    let calendarColor: RGB
    let location: String?
}

struct CalendarInfo: Identifiable, Equatable {
    let id: String
    let title: String
    let color: RGB
    let account: String
    var writable = true
}

/// What the quick-add sheet has collected so far.
struct QuickDraft: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var start: Date
    var end: Date
    var isAllDay: Bool
    var calendarID: String?
}

/// Reads and writes the calendars registered on the device (EventKit is the source of truth).
@Observable
final class CalendarStore {
    enum Access {
        case notDetermined, granted, denied
    }

    let eventStore = EKEventStore()
    let calendar = Calendar.current
    private(set) var access: Access = CalendarStore.currentAccess()
    private(set) var events: [EventItem] = []
    private(set) var calendars: [CalendarInfo] = []
    private var range: (from: Date, to: Date)?
    /// Calendars the person switched off in 設定 → 表示するカレンダー.
    private(set) var hiddenCalendarIDs: Set<String>
    private var sampleItems: [EventItem] = []
    private static let hiddenKey = "calendars.hidden"
    /// True when the store shows fixed sample items instead of the device calendars (screenshots, previews).
    private let isSample: Bool

    init() {
        isSample = false
        hiddenCalendarIDs = Set(UserDefaults.standard.stringArray(forKey: CalendarStore.hiddenKey) ?? [])
    }

    func isVisible(_ id: String) -> Bool { !hiddenCalendarIDs.contains(id) }

    func setVisible(_ id: String, _ visible: Bool) {
        if visible { hiddenCalendarIDs.remove(id) } else { hiddenCalendarIDs.insert(id) }
        if !isSample { UserDefaults.standard.set(Array(hiddenCalendarIDs).sorted(), forKey: CalendarStore.hiddenKey) }
        reload()
    }

    /// A store that never touches EventKit. For screenshots and previews, with fictional items.
    init(sample: [EventItem]) {
        isSample = true
        hiddenCalendarIDs = []
        access = .granted
        sampleItems = sample.sorted { $0.start != $1.start ? $0.start < $1.start : $0.title < $1.title }
        events = sampleItems
        var seen: [String: CalendarInfo] = [:]
        for item in sample where seen[item.calendarID] == nil {
            seen[item.calendarID] = CalendarInfo(id: item.calendarID, title: item.calendarTitle,
                                                 color: item.calendarColor, account: "")
        }
        calendars = seen.values.sorted { $0.title < $1.title }
    }

    static func currentAccess() -> Access {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: return .granted
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }

    /// Shows the system dialog (only the first time).
    func requestAccess() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            eventStore.requestFullAccessToEvents { @Sendable _, _ in continuation.resume() }
        }
        refreshAccess()
    }

    func refreshAccess() {
        guard !isSample else { return }
        access = CalendarStore.currentAccess()
        reload()
    }

    func load(from: Date, to: Date) {
        range = (from, to)
        reload()
    }

    func reload() {
        guard !isSample else {
            events = sampleItems.filter { isVisible($0.calendarID) }
            return
        }
        guard access == .granted else {
            events = []
            calendars = []
            return
        }
        calendars = eventStore.calendars(for: .event)
            .map { CalendarInfo(id: $0.calendarIdentifier, title: $0.title,
                                color: CalendarStore.rgb($0.cgColor), account: $0.source?.title ?? "",
                                writable: $0.allowsContentModifications) }
            .sorted { ($0.account, $0.title) < ($1.account, $1.title) }
        guard let range else { return }
        let predicate = eventStore.predicateForEvents(withStart: range.from, end: range.to, calendars: nil)
        events = eventStore.events(matching: predicate).map(CalendarStore.item)
            .filter { isVisible($0.calendarID) }
            .sorted { $0.start != $1.start ? $0.start < $1.start : $0.title < $1.title }
    }

    /// New events can only go to calendars that are writable and shown.
    var writableCalendars: [CalendarInfo] { calendars.filter { $0.writable && isVisible($0.id) } }

    /// The calendar new events go to unless the person picks another one.
    var defaultCalendarID: String? {
        if isSample { return calendars.first?.id }
        let preferred = eventStore.defaultCalendarForNewEvents?.calendarIdentifier
        return writableCalendars.contains { $0.id == preferred } ? preferred : writableCalendars.first?.id
    }

    /// An unsaved EventKit event filled from a draft (for saving, or for the system edit screen).
    func makeEvent(from draft: QuickDraft) -> EKEvent {
        let event = EKEvent(eventStore: eventStore)
        event.title = draft.title
        event.isAllDay = draft.isAllDay
        event.startDate = draft.isAllDay ? calendar.startOfDay(for: draft.start) : draft.start
        event.endDate = draft.isAllDay ? calendar.startOfDay(for: max(draft.start, draft.end)) : max(draft.start, draft.end)
        event.calendar = eventStore.calendars(for: .event).first { $0.calendarIdentifier == draft.calendarID }
            ?? eventStore.defaultCalendarForNewEvents
        return event
    }

    /// Saves a draft and returns the new event's identifier.
    @discardableResult
    func add(_ draft: QuickDraft) throws -> String? {
        guard !isSample else { return nil }
        let event = makeEvent(from: draft)
        try eventStore.save(event, span: .thisEvent, commit: true)
        reload()
        return event.eventIdentifier
    }

    /// Deletes an event that was just added (for "取り消す").
    func remove(eventIdentifier: String) {
        guard !isSample, let event = eventStore.event(withIdentifier: eventIdentifier) else { return }
        try? eventStore.remove(event, span: .thisEvent, commit: true)
        reload()
    }

    /// Events from one year back to one year ahead, for searching.
    func eventsAround() -> [EventItem] {
        if isSample { return sampleItems.filter { isVisible($0.calendarID) } }
        guard access == .granted,
              let from = calendar.date(byAdding: .year, value: -1, to: Date()),
              let to = calendar.date(byAdding: .year, value: 1, to: Date()) else { return [] }
        let predicate = eventStore.predicateForEvents(withStart: from, end: to, calendars: nil)
        return eventStore.events(matching: predicate).map(CalendarStore.item)
            .filter { isVisible($0.calendarID) }
            .sorted { $0.start > $1.start }
    }

    /// The EventKit object behind an item (for the system edit screen).
    func ekEvent(for item: EventItem) -> EKEvent? {
        let predicate = eventStore.predicateForEvents(withStart: item.start.addingTimeInterval(-1),
                                                      end: item.end.addingTimeInterval(1), calendars: nil)
        return eventStore.events(matching: predicate)
            .first { $0.eventIdentifier == item.eventIdentifier && $0.startDate == item.start }
            ?? eventStore.event(withIdentifier: item.eventIdentifier)
    }

    private static func item(_ event: EKEvent) -> EventItem {
        let identifier = event.eventIdentifier ?? UUID().uuidString
        let start: Date = event.startDate ?? Date()
        let end: Date = event.endDate ?? start
        let title: String = event.title ?? ""
        let location: String = event.location ?? ""
        return EventItem(
            id: "\(identifier)|\(start.timeIntervalSince1970)",
            eventIdentifier: identifier,
            title: title.isEmpty ? String(localized: "（題名なし）") : title,
            start: start, end: max(start, end), isAllDay: event.isAllDay,
            calendarID: event.calendar?.calendarIdentifier ?? "",
            calendarTitle: event.calendar?.title ?? "",
            calendarColor: rgb(event.calendar?.cgColor),
            location: location.isEmpty ? nil : location)
    }

    private static func rgb(_ color: CGColor?) -> RGB {
        guard let color else { return RGB(red: 0, green: 0.53, blue: 1) }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard UIColor(cgColor: color).getRed(&r, green: &g, blue: &b, alpha: &a) else {
            return RGB(red: 0, green: 0.53, blue: 1)
        }
        return RGB(red: Double(r), green: Double(g), blue: Double(b))
    }
}

// MARK: - Day helpers

extension CalendarStore {
    /// First and last day an item touches. An item that ends exactly at midnight does not count the next day.
    func days(of item: EventItem) -> (start: DayKey, end: DayKey) {
        let start = DayKey(date: item.start, calendar: calendar)
        let last = item.end > item.start ? item.end.addingTimeInterval(-1) : item.end
        return (start, max(start, DayKey(date: last, calendar: calendar)))
    }

    func events(on day: DayKey) -> [EventItem] {
        events
            .filter { let d = days(of: $0); return d.start <= day && day <= d.end }
            .sorted { a, b in
                if a.isAllDay != b.isAllDay { return a.isAllDay }
                return a.start != b.start ? a.start < b.start : a.title < b.title
            }
    }

    /// Bars for the month view.
    var spanItems: [SpanItem<String>] {
        events.map { item in
            let d = days(of: item)
            let minutes = calendar.component(.hour, from: item.start) * 60 + calendar.component(.minute, from: item.start)
            return SpanItem(id: item.id, start: d.start, end: d.end, sortKey: item.isAllDay ? -1 : minutes)
        }
    }

    /// Start and end in minutes from midnight on `day`, clipped to that day.
    func minutes(of item: EventItem, on day: DayKey) -> (start: Int, end: Int)? {
        guard let dayStart = day.date(calendar: calendar),
              let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart),
              item.start < dayEnd, item.end >= dayStart else { return nil }
        let start = Int(max(item.start, dayStart).timeIntervalSince(dayStart) / 60)
        let end = Int(min(item.end, dayEnd).timeIntervalSince(dayStart) / 60)
        return (start, max(start, end))
    }

    func timeText(_ item: EventItem) -> String {
        if item.isAllDay { return String(localized: "終日") }
        return "\(clock(item.start))〜\(clock(item.end))"
    }

    func clock(_ date: Date) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    func heading(_ day: DayKey, today: DayKey?) -> String {
        var text = "\(day.month)月\(day.day)日"
        if let weekday = day.weekday(calendar: calendar) {
            text += "（\(DayKey.weekdaySymbolsJa[weekday - 1])）"
        }
        if day == today { text += "・今日" }
        return text
    }
}
