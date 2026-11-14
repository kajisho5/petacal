import PetaCore
import SwiftUI

/// Adding, changing and deleting an event in a Google calendar connected directly.
/// (The system edit screen only knows EventKit, so Google events use this form on every device.)
struct GoogleEventEditor: View {
    private enum Mode {
        case add(GoogleRef)
        case edit(GoogleRef)
    }

    private let mode: Mode
    private let onDone: () -> Void

    @Environment(CalendarStore.self) private var store
    @State private var title: String
    @State private var location: String
    @State private var notes: String
    @State private var isAllDay: Bool
    @State private var start: Date
    @State private var end: Date
    @State private var saving = false
    @State private var failure: LocalizedStringKey?
    @State private var confirmDelete = false
    @State private var confirmDiscard = false
    @State private var loadedNotes = false
    private let original: [String]

    /// A new event from the quick-add sheet's 「くわしく設定」.
    init(target: GoogleRef, draft: QuickDraft, onDone: @escaping () -> Void) {
        mode = .add(target.calendar)
        self.onDone = onDone
        _title = State(initialValue: draft.title)
        _location = State(initialValue: draft.location ?? "")
        _notes = State(initialValue: "")
        _isAllDay = State(initialValue: draft.isAllDay)
        _start = State(initialValue: draft.start)
        _end = State(initialValue: draft.isAllDay ? draft.start : max(draft.start, draft.end))
        original = []
    }

    init(editing ref: GoogleRef, item: EventItem, onDone: @escaping () -> Void) {
        mode = .edit(ref)
        self.onDone = onDone
        _title = State(initialValue: item.title)
        _location = State(initialValue: item.location ?? "")
        _notes = State(initialValue: "")
        _isAllDay = State(initialValue: item.isAllDay)
        _start = State(initialValue: item.start)
        // On screen an all-day event ends on its last day; Google keeps the day after.
        let last = item.isAllDay ? max(item.start, item.end.addingTimeInterval(-1)) : item.end
        _end = State(initialValue: item.isAllDay ? Calendar.current.startOfDay(for: last) : item.end)
        original = [item.title, item.location ?? "", "", "\(item.isAllDay)", "\(item.start)", "\(item.end)"]
    }

    private var ref: GoogleRef {
        switch mode {
        case .add(let target), .edit(let target): target
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var calendarTitle: String {
        store.calendars.first { $0.id == ref.calendarKey }?.title ?? ref.calendarID
    }

    private var changed: Bool {
        guard isEditing else { return true }
        return [title, location, notes, "\(isAllDay)", "\(start)", "\(end)"] != original
    }

    private var isRepeating: Bool {
        isEditing && store.google?.event(ref)?.recurringEventID != nil
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
                    DatePicker("開始", selection: $start,
                               displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute])
                    DatePicker(isAllDay ? "最後の日" : "終了", selection: $end, in: start...,
                               displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute])
                } footer: {
                    if isRepeating {
                        Text("くり返しの予定です。変更と削除は、この日の分だけに効きます。")
                    }
                }
                Section {
                    LabeledContent("カレンダー") { Text(verbatim: calendarTitle) }
                    TextField("メモ", text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                } footer: {
                    Text("Google カレンダーに直接保存します。")
                }
                if isEditing {
                    Section {
                        Button("予定を削除", role: .destructive) { confirmDelete = true }
                            .disabled(saving)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(isEditing ? "予定を編集" : "予定を追加")
            .inlineTitle()
            .disabled(saving)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル", systemImage: "xmark") {
                        if isEditing && changed { confirmDiscard = true } else { onDone() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if saving {
                        ProgressView()
                    } else {
                        Button("保存", systemImage: "checkmark") { save() }
                            .buttonStyle(.borderedProminent)
                            .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || !changed)
                    }
                }
            }
            .confirmationDialog("この予定を削除しますか？", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("削除", role: .destructive) { delete() }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("Google カレンダーからも消えます。")
            }
            .confirmationDialog("変更を破棄しますか？", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("変更を破棄", role: .destructive) { onDone() }
                Button("編集を続ける", role: .cancel) {}
            }
            .alert("保存できませんでした", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                if let failure { Text(failure) }
            }
        }
        .interactiveDismissDisabled(isEditing && changed)
        .onChange(of: start) { _, new in
            if end < new { end = isAllDay ? new : new.addingTimeInterval(3600) }
        }
        .onAppear {
            guard !loadedNotes else { return }
            loadedNotes = true
            if isEditing, let saved = store.google?.event(ref)?.notes {
                notes = saved
            }
        }
    }

    private var draft: GoogleEventDraft {
        let calendar = Calendar.current
        var to = end
        if isAllDay {
            let last = calendar.startOfDay(for: max(start, end))
            to = calendar.date(byAdding: .day, value: 1, to: last) ?? last
        }
        return GoogleEventDraft(title: title.trimmingCharacters(in: .whitespaces),
                                start: isAllDay ? calendar.startOfDay(for: start) : start,
                                end: to, isAllDay: isAllDay,
                                location: location.isEmpty ? nil : location,
                                notes: notes.isEmpty ? nil : notes)
    }

    private func save() {
        guard let google = store.google else { return }
        saving = true
        Task {
            defer { saving = false }
            do {
                switch mode {
                case .add(let target): _ = try await google.insert(draft, into: target)
                case .edit(let target): try await google.update(target, with: draft)
                }
                onDone()
            } catch {
                failure = Self.message(for: error)
            }
        }
    }

    private func delete() {
        guard let google = store.google else { return }
        saving = true
        Task {
            defer { saving = false }
            do {
                try await google.delete(ref)
                onDone()
            } catch {
                failure = Self.message(for: error)
            }
        }
    }

    static func message(for error: Error) -> LocalizedStringKey {
        switch error as? GoogleStore.Failure {
        case .network:
            "Google につながりませんでした。通信の状態を確かめて、もう一度試してください。"
        case .signInAgain, .missingPermission:
            "Google へのログインが切れています。設定の「カレンダーのアカウント」からログインし直してください。"
        default:
            "Google カレンダーに保存できませんでした。少し待ってから、もう一度試してください。"
        }
    }
}
