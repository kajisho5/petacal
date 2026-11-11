import PetaCore
import SwiftData
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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
    @State private var bulk = false
    /// The record shown on the trailing side (wide screens only).
    @State private var selectedID: UUID?
    @Environment(\.horizontalSizeClass) private var widthClass
    /// A Mac window is always treated as wide enough to decide by its real width.
    private var isRegularWidth: Bool {
        #if os(macOS)
        true
        #else
        widthClass == .regular
        #endif
    }

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
                GeometryReader { proxy in
                    if isRegularWidth, proxy.size.width >= PaneSplit.minimumWidth {
                        // Wide screens: the list on the leading side, the chosen record beside it.
                        // Until something is chosen, the newest record is shown.
                        let current = shown.first { $0.id == selectedID } ?? shown.first
                        HStack(spacing: 0) {
                            list(wide: true, current: current?.id)
                                .frame(width: min(max(proxy.size.width * 0.4, 320), 420))
                            Divider()
                            RecordDetailPane(record: current) { target = .edit($0) }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    } else {
                        list(wide: false, current: nil)
                    }
                }
            }
        }
        .navigationTitle("記録")
        .toolbar {
            ToolbarItem(placement: .barTrailing) {
                Menu {
                    Button("記録を追加", systemImage: "square.and.pencil") { add() }
                    Button("写真をまとめて記録にする", systemImage: "photo.on.rectangle.angled") { bulk = true }
                } label: {
                    Label("追加", systemImage: "plus")
                }
                .menuStyle(.button)
                .buttonStyle(.borderedProminent)
            }
        }
        .sheet(item: $target) { target in
            RecordEditor(target: target).sheetSize()
        }
        .sheet(isPresented: $bulk) { BulkPhotosSheet().sheetSize() }
    }

    private func list(wide: Bool, current: UUID?) -> some View {
        List {
            Section {
                Picker("絞り込み", selection: $filter) {
                    Text("すべて").tag("all")
                    ForEach(RecordKind.allCases, id: \.rawValue) { kind in
                        Text(verbatim: kind.label).tag(kind.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            if shown.isEmpty {
                Text("この種類の記録はありません。").foregroundStyle(.secondary)
            }
            ForEach(groups, id: \.day) { group in
                Section {
                    ForEach(group.records) { record in
                        Button {
                            if wide { selectedID = record.id } else { target = .edit(record) }
                        } label: {
                            RecordRow(record: record)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(wide && record.id == current ? Color.accentColor.opacity(0.15) : nil)
                        .accessibilityAddTraits(wide && record.id == current ? .isSelected : [])
                    }
                } header: {
                    Text(verbatim: store.heading(group.day, today: nil))
                }
            }
        }
    }

    private func add() {
        target = .new(store.calendar.startOfDay(for: Date()))
    }
}

/// The chosen record, read-only, beside the list on wide screens. "編集" opens the same editor as on iPhone.
struct RecordDetailPane: View {
    let record: Record?
    let onEdit: (Record) -> Void

    @Environment(CalendarStore.self) private var store

    var body: some View {
        if let record {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(verbatim: record.displayTitle)
                                .font(.title2.weight(.semibold))
                            Text(verbatim: ([store.heading(DayKey(date: record.day, calendar: store.calendar), today: nil),
                                             record.kind.label, record.category] as [String])
                                .filter { !$0.isEmpty }.joined(separator: "・"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 12)
                        Button("編集") { onEdit(record) }
                            .buttonStyle(.bordered)
                    }
                    if let amount = record.countedAmount {
                        Text(verbatim: Yen.signed(amount))
                            .font(.largeTitle.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(Color.amount(amount))
                    }
                    if !record.memo.isEmpty {
                        Text(verbatim: record.memo)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 24))
                    }
                    ForEach(record.sortedPhotos) { photo in
                        if let image = PlatformImage.make(photo.data) {
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 560)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .accessibilityLabel(Text("記録の写真"))
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            ContentUnavailableView("記録を選ぶと、ここに内容が出ます", systemImage: "note.text")
        }
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
    private static let cache = NSCache<NSString, NativeImage>()

    static func image(for photo: RecordPhoto) -> NativeImage? {
        let key = photo.id.uuidString as NSString
        if let hit = cache.object(forKey: key) { return hit }
        guard let full = NativeImage(data: photo.data) else { return nil }
        #if os(macOS)
        let small = full
        #else
        // Keep the shape: the short side becomes 176pt and the view crops the rest.
        let shortSide = max(min(full.size.width, full.size.height), 1)
        let scale = min(1, 176 / shortSide)
        let size = CGSize(width: full.size.width * scale, height: full.size.height * scale)
        let small = full.preparingThumbnail(of: size) ?? full
        #endif
        cache.setObject(small, forKey: key)
        return small
    }
}

struct RecordThumb: View {
    let record: Record
    var size: CGFloat = 44

    @Environment(ColorStore.self) private var colors
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Group {
            if let photo = record.sortedPhotos.first, let image = ThumbCache.image(for: photo) {
                Image(native: image)
                    .resizable()
                    .scaledToFill()
            } else {
                // The kind's colour, with its own symbol so colour is not the only cue.
                Image(systemName: record.kind.symbol)
                    .font(.title3)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(colors.color(for: record.kind, scheme: scheme).opacity(0.35))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityHidden(true)
    }
}
