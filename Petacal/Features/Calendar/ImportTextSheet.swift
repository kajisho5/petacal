import PetaCore
import PhotosUI
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import UniformTypeIdentifiers

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
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var pickingFile = false
    @State private var isReading = false
    @State private var readFailed = false
    /// The on-device model is tidying titles and looking for places.
    @State private var refining: Task<Void, Never>?
    @State private var refinedCount = 0
    /// The free plan's AI reads for this month are used up (the dates are still read without AI).
    @State private var quotaUsedUp = false
    @Environment(EntitlementStore.self) private var entitlements
    private let searchNow: Bool

    struct Candidate: Identifiable {
        let id = UUID()
        var isOn = true
        var title: String
        var place = ""
        var event: ExtractedEvent
        /// The sentence the event was found in, and the title cut out of it without AI.
        var sentence = ""
        var plainTitle = ""
        var byAI = false
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
                    HStack {
                        PhotosPicker(selection: $pickedPhoto, matching: .images) {
                            Label("写真から読み取る", systemImage: "photo")
                        }
                        .buttonStyle(.bordered)
                        Spacer()
                        Button { pickingFile = true } label: { Label("ファイルから", systemImage: "doc") }
                            .buttonStyle(.bordered)
                    }
                    if isReading {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("文字を読み取っています")
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                    if readFailed {
                        Label("文字を読み取れませんでした。別の写真かファイルで試すか、文章を貼り付けてください。",
                              systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("文章")
                } footer: {
                    Text("LINE やメールの文章をコピーして、「ペースト」を押します。告知やチケットの写真、テキストや PDF のファイルからも読み取れます（この端末の中で読み取り、外には送りません）。日付が入っている文ごとに、予定の候補をつくります。")
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
                                TextField("場所（なくてもかまいません）", text: $candidate.place)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.subheadline)
                                    .disabled(!candidate.isOn)
                                    .accessibilityLabel(Text("場所"))
                                if candidate.byAI {
                                    Label("AIが読み取った結果です", systemImage: "sparkles")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        if quotaUsedUp {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("今月の AI 読み取り（無料版は月\(MonthlyQuota.freeLimit)回）を使い切りました。日付と時刻はこれまでどおり読み取れます。")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Button("Pro の内容を見る") {
                                    entitlements.ask(String(localized: "AI 読み取りは無料版で月\(MonthlyQuota.freeLimit)回までです"))
                                }
                                .font(.footnote)
                            }
                        }
                        if refining != nil {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("AIが題名と場所を読み取っています")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button("中止") { stopRefining() }
                                    .font(.footnote)
                            }
                        } else if refinedCount > 0 {
                            Button("AIの読み取りを取り消す", systemImage: "arrow.uturn.backward") { undoRefining() }
                                .font(.footnote)
                        }
                    } header: {
                        Text("見つかった予定（\(found.count)件）")
                    } footer: {
                        if refinedCount > 0 || refining != nil {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("日付と時刻はアプリが計算し、題名と場所だけを AI が読み取ります。AI はこの端末の中で動き、文章を外に送りません。まちがいがあれば、追加する前に直してください。")
                                if !entitlements.isPro {
                                    Text("AI 読み取り 今月の残り \(AIQuota.remaining()) 回（無料版）")
                                }
                            }
                        } else {
                            Text("題名は文章から機械的に切り出したものです。追加する前に直せます。時刻がないものは終日の予定になります。")
                        }
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
            .inlineTitle()
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
        .onChange(of: pickedPhoto) { _, item in
            guard let item else { return }
            Task {
                isReading = true
                readFailed = false
                let data = try? await item.loadTransferable(type: Data.self)
                let read = await data.asyncMap { await TextRecognizer.recognize($0) } ?? ""
                isReading = false
                pickedPhoto = nil
                append(read)
            }
        }
        .fileImporter(isPresented: $pickingFile, allowedContentTypes: [.plainText, .pdf]) { result in
            readFailed = false
            if case .success(let url) = result, let read = FileTextReader.text(at: url) {
                append(read)
            } else if case .success = result {
                readFailed = true
            }
        }
        .onAppear {
            if calendarID == nil { calendarID = store.defaultCalendarID }
            if searchNow { search() }
        }
        .onDisappear { refining?.cancel() }
    }

    /// Adds text read from a photo or a file, then looks for events.
    private func append(_ read: String) {
        let cleaned = read.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            readFailed = true
            return
        }
        text = text.isEmpty ? cleaned : text + "\n" + cleaned
        search()
    }

    private func search() {
        editing = false
        stopRefining()
        refinedCount = 0
        found = TextEventExtractor.extractDetailed(text, now: Date(), calendar: store.calendar)
            .map { Candidate(title: $0.event.title, event: $0.event, sentence: $0.sentence, plainTitle: $0.event.title) }
        searched = true
        refine()
    }

    /// Asks the on-device model for a tidier title and the place, one event at a time.
    /// Does nothing where the model is unavailable: the mechanical titles stay as they are.
    private func refine() {
        quotaUsedUp = false
        guard EventAI.isAvailable, !found.isEmpty else { return }
        // One search uses one of the free plan's monthly AI reads.
        if !entitlements.isPro, !AIQuota.consume() {
            quotaUsedUp = true
            return
        }
        let fullText = text
        let jobs = found.map { (id: $0.id, sentence: $0.sentence, plainTitle: $0.plainTitle) }
        refining = Task {
            for job in jobs {
                if Task.isCancelled { break }
                guard let result = await EventAI.details(sentence: job.sentence, fullText: fullText,
                                                         fallbackTitle: job.plainTitle),
                      !Task.isCancelled,
                      let index = found.firstIndex(where: { $0.id == job.id }) else { continue }
                // Never overwrite what the person has already typed.
                var changed = false
                if found[index].title == job.plainTitle, result.title != job.plainTitle {
                    found[index].title = result.title
                    changed = true
                }
                if found[index].place.isEmpty, !result.place.isEmpty {
                    found[index].place = result.place
                    changed = true
                }
                if changed {
                    found[index].byAI = true
                    refinedCount += 1
                }
            }
            if !Task.isCancelled { refining = nil }
        }
    }

    private func stopRefining() {
        refining?.cancel()
        refining = nil
    }

    /// Back to the titles cut out without AI (places found by AI are removed too).
    private func undoRefining() {
        stopRefining()
        for index in found.indices where found[index].byAI {
            found[index].title = found[index].plainTitle
            found[index].place = ""
            found[index].byAI = false
        }
        refinedCount = 0
    }

    private func whenText(_ event: ExtractedEvent) -> String {
        let day = store.heading(event.day, today: nil)
        guard let start = event.start else { return "\(day) 終日" }
        func clock(_ time: QuickAddParser.Time) -> String { String(format: "%d:%02d", time.hour, time.minute) }
        let end = event.end ?? QuickAddParser.Time(hour: min(start.hour + 1, 24), minute: start.hour >= 23 ? 0 : start.minute)
        return "\(day) \(clock(start))〜\(clock(end))"
    }

    private func addChosen() {
        Task { await addChosenNow() }
    }

    private func addChosenNow() async {
        var anyFailed = false
        var added: [String] = []
        for candidate in chosen {
            guard let dayStart = candidate.event.day.date(calendar: store.calendar) else { continue }
            let draft: QuickDraft
            if let start = candidate.event.start {
                let from = dayStart.addingTimeInterval(Double(start.minutes) * 60)
                let to = candidate.event.end.map { dayStart.addingTimeInterval(Double($0.minutes) * 60) }
                    ?? from.addingTimeInterval(3600)
                draft = QuickDraft(title: candidate.title, start: from, end: to, isAllDay: false, calendarID: calendarID,
                                   location: candidate.place)
            } else {
                draft = QuickDraft(title: candidate.title, start: dayStart, end: dayStart, isAllDay: true, calendarID: calendarID,
                                   location: candidate.place)
            }
            do {
                if let identifier = try await store.add(draft) { added.append(identifier) }
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

private extension Optional {
    /// `map` for async closures.
    func asyncMap<T>(_ transform: (Wrapped) async -> T) async -> T? {
        guard let value = self else { return nil }
        return await transform(value)
    }
}

/// The free plan's AI reads (PetaCore's MonthlyQuota, kept on this device).
enum AIQuota {
    private static let key = "ai.quota"

    private static func load(_ defaults: UserDefaults) -> MonthlyQuota {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(MonthlyQuota.self, from: $0) } ?? MonthlyQuota()
    }

    static func remaining(now: Date = Date(), defaults: UserDefaults = .standard) -> Int {
        load(defaults).remaining(monthKey: MonthlyQuota.key(for: now, calendar: .current))
    }

    static func consume(now: Date = Date(), defaults: UserDefaults = .standard) -> Bool {
        var quota = load(defaults)
        let ok = quota.consume(monthKey: MonthlyQuota.key(for: now, calendar: .current))
        if ok, let data = try? JSONEncoder().encode(quota) { defaults.set(data, forKey: key) }
        return ok
    }
}
