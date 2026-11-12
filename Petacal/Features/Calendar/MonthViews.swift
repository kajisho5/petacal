import PetaCore
import SwiftData
import SwiftUI

/// The standard month look: titled bars that span days (design-spec 月の表示パターン「帯」).
struct MonthBarsView: View {
    let grid: MonthGrid
    let today: DayKey
    /// The day's money in and out added up (empty while records are locked).
    var amounts: [DayKey: Int] = [:]
    /// The day shown in the list beside the month (wide screens only).
    var selected: DayKey?
    let onTap: (DayKey) -> Void
    let onLongPress: (DayKey) -> Void

    @Environment(CalendarStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .caption2) private var laneHeight: CGFloat = 20
    @ScaledMetric(relativeTo: .footnote) private var numberHeight: CGFloat = 30

    var body: some View {
        if typeSize.isAccessibilitySize {
            // Titles cannot fit at the largest sizes: the day and how many events it has.
            MonthCountView(grid: grid, today: today, selected: selected, onTap: onTap, onLongPress: onLongPress)
        } else {
            bars
        }
    }

    private var bars: some View {
        GeometryReader { geo in
            let headerHeight: CGFloat = 24
            let minimum = numberHeight + laneHeight * 2 + 4
            let rowHeight = max(minimum, (geo.size.height - headerHeight) / CGFloat(max(grid.weeks.count, 1)))
            let lanes = max(1, min(5, Int((rowHeight - numberHeight - laneHeight * 1.6) / laneHeight)))
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
                                     numberHeight: numberHeight, columnWidth: geo.size.width / 7,
                                     amounts: amounts, selected: selected, onTap: onTap, onLongPress: onLongPress)
                            .frame(height: rowHeight)
                    }
                }
            }
        }
    }
}

/// The month at the accessibility text sizes: each day with the number of its events (design-spec B-4).
/// The amounts move to the day's sheet, where there is room for them.
struct MonthCountView: View {
    let grid: MonthGrid
    let today: DayKey
    var selected: DayKey?
    let onTap: (DayKey) -> Void
    let onLongPress: (DayKey) -> Void

