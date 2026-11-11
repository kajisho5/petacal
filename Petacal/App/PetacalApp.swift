import SwiftUI

@main
struct PetacalApp: App {
    @State private var calendarStore = CalendarStore()
    @State private var colorStore = ColorStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(calendarStore)
                .environment(colorStore)
        }
    }
}
