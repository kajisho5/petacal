import PetaCore
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

/// S-14 写真をまとめて追加: pick many photos; they become one record per day they were taken.
struct BulkPhotosSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(CalendarStore.self) private var store
    @Environment(UndoCenter.self) private var undo

    @State private var picked: [PhotosPickerItem] = []
    @State private var photos: [(data: Data, takenAt: Date?)] = []
    @State private var loadedCount = 0
    @State private var isLoading = false
    @State private var kind: RecordKind = .free

    static let maxPhotos = 50

    private var groups: [PhotoGrouper.Group] {
        PhotoGrouper.group(takenAt: photos.map(\.takenAt), today: Date(), calendar: store.calendar)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    PhotosPicker(selection: $picked, maxSelectionCount: BulkPhotosSheet.maxPhotos, matching: .images) {
                        Label(photos.isEmpty ? "写真を選ぶ" : "写真を選び直す", systemImage: "photo.on.rectangle.angled")
                    }
                    if isLoading {
                        ProgressView(value: Double(loadedCount), total: Double(max(picked.count, 1))) {
                            Text("\(picked.count)枚中 \(loadedCount)枚を読み込みました")
                        }
                    }
                } footer: {
                    Text("写真を撮った日ごとに、1件の記録にまとめます（1件に\(RecordEditor.maxPhotos)枚まで。多い日は分けます）。撮った日が分からない写真は今日の記録になります。一度に\(BulkPhotosSheet.maxPhotos)枚まで選べます。")
                }
                if !photos.isEmpty {
                    Section {
                        Picker("記録の種類", selection: $kind) {
                            Text(verbatim: RecordKind.free.label).tag(RecordKind.free)
                            Text(verbatim: RecordKind.oshi.label).tag(RecordKind.oshi)
                        }
                    }
                    Section("できる記録（\(groups.count)日分）") {
                        ForEach(groups, id: \.day) { group in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(verbatim: "\(store.heading(group.day, today: nil))・\(group.indices.count)枚")
                                    .font(.subheadline.weight(.semibold))
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        ForEach(group.indices, id: \.self) { index in
                                            if let image = UIImage(data: photos[index].data) {
                                                Image(uiImage: image)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 56, height: 56)
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                                    .accessibilityHidden(true)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("写真をまとめて追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加", systemImage: "checkmark") { save() }
                        .buttonStyle(.borderedProminent)
                        .disabled(photos.isEmpty || isLoading)
                }
            }
        }
        .onChange(of: picked) { _, items in
            Task { await load(items) }
        }
    }

    private func load(_ items: [PhotosPickerItem]) async {
        isLoading = true
        loadedCount = 0
        var loaded: [(data: Data, takenAt: Date?)] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                let takenAt = PhotoMeta.takenAt(data)
                if let small = PhotoShrinker.jpeg(from: data) { loaded.append((small, takenAt)) }
            }
            loadedCount += 1
        }
        photos = loaded
        isLoading = false
    }

    private func save() {
        var created: [Record] = []
        for group in groups {
            guard let day = group.day.date(calendar: store.calendar) else { continue }
            // At most 10 photos per record: a busy day becomes several records.
            for start in stride(from: 0, to: group.indices.count, by: RecordEditor.maxPhotos) {
                let slice = group.indices[start..<min(start + RecordEditor.maxPhotos, group.indices.count)]
                let record = Record(day: day, kind: kind)
                record.source = "bulk"
                context.insert(record)
                record.photos = slice.enumerated().map { order, index in
                    RecordPhoto(data: photos[index].data, order: order, takenAt: photos[index].takenAt)
                }
                created.append(record)
            }
        }
        try? context.save()
        if !created.isEmpty {
            let modelContext = context
            undo.show(String(localized: "記録を\(created.count)件追加しました")) {
                for record in created { modelContext.delete(record) }
                try? modelContext.save()
            }
        }
        dismiss()
    }
}
