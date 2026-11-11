import PetaCore
import SwiftUI

/// S-15 新しい予定（かんたん入力）: opens from a long press on a day or a time, and from ＋.
struct QuickAddSheet: View {
    @Binding var sheet: CalendarSheet?

    @Environment(CalendarStore.self) private var store
    @Environment(ColorStore.self) private var colors
    @Environment(\.colorScheme) private var scheme

    @State private var text = ""
    @State private var start: Date
    @State private var end: Date
    @State private var isAllDay: Bool
    @State private var calendarID: String?
    @State private var colorPreset: Int?
    @State private var confirmDiscard = false
    @State private var failed = false
    /// The date and time last taken from the title, so rows edited by hand are not overwritten on every keystroke.
    @State private var applied: QuickAddParser.Result?
    @FocusState private var titleFocused: Bool

    /// Where the sheet started, so words like "15時" apply to the pressed day.
    private let baseDay: Date

    init(start: Date, allDay: Bool, sheet: Binding<CalendarSheet?>, text: String = "") {
        _sheet = sheet
        _start = State(initialValue: start)
        _end = State(initialValue: allDay ? start : start.addingTimeInterval(3600))
        _isAllDay = State(initialValue: allDay)
        _text = State(initialValue: text)
        baseDay = start
    }

    private var parsed: QuickAddParser.Result {
        QuickAddParser.parse(text, now: Date(), calendar: store.calendar)
    }

    private var title: String {
        let result = parsed
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.matched.isEmpty || result.title.isEmpty ? trimmed : result.title
    }

    private var hint: String? {
        let result = parsed
        guard !result.matched.isEmpty else { return nil }
        let words = result.matched.joined()
        return result.title.isEmpty
            ? "「\(words)」を日時として読み取りました。"
            : "「\(words)」を日時として読み取りました。題名は「\(result.title)」になります。"
    }

    private var draft: QuickDraft {
        QuickDraft(title: title, start: start, end: end, isAllDay: isAllDay, calendarID: calendarID)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("題名（例：明日15時 打ち合わせ）", text: $text)
                        .font(.title3)
                        .focused($titleFocused)
                        .submitLabel(.done)
                } footer: {
                    if let hint { Text(verbatim: hint) }
                }
                Section {
                    DatePicker("開始", selection: $start,
                               displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute])
                    DatePicker("終了", selection: $end, in: start...,
                               displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute])
                    Toggle("終日", isOn: $isAllDay)
                    if store.writableCalendars.isEmpty {
                        Text("書き込めるカレンダーがありません。").foregroundStyle(.secondary)
                    } else {
                        Picker("カレンダー", selection: $calendarID) {
                            ForEach(store.writableCalendars) { info in
                                Text(verbatim: info.title).tag(Optional(info.id))
                            }
                        }
                    }
                    NavigationLink {
                        ColorPickerView(title: "この予定の色", sample: title.isEmpty ? String(localized: "新しい予定") : title,
                                        fallback: calendarColor, resetLabel: "カレンダーの色に戻す",
                                        selection: $colorPreset)
                    } label: {
                        LabeledContent("色") {
                            HStack(spacing: 8) {
                                Text(verbatim: colorPreset.flatMap(ColorPalette.preset)?.name
                                     ?? String(localized: "カレンダーの色"))
                                Circle()
                                    .fill(colorPreset.flatMap(ColorPalette.preset).map { Color($0, scheme: scheme) }
                                          ?? calendarColor)
                                    .frame(width: 18, height: 18)
                            }
                        }
                    }
                }
                Section {
                    Button("くわしく設定（場所・くり返し・通知）") { sheet = .compose(draft) }
                }
            }
            .navigationTitle("新しい予定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル", systemImage: "xmark") {
                        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            sheet = nil
                        } else {
                            confirmDiscard = true
                        }
                    }
                    .confirmationDialog("入力した内容を破棄しますか？", isPresented: $confirmDiscard, titleVisibility: .visible) {
                        Button("変更を破棄", role: .destructive) { sheet = nil }
                        Button("キャンセル", role: .cancel) {}
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", systemImage: "checkmark") { save() }
                        .buttonStyle(.borderedProminent)
                        .disabled(title.isEmpty || store.writableCalendars.isEmpty)
                }
            }
            .alert("保存できませんでした", isPresented: $failed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("カレンダーに書き込めませんでした。保存先のカレンダーを変えて、もう一度試してください。")
            }
        }
        .interactiveDismissDisabled(!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .onAppear {
            if calendarID == nil { calendarID = store.defaultCalendarID }
            apply(parsed)
        }
        .task {
            // Bring up the keyboard after the sheet has finished rising, so the two do not fight.
            try? await Task.sleep(for: .milliseconds(450))
            titleFocused = true
        }
        .onChange(of: text) { _, _ in apply(parsed) }
        .onChange(of: start) { _, new in
            // The end never comes before the start.
            if end < new { end = isAllDay ? new : new.addingTimeInterval(3600) }
        }
    }

    private var calendarColor: Color {
        store.calendars.first { $0.id == calendarID }.map { colors.color(for: $0, scheme: scheme) } ?? Color.accentColor
    }

    /// Applies the date and time words found in the title to the rows below.
    private func apply(_ result: QuickAddParser.Result) {
        guard result.day != nil || result.start != nil else { return }
        if let applied, applied.day == result.day, applied.start == result.start, applied.end == result.end { return }
        applied = result
        let calendar = store.calendar
        let dayStart = result.day?.date(calendar: calendar) ?? calendar.startOfDay(for: result.start != nil ? baseDay : start)
        if let time = result.start {
            let newStart = dayStart.addingTimeInterval(Double(time.minutes) * 60)
            let newEnd = result.end.map { dayStart.addingTimeInterval(Double($0.minutes) * 60) }
                ?? newStart.addingTimeInterval(3600)
            isAllDay = false
            start = newStart
            end = newEnd
        } else {
            let offset = isAllDay ? 0 : start.timeIntervalSince(calendar.startOfDay(for: start))
            let length = end.timeIntervalSince(start)
            let newStart = dayStart.addingTimeInterval(offset)
            start = newStart
            end = newStart.addingTimeInterval(length)
        }
    }

    private func save() {
        do {
            let identifier = try store.add(draft)
            if let identifier, let colorPreset { colors.setEvent(identifier, preset: colorPreset) }
            sheet = nil
        } catch {
            failed = true
        }
    }
}
