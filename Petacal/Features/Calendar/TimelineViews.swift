import PetaCore
import SwiftUI

/// The day view (one column) and the week view (seven columns) share this screen.
struct TimelineScreen: View {
    let days: [DayKey]
    let today: DayKey
    @Binding var focus: DayKey
    @Binding var sheet: CalendarSheet?

    @Environment(CalendarStore.self) private var store
    @Environment(ColorStore.self) private var colors
    @Environment(\.colorScheme) private var scheme
    @ScaledMetric(relativeTo: .caption2) private var hourHeight: CGFloat = 52
    @ScaledMetric(relativeTo: .caption2) private var gutter: CGFloat = 44
    @ScaledMetric(relativeTo: .caption2) private var laneHeight: CGFloat = 20
    @ScaledMetric(relativeTo: .caption2) private var labelInset: CGFloat = 7

    private var isWeek: Bool { days.count > 1 }

    var body: some View {
        VStack(spacing: 0) {
            if isWeek { weekHeader }
            allDayArea
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    HStack(alignment: .top, spacing: 0) {
                        hourLabels
                        ZStack(alignment: .topLeading) {
                            hourLines
                            HStack(alignment: .top, spacing: 0) {
                                ForEach(days, id: \.self) { day in
                                    DayColumn(day: day, isToday: day == today, hourHeight: hourHeight,
                                              compact: isWeek) { sheet = .event($0) }
                                }
                            }
                        }
                        .padding(.top, labelInset)     // lines run through the middle of the hour labels
                    }
                    .frame(height: hourHeight * 24 + labelInset, alignment: .top)
                    .padding(.bottom, 8)
                }
                .onAppear { proxy.scrollTo(8, anchor: .top) }
            }
        }
    }

    private var weekHeader: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: gutter, height: 1)
            ForEach(days, id: \.self) { day in
                Button {
                    focus = day
                    sheet = .day(day)
                } label: {
                    VStack(spacing: 2) {
                        Text(verbatim: weekdaySymbol(day)).font(.caption).foregroundStyle(.secondary)
                        DayNumber(day: day, isToday: day == today)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: store.heading(day, today: today)))
            }
        }
    }

    /// All-day events (and events longer than a day) sit above the hours as bars.
    private var allDayArea: some View {
        let items = store.spanItems.filter { span in
            guard let item = store.events.first(where: { $0.id == span.id }) else { return false }
            return item.isAllDay || span.start != span.end
        }
        let bars = MonthBarLayout.layout(items: items, days: days.map { Optional($0) }, maxLanes: 3)
        let lanes = (bars.segments.map(\.lane).max() ?? -1) + 1
        let lookup = Dictionary(store.events.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return HStack(spacing: 0) {
            Text("終日")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: gutter)
                .opacity(lanes > 0 ? 1 : 0)
            GeometryReader { geo in
                let width = geo.size.width / CGFloat(days.count)
                ZStack(alignment: .topLeading) {
                    ForEach(bars.segments, id: \.id) { segment in
                        if let item = lookup[segment.id] {
                            Button { sheet = .event(item) } label: {
                                EventBar(title: item.title, color: colors.color(for: item, scheme: scheme),
                                         capped: !segment.continuesBefore)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(verbatim: "\(item.title) \(store.timeText(item))"))
                            .frame(width: max(0, CGFloat(segment.endColumn - segment.startColumn + 1) * width - 2),
                                   height: laneHeight - 2)
                            .offset(x: CGFloat(segment.startColumn) * width + 1, y: CGFloat(segment.lane) * laneHeight)
                        }
                    }
                }
            }
        }
        .frame(height: CGFloat(lanes) * laneHeight + (lanes > 0 ? 4 : 0))
        .clipped()
    }

    private var hourLabels: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                Text(verbatim: "\(hour):00")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: gutter, height: hourHeight, alignment: .top)
                    .id(hour)
            }
        }
        .accessibilityHidden(true)
    }

    private var hourLines: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { _ in
                VStack(spacing: 0) {
                    Divider()
                    Spacer(minLength: 0)
                }
                .frame(height: hourHeight)
            }
        }
    }

    private func weekdaySymbol(_ day: DayKey) -> String {
        day.weekday(calendar: store.calendar).map { DayKey.weekdaySymbolsJa[$0 - 1] } ?? ""
    }
}

private struct DayColumn: View {
    let day: DayKey
    let isToday: Bool
    let hourHeight: CGFloat
    let compact: Bool
    let onTap: (EventItem) -> Void

    @Environment(CalendarStore.self) private var store
    @Environment(ColorStore.self) private var colors
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let timed = store.events(on: day).filter { !$0.isAllDay && store.days(of: $0).start == store.days(of: $0).end }
        let lookup = Dictionary(timed.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let placed = TimelineLayout.layout(timed.compactMap { item in
            store.minutes(of: item, on: day).map { TimedItem(id: item.id, start: $0.start, end: $0.end) }
        })
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                if isToday {
                    Rectangle().fill(Color.red)
                        .frame(height: 1.5)
                        .offset(y: nowOffset)
                        .accessibilityHidden(true)
                }
                ForEach(placed, id: \.id) { place in
                    if let item = lookup[place.id] {
                        let width = geo.size.width / CGFloat(place.columnCount)
                        Button { onTap(item) } label: {
                            EventBlock(item: item, color: colors.color(for: item, scheme: scheme), compact: compact)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(verbatim: "\(item.title) \(store.timeText(item))"))
                        .frame(width: max(0, width - 2),
                               height: max(18, CGFloat(place.end - place.start) / 60 * hourHeight - 2))
                        .offset(x: CGFloat(place.column) * width + 1, y: CGFloat(place.start) / 60 * hourHeight + 1)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: hourHeight * 24)
    }

    private var nowOffset: CGFloat {
        let c = store.calendar.dateComponents([.hour, .minute], from: Date())
        return CGFloat((c.hour ?? 0) * 60 + (c.minute ?? 0)) / 60 * hourHeight
    }
}

private struct EventBlock: View {
    let item: EventItem
    let color: Color
    let compact: Bool

    @Environment(CalendarStore.self) private var store

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            RoundedRectangle(cornerRadius: 1.5).fill(color).frame(width: 3)
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: item.title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(compact ? 3 : 2)
                if !compact {
                    Text(verbatim: [store.timeText(item), item.location].compactMap { $0 }.joined(separator: "・"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 2)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(color.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
    }
}
