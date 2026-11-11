import Combine
import EventKit
import PetaCore
import SwiftData
import SwiftUI

enum CalendarMode: String, CaseIterable, Identifiable {
    case day, week, month
    var id: String { rawValue }
    var label: LocalizedStringKey {
        switch self {
        case .day: "日"
        case .week: "週"
        case .month: "月"
        }
    }
}

enum MonthPattern: String, CaseIterable, Identifiable {
    case bars, dots
    var id: String { rawValue }
}

/// What the calendar tab is presenting. One sheet at a time (no stacked modals).
enum CalendarSheet: Identifiable {
    case day(DayKey)
    case event(EventItem)
    /// The quick-add sheet. `allDay` is true when it was opened from a day in the month view.
    case new(Date, allDay: Bool)
    /// The system edit screen, continuing from what the quick-add sheet has.
    case compose(QuickDraft)
    case edit(EventItem)
    case record(RecordTarget)

    var id: String {
        switch self {
        case .day(let day): "day-\(day.year)-\(day.month)-\(day.day)"
        case .event(let item): "event-\(item.id)"
        case .new(let date, let allDay): "new-\(date.timeIntervalSince1970)-\(allDay)"
        case .compose(let draft): "compose-\(draft.id)"
        case .edit(let item): "edit-\(item.id)"
        case .record(let target): "record-\(target.id)"
        }
    }
}

struct MonthRef: Equatable {
    var year: Int
    var month: Int
}

/// S-01 カレンダー: day / week / month, with the events of the calendars registered on the device.
struct CalendarScreen: View {
    @Environment(CalendarStore.self) private var store
    @Environment(LockGate.self) private var lock
    @Environment(\.scenePhase) private var scenePhase
    @Query private var records: [Record]
    @AppStorage("calendar.mode") private var modeRaw = CalendarMode.month.rawValue
    @AppStorage("calendar.pattern") private var patternRaw = MonthPattern.bars.rawValue
    @State private var focus = DayKey(date: Date(), calendar: .current)
    @State private var sheet: CalendarSheet?
    /// Bumped on each long press, for the haptic tap.
    @State private var pressCount = 0

    private var calendar: Calendar { store.calendar }
    private var today: DayKey { DayKey(date: Date(), calendar: calendar) }
    private var mode: CalendarMode { CalendarMode(rawValue: modeRaw) ?? .month }
    private var pattern: MonthPattern { MonthPattern(rawValue: patternRaw) ?? .bars }
    private var month: MonthRef { MonthRef(year: focus.year, month: focus.month) }

