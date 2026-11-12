import SwiftData
import SwiftUI
import UserNotifications

@main
struct PetacalApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var calendarStore = CalendarStore()
    @State private var colorStore = ColorStore()
    @State private var lockGate = LockGate()
    @State private var undoCenter = UndoCenter()
    @State private var router = AppRouter()
    @State private var entitlements = EntitlementStore()
    private let notificationPresenter = NotificationPresenter()
    #if os(macOS)
    /// One store for the main window and the settings window.
    private let container: ModelContainer = {
        do {
            return try ModelContainer(for: Record.self, RecordPhoto.self)
        } catch {
            fatalError("The records could not be opened: \(error)")
        }
    }()
    #endif

    init() {
        UNUserNotificationCenter.current().delegate = notificationPresenter
    }

    var body: some Scene {
        #if os(macOS)
        WindowGroup {
            RootView()
                .environment(calendarStore)
                .environment(colorStore)
                .environment(lockGate)
                .environment(undoCenter)
                .environment(router)
                .environment(entitlements)
                .task { await entitlements.start() }
        }
        .modelContainer(container)
        .defaultSize(width: 1200, height: 780)
        .commands { AppCommands(router: router) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { lockGate.lock() }
        }

        Settings {
            NavigationStack { SettingsScreen() }
                .environment(calendarStore)
                .environment(colorStore)
                .environment(lockGate)
                .environment(undoCenter)
                .environment(entitlements)
                .frame(width: 520, height: 600)
        }
        .modelContainer(container)
        #else
        WindowGroup {
            RootView()
                .environment(calendarStore)
                .environment(colorStore)
                .environment(lockGate)
                .environment(undoCenter)
                .environment(router)
                .environment(entitlements)
                .task { await entitlements.start() }
        }
        .modelContainer(for: [Record.self, RecordPhoto.self])
        .commands { AppCommands(router: router) }
        .onChange(of: scenePhase, initial: true) { _, phase in
            // Closing the app locks the records again.
            if phase == .background { lockGate.lock() }
            // What was sent from another app's share menu, one at a time.
            if phase == .active, let payload = ShareInbox.next() { router.send(.shared(payload)) }
        }
        #endif
    }
}
