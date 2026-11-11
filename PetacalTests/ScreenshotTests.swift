import Foundation
import PetaCore
import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import Petacal

/// Draws the calendar with fictional events and saves PNGs, so the layout can be looked at after every CI run.
/// The files go to the folder in PETACAL_SHOTS (default /tmp/petacal-shots).
@Suite(.serialized) struct ScreenshotTests {
    private static let folder = URL(fileURLWithPath:
        ProcessInfo.processInfo.environment["PETACAL_SHOTS"] ?? "/tmp/petacal-shots")

    /// Fictional events around today: long titles, several-day spans, a crowded day and overlapping times.
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
        add("展示会の設営と本番（そらまめホール）とても長い題名の予定", day: 1, days: 3, calendarName: "仕事", color: blue)
        add("出張（みなと市）", day: 3, days: 2, calendarName: "仕事", color: blue)
        add("ソラマメーズ遠征とライブ鑑賞の旅", day: 5, days: 4, calendarName: "プライベート", color: green)
        add("架空の記念日", day: 0, calendarName: "家族", color: orange)
        add("家族で買い出しと大掃除の相談", day: 6, calendarName: "家族", color: orange)
        for index in 0..<6 {
            add("同じ日の予定その\(index + 1) 題名が長い場合", day: 2, calendarName: index % 2 == 0 ? "仕事" : "家族",
                color: index % 2 == 0 ? blue : orange)
        }
        add("週次ミーティング", day: 3, hour: 10, calendarName: "仕事", color: blue)
        add("そらまめ商店 打ち合わせ", day: 3, hour: 10.5, length: 1.5, calendarName: "仕事", color: blue)
        add("資料の確認", day: 3, hour: 11, length: 0.5, calendarName: "仕事", color: blue)
        add("歯医者", day: 4, hour: 9, length: 0.25, calendarName: "プライベート", color: green)
        add("懇親会", day: 4, hour: 12, length: 2, calendarName: "プライベート", color: green)
        add("企画レビュー", day: 1, hour: 13, length: 1, calendarName: "仕事", color: blue)
        add("来月の計画", day: 10, hour: 9, calendarName: "仕事", color: blue)
        add("実家へ帰省", day: -5, days: 3, calendarName: "家族", color: orange)
        return items
    }

    /// Fictional records in the current month and the two before it.
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
            Record(day: day(calendar.component(.day, from: today) - 1), kind: .balance, title: "ポイント還元",
                   category: "副収入", amount: 5400),
            Record(day: day(calendar.component(.day, from: today) - 1), kind: .free, title: "公園を散歩", memo: "紅葉がきれいだった"),
            Record(day: day(13), kind: .balance, title: "家電の買い替え", category: "日用品", amount: -8800),
            Record(day: day(18), kind: .oshi, title: "遠征の交通費", category: "ライブ・音楽", amount: -8800),
            Record(day: day(4, monthsBack: 1), kind: .balance, title: "副業の入金", category: "副収入", amount: 12000),
            Record(day: day(9, monthsBack: 1), kind: .balance, title: "食材", category: "食費", amount: -4300),
            Record(day: day(3, monthsBack: 2), kind: .balance, title: "修理代", category: "日用品", amount: -6500),
        ]
        for record in samples { container.mainContext.insert(record) }
        try container.mainContext.save()
        return container
    }

    private func shoot(_ name: String, mode: CalendarMode, pattern: MonthPattern = .bars,
                       style: UIUserInterfaceStyle = .dark) async throws {
        UserDefaults.standard.set(mode.rawValue, forKey: "calendar.mode")
        UserDefaults.standard.set(pattern.rawValue, forKey: "calendar.pattern")
        try await render(name, style: style, view: AnyView(NavigationStack { CalendarScreen() }))
    }

    private func render(_ name: String, style: UIUserInterfaceStyle, view: AnyView) async throws {
        let defaults = UserDefaults(suiteName: "petacal-tests-shots")!
        defaults.removePersistentDomain(forName: "petacal-tests-shots")
        let container = try ScreenshotTests.sampleContainer()
        let root = view
            .environment(CalendarStore(sample: ScreenshotTests.sample()))
            .environment(ColorStore(defaults: defaults))
            .environment(LockGate(defaults: defaults))
            .modelContainer(container)
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let frame = CGRect(x: 0, y: 0, width: 402, height: 874)
        let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow(frame: frame)
        window.frame = frame
        window.overrideUserInterfaceStyle = style
        window.rootViewController = UIHostingController(rootView: root)
        window.makeKeyAndVisible()
        try await Task.sleep(for: .milliseconds(1200))
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        try FileManager.default.createDirectory(at: ScreenshotTests.folder, withIntermediateDirectories: true)
        let data = try #require(image.pngData())
        try data.write(to: ScreenshotTests.folder.appendingPathComponent("\(name).png"))
        window.isHidden = true
        #expect(data.count > 10_000)
    }

    @Test func monthBarsDark() async throws { try await shoot("month-bars-dark", mode: .month) }
    @Test func monthBarsLight() async throws { try await shoot("month-bars-light", mode: .month, style: .light) }
    @Test func monthDots() async throws { try await shoot("month-dots-dark", mode: .month, pattern: .dots) }
    @Test func week() async throws { try await shoot("week-dark", mode: .week) }
    @Test func day() async throws { try await shoot("day-light", mode: .day, style: .light) }

    @Test func recordsAndStats() async throws {
        try await render("records-light", style: .light, view: AnyView(NavigationStack { RecordsScreen() }))
        try await render("stats-dark", style: .dark, view: AnyView(NavigationStack { StatsScreen() }))
        try await render("stats-light", style: .light, view: AnyView(NavigationStack { StatsScreen() }))
        try await render("record-editor-dark", style: .dark, view: AnyView(
            RecordEditor(target: .new(Calendar.current.startOfDay(for: Date())))))
        try await render("settings-calendars-light", style: .light, view: AnyView(NavigationStack { VisibleCalendarsScreen() }))
    }

    @Test func importText() async throws {
        let text = "来週の打ち合わせ、18日(水)15時からでお願いします。場所は会議室Bです。25日の懇親会は19時スタートです！"
        try await render("import-text-light", style: .light, view: AnyView(
            ImportTextSheet(sheet: .constant(nil), text: text, searchNow: true)))
        try await render("import-text-empty-dark", style: .dark, view: AnyView(ImportTextSheet(sheet: .constant(nil))))
    }

    @Test func quickAdd() async throws {
        let start = Calendar.current.startOfDay(for: Date())
        for (name, style) in [("quick-add-dark", UIUserInterfaceStyle.dark), ("quick-add-light", .light)] {
            try await render(name, style: style, view: AnyView(
                QuickAddSheet(start: start, allDay: true, sheet: .constant(nil), text: "明日15時 打ち合わせ")))
        }
    }
}