    @Environment(CalendarStore.self) private var store
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        ScrollView {
            VStack(spacing: 4) {
                WeekdayHeader(symbols: grid.weekdaySymbols)
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(Array(grid.weeks.joined().enumerated()), id: \.offset) { _, number in
                        if let number {
                            cell(DayKey(year: grid.year, month: grid.month, day: number))
                        } else {
                            Color.clear.frame(minHeight: 44)
                        }
                    }
                }
            }
            .padding(.bottom, 24)
        }
    }

    private func cell(_ day: DayKey) -> some View {
        let count = store.events(on: day).count
        return VStack(spacing: 2) {
            DayNumber(day: day, isToday: day == today, isSelected: day == selected)
            Text(verbatim: count > 0 ? "\(count)" : " ")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .contentShape(Rectangle())
        .onTapGesture { onTap(day) }
        .onLongPressGesture(minimumDuration: 0.4) { onLongPress(day) }
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: "\(day.month)月\(day.day)日" + (day == today ? " 今日" : "")
            + (count > 0 ? " 予定\(count)件" : " " + String(localized: "予定なし"))))
        .accessibilityAddTraits(day == selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { onTap(day) }
        .accessibilityAction(named: Text("予定を追加")) { onLongPress(day) }
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
    let amounts: [DayKey: Int]
    let selected: DayKey?
    let onTap: (DayKey) -> Void
    let onLongPress: (DayKey) -> Void

    @Environment(CalendarStore.self) private var store
    @Environment(ColorStore.self) private var colors
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack(alignment: .topLeading) {
            Divider()
            HStack(spacing: 0) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    DayNumber(day: day, isToday: day == today, isSelected: day != nil && day == selected)
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
            // The day's amount at the bottom of the cell, always with its sign.
            HStack(spacing: 0) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    Group {
                        if let day, let amount = amounts[day] {
                            Text(verbatim: Yen.signed(amount, unit: false))
                                .font(.caption2.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(Color.amount(amount))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .padding(.horizontal, 2)
                        } else {
                            Color.clear
                        }
                    }
                    .frame(width: columnWidth, height: laneHeight * 0.8)
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
            .accessibilityHidden(true)
            // One tap target per day, on top of everything.
            HStack(spacing: 0) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    if let day {
                        // Tap opens the day; long press adds an event (also offered as a VoiceOver action and by ＋).
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { onTap(day) }
                            .onLongPressGesture(minimumDuration: 0.4) { onLongPress(day) }
                            .accessibilityElement()
                            .accessibilityLabel(Text(verbatim: label(for: day)))
                            .accessibilityAddTraits(day == selected ? [.isButton, .isSelected] : .isButton)
                            .accessibilityAction { onTap(day) }
                            .accessibilityAction(named: Text("予定を追加")) { onLongPress(day) }
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
        if let amount = amounts[day] { text += " 収支 \(Yen.signed(amount))" }
        return text
    }
}

struct DayNumber: View {
    let day: DayKey?
    let isToday: Bool
    var isSelected = false

    var body: some View {
        if let day {
            Text(verbatim: String(day.day))
                .font(.footnote)
                .fontWeight(isToday ? .bold : .regular)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(isToday ? Color.white : Color.primary)
                .padding(.horizontal, 5)
                .frame(minWidth: 24, minHeight: 24)
                .background {
                    if isToday {
                        Capsule().fill(Color.accentColor)
                    } else if isSelected {
                        Capsule().strokeBorder(Color.accentColor, lineWidth: 1.5)
                    }
                }
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
        // The title sits in an overlay so a long title can never widen the bar; it is cut at the bar's edge.
        color.opacity(0.35)
            .overlay(alignment: .leading) {
                HStack(spacing: 3) {
                    if capped {
                        RoundedRectangle(cornerRadius: 1.5).fill(color).frame(width: 3)
                    }
                    Text(verbatim: title)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .padding(.leading, capped ? 0 : 5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .accessibilityHidden(true)
    }
}

/// The compact month looks (点と一覧／金額／写真): a small month on top, the selected day's contents below.
struct MonthCompactView: View {
    let style: MonthPattern
    let grid: MonthGrid
    let today: DayKey
    @Binding var focus: DayKey
    @Binding var sheet: CalendarSheet?
    /// False on wide screens, where the day's list sits beside the month instead of under it.
    var showsDay = true
    let onLongPress: (DayKey) -> Void

    @Environment(CalendarStore.self) private var store
    @Environment(ColorStore.self) private var colors
    @Environment(LockGate.self) private var lock
    @Environment(\.colorScheme) private var scheme
    @Query private var records: [Record]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    var body: some View {
        let byDay: [DayKey: [Record]] = lock.isLocked
            ? [:] : Dictionary(grouping: records) { DayKey(date: $0.day, calendar: store.calendar) }
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                WeekdayHeader(symbols: grid.weekdaySymbols)
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(Array(grid.weeks.joined().enumerated()), id: \.offset) { _, number in
                        if let number {
                            let day = DayKey(year: grid.year, month: grid.month, day: number)
                            cell(day, records: byDay[day] ?? [])
                        } else {
                            Color.clear.frame(height: 48)
                        }
                    }
                }
                if showsDay {
                    Text(verbatim: store.heading(focus, today: today))
                        .font(.title3.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    DayContents(day: focus, sheet: $sheet) { sheet = .event($0) }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }

    @ViewBuilder
    private func face(_ day: DayKey, records: [Record], events: [EventItem]) -> some View {
        let amount = records.compactMap(\.countedAmount).reduce(0, +)
        let hasAmount = records.contains { $0.countedAmount != nil }
        let photo = records.lazy.compactMap { $0.sortedPhotos.first }.first
        let number = DayNumber(day: day, isToday: day == today)
            .frame(height: 26)
            .overlay {
                if day == focus && day != today {
                    Capsule().strokeBorder(Color.accentColor, lineWidth: 1.5)
                }
            }
        let dots = HStack(spacing: 3) {
            ForEach(Array(events.prefix(3).enumerated()), id: \.offset) { _, item in
                Circle().fill(colors.color(for: item, scheme: scheme)).frame(width: 6, height: 6)
            }
        }
        .frame(height: 6)

        switch style {
        case .amount:
            VStack(spacing: 2) {
                number
                Text(verbatim: hasAmount ? Yen.signed(amount, unit: false) : " ")
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.amount(amount))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                dots
            }
            .frame(maxWidth: .infinity, minHeight: 62)
        case .photo:
            ZStack(alignment: .top) {
                if let photo, let image = ThumbCache.image(for: photo) {
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                        .overlay { Image(native: image).resizable().scaledToFill() }
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(alignment: .top) {
                            // The number sits on its own plate so it stays readable on any photo.
                            number.background(.regularMaterial, in: Capsule()).padding(.top, 2)
                        }
                        .overlay(alignment: .bottom) { dots.padding(3).background(.regularMaterial, in: Capsule()).padding(.bottom, 2)
                            .opacity(events.isEmpty ? 0 : 1) }
                } else {
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(alignment: .top) { number.padding(.top, 2) }
                        .overlay(alignment: .bottom) { dots.padding(.bottom, 5) }
                }
            }
            .frame(maxWidth: .infinity)
        default:
            VStack(spacing: 3) {
                number
                dots
            }
            .frame(maxWidth: .infinity, minHeight: 48)
        }
    }

    private func cell(_ day: DayKey, records: [Record]) -> some View {
        let events = store.events(on: day)
        let traits: AccessibilityTraits = day == focus ? [.isButton, .isSelected] : [.isButton]
        var label = "\(day.month)月\(day.day)日 予定\(events.count)件"
        if !records.isEmpty { label += " 記録\(records.count)件" }
        if records.contains(where: { $0.countedAmount != nil }) {
            label += " " + Yen.signed(records.compactMap(\.countedAmount).reduce(0, +))
        }
        return face(day, records: records, events: events)
            .contentShape(Rectangle())
            .onTapGesture { focus = day }
            .onLongPressGesture(minimumDuration: 0.4) { onLongPress(day) }
            .accessibilityElement()
            .accessibilityLabel(Text(verbatim: label))
            .accessibilityAddTraits(traits)
            .accessibilityAction { focus = day }
            .accessibilityAction(named: Text("予定を追加")) { onLongPress(day) }
    }
}
