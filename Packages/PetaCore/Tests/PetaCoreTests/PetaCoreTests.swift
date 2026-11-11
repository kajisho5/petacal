import Foundation
import Testing
@testable import PetaCore

/// Gregorian calendar fixed to Japan time, weeks starting on Sunday.
private let jst: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 9 * 3600)!
    calendar.firstWeekday = 1
    return calendar
}()

private func at(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0) -> Date {
    var c = DateComponents()
    c.year = y
    c.month = mo
    c.day = d
    c.hour = h
    c.minute = mi
    return jst.date(from: c)!
}

@Suite struct DayKeyTests {
    @Test func roundTripsAndRejectsMissingDays() {
        let key = DayKey(year: 2026, month: 11, day: 11)
        #expect(DayKey(date: key.date(calendar: jst)!, calendar: jst) == key)
        #expect(key.weekday(calendar: jst) == 4)   // Wednesday
        #expect(DayKey(year: 2026, month: 2, day: 30).date(calendar: jst) == nil)
        #expect(DayKey(year: 2026, month: 11, day: 3) < DayKey(year: 2026, month: 11, day: 11))
        #expect(DayKey(year: 2025, month: 12, day: 31) < DayKey(year: 2026, month: 1, day: 1))
    }
}

@Suite struct MonthGridTests {
    @Test func november2026StartsOnSunday() {
        let grid = MonthGrid(year: 2026, month: 11, calendar: jst)
        #expect(grid.dayCount == 30)
        #expect(grid.weeks.count == 5)
        #expect(grid.weeks[0] == [1, 2, 3, 4, 5, 6, 7])
        #expect(grid.weeks[4] == [29, 30, nil, nil, nil, nil, nil])
        #expect(grid.weekdaySymbols == ["日", "月", "火", "水", "木", "金", "土"])
    }

    @Test func leadingBlanksAndMondayStart() {
        // 1 December 2026 is a Tuesday.
        let grid = MonthGrid(year: 2026, month: 12, calendar: jst)
        #expect(grid.weeks[0] == [nil, nil, 1, 2, 3, 4, 5])
        #expect(grid.dayCount == 31)
        var monday = jst
        monday.firstWeekday = 2
        let mondayGrid = MonthGrid(year: 2026, month: 12, calendar: monday)
        #expect(mondayGrid.weeks[0] == [nil, 1, 2, 3, 4, 5, 6])
        #expect(mondayGrid.weekdaySymbols.first == "月")
        #expect(mondayGrid.weeks.allSatisfy { $0.count == 7 })
    }

    @Test func february2028IsALeapMonth() {
        #expect(MonthGrid(year: 2028, month: 2, calendar: jst).dayCount == 29)
    }

    @Test func shiftsAcrossYears() {
        func shifted(_ year: Int, _ month: Int, _ offset: Int) -> [Int] {
            let result = MonthGrid.shifted(year: year, month: month, by: offset)
            return [result.year, result.month]
        }
        #expect(shifted(2026, 12, 1) == [2027, 1])
        #expect(shifted(2026, 1, -1) == [2025, 12])
        #expect(shifted(2026, 11, -23) == [2024, 12])
        #expect(shifted(2026, 11, 0) == [2026, 11])
    }
}

@Suite struct YenTests {
    @Test func groupsAndSigns() {
        #expect(Yen.grouped(0) == "0")
        #expect(Yen.grouped(999) == "999")
        #expect(Yen.grouped(1000) == "1,000")
        #expect(Yen.grouped(12100) == "12,100")
        #expect(Yen.grouped(1234567) == "1,234,567")
        #expect(Yen.signed(5400) == "+5,400円")
        #expect(Yen.signed(-2000) == "\u{2212}2,000円")
        #expect(Yen.signed(0) == "0円")
        #expect(Yen.signed(6600, unit: false) == "+6,600")
        #expect(Yen.plain(-12100) == "12,100円")
    }
}

