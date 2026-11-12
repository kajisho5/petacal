import Observation
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// S-13 ペタカレに送る: the sheet that opens from another app's share menu (LINE, mail, Safari, Photos).
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? []).flatMap { $0.attachments ?? [] }
        let model = ShareModel()
        let host = UIHostingController(rootView: ShareView(model: model) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        })
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
        Task { await model.load(providers) }
    }
}

@Observable
final class ShareModel {
    var text = ""
    var photos: [Data] = []
    var isLoading = true
    var saved: SharedItem.Kind?
    var failed = false

    func load(_ providers: [NSItemProvider]) async {
        var texts: [String] = []
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier), photos.count < ShareInbox.maxPhotos {
                if let data = await loadData(provider, type: .image), let small = ShareInbox.shrink(data) {
                    photos.append(small)
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                      !provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                if let url = await loadURL(provider) { texts.append(url.absoluteString) }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                if let string = await loadString(provider) { texts.append(string) }
            }
        }
        text = texts.joined(separator: "\n")
        isLoading = false
    }

    func save(_ kind: SharedItem.Kind) {
        do {
            try ShareInbox.save(kind: kind, text: text, photos: photos)
            saved = kind
        } catch {
            failed = true
        }
    }

    private func loadData(_ provider: NSItemProvider, type: UTType) async -> Data? {
        await withCheckedContinuation { continuation in
            _ = provider.loadDataRepresentation(for: type) { @Sendable data, _ in continuation.resume(returning: data) }
        }
    }

    private func loadString(_ provider: NSItemProvider) async -> String? {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: String.self) { @Sendable string, _ in continuation.resume(returning: string) }
        }
    }

    private func loadURL(_ provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: URL.self) { @Sendable url, _ in continuation.resume(returning: url) }
        }
    }
}

struct ShareView: View {
    let model: ShareModel
    let done: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                if model.isLoading {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("受け取った内容を読み込んでいます")
                    }
                } else if model.text.isEmpty && model.photos.isEmpty {
                    Section {
                        Label("この内容は受け取れません", systemImage: "exclamationmark.triangle")
                        Text("文章・リンク・写真を送ってください。").font(.footnote).foregroundStyle(.secondary)
                    }
                } else if let saved = model.saved {
                    Section {
                        Label(saved == .event ? "予定の候補として受け取りました" : "記録の下書きとして受け取りました",
                              systemImage: "checkmark.circle.fill")
                            .font(.headline)
                        Text("ペタカレを開くと、内容を確かめて保存できます。").foregroundStyle(.secondary)
                    }
                } else {
                    if !model.text.isEmpty {
                        Section("受け取った文章") {
                            Text(verbatim: model.text).lineLimit(8).font(.subheadline)
                        }
                    }
                    if !model.photos.isEmpty {
                        Section("受け取った写真（\(model.photos.count)枚）") {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(Array(model.photos.enumerated()), id: \.offset) { index, data in
                                        if let image = UIImage(data: data) {
                                            Image(uiImage: image).resizable().scaledToFill()
                                                .frame(width: 64, height: 64)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                                .accessibilityLabel(Text("写真 \(index + 1)"))
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Section {
                        Button {
                            model.save(.event)
                        } label: {
                            Label("予定にする", systemImage: "calendar.badge.plus")
                        }
                        .disabled(model.text.isEmpty)
                        Button {
                            model.save(.record)
                        } label: {
                            Label("記録にする", systemImage: "square.and.pencil")
                        }
                    } footer: {
                        Text("「予定にする」は文章の日付から予定の候補をつくります。「記録にする」は写真と文章を記録の下書きにします。どちらも、ペタカレを開いて確かめてから保存します。")
                    }
                }
            }
            .navigationTitle("ペタカレに送る")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(model.saved == nil ? "キャンセル" : "閉じる", systemImage: "xmark") { done() }
                }
            }
            .alert("受け取れませんでした", isPresented: Binding(get: { model.failed }, set: { model.failed = $0 })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("写真が大きすぎるか、端末の空きが足りない可能性があります。写真を減らして、もう一度送ってください。")
            }
        }
    }
}
