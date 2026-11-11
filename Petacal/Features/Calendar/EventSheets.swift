import EventKit
import EventKitUI
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる", systemImage: "xmark") { sheet = nil }
                }
                ToolbarItem(placement: .topBarTrailing) {
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
                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
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
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
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
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsClose {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる", systemImage: "xmark") { sheet = nil }
                }
            }
        }
    }
}

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
