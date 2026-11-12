import PetaCore
import SwiftUI

struct SettingsScreen: View {
    @Environment(LockGate.self) private var lock
    @Environment(EntitlementStore.self) private var entitlements
    @State private var managing = false
    @Environment(\.openURL) private var openURL
    @State private var lockUnavailable = false
    @AppStorage("budget.oshi") private var oshiBudget = 0
    @AppStorage(BudgetNotifier.enabledKey) private var budgetNotify = false
    @State private var notifyDenied = false

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "-"
        let build = info?["CFBundleVersion"] as? String ?? "-"
        return "\(short)（\(build)）"
    }

    var body: some View {
        List {
            Section {
                LabeledContent("いまのプラン", value: entitlements.planName)
                if !entitlements.isPro || entitlements.testUnlock {
                    Button("Pro の内容を見る") { entitlements.ask(String(localized: "設定から開きました")) }
                }
                Button("購入を復元") { Task { await entitlements.restore() } }
                if entitlements.hasSubscription {
                    Button("サブスクリプションを管理") { managing = true }
                }
                NavigationLink("プライバシーポリシー") { PrivacyPolicyScreen() }
            } header: {
                Text("ペタカレ Pro")
            }
            Section("表示") {
                NavigationLink("表示するカレンダー") { VisibleCalendarsScreen() }
                NavigationLink("カレンダーの表示") { PatternSettingsScreen() }
                NavigationLink("色分け") { ColorSettingsScreen() }
            }
            Section {
                Toggle("記録をロック", isOn: Binding(
                    get: { lock.isEnabled },
                    set: { value in
                        if value && !LockGate.canAuthenticate {
                            lockUnavailable = true
                        } else {
                            Task { await lock.setEnabled(value) }
                        }
                    }))
                .alert("ロックを使えません", isPresented: $lockUnavailable) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("この端末にパスコードが設定されていません。「設定」アプリでパスコードを設定してから、もう一度試してください。")
                }
                LabeledContent("推し活・趣味の予算（月）") {
                    HStack(spacing: 4) {
                        TextField("なし", value: $oshiBudget, format: .number)
                            .numberPad()
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 120)
                        Text("円").foregroundStyle(.secondary)
                    }
                }
                if oshiBudget > 0 {
                    Toggle("予算の8割と超えたときに通知", isOn: Binding(
                        get: { budgetNotify },
                        set: { value in
                            guard value else { budgetNotify = false; return }
                            Task {
                                let granted = await BudgetNotifier.requestPermission()
                                budgetNotify = granted
                                notifyDenied = !granted
                            }
                        }))
                    .alert("通知を送れません", isPresented: $notifyDenied) {
                        Button("設定を開く") { SystemSettings.openNotifications() }
                        Button("閉じる", role: .cancel) {}
                    } message: {
                        Text("このアプリの通知がオフになっています。「設定」でオンにすると、予算のお知らせが届きます。")
                    }
                }
            } header: {
                Text("記録")
            } footer: {
                Text("ロックをオンにすると、記録・金額・集計は Face ID／Touch ID／パスコードで解除するまで隠れます。予定はそのまま見られます。アプリを閉じると、もう一度ロックされます。予算を入れると、集計に使った割合が出て、8割を超えたら知らせます（0 で予算なし）。通知の文には金額を入れません。")
            }
            Section {
                LabeledContent("バージョン", value: version)
            } footer: {
                Text("記録は今はこの端末の中だけに保存されます。iCloud でほかの端末とそろえる機能は、このあと追加します。")
            }
        }
        .navigationTitle("設定")
        #if os(iOS)
        .manageSubscriptionsSheet(isPresented: $managing)
        #else
        .onChange(of: managing) { _, open in
            if open, let url = URL(string: "https://apps.apple.com/account/subscriptions") { openURL(url) }
            managing = false
        }
        #endif
    }
}

/// 設定 → カレンダーの表示: how the month looks.
struct PatternSettingsScreen: View {
    @AppStorage("calendar.pattern") private var patternRaw = MonthPattern.bars.rawValue
    @Environment(EntitlementStore.self) private var entitlements

    var body: some View {
        List {
            Section {
                row(.bars, title: "帯（標準）", detail: "予定の題名が見える")
                row(.dots, title: "点と一覧", detail: "月は小さく、下に一覧")
                row(.amount, title: "金額", detail: "その日の金額を大きく", pro: true)
                row(.photo, title: "写真", detail: "記録の写真を日ごとに並べる", pro: true)
            } footer: {
                Text("「日」「週」の画面は、どのパターンでも同じです。「金額」「写真」は Pro で使えます。")
            }
        }
        .navigationTitle("カレンダーの表示")
        .inlineTitle()
    }

