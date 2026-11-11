import PetaCore
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// S-04 候補日をつくる: finds free time in the calendar and writes the message to send.
struct SlotsSheet: View {
    @Environment(CalendarStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var from: Date
    @State private var to: Date
    @State private var minutes = 60
    @State private var startHour = 10
    @State private var endHour = 18
    @State private var weekdaysOnly = true
    @State private var off: Set<Int> = []
    @State private var copied = false

    init() {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) ?? Date()
        _from = State(initialValue: tomorrow)
        _to = State(initialValue: calendar.date(byAdding: .day, value: 6, to: tomorrow) ?? tomorrow)
    }

    private var slots: [TimeRange] {
        let calendar = store.calendar
        let first = calendar.startOfDay(for: from)
        let last = calendar.startOfDay(for: max(from, to))
        guard let end = calendar.date(byAdding: .day, value: 1, to: last) else { return [] }
        let request = SlotRequest(firstDay: DayKey(date: first, calendar: calendar), lastDay: DayKey(date: last, calendar: calendar),
                                  minutes: minutes, dayStartHour: startHour, dayEndHour: max(endHour, startHour + 1),
                                  weekdaysOnly: weekdaysOnly)
        let now = Date()
        return SlotFinder.freeSlots(request, busy: store.busyRanges(from: first, to: end), calendar: calendar)
            .filter { $0.start > now }
            .prefix(20).map { $0 }
    }

    var body: some View {
        let all = slots
        let chosen = all.enumerated().filter { !off.contains($0.offset) }.map(\.element)
        let message = SlotFinder.message(for: chosen, calendar: store.calendar)
        NavigationStack {
            Form {
                Section {
                    DatePicker("いつから", selection: $from, displayedComponents: .date)
                    DatePicker("いつまで", selection: $to, in: from..., displayedComponents: .date)
                    Picker("長さ", selection: $minutes) {
                        Text("30分").tag(30)
                        Text("1時間").tag(60)
                        Text("1時間半").tag(90)
                        Text("2時間").tag(120)
                    }
                    Picker("何時から", selection: $startHour) {
                        ForEach(6..<15, id: \.self) { Text(verbatim: "\($0):00").tag($0) }
                    }
                    Picker("何時まで", selection: $endHour) {
                        ForEach(12..<24, id: \.self) { Text(verbatim: "\($0):00").tag($0) }
                    }
                    Toggle("平日だけ", isOn: $weekdaysOnly)
                } footer: {
                    Text("時間の決まった予定が入っていない時間をさがします（終日の予定は空きとして扱います）。1日に2つまで出します。")
                }
                Section("空いている時間（\(all.count)件）") {
                    if all.isEmpty {
                        Text("この条件では空いている時間が見つかりませんでした。期間や時間帯を広げてください。")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(Array(all.enumerated()), id: \.offset) { index, slot in
                        Toggle(isOn: Binding(
                            get: { !off.contains(index) },
                            set: { if $0 { off.remove(index) } else { off.insert(index) } })) {
                            Text(verbatim: SlotFinder.line(for: slot, calendar: store.calendar)).monospacedDigit()
                        }
                    }
                }
                if !chosen.isEmpty {
                    Section("送る文面") {
                        Text(verbatim: message).font(.callout).textSelection(.enabled)
                        ShareLink(item: message) { Label("共有", systemImage: "square.and.arrow.up") }
                        Button {
                            Clipboard.copy(message)
                            copied = true
                        } label: {
                            Label(copied ? "コピーしました" : "コピー", systemImage: copied ? "checkmark" : "doc.on.doc")
                        }
                    }
                }
            }
            .navigationTitle("候補日をつくる")
            .inlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる", systemImage: "xmark") { dismiss() }
                }
            }
            .onChange(of: from) { _, _ in reset() }
            .onChange(of: to) { _, _ in reset() }
            .onChange(of: minutes) { _, _ in reset() }
            .onChange(of: startHour) { _, _ in reset() }
            .onChange(of: endHour) { _, _ in reset() }
            .onChange(of: weekdaysOnly) { _, _ in reset() }
        }
    }

    private func reset() {
        off = []
        copied = false
        if to < from { to = from }
    }
}
