import PetaCore
import SwiftData
import SwiftUI
import UIKit

/// Which record the editor is for.
enum RecordTarget: Identifiable {
    case new(Date)
    case edit(Record)

    var id: String {
        switch self {
        case .new(let date): "new-\(date.timeIntervalSince1970)"
        case .edit(let record): "edit-\(record.id)"
        }
    }
}

/// S-10 記録: every record, newest day first.
struct RecordsScreen: View {
    @Environment(CalendarStore.self) private var store
    @Environment(LockGate.self) private var lock
    @Query(sort: \Record.day, order: .reverse) private var records: [Record]
    @State private var filter = "all"
    @State private var target: RecordTarget?

    private var shown: [Record] {
        filter == "all" ? records : records.filter { $0.kindRaw == filter }
    }

    private var groups: [(day: DayKey, records: [Record])] {
        Dictionary(grouping: shown) { DayKey(date: $0.day, calendar: store.calendar) }
            .map { (day: $0.key, records: $0.value.sorted { $0.createdAt > $1.createdAt }) }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        Group {
            if lock.isLocked {
                LockedView()
            } else if records.isEmpty {
                ContentUnavailableView {
                    Label("まだ記録がありません", systemImage: "note.text")
                } description: {
                    Text("写真・金額・メモを、その日に残せます。")
                } actions: {
                    Button("記録を追加") { add() }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    Section {
                        Picker("絞り込み", selection: $filter) {
                            Text("すべて").tag("all")
                            ForEach(RecordKind.allCases, id: \.rawValue) { kind in
                                Text(verbatim: kind.label).tag(kind.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }
                    if shown.isEmpty {
                        Text("この種類の記録はありません。").foregroundStyle(.secondary)
                    }
                    ForEach(groups, id: \.day) { group in
                        Section {
                            ForEach(group.records) { record in
                                Button { target = .edit(record) } label: { RecordRow(record: record) }
                                    .buttonStyle(.plain)
                            }
                        } header: {
                            Text(verbatim: store.heading(group.day, today: nil))
                        }
                    }
                }
            }
        }
        .navigationTitle("記録")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("記録を追加", systemImage: "plus") { add() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .sheet(item: $target) { target in
            RecordEditor(target: target)
        }
    }

    private func add() {
        target = .new(store.calendar.startOfDay(for: Date()))
    }
}

/// One record in a list: photo or symbol, name, kind and 種目, amount with its sign.
struct RecordRow: View {
    let record: Record

    var body: some View {
        HStack(spacing: 12) {
            RecordThumb(record: record)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: record.displayTitle)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                Text(verbatim: [record.kind.label, record.category].filter { !$0.isEmpty && $0 != record.displayTitle }
                    .joined(separator: "／"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if let amount = record.countedAmount {
                Text(verbatim: Yen.signed(amount))
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.amount(amount))
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// Small decoded photos, kept in memory so lists do not decode full-size photos while scrolling.
enum ThumbCache {
    private static let cache = NSCache<NSString, UIImage>()

    static func image(for photo: RecordPhoto) -> UIImage? {
        let key = photo.id.uuidString as NSString
        if let hit = cache.object(forKey: key) { return hit }
        guard let full = UIImage(data: photo.data) else { return nil }
        // Keep the shape: the short side becomes 176pt and the view crops the rest.
        let shortSide = max(min(full.size.width, full.size.height), 1)
        let scale = min(1, 176 / shortSide)
        let size = CGSize(width: full.size.width * scale, height: full.size.height * scale)
        let small = full.preparingThumbnail(of: size) ?? full
        cache.setObject(small, forKey: key)
        return small
    }
}

struct RecordThumb: View {
    let record: Record
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let photo = record.sortedPhotos.first, let image = ThumbCache.image(for: photo) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: record.kind.symbol)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(uiColor: .tertiarySystemFill))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityHidden(true)
    }
}
