import Charts
import PetaCore
import SwiftData
import SwiftUI

/// S-11 集計: the month's totals, by 種目, and charts.
struct StatsScreen: View {
    @Environment(CalendarStore.self) private var store
    @Environment(LockGate.self) private var lock
    @Query private var records: [Record]
    @State private var month = StatsScreen.currentMonth()
    @State private var showSummary = false
    @AppStorage("budget.oshi") private var oshiBudget = 0
    @Environment(EntitlementStore.self) private var entitlements

    private static func currentMonth() -> MonthRef {
        let today = DayKey(date: Date(), calendar: .current)
        return MonthRef(year: today.year, month: today.month)
    }

    private var calendar: Calendar { store.calendar }

    private var monthRecords: [Record] {
        records.filter {
            let day = DayKey(date: $0.day, calendar: calendar)
            return day.year == month.year && day.month == month.month
        }
    }

    private var stats: MonthStats {
        StatsCalculator.monthStats(monthRecords.map {
            RecordAmount(kind: $0.kind, category: $0.category, amount: $0.amount)
        })
    }

    /// Money in and out for 収支 records only (the charts follow the same rule as the total).
    private var balanceAmounts: [(day: DayKey, amount: Int)] {
        records.filter { $0.kind == .balance }.dayAmounts(calendar: calendar)
    }

