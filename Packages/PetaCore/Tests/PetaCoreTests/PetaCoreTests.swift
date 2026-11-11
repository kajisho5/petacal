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
        for _ in 0..<5 { #expect(quota.consume(monthKey: november)) }
        #expect(quota.remaining(monthKey: november) == 0)
        #expect(!quota.consume(monthKey: november))
        #expect(quota.used == 5)
        #expect(quota.remaining(monthKey: december) == 5)
        #expect(quota.consume(monthKey: december))
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