    private var title: String {
        switch mode {
        case .month: return "\(focus.year)年\(focus.month)月"
        case .week:
            let week = focus.week(calendar: calendar)
            guard let first = week.first, let last = week.last else { return "" }
            return first.month == last.month
                ? "\(first.month)月\(first.day)日〜\(last.day)日"
                : "\(first.month)月\(first.day)日〜\(last.month)月\(last.day)日"
        case .day: return store.heading(focus, today: nil)   // short, so it fits beside the buttons
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("表示の切り替え", selection: $modeRaw) {
                ForEach(CalendarMode.allCases) { mode in
                    Text(mode.label).tag(mode.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            if store.access == .denied {
                AccessDeniedBanner()
            }
            if store.access == .notDetermined && !records.isEmpty {
                AccessAskBanner { Task { await store.requestAccess() } }
            }
            if store.access == .notDetermined && records.isEmpty {
                AccessIntro { Task { await store.requestAccess() } }
            } else {
                content
            }
        }
        .navigationTitle(Text(verbatim: title))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("今日") { focus = today }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("前へ", systemImage: "chevron.backward") { move(by: -1) }
                Button("次へ", systemImage: "chevron.forward") { move(by: 1) }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("予定を追加", systemImage: "calendar.badge.plus") {
                        sheet = .new(newEventStart(on: focus), allDay: false)
                    }
                    .disabled(store.access != .granted)
                    Button("記録を追加", systemImage: "square.and.pencil") {
                        sheet = .record(.new(focus.date(calendar: calendar) ?? Date()))
                    }
                } label: {
                    Label("追加", systemImage: "plus")
                }
                .menuStyle(.button)
                .buttonStyle(.borderedProminent)
            }
        }
        .sheet(item: $sheet) { current in
            switch current {
            case .day(let day):
                DaySheet(day: day, sheet: $sheet)
            case .event(let item):
                NavigationStack { EventDetailView(item: item, sheet: $sheet, showsClose: true) }
                    .presentationDetents([.medium, .large])
            case .new(let date, let allDay):
                QuickAddSheet(start: date, allDay: allDay, sheet: $sheet)
            case .compose(let draft):
                EventEditor(store: store.eventStore, event: store.makeEvent(from: draft)) { store.reload(); sheet = nil }
                    .ignoresSafeArea()
            case .edit(let item):
                EventEditor(store: store.eventStore, event: store.ekEvent(for: item)) {
                    store.reload()
                    sheet = nil
                }
                .ignoresSafeArea()
            case .record(let target):
                RecordEditor(target: target)
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: pressCount)
        .task(id: month) { loadAround() }
        .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged).receive(on: RunLoop.main)) { _ in
            store.reload()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.refreshAccess() }
        }
    }

    @ViewBuilder private var content: some View {
        Group {
            switch mode {
            case .month:
                if pattern == .dots {
                    MonthDotsView(grid: MonthGrid(year: focus.year, month: focus.month, calendar: calendar),
                                  today: today, focus: $focus, sheet: $sheet) { addAllDay(on: $0) }
                } else {
                    MonthBarsView(grid: MonthGrid(year: focus.year, month: focus.month, calendar: calendar),
                                  today: today,
                                  amounts: lock.isLocked ? [:] : records.totalsByDay(calendar: calendar)) {
                        sheet = .day($0)
                    } onLongPress: { addAllDay(on: $0) }
                }
            case .week:
                TimelineScreen(days: focus.week(calendar: calendar), today: today, focus: $focus, sheet: $sheet,
                               pressCount: $pressCount)
            case .day:
                TimelineScreen(days: [focus], today: today, focus: $focus, sheet: $sheet, pressCount: $pressCount)
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 40).onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) * 2 else { return }
                move(by: value.translation.width < 0 ? 1 : -1)
            }
        )
    }

    /// Previous / next month, week or day. The buttons do the same as swiping sideways.
    private func move(by step: Int) {
        switch mode {
        case .month:
            let next = MonthGrid.shifted(year: focus.year, month: focus.month, by: step)
            let now = today
            focus = (now.year == next.year && now.month == next.month)
                ? now : DayKey(year: next.year, month: next.month, day: 1)
        case .week: focus = focus.adding(days: 7 * step, calendar: calendar)
        case .day: focus = focus.adding(days: step, calendar: calendar)
        }
    }

    /// Long press on a day: a new all-day event on that day.
    private func addAllDay(on day: DayKey) {
        guard store.access == .granted, let date = day.date(calendar: calendar) else { return }
        pressCount += 1
        sheet = .new(date, allDay: true)
    }

    /// Loads the month on screen plus the weeks around it (week view can reach into the next month).
    private func loadAround() {
        let first = DayKey(year: focus.year, month: focus.month, day: 1)
        guard let start = first.date(calendar: calendar),
              let from = calendar.date(byAdding: .day, value: -8, to: start),
              let to = calendar.date(byAdding: .day, value: 40, to: start) else { return }
        store.load(from: from, to: to)
    }

    /// New events start at the next full hour today, or at 9:00 on other days.
    private func newEventStart(on day: DayKey) -> Date {
        let base = day.date(calendar: calendar) ?? Date()
        let hour = day == today ? min(calendar.component(.hour, from: Date()) + 1, 23) : 9
        return calendar.date(byAdding: .hour, value: hour, to: base) ?? base
    }
}

/// S-06: shown before the system dialog. One button.
private struct AccessIntro: View {
    let action: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("カレンダーの予定を表示します", systemImage: "calendar")
        } description: {
            Text("この iPhone に登録してあるカレンダー（iCloud、Google など）の予定を、ここに並べます。予定の内容が外に送られることはありません。")
        } actions: {
            Button("続ける", action: action)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxHeight: .infinity)
    }
}

/// Shown above the calendar when records exist but calendar access was never asked.
private struct AccessAskBanner: View {
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("この iPhone のカレンダーの予定も、ここに並べられます。")
                .font(.subheadline)
            Button("続ける", action: action)
                .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

private struct AccessDeniedBanner: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("予定を表示するには、「設定」でカレンダーへのフルアクセスを許可してください。")
                .font(.subheadline)
            Button("設定を開く") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

#Preview {
    NavigationStack { CalendarScreen() }
        .environment(CalendarStore())
        .environment(ColorStore())
        .environment(LockGate())
        .modelContainer(for: [Record.self, RecordPhoto.self], inMemory: true)
}
