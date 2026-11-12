import AppKit
import Foundation
import PetaCore
import SwiftData
import SwiftUI
import Testing
@testable import Petacal

/// Draws the Mac window with fictional events and records and saves PNGs, so the layout can be looked at
/// after every CI run (nobody on this project has a Mac to open the app on).
/// The files go to the folder in PETACAL_SHOTS (default /tmp/petacal-shots-mac).
@Suite(.serialized) struct MacScreenshotTests {
    private static let folder = URL(fileURLWithPath:
        ProcessInfo.processInfo.environment["PETACAL_SHOTS"] ?? "/tmp/petacal-shots-mac")

    private static func sample() -> [EventItem] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekStart = DayKey(date: today, calendar: calendar).startOfWeek(calendar: calendar).date(calendar: calendar)!
        let blue = RGB(red: 0, green: 0.53, blue: 1)
        let green = RGB(red: 0.2, green: 0.78, blue: 0.35)
        let orange = RGB(red: 1, green: 0.58, blue: 0)
        var items: [EventItem] = []
        func add(_ title: String, day: Int, hour: Double? = nil, length: Double = 1, days: Int = 1,
                 calendarName: String, color: RGB) {
            let base = calendar.date(byAdding: .day, value: day, to: weekStart)!
            let start = hour.map { base.addingTimeInterval($0 * 3600) } ?? base
            let end = hour == nil
                ? calendar.date(byAdding: .day, value: days, to: base)!.addingTimeInterval(-1)
                : start.addingTimeInterval(length * 3600)
            items.append(EventItem(id: "s\(items.count)|\(start.timeIntervalSince1970)", eventIdentifier: "s\(items.count)",
                                   title: title, start: start, end: end, isAllDay: hour == nil,
                                   calendarID: calendarName, calendarTitle: calendarName, calendarColor: color,
                                   location: hour == nil ? nil : "みどり台ビル 3階"))
        }
        let todayOffset = calendar.dateComponents([.day], from: weekStart, to: today).day ?? 0
        add("展示会の設営と本番（そらまめホール）", day: 1, days: 3, calendarName: "仕事", color: blue)
        add("ソラマメーズ遠征", day: 5, days: 3, calendarName: "プライベート", color: green)
        add("家族で買い出し", day: 6, calendarName: "家族", color: orange)
        add("週次ミーティング", day: todayOffset, hour: 10, calendarName: "仕事", color: blue)
        add("そらまめ商店 打ち合わせ", day: todayOffset, hour: 13.5, calendarName: "仕事", color: blue)
        add("懇親会", day: todayOffset + 1, hour: 19, length: 2, calendarName: "プライベート", color: green)
        add("来月の計画", day: 10, hour: 9, calendarName: "仕事", color: blue)
        return items
    }

    private static func sampleContainer() throws -> ModelContainer {
        let container = try ModelContainer(for: Record.self, RecordPhoto.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let first = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
        func day(_ offset: Int, monthsBack: Int = 0) -> Date {
            let base = calendar.date(byAdding: .month, value: -monthsBack, to: first)!
            return calendar.date(byAdding: .day, value: offset, to: base)!
        }
        let samples: [Record] = [
            Record(day: day(2), kind: .oshi, title: "ソラマメーズ 新譜を購入", category: "ライブ・音楽", amount: -3300),
            Record(day: day(6), kind: .balance, title: "フリマの売り上げ", category: "副収入", amount: 3200),
            Record(day: day(7), kind: .balance, title: "まとめ買い", category: "食費", amount: -2000),
            Record(day: today, kind: .balance, title: "ポイント還元", category: "副収入", amount: 5400),
            Record(day: today, kind: .free, title: "公園を散歩", memo: "紅葉がきれいだった"),
            Record(day: day(13), kind: .balance, title: "家電の買い替え", category: "日用品", amount: -8800),
            Record(day: day(4, monthsBack: 1), kind: .balance, title: "副業の入金", category: "副収入", amount: 12000),
            Record(day: day(9, monthsBack: 1), kind: .balance, title: "食材", category: "食費", amount: -4300),
        ]
        for record in samples { container.mainContext.insert(record) }
        try container.mainContext.save()
        return container
    }

    private func render(_ name: String, dark: Bool, size: CGSize = CGSize(width: 1200, height: 780),
                        section: AppRouter.Section = .calendar, freePlan: Bool = false, view: AnyView? = nil) async throws {
        let defaults = UserDefaults(suiteName: "petacal-mac-tests-shots")!
        defaults.removePersistentDomain(forName: "petacal-mac-tests-shots")
        UserDefaults.standard.set(CalendarMode.month.rawValue, forKey: "calendar.mode")
        UserDefaults.standard.set(MonthPattern.bars.rawValue, forKey: "calendar.pattern")
        let router = AppRouter()
        router.section = section
        let root = (view ?? AnyView(RootView()))
            .environment(CalendarStore(sample: MacScreenshotTests.sample()))
            .environment(ColorStore(defaults: defaults))
            .environment(LockGate(defaults: defaults))
            .environment(UndoCenter())
            .environment(EntitlementStore(forced: !freePlan))
            .environment(router)
            .modelContainer(try MacScreenshotTests.sampleContainer())
        let controller = NSHostingController(rootView: root)
        controller.sceneBridgingOptions = [.title, .toolbars]
        let window = FreeSizeWindow(contentRect: NSRect(origin: .zero, size: size),
                              // The same style as the windows SwiftUI makes itself (contents run under the title bar).
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.contentViewController = controller
        window.setContentSize(size)
        window.orderFrontRegardless()
        try await Task.sleep(for: .milliseconds(1500))
        // The whole window (title bar and toolbar included) when it can be drawn, otherwise its contents.
        let target = window.contentView?.superview ?? controller.view
        let rep = try #require(target.bitmapImageRepForCachingDisplay(in: target.bounds))
        target.cacheDisplay(in: target.bounds, to: rep)
        let data = try #require(rep.representation(using: .png, properties: [:]))
        try FileManager.default.createDirectory(at: MacScreenshotTests.folder, withIntermediateDirectories: true)
        try data.write(to: MacScreenshotTests.folder.appendingPathComponent("\(name).png"))
        window.close()
        #expect(data.count > 10_000)
    }

    @Test func windowSections() async throws {
        try await render("mac-calendar-light", dark: false)
        try await render("mac-calendar-dark", dark: true)
        try await render("mac-records-light", dark: false, section: .records)
        try await render("mac-stats-dark", dark: true, section: .stats)
        try await render("mac-min-calendar-light", dark: false, size: CGSize(width: 800, height: 560))
    }

    /// App Store screenshots: 1440 × 900 points, one of the 16:10 sizes App Store Connect accepts
    /// (1440 × 900 or 2880 × 1800 pixels, depending on the runner's screen).
    @Test func storeShots() async throws {
        let size = CGSize(width: 1440, height: 900)
        try await render("store-mac-1-month", dark: false, size: size)
        try await render("store-mac-2-records", dark: false, size: size, section: .records)
        try await render("store-mac-3-stats", dark: false, size: size, section: .stats)
        try await render("store-mac-4-month-dark", dark: true, size: size)
    }

    /// The window the app opened by itself when the tests started it: its real title bar and toolbar
    /// (no sample data in it, so it shows the first-run screen).
    @Test func realWindow() async throws {
        try await Task.sleep(for: .milliseconds(1500))
        let window = try #require(NSApp.windows.first { $0.isVisible && $0.contentView != nil && $0.frame.width >= 600 })
        let target = window.contentView?.superview ?? window.contentView!
        let rep = try #require(target.bitmapImageRepForCachingDisplay(in: target.bounds))
        target.cacheDisplay(in: target.bounds, to: rep)
        let data = try #require(rep.representation(using: .png, properties: [:]))
        try FileManager.default.createDirectory(at: MacScreenshotTests.folder, withIntermediateDirectories: true)
        try data.write(to: MacScreenshotTests.folder.appendingPathComponent("mac-real-window.png"))
    }

    @Test func paywall() async throws {
        try await render("mac-paywall-light", dark: false, size: CGSize(width: 540, height: 760), freePlan: true,
                         view: AnyView(PaywallSheet(reason: nil).sheetSize()))
    }

    @Test func sheetsAndSettings() async throws {
        try await render("mac-settings-light", dark: false, size: CGSize(width: 520, height: 600),
                         view: AnyView(NavigationStack { SettingsScreen() }))
        let text = "来週の打ち合わせ、18日(水)15時からでお願いします。場所は会議室Bです。25日の懇親会は19時スタートです！"
        try await render("mac-import-light", dark: false, size: CGSize(width: 540, height: 640),
                         view: AnyView(ImportTextSheet(sheet: .constant(nil), text: text, searchNow: true).sheetSize()))
        try await render("mac-record-editor-dark", dark: true, size: CGSize(width: 540, height: 640),
                         view: AnyView(RecordEditor(target: .new(Calendar.current.startOfDay(for: Date()))).sheetSize()))
        try await render("mac-event-editor-light", dark: false, size: CGSize(width: 540, height: 560),
                         view: AnyView(EventEditor(store: CalendarStore(sample: []).eventStore, event: nil) {}.sheetSize()))
    }
}

/// A window that keeps the size it is given even when the runner's screen is smaller
/// (the CI Mac's screen is 1024 points wide; the App Store sizes are wider).
private final class FreeSizeWindow: NSWindow {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}
