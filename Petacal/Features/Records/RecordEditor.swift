import PetaCore
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

/// S-09 記録を追加／編集.
struct RecordEditor: View {
    let target: RecordTarget

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var allRecords: [Record]

    @State private var kind: RecordKind
    @State private var day: Date
    @State private var title: String
    @State private var category: String
    @State private var isPlus: Bool
    @State private var amountText: String
    @State private var memo: String
    @State private var photos: [Data]
    @State private var picked: [PhotosPickerItem] = []
    @State private var isLoadingPhotos = false
    @State private var confirmDelete = false
    @State private var confirmDiscard = false
    @State private var changed = false
    @FocusState private var amountFocused: Bool

    static let maxPhotos = 10

    init(target: RecordTarget) {
        self.target = target
        switch target {
        case .new(let date):
            _kind = State(initialValue: .balance)
            _day = State(initialValue: date)
            _title = State(initialValue: "")
            _category = State(initialValue: "")
            _isPlus = State(initialValue: false)
            _amountText = State(initialValue: "")
            _memo = State(initialValue: "")
            _photos = State(initialValue: [])
        case .edit(let record):
            _kind = State(initialValue: record.kind)
            _day = State(initialValue: record.day)
            _title = State(initialValue: record.title)
            _category = State(initialValue: record.category)
            _isPlus = State(initialValue: (record.amount ?? -1) > 0)
            _amountText = State(initialValue: record.amount.map { String($0.magnitude) } ?? "")
            _memo = State(initialValue: record.memo)
            _photos = State(initialValue: record.sortedPhotos.map(\.data))
        }
    }

    private var existing: Record? {
        if case .edit(let record) = target { return record }
        return nil
    }

    /// The signed amount, or nil when the field is empty or the kind has no amount.
    private var amount: Int? {
        guard kind != .free, let value = Int(amountText.filter(\.isNumber)), value > 0 else { return nil }
        return (kind == .balance && isPlus) ? value : -value
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty || amount != nil || !photos.isEmpty
    }

    private var suggestions: [String] {
        var seen = Set<String>()
        return allRecords.sorted { $0.createdAt > $1.createdAt }
            .map(\.category).filter { !$0.isEmpty && seen.insert($0).inserted }
            .prefix(8).map { $0 }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("種類", selection: $kind) {
                        ForEach(RecordKind.allCases, id: \.self) { kind in
                            Text(verbatim: kind.label).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    DatePicker("日付", selection: $day, displayedComponents: .date)
                }
                Section {
                    TextField("題名", text: $title)
                    if kind != .free {
                        HStack {
                            TextField("種目（例：食費、趣味、ライブ）", text: $category)
                            if !suggestions.isEmpty {
                                Menu {
                                    ForEach(suggestions, id: \.self) { name in
                                        Button(name) { category = name }
                                    }
                                } label: {
                                    Label("前に使った種目", systemImage: "chevron.down.circle").labelStyle(.iconOnly)
                                }
                            }
                        }
                        HStack(spacing: 12) {
                            if kind == .balance {
                                Picker("金額の向き", selection: $isPlus) {
                                    Text(verbatim: "+").tag(true)
                                    Text(verbatim: "\u{2212}").tag(false)
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 96)
                                .accessibilityLabel(Text("金額の向き"))
                            }
                            TextField(kind == .oshi ? "使った金額" : "金額", text: $amountText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .focused($amountFocused)
                            Text("円").foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    if kind == .balance {
                        Text("+ は入ったお金、\u{2212} は出たお金です。")
                    }
                }
                Section("メモ") {
                    TextField("メモ", text: $memo, axis: .vertical)
                        .lineLimit(3...8)
                }
                Section {
                    photoStrip
                } header: {
                    Text("写真")
                } footer: {
                    Text("1件に\(RecordEditor.maxPhotos)枚まで。")
                }
                if existing != nil {
                    Section {
                        Button("記録を削除", role: .destructive) { confirmDelete = true }
                            .confirmationDialog("この記録を削除しますか？", isPresented: $confirmDelete, titleVisibility: .visible) {
                                Button("記録を削除", role: .destructive) { delete() }
                                Button("キャンセル", role: .cancel) {}
                            }
                    }
                }
            }
            .navigationTitle(existing == nil ? "記録を追加" : "記録を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル", systemImage: "xmark") {
                        if changed && canSave { confirmDiscard = true } else { dismiss() }
                    }
                    .confirmationDialog("入力した内容を破棄しますか？", isPresented: $confirmDiscard, titleVisibility: .visible) {
                        Button("変更を破棄", role: .destructive) { dismiss() }
                        Button("キャンセル", role: .cancel) {}
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", systemImage: "checkmark") { save() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canSave || isLoadingPhotos)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完了") { amountFocused = false }
                }
            }
        }
        .interactiveDismissDisabled(changed && canSave)
        .onChange(of: title) { _, _ in changed = true }
        .onChange(of: amountText) { _, _ in changed = true }
        .onChange(of: memo) { _, _ in changed = true }
        .onChange(of: photos) { _, _ in changed = true }
        .onChange(of: picked) { _, items in
            guard !items.isEmpty else { return }
            Task { await load(items) }
        }
    }

    private var photoStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(photos.enumerated()), id: \.offset) { index, data in
                    ZStack(alignment: .topTrailing) {
                        if let image = UIImage(data: data) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 76, height: 76)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .accessibilityLabel(Text("写真 \(index + 1)"))
                        }
                        Button {
                            photos.remove(at: index)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .black.opacity(0.6))
                                .frame(width: 44, height: 44, alignment: .topTrailing)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("写真 \(index + 1) を外す"))
                    }
                }
                if isLoadingPhotos {
                    ProgressView().frame(width: 76, height: 76)
                }
                if photos.count < RecordEditor.maxPhotos {
                    PhotosPicker(selection: $picked, maxSelectionCount: RecordEditor.maxPhotos - photos.count,
                                 matching: .images) {
                        VStack(spacing: 4) {
                            Image(systemName: "photo.badge.plus").font(.title2)
                            Text("写真を追加").font(.caption)
                        }
                        .frame(width: 96, height: 76)
                        .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func load(_ items: [PhotosPickerItem]) async {
        isLoadingPhotos = true
        for item in items where photos.count < RecordEditor.maxPhotos {
            if let data = try? await item.loadTransferable(type: Data.self),
               let small = PhotoShrinker.jpeg(from: data) {
                photos.append(small)
            }
        }
        picked = []
        isLoadingPhotos = false
    }

    private func save() {
        let record = existing ?? Record(day: day, kind: kind)
        record.day = Calendar.current.startOfDay(for: day)
        record.kindRaw = kind.rawValue
        record.title = title.trimmingCharacters(in: .whitespaces)
        record.category = kind == .free ? "" : category.trimmingCharacters(in: .whitespaces)
        record.amount = amount
        record.memo = memo
        if existing == nil { context.insert(record) }
        for old in record.photos ?? [] { context.delete(old) }
        record.photos = photos.enumerated().map { index, data in RecordPhoto(data: data, order: index) }
        try? context.save()
        dismiss()
    }

    private func delete() {
        if let existing { context.delete(existing) }
        try? context.save()
        dismiss()
    }
}
