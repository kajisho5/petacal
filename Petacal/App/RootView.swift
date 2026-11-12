import SwiftUI

#if os(macOS)
/// The Mac window: a sidebar with the sections and the calendars to show, the chosen section beside it.
/// Settings live in their own window (ペタカレ → 設定…, ⌘,), as on every Mac app.
struct RootView: View {
    @Environment(UndoCenter.self) private var undo
    @Environment(AppRouter.self) private var router
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(CalendarStore.self) private var store
    @Environment(ColorStore.self) private var colors
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let selection = Binding<AppRouter.Section?>(
            get: { router.section == .settings ? .calendar : router.section },
            set: { if let section = $0 { router.section = section } })
        NavigationSplitView {
            List(selection: selection) {
                Label("カレンダー", systemImage: "calendar").tag(AppRouter.Section.calendar)
                Label("記録", systemImage: "note.text").tag(AppRouter.Section.records)
                Label("集計", systemImage: "chart.bar").tag(AppRouter.Section.stats)
                Label("検索", systemImage: "magnifyingglass").tag(AppRouter.Section.search)
                if !store.calendars.isEmpty {
                    Section("表示するカレンダー") {
                        ForEach(store.calendars) { info in
                            Toggle(isOn: Binding(
                                get: { store.isVisible(info.id) },
                                set: { store.setVisible(info.id, $0) })) {
                                HStack(spacing: 8) {
                                    Circle().fill(colors.color(for: info, scheme: scheme)).frame(width: 10, height: 10)
                                        .accessibilityHidden(true)
                                    Text(verbatim: info.title)
                                }
                            }
                            .toggleStyle(.checkbox)
                            .selectionDisabled()
                        }
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
        } detail: {
            NavigationStack {
                switch router.section {
                case .records: RecordsScreen()
                case .stats: StatsScreen()
                case .search: SearchScreen()
                case .calendar, .settings: CalendarScreen()
                }
            }
        }
        // Smaller than this and the month can no longer show its bars (design-spec B-4).
        .frame(minWidth: 800, minHeight: 560)
        .sheet(isPresented: Binding(get: { entitlements.paywallReason != nil },
                                    set: { if !$0 { entitlements.paywallReason = nil } })) {
            PaywallSheet(reason: entitlements.paywallReason).sheetSize()
        }
        .overlay(alignment: .bottom) {
            UndoBanner()
                .frame(maxWidth: 520)
                .padding(.bottom, 16)
                .animation(.snappy, value: undo.message)
        }
    }
}
#else
/// The four top-level sections (design/design-spec.md, B-2 ナビゲーション).
/// iPhone: tab bar at the bottom. iPad: tab bar at the top that can turn into a sidebar.
/// iPhone Duo: the system moves the bars to the side by itself.
struct RootView: View {
    @Environment(UndoCenter.self) private var undo
    @Environment(AppRouter.self) private var router
    @Environment(EntitlementStore.self) private var entitlements

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
        .sheet(isPresented: Binding(get: { entitlements.paywallReason != nil },
                                    set: { if !$0 { entitlements.paywallReason = nil } })) {
            PaywallSheet(reason: entitlements.paywallReason).sheetSize()
        }
        .overlay(alignment: .bottom) {
            UndoBanner()
                .frame(maxWidth: 520)
                .padding(.bottom, 72)      // above the tab bar
                .animation(.snappy, value: undo.message)
        }
    }
}
#endif

#Preview {
    RootView()
        .environment(CalendarStore())
        .environment(ColorStore())
        .environment(LockGate())
        .environment(UndoCenter())
        .environment(AppRouter())
        .environment(EntitlementStore(forced: false))
        .modelContainer(for: [Record.self, RecordPhoto.self], inMemory: true)
}
