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
    case bars, dots, amount, photo
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
    /// S-03: paste a message and pick the events found in it.
    case importText(String)
    case bulkPhotos
    case slots

    var id: String {
        switch self {
        case .day(let day): "day-\(day.year)-\(day.month)-\(day.day)"
        case .event(let item): "event-\(item.id)"
        case .new(let date, let allDay): "new-\(date.timeIntervalSince1970)-\(allDay)"
        case .compose(let draft): "compose-\(draft.id)"
        case .edit(let item): "edit-\(item.id)"
        case .record(let target): "record-\(target.id)"
        case .importText: "import-text"
        case .bulkPhotos: "bulk-photos"
        case .slots: "slots"
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
    @Environment(\.horizontalSizeClass) private var widthClass
    @Environment(\.dynamicTypeSize) private var typeSize
    /// A Mac window is always treated as wide enough to decide by its real width.
    private var isRegularWidth: Bool {
        #if os(macOS)
        true
        #else
        widthClass == .regular
        #endif
    }
    /// Missing in previews and tests that show this screen on its own.
    @Environment(AppRouter.self) private var router: AppRouter?
    @Environment(EntitlementStore.self) private var entitlements: EntitlementStore?
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
    private var pattern: MonthPattern {
        let chosen = MonthPattern(rawValue: patternRaw) ?? .bars
        // After Pro ends, the paid looks fall back to the free one (the choice is kept for later).
        if (chosen == .amount || chosen == .photo), entitlements?.isPro == false { return .bars }
        return chosen
    }
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
            .labelsHidden()
            .padding(.horizontal)
            .padding(.vertical, 8)

            if mode == .month && !lock.isLocked {
                MonthTotalsLine(records: records, month: month, calendar: calendar)
            }
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
        // The keyboard of a sheet on top must not squeeze the calendar underneath.
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .navigationTitle(Text(verbatim: title))
        .inlineTitle()
        .toolbar {
            ToolbarItem(placement: .barLeading) {
                Button("今日") { focus = today }
            }
            ToolbarItemGroup(placement: .barTrailing) {
                Button("前へ", systemImage: "chevron.backward") { move(by: -1) }
                Button("次へ", systemImage: "chevron.forward") { move(by: 1) }
            }
            ToolbarItem(placement: .barTrailing) {
                Menu {
                    Button("予定を追加", systemImage: "calendar.badge.plus") {
                        sheet = .new(newEventStart(on: focus), allDay: false)
                    }
                    .disabled(store.access != .granted)
                    Button("貼り付けた文章から予定をつくる", systemImage: "doc.on.clipboard") {
                        sheet = .importText("")
                    }
                    .disabled(store.access != .granted)
                    Button("候補日をつくる（空き時間）", systemImage: "calendar.badge.clock") {
                        if entitlements?.isPro == false {
                            entitlements?.ask(String(localized: "候補日をつくるのは Pro の機能です"))
                        } else {
                            sheet = .slots
                        }
                    }
                        .disabled(store.access != .granted)
                    Divider()
                    Button("記録を追加", systemImage: "square.and.pencil") {
                        sheet = .record(.new(focus.date(calendar: calendar) ?? Date()))
                    }
                    Button("写真をまとめて記録にする", systemImage: "photo.on.rectangle.angled") { sheet = .bulkPhotos }
                } label: {
                    Label("追加", systemImage: "plus")
                }
                .menuStyle(.button)
                .buttonStyle(.borderedProminent)
            }
        }
        .calendarSheets($sheet)
        .sensoryFeedback(.impact(weight: .medium), trigger: pressCount)
        .task(id: month) { loadAround() }
        .onAppear {
            // At the largest text sizes the day view reads best: the default until the person picks another.
            if typeSize.isAccessibilitySize, UserDefaults.standard.object(forKey: "calendar.mode") == nil {
                modeRaw = CalendarMode.day.rawValue
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged).receive(on: RunLoop.main)) { _ in
            store.reload()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.refreshAccess() }
        }
        .onChange(of: router?.command, initial: true) { _, command in
            guard let command else { return }
            router?.command = nil
            run(command)
        }
    }

    /// Commands from the keyboard and the menu bar. Each one is also a button on screen.
    private func run(_ command: AppRouter.Command) {
        switch command {
        case .today: focus = today
        case .newRecord: sheet = .record(.new(focus.date(calendar: calendar) ?? Date()))
        case .newEvent:
            if store.access == .granted { sheet = .new(newEventStart(on: focus), allDay: false) }
        case .importText:
            if store.access == .granted { sheet = .importText("") }
        case .shared(let payload):
            let today = calendar.startOfDay(for: Date())
            if payload.item.kind == .event, store.access == .granted {
                sheet = .importText(payload.item.text)
            } else {
                // A record, or an event while calendar access is off: keep it as a record draft.
                sheet = .record(.prefilled(today, memo: payload.item.text, photos: payload.photos))
            }
        }
    }

    private var grid: MonthGrid { MonthGrid(year: focus.year, month: focus.month, calendar: calendar) }

    @ViewBuilder private var content: some View {
        Group {
            switch mode {
            case .month:
                GeometryReader { proxy in
                    // Decided by the room there is, not by the kind of device.
                    let split = isRegularWidth
                        ? PaneSplit.compute(width: proxy.size.width, fold: FoldReader.fold(in: proxy)) : nil
                    if let split {
                        wideMonth(split)
                    } else if pattern != .bars {
                        MonthCompactView(style: pattern, grid: grid, today: today, focus: $focus, sheet: $sheet) {
                            addAllDay(on: $0)
                        }
                    } else {
                        MonthBarsView(grid: grid, today: today,
                                      amounts: lock.isLocked ? [:] : records.totalsByDay(calendar: calendar)) {
                            sheet = .day($0)
                        } onLongPress: { addAllDay(on: $0) }
                    }
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

    /// Wide screens: the month on the leading side, the chosen day's list on the trailing side.
    /// On a foldable the two halves meet at the fold, and nothing is drawn on it while it is partly folded.
    private func wideMonth(_ split: PaneSplit) -> some View {
        HStack(alignment: .top, spacing: split.gap) {
            Group {
                if split.compactMonth || pattern != .bars {
                    MonthCompactView(style: pattern == .bars ? .amount : pattern, grid: grid, today: today,
                                     focus: $focus, sheet: $sheet, showsDay: false) { addAllDay(on: $0) }
                } else {
                    MonthBarsView(grid: grid, today: today,
                                  amounts: lock.isLocked ? [:] : records.totalsByDay(calendar: calendar),
                                  selected: focus) {
                        focus = $0
                    } onLongPress: { addAllDay(on: $0) }
                    .padding(.leading)
                }
            }
            .frame(width: split.leading)
            ScrollView {
                DaySidePane(day: focus, today: today, sheet: $sheet)
                    .padding(.trailing)
                    .padding(.bottom, 24)
            }
            .frame(width: split.trailing)
        }
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

/// The list beside the month on wide screens: the chosen day, then a short look at the next day.
private struct DaySidePane: View {
    let day: DayKey
    let today: DayKey
    @Binding var sheet: CalendarSheet?

    @Environment(CalendarStore.self) private var store

    var body: some View {
        let next = day.adding(days: 1, calendar: store.calendar)
        let nextEvents = store.events(on: next)
        VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: store.heading(day, today: today))
                .font(.title3.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            DayContents(day: day, sheet: $sheet) { sheet = .event($0) }
            Text(verbatim: store.heading(next, today: today))
                .font(.headline)
                .padding(.top, 8)
                .accessibilityAddTraits(.isHeader)
            if nextEvents.isEmpty {
                Text("予定はありません")
                    .foregroundStyle(.secondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 24))
            } else {
                DayEventList(items: nextEvents) { sheet = .event($0) }
            }
        }
    }
}

/// Reads where the fold of a foldable iPhone crosses a view (iOS 27.1 and later; nil everywhere else).
enum FoldReader {
    static func fold(in proxy: GeometryProxy) -> FoldRegion? {
        #if os(iOS)
        guard #available(iOS 27.1, *) else { return nil }
        // Inactive regions are included so the split is already at the fold before the device is folded.
        let regions = proxy.reservedRegions(kind: .division, options: .includeInactive)
        // Only a fold that runs top to bottom splits the screen into left and right.
        guard let region = regions.first(where: { $0.frame.height >= $0.frame.width }) else { return nil }
        return FoldRegion(minX: region.frame.minX, maxX: region.frame.maxX, isActive: region.isActive)
        #else
        return nil
        #endif
    }
}

/// Presents whatever `CalendarSheet` asks for. Shared by the calendar and the search screen.
private struct CalendarSheetHost: ViewModifier {
    @Binding var sheet: CalendarSheet?
    @Environment(CalendarStore.self) private var store

    func body(content: Content) -> some View {
        content
        .sheet(item: $sheet) { current in
            Group {
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
            case .importText(let text):
                ImportTextSheet(sheet: $sheet, text: text, searchNow: !text.isEmpty)
            case .bulkPhotos:
                BulkPhotosSheet()
            case .slots:
                SlotsSheet()
            }
            }
            .sheetSize()
        }
    }
}

extension View {
    func calendarSheets(_ sheet: Binding<CalendarSheet?>) -> some View {
        modifier(CalendarSheetHost(sheet: sheet))
    }
}

/// S-06: shown before the system dialog. One button.
private struct AccessIntro: View {
    let action: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("カレンダーの予定を表示します", systemImage: "calendar")
        } description: {
            Text("この端末に登録してあるカレンダー（iCloud、Google など）の予定を、ここに並べます。予定の内容が外に送られることはありません。")
        } actions: {
            Button("続ける", action: action)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxHeight: .infinity)
    }
}

