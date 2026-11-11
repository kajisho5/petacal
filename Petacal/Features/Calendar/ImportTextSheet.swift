import PetaCore
import SwiftUI
import UIKit

/// S-03 予定を取り込む（文章）: paste a message, check the events found in it, add the ones you want.
struct ImportTextSheet: View {
    @Binding var sheet: CalendarSheet?

    @Environment(CalendarStore.self) private var store
    @Environment(UndoCenter.self) private var undo
    @State private var text: String
    @State private var found: [Candidate] = []
    @State private var searched = false
    @State private var calendarID: String?
    @State private var failed = false
    @State private var confirmDiscard = false
    @FocusState private var editing: Bool
    private let searchNow: Bool

    struct Candidate: Identifiable {
        let id = UUID()
        var isOn = true
        var title: String
        var event: ExtractedEvent
    }

    init(sheet: Binding<CalendarSheet?>, text: String = "", searchNow: Bool = false) {
        _sheet = sheet
        _text = State(initialValue: text)
        self.searchNow = searchNow
    }

    private var chosen: [Candidate] { found.filter { $0.isOn && !$0.title.trimmingCharacters(in: .whitespaces).isEmpty } }
    private var hasText: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("ここに文章を貼り付けます", text: $text, axis: .vertical)
                        .lineLimit(4...10)
                        .focused($editing)
                    HStack {
                        PasteButton(payloadType: String.self) { strings in
                            // The system calls this off the main thread.
                            let pasted = strings.joined(separator: "\n")
                            Task { @MainActor in
                                text = text.isEmpty ? pasted : text + "\n" + pasted
                                search()
                            }
                        }
                        .labelStyle(.titleAndIcon)
                        Spacer()
                        Button("予定をさがす") { search() }
                            .buttonStyle(.borderedProminent)
                            .disabled(!hasText)
                    }
                } header: {
                    Text("文章")
                } footer: {
                    Text("LINE やメールの文章をコピーして、「ペースト」を押します。日付が入っている文ごとに、予定の候補をつくります。")
                }

                if searched && found.isEmpty {
                    Section {
                        Label("日付が見つかりませんでした", systemImage: "calendar.badge.exclamationmark")
                        Text("「18日 15時 打ち合わせ」「12/3 大掃除」のように、日付が入った文章を貼ってください。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if !found.isEmpty {
                    Section {
                        ForEach($found) { $candidate in
                            VStack(alignment: .leading, spacing: 6) {
                                Toggle(isOn: $candidate.isOn) {
                                    Text(verbatim: whenText(candidate.event))
                                        .font(.subheadline.weight(.semibold))
                                }
                                TextField("題名", text: $candidate.title)
                                    .textFieldStyle(.roundedBorder)
                                    .disabled(!candidate.isOn)
                                    .accessibilityLabel(Text("題名"))
                            }
                            .padding(.vertical, 4)
                        }
                    } header: {
                        Text("見つかった予定（\(found.count)件）")
                    } footer: {
                        Text("題名は文章から機械的に切り出したものです。追加する前に直せます。時刻がないものは終日の予定になります。")
                    }
                    Section {
                        if store.writableCalendars.isEmpty {
                            Text("書き込めるカレンダーがありません。").foregroundStyle(.secondary)
                        } else {
                            Picker("カレンダー", selection: $calendarID) {
                                ForEach(store.writableCalendars) { info in
                                    Text(verbatim: info.title).tag(Optional(info.id))
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("文章から予定をつくる")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル", systemImage: "xmark") {
                        if hasText { confirmDiscard = true } else { sheet = nil }
                    }
                    .confirmationDialog("入力した内容を破棄しますか？", isPresented: $confirmDiscard, titleVisibility: .visible) {
                        Button("変更を破棄", role: .destructive) { sheet = nil }
                        Button("キャンセル", role: .cancel) {}
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加", systemImage: "checkmark") { addChosen() }
                        .buttonStyle(.borderedProminent)
                        .disabled(chosen.isEmpty || store.writableCalendars.isEmpty)
                        .accessibilityLabel(Text("\(chosen.count)件の予定を追加"))
                }
            }
            .alert("追加できませんでした", isPresented: $failed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("カレンダーに書き込めませんでした。保存先のカレンダーを変えて、もう一度試してください。")
            }
        }
        .interactiveDismissDisabled(hasText)
        .onAppear {
            if calendarID == nil { calendarID = store.defaultCalendarID }
            if searchNow { search() }
        }
    }

    private func search() {
        editing = false
        found = TextEventExtractor.extract(text, now: Date(), calendar: store.calendar)
            .map { Candidate(title: $0.title, event: $0) }
        searched = true
    }

    private func whenText(_ event: ExtractedEvent) -> String {
        let day = store.heading(event.day, today: nil)
        guard let start = event.start else { return "\(day) 終日" }
        func clock(_ time: QuickAddParser.Time) -> String { String(format: "%d:%02d", time.hour, time.minute) }
        let end = event.end ?? QuickAddParser.Time(hour: min(start.hour + 1, 24), minute: start.hour >= 23 ? 0 : start.minute)
        return "\(day) \(clock(start))〜\(clock(end))"
    }

    private func addChosen() {
        var anyFailed = false
        var added: [String] = []
        for candidate in chosen {
            guard let dayStart = candidate.event.day.date(calendar: store.calendar) else { continue }
            let draft: QuickDraft
            if let start = candidate.event.start {
                let from = dayStart.addingTimeInterval(Double(start.minutes) * 60)
                let to = candidate.event.end.map { dayStart.addingTimeInterval(Double($0.minutes) * 60) }
                    ?? from.addingTimeInterval(3600)
                draft = QuickDraft(title: candidate.title, start: from, end: to, isAllDay: false, calendarID: calendarID)
            } else {
                draft = QuickDraft(title: candidate.title, start: dayStart, end: dayStart, isAllDay: true, calendarID: calendarID)
            }
            do {
                if let identifier = try store.add(draft) { added.append(identifier) }
            } catch {
                anyFailed = true
            }
        }
        if !added.isEmpty {
            let calendarStore = store
            let identifiers = added
            undo.show(String(localized: "予定を\(identifiers.count)件追加しました")) {
                identifiers.forEach { calendarStore.remove(eventIdentifier: $0) }
            }
        }
        if anyFailed { failed = true } else { sheet = nil }
    }
}