    var body: some View {
        Group {
            if lock.isLocked {
                LockedView()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        monthPicker
                        if monthRecords.isEmpty {
                            ContentUnavailableView("この月の記録はありません", systemImage: "chart.bar")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                        }
                        // One column on iPhone; two or three side by side when there is room.
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 340), spacing: 16, alignment: .top)],
                                  alignment: .leading, spacing: 16) {
                            if !monthRecords.isEmpty {
                                totalCard
                                dailyCard
                                if entitlements.isPro {
                                    if oshiBudget > 0 { budgetCard }
                                    if !stats.byCategory.isEmpty { categoryCard }
                                } else {
                                    proCard
                                }
                            }
                            trendCard
                        }
                        if !monthRecords.isEmpty {
                            Button {
                                if entitlements.isPro {
                                    showSummary = true
                                } else {
                                    entitlements.ask(String(localized: "まとめ画像は Pro の機能です"))
                                }
                            } label: {
                                Label("まとめ画像をつくる", systemImage: "photo")
                                    .frame(maxWidth: 520, minHeight: 44)
                            }
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("集計")
        .sheet(isPresented: $showSummary) {
            SummarySheet(year: month.year, month: month.month, stats: stats).sheetSize()
        }
    }

    private var monthPicker: some View {
        HStack {
            Button("前の月", systemImage: "chevron.backward") { move(-1) }
                .labelStyle(.iconOnly)
                .frame(minWidth: 44, minHeight: 44)
            Spacer()
            Text(verbatim: "\(month.year)年\(month.month)月")
                .font(.title2.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button("次の月", systemImage: "chevron.forward") { move(1) }
                .labelStyle(.iconOnly)
                .frame(minWidth: 44, minHeight: 44)
        }
    }

    private var totalCard: some View {
        let stats = self.stats
        return Card {
            Text("収支の合計").font(.subheadline).foregroundStyle(.secondary)
            Text(verbatim: Yen.signed(stats.balanceTotal))
                .font(.largeTitle.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Color.amount(stats.balanceTotal))
            Text("プラス \(stats.plusCount)件・マイナス \(stats.minusCount)件")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if stats.oshiCount > 0 {
                Divider()
                LabeledContent {
                    Text(verbatim: Yen.plain(stats.oshiSpent)).monospacedDigit()
                } label: {
                    Text("推し活・趣味に使った金額（\(stats.oshiCount)件）")
                }
                .font(.subheadline)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var dailyCard: some View {
        let grid = MonthGrid(year: month.year, month: month.month, calendar: calendar)
        let series = ChartSeries.daily(balanceAmounts, year: month.year, month: month.month, dayCount: grid.dayCount)
        let last = series.last?.cumulative ?? 0
        return Card {
            Text("日ごとの収支").font(.headline)
            Text("棒はその日の合計、線は月初めからの積み上げです。月末の時点で \(Yen.signed(last))。")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Chart {
                ForEach(series) { day in
                    BarMark(x: .value("日", day.day), y: .value("その日の合計", day.total))
                        .foregroundStyle(day.total >= 0 ? Color.plusAmount : Color.minusAmount)
                        .accessibilityLabel(Text(verbatim: "\(day.day)日"))
                        .accessibilityValue(Text(verbatim: Yen.signed(day.total)))
                }
                ForEach(series) { day in
                    LineMark(x: .value("日", day.day), y: .value("積み上げ", day.cumulative))
                        .foregroundStyle(Color.primary)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 3]))
                        .accessibilityHidden(true)
                }
                RuleMark(y: .value("0", 0)).foregroundStyle(Color.secondary.opacity(0.5))
            }
            .chartXScale(domain: 1...max(grid.dayCount, 2))
            .frame(height: 200)
        }
    }

    /// Free plan: where the paid cards would be.
    private var proCard: some View {
        Card {
            HStack(spacing: 6) {
                Text("種目ごとの合計・予算").font(.headline)
                ProBadge()
            }
            Text("種目ごとの収支と、推し活・趣味の予算は Pro で使えます。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Pro の内容を見る") { entitlements.ask(String(localized: "集計の種目別と予算は Pro の機能です")) }
                .buttonStyle(.bordered)
        }
    }

    private var categoryCard: some View {
        let rows = self.stats.byCategory
        return Card {
            Text("種目ごとの合計").font(.headline)
            Chart {
                ForEach(rows, id: \.name) { row in
                    BarMark(x: .value("合計", row.total), y: .value("種目", row.name))
                        .foregroundStyle(row.total >= 0 ? Color.plusAmount : Color.minusAmount)
                        .annotation(position: row.total >= 0 ? .trailing : .leading) {
                            Text(verbatim: Yen.signed(row.total, unit: false)).font(.caption2).monospacedDigit()
                        }
                        .accessibilityLabel(Text(verbatim: row.name))
                        .accessibilityValue(Text(verbatim: "\(Yen.signed(row.total)) \(row.count)件"))
                }
                RuleMark(x: .value("0", 0)).foregroundStyle(Color.secondary.opacity(0.5))
            }
            .frame(height: CGFloat(rows.count) * 40 + 32)
        }
    }

    /// 推し活・趣味の予算: how much of this month's budget is used, with a notice from 80%.
    private var budgetCard: some View {
        let usage = BudgetUsage(limit: oshiBudget, spent: self.stats.oshiSpent)
        return Card {
            Text("推し活・趣味の予算").font(.headline)
            ProgressView(value: Double(min(usage.spent, usage.limit)), total: Double(max(usage.limit, 1)))
                .tint(usage.level == .ok ? Color.accentColor : Color.warnAmount)
                .accessibilityHidden(true)
            Text("\(Yen.plain(usage.limit))のうち \(Yen.plain(usage.spent))（\(usage.percent)%）")
                .font(.subheadline)
                .monospacedDigit()
            switch usage.level {
            case .ok:
                Text("残り \(Yen.plain(usage.remaining))").font(.footnote).foregroundStyle(.secondary)
            case .near:
                Label("予算の8割を超えました。残り \(Yen.plain(usage.remaining))", systemImage: "exclamationmark.triangle")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.warnAmount)
            case .over:
                Label("予算を \(Yen.plain(-usage.remaining)) 超えています", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.warnAmount)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var trendCard: some View {
        let series = ChartSeries.monthly(balanceAmounts, endYear: month.year, endMonth: month.month, months: 6)
        return Card {
            Text("月ごとの収支（6か月）").font(.headline)
            if series.allSatisfy({ $0.total == 0 }) {
                Text("収支の記録を付けると、ここに月ごとの推移が出ます。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Chart {
                    ForEach(series) { item in
                        BarMark(x: .value("月", "\(item.month)月"), y: .value("合計", item.total))
                            .foregroundStyle(item.total >= 0 ? Color.plusAmount : Color.minusAmount)
                            .annotation(position: item.total >= 0 ? .top : .bottom) {
                                Text(verbatim: Yen.signed(item.total, unit: false)).font(.caption2).monospacedDigit()
                            }
                            .accessibilityLabel(Text(verbatim: "\(item.year)年\(item.month)月"))
                            .accessibilityValue(Text(verbatim: Yen.signed(item.total)))
                    }
                    RuleMark(y: .value("0", 0)).foregroundStyle(Color.secondary.opacity(0.5))
                }
                .frame(height: 180)
            }
        }
    }

    private func move(_ step: Int) {
        let next = MonthGrid.shifted(year: month.year, month: month.month, by: step)
        month = MonthRef(year: next.year, month: next.month)
    }
}

/// A grouped card for the stats screen.
private struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 24))
    }
}