@Suite struct StatsTests {
    @Test func monthTotalsMatchTheDesignSample() {
        let stats = StatsCalculator.monthStats([
            RecordAmount(kind: .oshi, category: "ソラマメーズ", amount: -3300),
            RecordAmount(kind: .balance, category: "競馬", amount: 3200),
            RecordAmount(kind: .balance, category: "競艇", amount: -2000),
            RecordAmount(kind: .balance, category: "FX", amount: 5400),
            RecordAmount(kind: .oshi, category: "ソラマメーズ", amount: -8800),
            RecordAmount(kind: .free),
        ])
        #expect(stats.balanceTotal == 6600)
        #expect(stats.plusCount == 2)
        #expect(stats.minusCount == 1)
        #expect(stats.byCategory.map(\.name) == ["FX", "競馬", "競艇"])
        #expect(stats.byCategory.map(\.total) == [5400, 3200, -2000])
        #expect(stats.oshiSpent == 12100)
        #expect(stats.oshiCount == 2)
    }

    @Test func emptyAndUncategorized() {
        #expect(StatsCalculator.monthStats([]) == MonthStats())
        let stats = StatsCalculator.monthStats([
            RecordAmount(kind: .balance, category: nil, amount: 100),
            RecordAmount(kind: .balance, category: "", amount: 200),
            RecordAmount(kind: .balance, category: "FX", amount: nil),
            RecordAmount(kind: .oshi, amount: 500),   // a refund is not spending
        ])
        #expect(stats.byCategory == [CategoryTotal(name: "その他", total: 300, count: 2)])
        #expect(stats.oshiSpent == 0)
        #expect(stats.oshiCount == 1)
    }

    @Test func budgetLevels() {
        let near = BudgetUsage(limit: 15000, spent: 12100)
        #expect(near.percent == 81)
        #expect(near.remaining == 2900)
        #expect(near.level == .near)
        #expect(BudgetUsage(limit: 15000, spent: 11999).level == .ok)
        #expect(BudgetUsage(limit: 15000, spent: 12000).level == .near)
        #expect(BudgetUsage(limit: 15000, spent: 15000).level == .near)
        #expect(BudgetUsage(limit: 15000, spent: 15001).level == .over)
        #expect(BudgetUsage(limit: 0, spent: 500).level == .ok)
        #expect(BudgetUsage(limit: 0, spent: 500).percent == 0)
    }
}

@Suite struct QuotaTests {
    @Test func countsDownAndResetsEachMonth() {
        let november = MonthlyQuota.key(for: at(2026, 11, 11), calendar: jst)
        let december = MonthlyQuota.key(for: at(2026, 12, 1), calendar: jst)
        #expect(november == "2026-11")
        #expect(MonthlyQuota.key(for: at(2027, 1, 5), calendar: jst) == "2027-01")
        var quota = MonthlyQuota()
        #expect(quota.remaining(monthKey: november) == 5)
        for _ in 0..<5 {
            let consumed = quota.consume(monthKey: november)
            #expect(consumed)
        }
        #expect(quota.remaining(monthKey: november) == 0)
        let sixth = quota.consume(monthKey: november)
        #expect(!sixth)
        #expect(quota.used == 5)
        #expect(quota.remaining(monthKey: december) == 5)
        let nextMonth = quota.consume(monthKey: december)
        #expect(nextMonth)
        #expect(quota.remaining(monthKey: december) == 4)
    }
}

@Suite struct PhotoGrouperTests {
    @Test func groupsByDayAndPutsUndatedPhotosOnToday() {
        let groups = PhotoGrouper.group(
            takenAt: [at(2026, 11, 11, 9), at(2026, 11, 7, 23, 59), nil, at(2026, 11, 8, 0, 0), at(2026, 11, 7, 8)],
            today: at(2026, 11, 11, 12), calendar: jst)
        #expect(groups.map(\.day.day) == [7, 8, 11])
        #expect(groups.map(\.indices) == [[1, 4], [3], [0, 2]])
        #expect(PhotoGrouper.group(takenAt: [], today: at(2026, 11, 11), calendar: jst).isEmpty)
    }
}

@Suite struct SlotFinderTests {
    private let week = SlotRequest(firstDay: DayKey(year: 2026, month: 11, day: 14),
                                   lastDay: DayKey(year: 2026, month: 11, day: 17), limitPerDay: 1)

