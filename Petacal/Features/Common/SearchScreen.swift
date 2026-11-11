import PetaCore
import SwiftData
import SwiftUI

/// 検索: events (one year back and ahead) and records, by words in the title, place, 種目 or memo.
struct SearchScreen: View {
    @Environment(CalendarStore.self) private var store
    @Environment(ColorStore.self) private var colors
    @Environment(LockGate.self) private var lock
    @Environment(\.colorScheme) private var scheme
    @Query(sort: \Record.day, order: .reverse) private var records: [Record]
    @State private var query: String
    @State private var pool: [EventItem] = []
    @State private var sheet: CalendarSheet?

    init(query: String = "") {
        _query = State(initialValue: query)
    }

    private var words: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var foundEvents: [EventItem] {
        guard !words.isEmpty else { return [] }
        return pool.filter {
            $0.title.localizedCaseInsensitiveContains(words) || ($0.location ?? "").localizedCaseInsensitiveContains(words)
        }.prefix(100).map { $0 }
    }

    private var foundRecords: [Record] {
        guard !words.isEmpty, !lock.isLocked else { return [] }
        return records.filter {
            $0.title.localizedCaseInsensitiveContains(words) || $0.category.localizedCaseInsensitiveContains(words)
                || $0.memo.localizedCaseInsensitiveContains(words)
        }.prefix(100).map { $0 }
    }

    var body: some View {
        let events = foundEvents
        let found = foundRecords
        List {
            if words.isEmpty {
                ContentUnavailableView {
                    Label("予定と記録をさがせます", systemImage: "magnifyingglass")
                } description: {
                    Text("題名、場所、種目、メモに入っている言葉でさがします。予定は前後1年が対象です。")
                }
                .listRowBackground(Color.clear)
            } else if events.isEmpty && found.isEmpty {
                ContentUnavailableView.search(text: words)
                    .listRowBackground(Color.clear)
            }
            if !events.isEmpty {
                Section("予定（\(events.count)件）") {
                    ForEach(events) { item in
                        Button { sheet = .event(item) } label: {
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 2).fill(colors.color(for: item, scheme: scheme)).frame(width: 4)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(verbatim: item.title).font(.body.weight(.medium))
                                    Text(verbatim: "\(dayText(item.start)) \(store.timeText(item))")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if !found.isEmpty {
                Section("記録（\(found.count)件）") {
                    ForEach(found) { record in
                        Button { sheet = .record(.edit(record)) } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(verbatim: dayText(record.day)).font(.footnote).foregroundStyle(.secondary)
                                RecordRow(record: record)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if lock.isLocked && !words.isEmpty {
                Section {
                    Label("記録はロック中なので、予定だけをさがしています。", systemImage: "lock")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("検索")
        .searchable(text: $query, prompt: Text("予定と記録をさがす"))
        .calendarSheets($sheet)
        .onAppear { pool = store.eventsAround() }
    }

    private func dayText(_ date: Date) -> String {
        let key = DayKey(date: date, calendar: store.calendar)
        return "\(key.year)年" + store.heading(key, today: nil)
    }
}
