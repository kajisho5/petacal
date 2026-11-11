import SwiftData
import SwiftUI

@main
struct PetacalApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var calendarStore = CalendarStore()
    @State private var colorStore = ColorStore()
    @State private var lockGate = LockGate()
    @State private var undoCenter = UndoCenter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(calendarStore)
                .environment(colorStore)
                .environment(lockGate)
                .environment(undoCenter)
        }
        .modelContainer(for: [Record.self, RecordPhoto.self])
        .onChange(of: scenePhase) { _, phase in
            // Closing the app locks the records again.
            if phase == .background { lockGate.lock() }
        }
    }
}