/// 今月の合計: one line above the month. Hidden when the month has no amounts.
private struct MonthTotalsLine: View {
    let records: [Record]
    let month: MonthRef
    let calendar: Calendar

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let inMonth = records.filter {
            let day = DayKey(date: $0.day, calendar: calendar)
            return day.year == month.year && day.month == month.month
        }
        let stats = StatsCalculator.monthStats(inMonth.map { RecordAmount(kind: $0.kind, category: $0.category, amount: $0.amount) })
        if stats.plusCount + stats.minusCount + stats.oshiCount > 0 {
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2)) : AnyLayout(HStackLayout(spacing: 12))
            layout {
                if stats.plusCount + stats.minusCount > 0 {
                    Text(verbatim: String(localized: "収支") + " " + Yen.signed(stats.balanceTotal))
                        .foregroundStyle(Color.amount(stats.balanceTotal))
                }
                if stats.oshiSpent > 0 {
                    Text(verbatim: String(localized: "推し活・趣味") + " " + Yen.plain(stats.oshiSpent))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .font(.footnote.weight(.semibold))
            .monospacedDigit()
            .padding(.horizontal)
            .padding(.bottom, 6)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(verbatim: String(localized: "今月の合計") + " "
                + String(localized: "収支") + " " + Yen.signed(stats.balanceTotal) + " "
                + String(localized: "推し活・趣味") + " " + Yen.plain(stats.oshiSpent)))
        }
    }
}

/// Shown above the calendar when records exist but calendar access was never asked.
private struct AccessAskBanner: View {
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("この端末のカレンダーの予定も、ここに並べられます。")
                .font(.subheadline)
            Button("続ける", action: action)
                .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

private struct AccessDeniedBanner: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("予定を表示するには、「設定」でカレンダーへのフルアクセスを許可してください。")
                .font(.subheadline)
            Button("設定を開く") { SystemSettings.openPrivacy() }
            .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16))
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
