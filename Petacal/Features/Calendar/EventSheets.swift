import EventKit
#if os(iOS)
import EventKitUI
#endif
import PetaCore
import SwiftData
import SwiftUI

/// The sheet that opens when a day is tapped in the month view.
struct DaySheet: View {
    let day: DayKey
    @Binding var sheet: CalendarSheet?

    @Environment(CalendarStore.self) private var store
    @State private var path: [EventItem] = []

    private var today: DayKey { DayKey(date: Date(), calendar: store.calendar) }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                DayContents(day: day, sheet: $sheet) { path.append($0) }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
            }
            .navigationTitle(Text(verbatim: store.heading(day, today: today)))
            .inlineTitle()
            .toolbar {
                ToolbarItem(placement: .barLeading) {
                    Button("閉じる", systemImage: "xmark") { sheet = nil }
                }
                ToolbarItem(placement: .barTrailing) {
                    Menu {
                        Button("予定を追加", systemImage: "calendar.badge.plus") { add() }
                            .disabled(store.access != .granted)
                        Button("記録を追加", systemImage: "square.and.pencil") {
                            sheet = .record(.new(day.date(calendar: store.calendar) ?? Date()))
                        }
                    } label: {
                        Label("追加", systemImage: "plus")
                    }
                }
            }
            .navigationDestination(for: EventItem.self) { item in
                EventDetailView(item: item, sheet: $sheet, showsClose: false)
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func add() {
        let base = day.date(calendar: store.calendar) ?? Date()
        sheet = .new(base.addingTimeInterval(9 * 3600), allDay: false)
    }
}

/// Everything on one day: events, then records. Shows the empty state when there is neither.
struct DayContents: View {
    let day: DayKey
    @Binding var sheet: CalendarSheet?
    let onSelectEvent: (EventItem) -> Void

    @Environment(CalendarStore.self) private var store
    @Environment(LockGate.self) private var lock
    @Query private var records: [Record]

    var body: some View {
        let events = store.events(on: day)
        let dayRecords = records.on(day, calendar: store.calendar)
        VStack(alignment: .leading, spacing: 16) {
            if events.isEmpty && dayRecords.isEmpty {
                ContentUnavailableView {
                    Label("この日はまだ何もありません", systemImage: "calendar")
                } actions: {
                    if store.access == .granted {
                        Button("予定を追加") {
                            let base = day.date(calendar: store.calendar) ?? Date()
                            sheet = .new(base.addingTimeInterval(9 * 3600), allDay: false)
                        }
                    }
                    Button("記録を追加") { sheet = .record(.new(day.date(calendar: store.calendar) ?? Date())) }
                }
                .frame(maxWidth: .infinity)
            }
            if !events.isEmpty {
                DayEventList(items: events, onSelect: onSelectEvent)
            }
            if !dayRecords.isEmpty {
                Text("記録").font(.footnote).foregroundStyle(.secondary).padding(.leading, 16)
                if lock.isLocked {
                    Label("記録 \(dayRecords.count)件（ロック中）", systemImage: "lock")
                        .foregroundStyle(.secondary)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 24))
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(dayRecords.enumerated()), id: \.element.id) { index, record in
                            if index > 0 { Divider().padding(.leading, 16) }
                            Button { sheet = .record(.edit(record)) } label: {
                                RecordRow(record: record)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 24))
                }
            }
        }
    }
}

/// The events of one day as a card.
struct DayEventList: View {
    let items: [EventItem]
    let onSelect: (EventItem) -> Void

    @Environment(ColorStore.self) private var colors
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 { Divider().padding(.leading, 16) }
                Button { onSelect(item) } label: {
                    EventRow(item: item, color: colors.color(for: item, scheme: scheme))
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 24))
    }
}

private struct EventRow: View {
    let item: EventItem
    let color: Color

