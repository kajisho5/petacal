import SwiftUI

/// The four top-level sections (design/design-spec.md, B-2 ナビゲーション).
struct RootView: View {
    @Environment(UndoCenter.self) private var undo

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
            Tab(role: .search) {
                NavigationStack { SearchScreen() }
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .overlay(alignment: .bottom) {
            UndoBanner()
                .padding(.bottom, 72)      // above the tab bar
                .animation(.snappy, value: undo.message)
        }
    }
}

#Preview {
    RootView()
        .environment(CalendarStore())
        .environment(ColorStore())
        .environment(LockGate())
        .environment(UndoCenter())
        .modelContainer(for: [Record.self, RecordPhoto.self], inMemory: true)
}
