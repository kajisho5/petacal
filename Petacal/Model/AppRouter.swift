import Observation
import SwiftUI

/// Which section is on screen, and commands sent from the keyboard or the menu bar
/// (design-spec B-4: ⌘N, ⇧⌘N, ⌘T, ⌘F, ⌘1〜⌘4).
@Observable
final class AppRouter {
    enum Section: Hashable {
        case calendar, records, stats, settings, search
    }

    enum Command: Equatable {
        case newRecord, newEvent, importText, today
    }

    var section: Section = .calendar
    /// Picked up (and cleared) by the calendar screen.
    var command: Command?

    func send(_ command: Command) {
        section = .calendar
        self.command = command
    }
}

/// The menu bar on iPad and Mac. Every item here is also reachable from the screen itself.
struct AppCommands: Commands {
    let router: AppRouter

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("記録を追加") { router.send(.newRecord) }
                .keyboardShortcut("n", modifiers: .command)
            Button("予定を追加") { router.send(.newEvent) }
                .keyboardShortcut("e", modifiers: .command)
            Button("文章から予定をつくる") { router.send(.importText) }
                .keyboardShortcut("n", modifiers: [.command, .shift])
        }
        CommandGroup(before: .toolbar) {
            Button("今日") { router.send(.today) }
                .keyboardShortcut("t", modifiers: .command)
            Divider()
            Button("カレンダー") { router.section = .calendar }
                .keyboardShortcut("1", modifiers: .command)
            Button("記録") { router.section = .records }
                .keyboardShortcut("2", modifiers: .command)
            Button("集計") { router.section = .stats }
                .keyboardShortcut("3", modifiers: .command)
            #if !os(macOS)
            Button("設定") { router.section = .settings }
                .keyboardShortcut("4", modifiers: .command)
            #endif
            Button("検索") { router.section = .search }
                .keyboardShortcut("f", modifiers: .command)
            Divider()
        }
    }
}