    @Test func skipsWeekendsAndBusyTime() {
        let busy = [TimeRange(start: at(2026, 11, 16, 9, 30), end: at(2026, 11, 16, 11, 15))]
        let slots = SlotFinder.freeSlots(week, busy: busy, calendar: jst)
        // 14 (Sat) and 15 (Sun) are skipped; Monday starts after the meeting, on the half hour.
        #expect(slots == [TimeRange(start: at(2026, 11, 16, 11, 30), end: at(2026, 11, 16, 12, 30)),
                          TimeRange(start: at(2026, 11, 17, 10, 0), end: at(2026, 11, 17, 11, 0))])
    }

    @Test func respectsTheDayEndAndBackToBackEvents() {
        var request = week
        request.firstDay = DayKey(year: 2026, month: 11, day: 16)
        request.lastDay = request.firstDay
        request.limitPerDay = 5
        let busy = [TimeRange(start: at(2026, 11, 16, 10), end: at(2026, 11, 16, 16)),
                    TimeRange(start: at(2026, 11, 16, 17), end: at(2026, 11, 16, 17, 30))]
        // 16:00-17:00 touches both events without overlapping; 17:30-18:30 would pass the end of the day.
        #expect(SlotFinder.freeSlots(request, busy: busy, calendar: jst)
                == [TimeRange(start: at(2026, 11, 16, 16), end: at(2026, 11, 16, 17))])
        request.weekdaysOnly = false
        request.firstDay = DayKey(year: 2026, month: 11, day: 15)
        request.lastDay = request.firstDay
        request.limitPerDay = 2
        #expect(SlotFinder.freeSlots(request, busy: [], calendar: jst).count == 2)
    }

    @Test func rejectsImpossibleRequests() {
        var request = week
        request.minutes = 0
        #expect(SlotFinder.freeSlots(request, busy: [], calendar: jst).isEmpty)
        request = week
        request.dayEndHour = request.dayStartHour
        #expect(SlotFinder.freeSlots(request, busy: [], calendar: jst).isEmpty)
        request = week
        request.minutes = 9 * 60
        #expect(SlotFinder.freeSlots(request, busy: [], calendar: jst).isEmpty)
    }

    @Test func writesTheMessage() {
        let slots = [TimeRange(start: at(2026, 11, 17, 10), end: at(2026, 11, 17, 11)),
                     TimeRange(start: at(2026, 11, 20, 16, 5), end: at(2026, 11, 20, 17, 5))]
        #expect(SlotFinder.message(for: slots, calendar: jst) == """
            以下の日程はいかがでしょうか。
            ・11/17（火） 10:00〜11:00
            ・11/20（金） 16:05〜17:05
            ご都合をお知らせください。
            """)
    }
}

@Suite struct JapaneseDateParserTests {
    private let now = at(2026, 11, 11, 9, 41)

    private func parse(_ text: String) -> [JapaneseDateParser.Moment] {
        JapaneseDateParser.parse(text, now: now, calendar: jst)
    }

    private func summary(_ text: String) -> [String] {
        parse(text).map { m in
            "\(m.day.year)-\(m.day.month)-\(m.day.day)" + (m.hour.map { " \($0):\(m.minute ?? 0)" } ?? "")
        }
    }

    @Test func readsTheDesignSample() {
        let text = "来週の打ち合わせ、18日(水)15時からでお願いします。場所は会議室Bです。25日の懇親会は19時スタートです！"
        #expect(summary(text) == ["2026-11-18 15:0", "2026-11-25 19:0"])
    }

    @Test func readsFullDatesSlashesAndClockTimes() {
        #expect(summary("2027年1月5日 10:30 開始") == ["2027-1-5 10:30"])
        #expect(summary("11月20日（金）午後3時半から") == ["2026-11-20 15:30"])
        #expect(summary("締切は12/1、発表は12/24の夜8時") == ["2026-12-1", "2026-12-24 20:0"])
        #expect(summary("１１月１８日　１５：００") == ["2026-11-18 15:0"])
        #expect(summary("11月18日 午前9時15分 集合") == ["2026-11-18 9:15"])
    }

    @Test func fillsInTheMonthAndYear() {
        // A day before today means next month; a month long past means next year.
        #expect(summary("5日に集合") == ["2026-12-5"])
        #expect(summary("11日の夜") == ["2026-11-11"])
        #expect(summary("3月3日の予定") == ["2027-3-3"])
        #expect(summary("10月20日の件") == ["2026-10-20"])
        #expect(summary("31日 18時") == ["2026-12-31 18:0"])   // November has no 31st
    }

    @Test func readsRelativeDays() {
        #expect(summary("明日の13時に電話") == ["2026-11-12 13:0"])
        #expect(summary("今日は休み、明後日 9:00 出発") == ["2026-11-11", "2026-11-13 9:0"])
    }

    @Test func ignoresThingsThatAreNotDates() {
        #expect(parse("よろしくお願いします").isEmpty)
        #expect(parse("3日間の出張、費用は1/2ずつ").map(\.day) == [DayKey(year: 2027, month: 1, day: 2)])
        #expect(parse("13月40日").isEmpty)
        #expect(parse("2月30日").isEmpty)
        #expect(summary("11/18 25時") == ["2026-11-18"])
        #expect(parse("").isEmpty)
    }

    @Test func keepsTheOrderOfAppearance() {
        let moments = parse("25日は19時、その前の18日は15時")
        #expect(moments.map(\.day.day) == [25, 18])
        #expect(moments.map(\.hour) == [19, 15])
        #expect(moments[0].offset < moments[1].offset)
    }
}

@Suite struct ColorPaletteTests {
    @Test func hasFiftyDistinctNamedColours() {
        #expect(ColorPalette.presets.count == 50)
        #expect(Set(ColorPalette.presets.map(\.light.hex)).count == 50)
        #expect(Set(ColorPalette.presets.map(\.dark.hex)).count == 50)
        #expect(Set(ColorPalette.presets.map(\.name)).count == 50)
        #expect(ColorPalette.preset(35)?.name == "ピンク・あざやか")
        #expect(ColorPalette.preset(50) == nil)
        #expect(ColorPalette.preset(-1) == nil)
    }

    @Test func matchesTheDesignMockValues() {
        // (family, tone) -> light, dark. Taken from design/build.py preset().
        let expected: [(Int, Int, String, String)] = [
            (0, 0, "#DA1B2B", "#E63746"), (2, 2, "#EEDCA0", "#F0DFA8"), (7, 0, "#D52080", "#E23C94"),
            (8, 3, "#62422D", "#8B5D3F"), (9, 4, "#948A75", "#A29886"), (5, 1, "#4C99F0", "#68A9F3"),
            (4, 3, "#1B8D85", "#24BCB2"), (3, 4, "#63A674", "#77B185"), (9, 0, "#717984", "#868D98"),
            (6, 2, "#C5A6E8", "#CAAEEA"),
        ]
        for (family, tone, light, dark) in expected {
            let preset = ColorPalette.presets[family * 5 + tone]
            #expect(preset.light.hex == light)
            #expect(preset.dark.hex == dark)
        }
    }

    @Test func luminanceTellsLightFromDark() {
        #expect(RGB(red: 1, green: 1, blue: 1).luminance > 0.99)
        #expect(RGB(red: 0, green: 0, blue: 0).luminance == 0)
        #expect(ColorPalette.presets[12].light.luminance > ColorPalette.presets[13].light.luminance)
    }
}

@Suite struct EventLayoutTests {
    private func d(_ day: Int) -> DayKey { DayKey(year: 2026, month: 11, day: day) }

    @Test func weekHelpers() {
        #expect(d(11).startOfWeek(calendar: jst) == d(8))
        #expect(d(8).startOfWeek(calendar: jst) == d(8))
        #expect(d(11).week(calendar: jst) == (8...14).map(d))
        #expect(d(30).adding(days: 1, calendar: jst) == DayKey(year: 2026, month: 12, day: 1))
        #expect(d(1).adding(days: -1, calendar: jst) == DayKey(year: 2026, month: 10, day: 31))
    }

    @Test func barsShareLanesAndClipToTheWeek() {
        let days: [DayKey?] = (15...21).map { d($0) }
        let items = [
            SpanItem(id: "trip", start: d(19), end: d(23), sortKey: -1),
            SpanItem(id: "meeting", start: d(18), end: d(18), sortKey: 15 * 60),
            SpanItem(id: "paper", start: d(20), end: d(20), sortKey: 9 * 60),
            SpanItem(id: "before", start: d(13), end: d(15), sortKey: -1),
        ]
        let bars = MonthBarLayout.layout(items: items, days: days, maxLanes: 3)
        let byID = Dictionary(uniqueKeysWithValues: bars.segments.map { ($0.id, $0) })
        #expect(byID["trip"] == BarSegment(id: "trip", lane: 0, startColumn: 4, endColumn: 6,
                                           continuesBefore: false, continuesAfter: true))
        #expect(byID["meeting"] == BarSegment(id: "meeting", lane: 0, startColumn: 3, endColumn: 3,
                                              continuesBefore: false, continuesAfter: false))
        #expect(byID["paper"]?.lane == 1)
        #expect(byID["before"] == BarSegment(id: "before", lane: 0, startColumn: 0, endColumn: 0,
                                             continuesBefore: true, continuesAfter: false))
        #expect(bars.hidden == Array(repeating: 0, count: 7))
    }

    @Test func extraItemsAreCountedNotDrawn() {
        let days: [DayKey?] = [nil, nil] + (1...5).map { d($0) }
        let items = (0..<5).map { SpanItem(id: $0, start: d(3), end: d(3), sortKey: $0 * 60) }
        let bars = MonthBarLayout.layout(items: items, days: days, maxLanes: 3)
        #expect(bars.segments.map(\.id) == [0, 1, 2])
        #expect(bars.segments.allSatisfy { $0.startColumn == 4 && $0.endColumn == 4 })
        #expect(bars.hidden == [0, 0, 0, 0, 2, 0, 0])
        #expect(MonthBarLayout.layout(items: items, days: Array(repeating: nil, count: 7), maxLanes: 3).segments.isEmpty)
    }

    @Test func overlappingTimesSitSideBySide() {
        let placed = TimelineLayout.layout([
            TimedItem(id: "a", start: 10 * 60, end: 11 * 60),
            TimedItem(id: "b", start: 10 * 60 + 30, end: 12 * 60),
            TimedItem(id: "c", start: 11 * 60, end: 11 * 60 + 30),
            TimedItem(id: "d", start: 13 * 60, end: 13 * 60 + 5),
        ])
        let byID = Dictionary(uniqueKeysWithValues: placed.map { ($0.id, $0) })
        #expect(byID["a"]?.column == 0)
        #expect(byID["b"]?.column == 1)
        #expect(byID["c"]?.column == 0)
        #expect(byID["a"]?.columnCount == 2)
        #expect(byID["c"]?.columnCount == 2)
        #expect(byID["d"] == TimedPlacement(id: "d", start: 13 * 60, end: 13 * 60 + 30, column: 0, columnCount: 1))
    }
}

@Suite struct QuickAddParserTests {
    private let now = at(2026, 11, 11, 9, 41)

    private func parse(_ text: String) -> QuickAddParser.Result {
        QuickAddParser.parse(text, now: now, calendar: jst)
    }

    @Test func readsTheDesignSample() {
        let result = parse("明日15時 打ち合わせ")
        #expect(result.title == "打ち合わせ")
        #expect(result.day == DayKey(year: 2026, month: 11, day: 12))
        #expect(result.start == QuickAddParser.Time(hour: 15, minute: 0))
        #expect(result.end == nil)
        #expect(result.matched == ["明日", "15時"])
    }

    @Test func keepsPlainTitles() {
        let result = parse("そらまめ商店に電話")
        #expect(result.title == "そらまめ商店に電話")
        #expect(result.day == nil)
        #expect(result.start == nil)
        #expect(result.matched.isEmpty)
    }

    @Test func readsDatesParticlesAndRanges() {
        let a = parse("11/20(金)の資料提出")
        #expect(a.title == "資料提出")
        #expect(a.day == DayKey(year: 2026, month: 11, day: 20))
        #expect(a.start == nil)

        let b = parse("懇親会 25日 19:00〜21:30")
        #expect(b.title == "懇親会")
        #expect(b.day == DayKey(year: 2026, month: 11, day: 25))
        #expect(b.start == QuickAddParser.Time(hour: 19, minute: 0))
        #expect(b.end == QuickAddParser.Time(hour: 21, minute: 30))

        let c = parse("午後3時半から歯医者")
        #expect(c.title == "歯医者")
        #expect(c.day == nil)
        #expect(c.start == QuickAddParser.Time(hour: 15, minute: 30))

        let d = parse("午後3時〜5時 作業")
        #expect(d.start == QuickAddParser.Time(hour: 15, minute: 0))
        #expect(d.end == QuickAddParser.Time(hour: 17, minute: 0))
        #expect(d.title == "作業")

        #expect(parse("3日間の合宿").day == nil)
        #expect(parse("").title == "")
    }
}

@Suite struct ChartSeriesTests {
    private let amounts: [(day: DayKey, amount: Int)] = [
        (DayKey(year: 2026, month: 11, day: 3), -3300), (DayKey(year: 2026, month: 11, day: 7), 3200),
        (DayKey(year: 2026, month: 11, day: 7), -1000), (DayKey(year: 2026, month: 10, day: 30), 500),
        (DayKey(year: 2026, month: 9, day: 1), -200),
    ]

    @Test func dailyCoversEveryDayAndRunsATotal() {
        let series = ChartSeries.daily(amounts, year: 2026, month: 11, dayCount: 30)
        #expect(series.count == 30)
        #expect(series[2] == DayAmount(day: 3, total: -3300, cumulative: -3300))
        #expect(series[6] == DayAmount(day: 7, total: 2200, cumulative: -1100))
        #expect(series[29].cumulative == -1100)
        #expect(ChartSeries.daily([], year: 2026, month: 11, dayCount: 0).isEmpty)
    }

    @Test func monthlyGoesBackAcrossYears() {
        let series = ChartSeries.monthly(amounts, endYear: 2026, endMonth: 11, months: 3)
        #expect(series.map(\.month) == [9, 10, 11])
        #expect(series.map(\.total) == [-200, 500, -1100])
        let wrap = ChartSeries.monthly([], endYear: 2026, endMonth: 1, months: 2)
        #expect(wrap.map { "\($0.year)-\($0.month)" } == ["2025-12", "2026-1"])
    }
}

@Suite struct ParserRegressionTests {
    private let now = at(2026, 11, 11, 9, 41)

    @Test func durationsAreNotTimes() {
        let a = QuickAddParser.parse("会議 2時間", now: now, calendar: jst)
        #expect(a.start == nil)
        #expect(a.title == "会議 2時間")
        #expect(JapaneseDateParser.parse("12日は3時間の研修", now: now, calendar: jst).first?.hour == nil)
    }

    @Test func particlesAfterDateAndTimeAreDropped() {
        let a = QuickAddParser.parse("明日の15時の会議", now: now, calendar: jst)
        #expect(a.title == "会議")
        #expect(a.day == DayKey(year: 2026, month: 11, day: 12))
        #expect(a.start == QuickAddParser.Time(hour: 15, minute: 0))
        let b = QuickAddParser.parse("１２日 １０時半 歯医者", now: now, calendar: jst)   // full-width digits
        #expect(b.day == DayKey(year: 2026, month: 11, day: 12))
        #expect(b.start == QuickAddParser.Time(hour: 10, minute: 30))
        #expect(b.title == "歯医者")
    }
}

@Suite struct TextEventExtractorTests {
    private let now = at(2026, 11, 11, 9, 41)

    @Test func findsTheEventsInTheDesignSample() {
        let text = "来週の打ち合わせ、18日(水)15時からでお願いします。場所は会議室Bです。25日の懇親会は19時スタートです！"
        let events = TextEventExtractor.extract(text, now: now, calendar: jst)
        #expect(events == [
            ExtractedEvent(title: "来週の打ち合わせ", day: DayKey(year: 2026, month: 11, day: 18),
                           start: QuickAddParser.Time(hour: 15, minute: 0)),
            ExtractedEvent(title: "懇親会", day: DayKey(year: 2026, month: 11, day: 25),
                           start: QuickAddParser.Time(hour: 19, minute: 0)),
        ])
    }

    @Test func handlesLinesAllDayAndNoDates() {
        let events = TextEventExtractor.extract("12/3 大掃除\n12月5日(土) 10:00〜12:00 そらまめ商店 棚卸し\nよろしく！", now: now, calendar: jst)
        #expect(events.count == 2)
        #expect(events[0] == ExtractedEvent(title: "大掃除", day: DayKey(year: 2026, month: 12, day: 3)))
        #expect(events[1].title == "そらまめ商店 棚卸し")
        #expect(events[1].end == QuickAddParser.Time(hour: 12, minute: 0))
        #expect(TextEventExtractor.extract("こんにちは。元気ですか？", now: now, calendar: jst).isEmpty)
        #expect(TextEventExtractor.extract("20日です。", now: now, calendar: jst).first?.title == "予定")
    }
}

@Suite struct PaneSplitTests {
    @Test func narrowWindowsStayOneColumn() {
        #expect(PaneSplit.compute(width: 402) == nil)
        #expect(PaneSplit.compute(width: 699) == nil)
    }

    @Test func wideWindowsGetTheDayListOnTheTrailingSide() throws {
        let landscape = try #require(PaneSplit.compute(width: 1194))
        #expect(landscape.trailing == 1194 * 0.34)
        #expect(abs(landscape.leading + landscape.gap + landscape.trailing - 1194) < 0.001)
        #expect(!landscape.compactMonth)
        let portrait = try #require(PaneSplit.compute(width: 834))
        #expect(portrait.trailing == 320)
        #expect(portrait.compactMonth)
        let huge = try #require(PaneSplit.compute(width: 2000))
        #expect(huge.trailing == 440)
    }

    @Test func foldSplitsInHalvesAndKeepsClearOfIt() throws {
        // Fully open: the fold is reported but inactive.
        let open = try #require(PaneSplit.compute(width: 867, fold: FoldRegion(minX: 455, maxX: 495, isActive: false)))
        #expect(open.gap == 16)
        #expect(open.leading == 467)
        #expect(open.trailing == 384)
        #expect(open.compactMonth)
        // Partly folded: nothing between minX and maxX.
        let folded = try #require(PaneSplit.compute(width: 867, fold: FoldRegion(minX: 455, maxX: 495, isActive: true)))
        #expect(folded.leading == 455)
        #expect(folded.gap == 40)
        #expect(folded.trailing == 372)
        // A fold outside the view is ignored.
        let outside = try #require(PaneSplit.compute(width: 867, fold: FoldRegion(minX: 900, maxX: 940, isActive: true)))
        #expect(outside.gap == 16)
        #expect(outside.trailing == 320)
    }
}

@Suite struct AIReplyTests {
    private let text = "来週の打ち合わせ、18日(水)15時からでお願いします。場所は会議室Bです。"

    @Test func readsTheTwoLines() {
        #expect(AIReply.parse("題名: 打ち合わせ\n場所: 会議室B") == AIReply(title: "打ち合わせ", place: "会議室B"))
        #expect(AIReply.parse("- 題名：「打ち合わせ」\n- 場所：なし") == AIReply(title: "打ち合わせ", place: nil))
        #expect(AIReply.parse("わかりました。") == AIReply())
    }

    @Test func keepsOnlyWhatCanBeTrusted() {
        let good = AIReply.checked(AIReply(title: "打ち合わせ", place: "会議室B"), fallbackTitle: "来週の打ち合わせ", fullText: text)
        #expect(good.title == "打ち合わせ")
        #expect(good.place == "会議室B")
        // A place that is not written in the text is dropped; an empty or overlong title falls back.
        let invented = AIReply.checked(AIReply(title: nil, place: "そらまめホール"), fallbackTitle: "来週の打ち合わせ", fullText: text)
        #expect(invented.title == "来週の打ち合わせ")
        #expect(invented.place == "")
        let long = AIReply.checked(AIReply(title: String(repeating: "あ", count: 41)), fallbackTitle: "予定", fullText: text)
        #expect(long.title == "予定")
    }

    @Test func extractorKeepsTheSentence() {
        let found = TextEventExtractor.extractDetailed(text, now: at(2026, 11, 11, 9, 41), calendar: jst)
        #expect(found.count == 1)
        #expect(found[0].sentence.contains("18日"))
    }
}