    private func row(_ pattern: MonthPattern, title: LocalizedStringKey, detail: LocalizedStringKey,
                     pro: Bool = false) -> some View {
        let isOn = patternRaw == pattern.rawValue
        let locked = pro && !entitlements.isPro
        return Button {
            if locked {
                entitlements.ask(String(localized: "月の「金額」「写真」の表示は Pro で使えます"))
            } else {
                patternRaw = pattern.rawValue
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title).foregroundStyle(.primary)
                        if pro { ProBadge() }
                    }
                    Text(detail).font(.footnote).foregroundStyle(.secondary)
                }
                Spacer()
                if isOn {
                    Image(systemName: "checkmark").fontWeight(.semibold).accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// 設定 → 色分け: one colour per calendar and per record kind.
struct ColorSettingsScreen: View {
    @Environment(CalendarStore.self) private var store
    @Environment(ColorStore.self) private var colors
    @Environment(\.colorScheme) private var scheme
    @State private var editing: ColorTarget?

    enum ColorTarget: Identifiable {
        case calendar(CalendarInfo)
        case kind(RecordKind)

        var id: String {
            switch self {
            case .calendar(let info): "calendar-\(info.id)"
            case .kind(let kind): "kind-\(kind.rawValue)"
            }
        }
    }

    var body: some View {
        List {
            Section {
                if store.calendars.isEmpty {
                    Text(store.access == .granted
                         ? "カレンダーがありません。"
                         : "カレンダーへのアクセスを許可すると、ここにカレンダーが並びます。")
                        .foregroundStyle(.secondary)
                }
                ForEach(store.calendars) { info in
                    row(color: colors.color(for: info, scheme: scheme), title: info.title, detail: info.account,
                        value: colors.calendarChoices[info.id].flatMap(ColorPalette.preset)?.name ?? String(localized: "元の色")) {
                        editing = .calendar(info)
                    }
                }
            } header: {
                Text("カレンダー")
            }
            Section {
                ForEach(RecordKind.allCases, id: \.self) { kind in
                    row(color: colors.color(for: kind, scheme: scheme), title: kind.label, detail: "",
                        value: colors.preset(for: kind).name) {
                        editing = .kind(kind)
                    }
                }
            } header: {
                Text("記録の種類")
            } footer: {
                Text("50色から選べます。予定を1件だけ別の色にするときは、予定を開いて「色」を選びます。ここで選んだ色はこのアプリの中だけで使い、Google カレンダーなど元のカレンダーの色は変わりません。")
            }
        }
        .navigationTitle("色分け")
        .inlineTitle()
        .sheet(item: $editing) { target in
            ColorPickerSheet(target: target).sheetSize()
        }
        .onAppear { store.reload() }
    }

    private func row(color: Color, title: String, detail: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Circle().fill(color).frame(width: 24, height: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: title).foregroundStyle(.primary)
                    if !detail.isEmpty {
                        Text(verbatim: detail).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(verbatim: value).foregroundStyle(.secondary)
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// The picker as a sheet: nothing changes until the check mark is tapped.
private struct ColorPickerSheet: View {
    let target: ColorSettingsScreen.ColorTarget

    @Environment(ColorStore.self) private var colors
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Int?
    @State private var loaded = false

    private var name: String {
        switch target {
        case .calendar(let info): info.title
        case .kind(let kind): kind.label
        }
    }

    private var fallback: Color {
        switch target {
        case .calendar(let info): Color(info.color)
        case .kind(let kind): ColorPalette.preset(ColorStore.kindDefaults[kind] ?? 45).map { Color($0, scheme: scheme) } ?? .gray
        }
    }

    var body: some View {
        NavigationStack {
            ColorPickerView(title: "「\(name)」の色", sample: name, fallback: fallback,
                            resetLabel: "最初の色に戻す", selection: $draft)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("キャンセル", systemImage: "xmark") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完了", systemImage: "checkmark") {
                            switch target {
                            case .calendar(let info): colors.setCalendar(info.id, preset: draft)
                            case .kind(let kind): colors.setKind(kind, preset: draft)
                            }
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
        }
        .onAppear {
            if !loaded {
                switch target {
                case .calendar(let info): draft = colors.calendarChoices[info.id]
                case .kind(let kind): draft = colors.kindChoices[kind.rawValue]
                }
                loaded = true
            }
        }
    }
}

/// 設定 → 表示するカレンダー: which of the calendars registered on the device show up in this app.
struct VisibleCalendarsScreen: View {
    @Environment(CalendarStore.self) private var store
    @Environment(ColorStore.self) private var colors
    @Environment(\.colorScheme) private var scheme

    private var accounts: [(name: String, calendars: [CalendarInfo])] {
        Dictionary(grouping: store.calendars, by: \.account)
            .map { (name: $0.key, calendars: $0.value) }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        List {
            if store.calendars.isEmpty {
                Text(store.access == .granted
                     ? "カレンダーがありません。"
                     : "カレンダーへのアクセスを許可すると、ここにカレンダーが並びます。")
                    .foregroundStyle(.secondary)
            }
            ForEach(accounts, id: \.name) { account in
                Section {
                    ForEach(account.calendars) { info in
                        Toggle(isOn: Binding(
                            get: { store.isVisible(info.id) },
                            set: { store.setVisible(info.id, $0) })) {
                            HStack(spacing: 12) {
                                Circle().fill(colors.color(for: info, scheme: scheme)).frame(width: 14, height: 14)
                                Text(verbatim: info.title)
                            }
                        }
                    }
                } header: {
                    Text(verbatim: account.name.isEmpty ? String(localized: "この端末") : account.name)
                }
            }
            if !store.calendars.isEmpty {
                Section {
                    Button("すべて表示") { store.calendars.forEach { store.setVisible($0.id, true) } }
                } footer: {
                    Text("オフにしたカレンダーの予定は、このアプリに出なくなります（元のカレンダーからは消えません）。カレンダーやアカウントの追加・削除は、端末の「設定」アプリのカレンダーの項目で行います。")
                }
            }
        }
        .navigationTitle("表示するカレンダー")
        .inlineTitle()
        .onAppear { store.reload() }
    }
}
