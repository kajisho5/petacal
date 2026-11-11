import SwiftUI

/// The four top-level sections (design/design-spec.md, B-2 ナビゲーション).
struct RootView: View {
    var body: some View {
        TabView {
            Tab("カレンダー", systemImage: "calendar") {
                NavigationStack { CalendarScreen() }
            }
            Tab("記録", systemImage: "note.text") {
                NavigationStack { RecordsScreen() }
            }
            Tab("集計", systemImage: "chart.bar") {
                NavigationStack { StatsScreen() }
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
