import PetaCore
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// S-12 まとめ画像: the month in one picture to save or share.
struct SummarySheet: View {
    let year: Int
    let month: Int
    let stats: MonthStats

    @Environment(\.dismiss) private var dismiss
    @State private var showAmounts = true
    @State private var includeOshi = true
    @State private var image: NativeImage?

    private var card: SummaryCard {
        SummaryCard(year: year, month: month, stats: stats, showAmounts: showAmounts, includeOshi: includeOshi)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    card
                        .frame(maxWidth: .infinity)
                        .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
                        .listRowBackground(Color.clear)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text(verbatim: card.spoken))
                }
                Section {
                    Toggle("金額を表示", isOn: $showAmounts)
                    Toggle("推し活・趣味を含める", isOn: $includeOshi)
                } footer: {
                    Text("金額を隠すと、件数だけの画像になります。")
                }
                Section {
                    if let image {
                        ShareLink(item: Image(native: image),
                                  preview: SharePreview(Text(verbatim: "\(year)年\(month)月のまとめ"), image: Image(native: image))) {
                            Label("画像を保存・共有", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
            .navigationTitle("まとめ画像")
            .inlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .onAppear { render() }
        .onChange(of: showAmounts) { _, _ in render() }
        .onChange(of: includeOshi) { _, _ in render() }
    }

    private func render() {
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        #if os(macOS)
        image = renderer.nsImage
        #else
        image = renderer.uiImage
        #endif
    }
}

/// The picture itself. Fixed colours (dark navy, white text) whatever the appearance.
struct SummaryCard: View {
    let year: Int
    let month: Int
    let stats: MonthStats
    let showAmounts: Bool
    let includeOshi: Bool

    private let navy = Color(red: 0.12, green: 0.16, blue: 0.27)

    var spoken: String {
        var text = "\(year)年\(month)月のまとめ。プラス\(stats.plusCount)件、マイナス\(stats.minusCount)件。"
        if showAmounts { text += "収支の合計 \(Yen.signed(stats.balanceTotal))。" }
        if includeOshi && stats.oshiCount > 0 {
            text += "推し活・趣味 \(stats.oshiCount)件" + (showAmounts ? " \(Yen.plain(stats.oshiSpent))。" : "。")
        }
        return text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(verbatim: "\(year)年\(month)月のまとめ")
                .font(.system(size: 20, weight: .semibold))
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: "収支の合計").font(.system(size: 13)).opacity(0.75)
                Text(verbatim: showAmounts ? Yen.signed(stats.balanceTotal) : "＊＊＊")
                    .font(.system(size: 40, weight: .bold))
                    .monospacedDigit()
                Text(verbatim: "プラス \(stats.plusCount)件・マイナス \(stats.minusCount)件")
                    .font(.system(size: 13)).opacity(0.75)
            }
            if !stats.byCategory.isEmpty {
                Rectangle().fill(Color.white.opacity(0.25)).frame(height: 1)
                ForEach(Array(stats.byCategory.prefix(4).enumerated()), id: \.offset) { _, row in
                    HStack {
                        Text(verbatim: row.name)
                        Spacer()
                        Text(verbatim: showAmounts ? Yen.signed(row.total) : "\(row.count)件").monospacedDigit()
                    }
                    .font(.system(size: 15))
                }
            }
            if includeOshi && stats.oshiCount > 0 {
                Rectangle().fill(Color.white.opacity(0.25)).frame(height: 1)
                HStack {
                    Text(verbatim: "推し活・趣味")
                    Spacer()
                    Text(verbatim: showAmounts ? Yen.plain(stats.oshiSpent) : "\(stats.oshiCount)件").monospacedDigit()
                }
                .font(.system(size: 15))
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(Color.white)
        .padding(24)
        .frame(width: 320, height: 400, alignment: .topLeading)
        .background(navy)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}
