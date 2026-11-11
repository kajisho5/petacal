import SwiftUI

/// The four top-level sections (design/design-spec.md, B-2 ナビゲーション).
struct RootView: View {
    var body: some View {
        TabView {
            Tab("カレンダー", systemImage: "calendar") {
                NavigationStack { CalendarScreen() }
            }
            Tab("記録", systemImage: "note.text") {
                NavigationStack {
                    ComingSoonScreen(title: "記録", systemImage: "note.text",
                                     message: "写真・金額・メモを、その日に残せるようになります。")
                }
            }
            Tab("集計", systemImage: "chart.bar") {
                NavigationStack {
                    ComingSoonScreen(title: "集計", systemImage: "chart.bar",
                                     message: "月ごとの収支と、推し活の予算を見られるようになります。")
                }
            }
            Tab("設定", systemImage: "gearshape") {
                NavigationStack { SettingsScreen() }
            }
        }
    }
}

#Preview {
    RootView()
}