    @Environment(CalendarStore.self) private var store

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                if item.isAllDay {
                    Text("終日").font(.subheadline.weight(.semibold))
                } else {
                    Text(verbatim: store.clock(item.start)).font(.subheadline.weight(.semibold))
                    Text(verbatim: store.clock(item.end)).font(.footnote).foregroundStyle(.secondary)
                }
            }
            .frame(minWidth: 48, alignment: .leading)
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: item.title).font(.body.weight(.medium))
                Text(verbatim: [item.calendarTitle, item.location].compactMap { $0 }.filter { !$0.isEmpty }
                    .joined(separator: "・"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.forward")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// S-02 予定の詳細.
struct EventDetailView: View {
    let item: EventItem
    @Binding var sheet: CalendarSheet?
    let showsClose: Bool

    @Environment(CalendarStore.self) private var store
    @Environment(ColorStore.self) private var colors
    @Environment(\.colorScheme) private var scheme

    private var dateText: String {
        let days = store.days(of: item)
        let today = DayKey(date: Date(), calendar: store.calendar)
        let first = store.heading(days.start, today: today)
        if days.start == days.end {
            return "\(first) \(store.timeText(item))"
        }
        let last = store.heading(days.end, today: today)
        return item.isAllDay
            ? "\(first)〜\(last)"
            : "\(first) \(store.clock(item.start))〜\(last) \(store.clock(item.end))"
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: item.title).font(.title2.weight(.semibold))
                    Text(verbatim: dateText).foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                if let location = item.location {
                    Label { Text(verbatim: location) } icon: { Image(systemName: "mappin.and.ellipse") }
                }
                LabeledContent("カレンダー") { Text(verbatim: item.calendarTitle) }
            }
            Section {
                NavigationLink {
                    ColorPickerView(
                        title: "この予定の色",
                        sample: item.title,
                        fallback: colors.calendarChoices[item.calendarID].flatMap(ColorPalette.preset)
                            .map { Color($0, scheme: scheme) } ?? Color(item.calendarColor),
                        resetLabel: "カレンダーの色に戻す",
                        selection: Binding(
                            get: { colors.eventChoices[item.eventIdentifier] },
                            set: { colors.setEvent(item.eventIdentifier, preset: $0) }))
                } label: {
                    LabeledContent("色") {
                        HStack(spacing: 8) {
                            Text(verbatim: colors.eventChoices[item.eventIdentifier]
                                .flatMap(ColorPalette.preset)?.name ?? String(localized: "カレンダーの色"))
                            Circle().fill(colors.color(for: item, scheme: scheme)).frame(width: 18, height: 18)
                        }
                    }
                }
            } footer: {
                Text("色はこのアプリの中だけで使います。元のカレンダーは変わりません。")
            }
            Section {
                Button("編集") { sheet = .edit(item) }
            }
        }
        .navigationTitle("予定")
        .inlineTitle()
        .toolbar {
            if showsClose {
                ToolbarItem(placement: .barLeading) {
                    Button("閉じる", systemImage: "xmark") { sheet = nil }
                }
            }
        }
    }
}

#if os(iOS)
/// The system screen for adding and editing an event (EventKitUI).
struct EventEditor: UIViewControllerRepresentable {
    let store: EKEventStore
    let event: EKEvent?
    let onDone: () -> Void

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let controller = EKEventEditViewController()
        controller.eventStore = store
        if let event { controller.event = event }
        controller.editViewDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: EKEventEditViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onDone)
    }

    final class Coordinator: NSObject, @preconcurrency EKEventEditViewDelegate {
        let onFinish: () -> Void

        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }

        func eventEditViewController(_ controller: EKEventEditViewController,
                                     didCompleteWith action: EKEventEditViewAction) {
            onFinish()
        }
    }
}
#else
/// The Mac has no system screen for editing an event, so this form stands in for it.
struct EventEditor: View {
    let store: EKEventStore
    let event: EKEvent?
    let onDone: () -> Void

    @State private var title = ""
    @State private var isAllDay = false
    @State private var start = Date()
    @State private var end = Date().addingTimeInterval(3600)
    @State private var location = ""
    @State private var notes = ""
    @State private var calendarID = ""
    @State private var failed = false
    @State private var loaded = false

    private var calendars: [EKCalendar] {
        store.calendars(for: .event).filter(\.allowsContentModifications)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("題名", text: $title)
                    TextField("場所", text: $location)
                }
                Section {
                    Toggle("終日", isOn: $isAllDay)
                    DatePicker("開始", selection: $start, displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute])
                    DatePicker("終了", selection: $end, in: start..., displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute])
                }
                Section {
                    Picker("カレンダー", selection: $calendarID) {
                        ForEach(calendars, id: \.calendarIdentifier) { calendar in
                            Text(verbatim: calendar.title).tag(calendar.calendarIdentifier)
                        }
                    }
                    TextField("メモ", text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(event?.eventIdentifier == nil ? "予定を追加" : "予定を編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { onDone() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || calendars.isEmpty)
                }
            }
            .alert("保存できませんでした", isPresented: $failed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("カレンダーに書き込めませんでした。保存先のカレンダーを変えて、もう一度試してください。")
            }
        }
        .onAppear(perform: load)
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let event {
            title = event.title ?? ""
            isAllDay = event.isAllDay
            start = event.startDate ?? Date()
            end = event.endDate ?? start.addingTimeInterval(3600)
            location = event.location ?? ""
            notes = event.notes ?? ""
            calendarID = event.calendar?.calendarIdentifier ?? ""
        }
        if !calendars.contains(where: { $0.calendarIdentifier == calendarID }) {
            calendarID = store.defaultCalendarForNewEvents?.calendarIdentifier ?? calendars.first?.calendarIdentifier ?? ""
        }
    }

    private func save() {
        let target = event ?? EKEvent(eventStore: store)
        target.title = title
        target.isAllDay = isAllDay
        target.startDate = start
        target.endDate = max(start, end)
        target.location = location.isEmpty ? nil : location
        target.notes = notes.isEmpty ? nil : notes
        if let calendar = calendars.first(where: { $0.calendarIdentifier == calendarID }) {
            target.calendar = calendar
        }
        do {
            try store.save(target, span: .thisEvent, commit: true)
            onDone()
        } catch {
            failed = true
        }
    }
}
#endif
