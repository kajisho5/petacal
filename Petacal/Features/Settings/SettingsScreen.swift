import PetaCore
import SwiftUI

struct SettingsScreen: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "-"
        let build = info?["CFBundleVersion"] as? String ?? "-"
        return "\(short)（\(build)）"
    }

    var body: some View {
        List {
            Section("表示") {
                NavigationLink("カレンダーの表示") { PatternSettingsScreen() }
                NavigationLink("色分け") { ColorSettingsScreen() }
            }
            Section {
                LabeledContent("バージョン", value: version)
            } footer: {
                Text("端末のカレンダーの予定を表示・追加できるバージョンです。記録の機能はこのあと追加します。")
            }
        }
        .navigationTitle("設定")
    }
}

/// 設定 → カレンダーの表示: how the month looks.
struct PatternSettingsScreen: View {
    @AppStorage("calendar.pattern") private var patternRaw = MonthPattern.bars.rawValue

    var body: some View {
        List {
            Section {
                row(.bars, title: "帯（標準）", detail: "予定の題名が見える")
                row(.dots, title: "点と一覧", detail: "月は小さく、下に一覧")
            } footer: {
                Text("「日」「週」の画面は、どちらでも同じです。「金額」「写真」のパターンは、記録の機能と一緒に追加します。")
            }
        }
        .navigationTitle("カレンダーの表示")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ pattern: MonthPattern, title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        let isOn = patternRaw == pattern.rawValue
        return Button { patternRaw = pattern.rawValue } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundStyle(.primary)
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

/// 設定 → 色分け: one colour per calendar.
struct ColorSettingsScreen: View {
    @Environment(CalendarStore.self) private var store
    @Environment(ColorStore.self) private var colors
    @Environment(\.colorScheme) private var scheme
    @State private var editing: CalendarInfo?

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
                    Button { editing = info } label: {
                        HStack(spacing: 12) {
                            Circle().fill(colors.color(for: info, scheme: scheme)).frame(width: 24, height: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: info.title).foregroundStyle(.primary)
                                if !info.account.isEmpty {
                                    Text(verbatim: info.account).font(.footnote).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text(verbatim: colors.calendarChoices[info.id].flatMap(ColorPalette.preset)?.name
                                 ?? String(localized: "元の色"))
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.forward")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                        }
                        .contentShape(Rectangle())
                    }
                }
            } header: {
                Text("カレンダー")
            } footer: {
                Text("50色から選べます。予定を1件だけ別の色にするときは、予定を開いて「色」を選びます。ここで選んだ色はこのアプリの中だけで使い、Google カレンダーなど元のカレンダーの色は変わりません。記録の種類の色は、記録の機能と一緒に追加します。")
            }
        }
        .navigationTitle("色分け")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { info in
            ColorPickerSheet(info: info)
        }
        .onAppear { store.reload() }
    }
}

/// The picker as a sheet: nothing changes until the check mark is tapped.
private struct ColorPickerSheet: View {
    let info: CalendarInfo

    @Environment(ColorStore.self) private var colors
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Int?
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            ColorPickerView(title: "「\(info.title)」の色", sample: info.title, fallback: Color(info.color),
                            resetLabel: "元の色に戻す", selection: $draft)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("キャンセル", systemImage: "xmark") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完了", systemImage: "checkmark") {
                            colors.setCalendar(info.id, preset: draft)
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
        }
        .onAppear {
            if !loaded {
                draft = colors.calendarChoices[info.id]
                loaded = true
            }
        }
    }
}
