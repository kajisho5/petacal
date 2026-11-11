import SwiftUI

/// The four top-level sections (design/design-spec.md, B-2 ナビゲーション).
/// iPhone: tab bar at the bottom. iPad: tab bar at the top that can turn into a sidebar.
/// iPhone Duo: the system moves the bars to the side by itself.
struct RootView: View {
    @Environment(UndoCenter.self) private var undo
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.section) {
            Tab("カレンダー", systemImage: "calendar", value: AppRouter.Section.calendar) {
                NavigationStack { CalendarScreen() }
            }
            Tab("記録", systemImage: "note.text", value: AppRouter.Section.records) {
                NavigationStack { RecordsScreen() }
            }
            Tab("集計", systemImage: "chart.bar", value: AppRouter.Section.stats) {
                NavigationStack { StatsScreen() }
            }
            Tab("設定", systemImage: "gearshape", value: AppRouter.Section.settings) {
                NavigationStack { SettingsScreen() }
            }
            Tab(value: AppRouter.Section.search, role: .search) {
                NavigationStack { SearchScreen() }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .overlay(alignment: .bottom) {
            UndoBanner()
                .frame(maxWidth: 520)
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
        .environment(AppRouter())
        .modelContainer(for: [Record.self, RecordPhoto.self], inMemory: true)
}
