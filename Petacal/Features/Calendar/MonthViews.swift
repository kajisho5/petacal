import PetaCore
import SwiftUI

/// The standard month look: titled bars that span days (design-spec 月の表示パターン「帯」).
struct MonthBarsView: View {
    let grid: MonthGrid
    let today: DayKey
    let onTap: (DayKey) -> Void

    @Environment(CalendarStore.self) private var store
    @ScaledMetric(relativeTo: .caption2) private var laneHeight: CGFloat = 20
    @ScaledMetric(relativeTo: .footnote) private var numberHeight: CGFloat = 30

    var body: some View {
        GeometryReader { geo in
            let headerHeight: CGFloat = 24
            let minimum = numberHeight + laneHeight * 2 + 4
            let rowHeight = max(minimum, (geo.size.height - headerHeight) / CGFloat(max(grid.weeks.count, 1)))
            let lanes = max(1, min(5, Int((rowHeight - numberHeight - laneHeight * 0.8) / laneHeight)))
            let items = store.spanItems
            let lookup = Dictionary(store.events.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            ScrollView {
                VStack(spacing: 0) {
                    WeekdayHeader(symbols: grid.weekdaySymbols)
                        .frame(height: headerHeight)
                    ForEach(Array(grid.weeks.enumerated()), id: \.offset) { _, week in
                        let days = week.map { $0.map { DayKey(year: grid.year, month: grid.month, day: $0) } }
                        MonthWeekRow(days: days, today: today,
                                     bars: MonthBarLayout.layout(items: items, days: days, maxLanes: lanes),
                                     lookup: lookup, lanes: lanes, laneHeight: laneHeight,
                                     numberHeight: numberHeight, columnWidth: geo.size.width / 7, onTap: onTap)
                            .frame(height: rowHeight)
                    }
                }
            }
        }
    }
}

struct WeekdayHeader: View {
    let symbols: [String]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(symbols.enumerated()), id: \.offset) { _, symbol in
                Text(verbatim: symbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct MonthWeekRow: View {
    let days: [DayKey?]
    let today: DayKey
    let bars: WeekBars<String>
    let lookup: [String: EventItem]
    let lanes: Int
    let laneHeight: CGFloat
    let numberHeight: CGFloat
    let columnWidth: CGFloat
    let onTap: (DayKey) -> Void

    @Environment(CalendarStore.self) private var store
    @Environment(ColorStore.self) private var colors
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack(alignment: .topLeading) {
            Divider()
            HStack(spacing: 0) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    DayNumber(day: day, isToday: day == today)
                        .frame(width: columnWidth, height: numberHeight)
                }
            }
            ForEach(bars.segments, id: \.id) { segment in
                if let item = lookup[segment.id] {
                    EventBar(title: item.title, color: colors.color(for: item, scheme: scheme),
                             capped: !segment.continuesBefore)
                        .frame(width: max(0, CGFloat(segment.endColumn - segment.startColumn + 1) * columnWidth - 2),
                               height: laneHeight - 2)
                        .offset(x: CGFloat(segment.startColumn) * columnWidth + 1,
                                y: numberHeight + CGFloat(segment.lane) * laneHeight)
                }
            }
            ForEach(Array(bars.hidden.enumerated()), id: \.offset) { column, count in
                if count > 0 {
                    Text(verbatim: "+\(count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: columnWidth, alignment: .leading)
                        .padding(.leading, 4)
                        .offset(x: CGFloat(column) * columnWidth, y: numberHeight + CGFloat(lanes) * laneHeight)
                }
            }
            // One tap target per day, on top of everything.
            HStack(spacing: 0) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    if let day {
                        Button { onTap(day) } label: { Color.clear.contentShape(Rectangle()) }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(verbatim: label(for: day)))
                    } else {
                        Color.clear
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
    }

    private func label(for day: DayKey) -> String {
        var text = "\(day.month)月\(day.day)日"
        if let weekday = day.weekday(calendar: store.calendar) {
            text += " \(DayKey.weekdaySymbolsJa[weekday - 1])曜日"
        }
        if day == today { text += " 今日" }
        let titles = store.events(on: day).map(\.title)
        text += titles.isEmpty ? " " + String(localized: "予定なし") : " 予定\(titles.count)件 " + titles.prefix(3).joined(separator: "、")
        return text
    }
}

struct DayNumber: View {
    let day: DayKey?
    let isToday: Bool

    var body: some View {
        if let day {
            Text(verbatim: String(day.day))
                .font(.footnote)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundStyle(isToday ? Color.white : Color.primary)
                .padding(.horizontal, 5)
                .frame(minWidth: 24, minHeight: 24)
                .background { if isToday { Capsule().fill(Color.accentColor) } }
                .accessibilityHidden(true)
        } else {
            Color.clear
        }
    }
}

/// A titled bar. The title is always there, so colour is never the only cue.
struct EventBar: View {
    let title: String
    let color: Color
    var capped = true

    var body: some View {
        HStack(spacing: 3) {
            if capped {
                RoundedRectangle(cornerRadius: 1.5).fill(color).frame(width: 3)
            }
            Text(verbatim: title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            Spacer(minLength: 0)
        }
        .padding(.leading, capped ? 0 : 5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(color.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .accessibilityHidden(true)
    }
}

/// 月の表示パターン「点と一覧」: a compact month with dots, and the selected day's list below.
struct MonthDotsView: View {
    let grid: MonthGrid
    let today: DayKey
    @Binding var focus: DayKey
    @Binding var sheet: CalendarSheet?

    @Environment(CalendarStore.self) private var store
    @Environment(ColorStore.self) private var colors
    @Environment(\.colorScheme) private var scheme

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                WeekdayHeader(symbols: grid.weekdaySymbols)
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(Array(grid.weeks.joined().enumerated()), id: \.offset) { _, number in
                        if let number {
                            dotCell(DayKey(year: grid.year, month: grid.month, day: number))
                        } else {
                            Color.clear.frame(height: 48)
                        }
                    }
                }
                Text(verbatim: store.heading(focus, today: today))
                    .font(.title3.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                DayEventList(day: focus) { sheet = .event($0) } onAdd: {
                    sheet = .new((focus.date(calendar: store.calendar) ?? Date()).addingTimeInterval(9 * 3600))
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }

    private func dotCell(_ day: DayKey) -> some View {
        let items = store.events(on: day)
        return Button { focus = day } label: {
            VStack(spacing: 3) {
                DayNumber(day: day, isToday: day == today)
                    .frame(height: 26)
                    .overlay {
                        if day == focus && day != today {
                            Capsule().strokeBorder(Color.accentColor, lineWidth: 1.5)
                        }
                    }
                HStack(spacing: 3) {
                    ForEach(Array(items.prefix(3).enumerated()), id: \.offset) { _, item in
                        Circle().fill(colors.color(for: item, scheme: scheme)).frame(width: 6, height: 6)
                    }
                }
                .frame(height: 6)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: "\(day.month)月\(day.day)日 予定\(items.count)件"))
        .accessibilityAddTraits(day == focus ? .isSelected : [])
    }
}
