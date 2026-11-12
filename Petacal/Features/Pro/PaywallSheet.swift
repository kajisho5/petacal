import StoreKit
import SwiftUI

/// S-07 Pro の案内. Prices come from the App Store (in the person's currency), never from this file.
struct PaywallSheet: View {
    let reason: String?

    @Environment(EntitlementStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.purchase) private var purchase
    @Environment(\.openURL) private var openURL
    @State private var chosen = EntitlementStore.yearly
    @State private var isBuying = false
    @State private var failed = false

    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    private var product: Product? { store.products[chosen] }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ペタカレ Pro").font(.largeTitle.weight(.bold))
                        Text("予定も記録も、制限なしで残せます。").font(.body)
                        if let reason {
                            Label(reason, systemImage: "lock")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                        }
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        feature("sparkles", "AI取り込みが回数の制限なし", "無料版は月5回まで")
                        feature("chart.bar", "集計と予算", "種目別の収支、推し活・趣味の予算と使いすぎのお知らせ")
                        feature("photo", "写真を1件に10枚まで・まとめ画像", "無料版は1件に1枚")
                        feature("calendar.badge.clock", "候補日をつくる", "空き時間から日程調整の文面をつくる")
                    }
                    if store.isPro && !store.testUnlock {
                        Label("\(store.planName)を使っています。", systemImage: "checkmark.seal.fill")
                            .font(.headline)
                            .foregroundStyle(Color.accentColor)
                    } else {
                        plans
                        buyButton
                        Text(note)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                    }
                    VStack(spacing: 12) {
                        Button("購入を復元") { Task { await store.restore() } }
                        HStack(spacing: 16) {
                            Button("利用規約") { openURL(PaywallSheet.termsURL) }
                            NavigationLink("プライバシーポリシー") { PrivacyPolicyScreen() }
                        }
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                }
                .padding(24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("")
            .inlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる", systemImage: "xmark") { dismiss() }
                }
            }
            .alert("購入できませんでした", isPresented: $failed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("通信の状態を確かめて、もう一度試してください。お金は引き落とされていません。")
            }
        }
        .task { if !store.didLoad { await store.loadProducts() } }
    }

    private func feature(_ symbol: String, _ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 36)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var plans: some View {
        VStack(spacing: 10) {
            plan(EntitlementStore.yearly, title: "年額プラン", detail: "最初の1週間無料・2か月分お得", unit: "年")
            plan(EntitlementStore.monthly, title: "月額プラン", detail: "最初の1週間無料", unit: "月")
            plan(EntitlementStore.lifetime, title: "買い切り", detail: "1回の支払いでずっと使えます（お試しなし）", unit: nil)
            Text("価格はすべて税込").font(.caption).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func plan(_ id: String, title: LocalizedStringKey, detail: LocalizedStringKey, unit: String?) -> some View {
        let isOn = chosen == id
        let price = store.products[id].map { $0.displayPrice + (unit.map { "／\($0)" } ?? "") }
        return Button { chosen = id } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isOn ? Color.accentColor : Color.secondary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(detail).font(.footnote).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Text(verbatim: price ?? "—")
                    .font(.headline)
                    .monospacedDigit()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.fillBackground, in: RoundedRectangle(cornerRadius: 20))
            .overlay {
                if isOn { RoundedRectangle(cornerRadius: 20).strokeBorder(Color.accentColor, lineWidth: 2) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private var buyButton: some View {
        Button {
            guard let product else { return }
            Task {
                isBuying = true
                defer { isBuying = false }
                do {
                    let result = try await purchase(product)
                    if await store.finish(result) { dismiss() }
                } catch {
                    failed = true
                }
            }
        } label: {
            HStack(spacing: 8) {
                if isBuying { ProgressView() }
                Text(buttonTitle).font(.headline)
            }
            .frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .disabled(product == nil || isBuying || (store.hasLifetime))
    }

    private var buttonTitle: String {
        guard let product else {
            return store.didLoad ? String(localized: "いまは購入できません") : String(localized: "価格を読み込んでいます")
        }
        if chosen == EntitlementStore.lifetime { return String(localized: "\(product.displayPrice) で購入") }
        return String(localized: "1週間無料で始める")
    }

    private var note: String {
        guard let product else {
            return String(localized: "App Store から価格を読み込めませんでした。通信の状態を確かめてください。")
        }
        if chosen == EntitlementStore.lifetime {
            return store.hasSubscription
                ? String(localized: "買い切りを買ったあとも、サブスクリプションは自動では止まりません。「設定」→ 名前 →「サブスクリプション」から解約してください。")
                : String(localized: "1回だけの支払いです。自動更新はありません。")
        }
        let unit = chosen == EntitlementStore.yearly ? String(localized: "年") : String(localized: "月")
        return String(localized: "無料期間が終わると \(product.displayPrice)／\(unit)で自動更新されます。解約は「設定」→ 名前 →「サブスクリプション」からいつでも。")
    }
}

/// プライバシーポリシー (in the app until a public page exists).
struct PrivacyPolicyScreen: View {
    /// The same text, published on the web (store/privacy.html in this repository).
    static let webURL = URL(string: "https://seventh-well.com/petacal/privacy/")!

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("ペタカレは、あなたの予定・記録・写真を開発者のサーバーに送りません。広告や利用状況の分析も入っていません。")
                section("予定", "端末に登録してあるカレンダーを、許可をもらったうえで読み書きします。予定の内容はこの端末の中だけで扱います。")
                section("記録と写真", "記録・金額・メモ・写真はこの端末に保存します。")
                section("文字の読み取りと AI", "写真や文章の読み取り、AI による題名や場所の読み取りは、すべてこの端末の中で行います。")
                section("購入", "購入の手続きは Apple が行います。開発者が知ることができるのは、あなたを特定しない売上の集計だけです。")
                section("通知", "予算のお知らせはこの端末の中でつくります。文に金額は入れません。")
                section("お問い合わせ", "SEVENTHWELL　info@seventh-well.com")
                Link("ウェブで全文を見る", destination: PrivacyPolicyScreen.webURL)
                Text("2026年11月12日 制定").font(.footnote).foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: 640, alignment: .leading)
        }
        .navigationTitle("プライバシーポリシー")
        .inlineTitle()
    }

    private func section(_ title: LocalizedStringKey, _ body: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(body)
        }
    }
}

/// A small "Pro" mark next to features of the paid plan.
struct ProBadge: View {
    var body: some View {
        Text(verbatim: "Pro")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(Color.accentColor)
            .background(Color.accentColor.opacity(0.15), in: Capsule())
            .accessibilityLabel(Text("Pro の機能"))
    }
}
