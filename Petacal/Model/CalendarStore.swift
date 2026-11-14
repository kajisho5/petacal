import EventKit
import Observation
import PetaCore
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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

    /// Events from Google come from the Google API, not EventKit (they cannot use the system edit screen).
    var google: GoogleRef? { GoogleRef(key: eventIdentifier) }
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
    var location: String?
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

    /// Google calendars connected directly (nil in screenshots and previews).
    let google: GoogleStore?
    /// Device calendars hidden because the same Google account is connected directly.
    private(set) var duplicateCalendarIDs: Set<String> = []

    init() {
        isSample = false
        hiddenCalendarIDs = Set(UserDefaults.standard.stringArray(forKey: CalendarStore.hiddenKey) ?? [])
        let google = GoogleStore()
        self.google = google
        google.onChange = { [weak self] in self?.reload() }
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
        google = nil
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
        if let google { Task { await google.loadAll() } }
    }

    /// Pull to refresh: reads Google again even if it was read a moment ago.
    func refreshNow() async {
        reload()
        await google?.loadAll(force: true)
    }

    /// Adding events works with either the device's calendars or a connected Google account.
    var canAddEvents: Bool { access == .granted || !writableCalendars.isEmpty }

    func load(from: Date, to: Date) {
        range = (from, to)
        reload()
    }

    func reload() {
        guard !isSample else {
            events = sampleItems.filter { isVisible($0.calendarID) }
            return
        }
        var device: [CalendarInfo] = []
        if access == .granted {
            device = eventStore.calendars(for: .event)
                .map { CalendarInfo(id: $0.calendarIdentifier, title: $0.title,
                                    color: CalendarStore.rgb($0.cgColor), account: $0.source?.title ?? "",
                                    writable: $0.allowsContentModifications) }
        }
        let emails = google?.accounts.map(\.email) ?? []
        duplicateCalendarIDs = GoogleMerge.duplicateDeviceCalendars(device.map { (id: $0.id, account: $0.account) },
                                                                    googleEmails: emails)
        calendars = (device.filter { !duplicateCalendarIDs.contains($0.id) }
                     + googleCalendars)
            .sorted { ($0.account, $0.title) < ($1.account, $1.title) }
        guard let range else {
            events = []
            return
        }
        events = items(from: range.from, to: range.to)
            .filter { isVisible($0.calendarID) }
            .sorted { $0.start != $1.start ? $0.start < $1.start : $0.title < $1.title }
    }

    /// Device and Google events in a range, before hiding switched-off calendars.
    private func items(from: Date, to: Date) -> [EventItem] {
        var result: [EventItem] = []
        if access == .granted {
            let predicate = eventStore.predicateForEvents(withStart: from, end: to, calendars: nil)
            result = eventStore.events(matching: predicate).map(CalendarStore.item)
                .filter { !duplicateCalendarIDs.contains($0.calendarID) }
        }
        return result + googleItems(from: from, to: to)
    }

    private var googleCalendars: [CalendarInfo] {
        guard let google else { return [] }
        return google.accounts.flatMap { account in
            account.calendars.map { entry in
                CalendarInfo(id: GoogleRef(email: account.email, calendarID: entry.id).calendarKey, title: entry.title,
                             color: entry.color, account: account.email, writable: entry.writable && !account.needsSignIn)
            }
        }
    }

    private func googleItems(from: Date, to: Date) -> [EventItem] {
        guard let google else { return [] }
        return google.accounts.flatMap { account -> [EventItem] in
            let entries = Dictionary(account.calendars.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            return (google.events[account.email] ?? []).compactMap { event in
                guard event.end > from || (event.end == event.start && event.start >= from), event.start < to,
                      let entry = entries[event.calendarID] else { return nil }
                let ref = GoogleRef(email: account.email, calendarID: event.calendarID, eventID: event.id)
                return EventItem(
                    id: ref.key,
                    eventIdentifier: ref.key,
                    title: event.title.isEmpty ? String(localized: "（題名なし）") : event.title,
                    start: event.start, end: event.end, isAllDay: event.isAllDay,
                    calendarID: ref.calendarKey,
                    calendarTitle: entry.title,
                    calendarColor: GoogleMerge.color(of: event, calendarColor: entry.color, palette: google.palette,
                                                     useEventColors: account.useEventColors),
                    location: event.location)
            }
        }
    }

    /// New events can only go to calendars that are writable and shown.
    var writableCalendars: [CalendarInfo] { calendars.filter { $0.writable && isVisible($0.id) } }

    /// The calendar new events go to unless the person picks another one.
    var defaultCalendarID: String? {
        if isSample { return calendars.first?.id }
        let preferred = access == .granted ? eventStore.defaultCalendarForNewEvents?.calendarIdentifier : nil
        return writableCalendars.contains { $0.id == preferred } ? preferred : writableCalendars.first?.id
    }

    /// An unsaved EventKit event filled from a draft (for saving, or for the system edit screen).
    func makeEvent(from draft: QuickDraft) -> EKEvent {
        let event = EKEvent(eventStore: eventStore)
        event.title = draft.title
        if let location = draft.location, !location.isEmpty { event.location = location }
        event.isAllDay = draft.isAllDay
        event.startDate = draft.isAllDay ? calendar.startOfDay(for: draft.start) : draft.start
        event.endDate = draft.isAllDay ? calendar.startOfDay(for: max(draft.start, draft.end)) : max(draft.start, draft.end)
        event.calendar = eventStore.calendars(for: .event).first { $0.calendarIdentifier == draft.calendarID }
            ?? eventStore.defaultCalendarForNewEvents
        return event
    }

    /// Saves a draft and returns the new event's identifier.
    @discardableResult
    func add(_ draft: QuickDraft) async throws -> String? {
        guard !isSample else { return nil }
        if let id = draft.calendarID, let target = GoogleRef(key: id), let google {
            let made = try await google.insert(GoogleEventDraft(draft), into: target)
            return made.key
        }
        let event = makeEvent(from: draft)
        try eventStore.save(event, span: .thisEvent, commit: true)
        reload()
        return event.eventIdentifier
    }

    /// Deletes an event that was just added (for "取り消す").
    func remove(eventIdentifier: String) {
        guard !isSample else { return }
        if let ref = GoogleRef(key: eventIdentifier), let google {
            Task { try? await google.delete(ref) }
            return
        }
        guard let event = eventStore.event(withIdentifier: eventIdentifier) else { return }
        try? eventStore.remove(event, span: .thisEvent, commit: true)
        reload()
    }

    /// Times taken by timed events (all-day events do not count), for finding free time.
    func busyRanges(from: Date, to: Date) -> [TimeRange] {
        let pool: [EventItem] = isSample ? sampleItems : items(from: from, to: to)
        return pool
            .filter { !$0.isAllDay && isVisible($0.calendarID) && $0.end > from && $0.start < to }
            .map { TimeRange(start: $0.start, end: $0.end) }
    }

    /// Events from one year back to one year ahead, for searching.
    func eventsAround() -> [EventItem] {
        if isSample { return sampleItems.filter { isVisible($0.calendarID) } }
        guard let from = calendar.date(byAdding: .year, value: -1, to: Date()),
              let to = calendar.date(byAdding: .year, value: 1, to: Date()) else { return [] }
        return items(from: from, to: to)
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
        #if os(macOS)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let converted = color.converted(to: space, intent: .defaultIntent, options: nil),
              let parts = converted.components, parts.count >= 3 else {
            return RGB(red: 0, green: 0.53, blue: 1)
        }
        return RGB(red: Double(parts[0]), green: Double(parts[1]), blue: Double(parts[2]))
        #else
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard UIColor(cgColor: color).getRed(&r, green: &g, blue: &b, alpha: &a) else {
            return RGB(red: 0, green: 0.53, blue: 1)
        }
        return RGB(red: Double(r), green: Double(g), blue: Double(b))
        #endif
    }
}

extension GoogleEventDraft {
    /// A quick draft's all-day end is the last day itself; Google wants the day after.
    init(_ draft: QuickDraft, calendar: Calendar = .current) {
        var end = draft.end
        if draft.isAllDay {
            let last = calendar.startOfDay(for: max(draft.start, draft.end))
            end = calendar.date(byAdding: .day, value: 1, to: last) ?? last
        }
        self.init(title: draft.title, start: draft.start, end: end, isAllDay: draft.isAllDay, location: draft.location)
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
