import PetaCore
import SwiftUI

/// S-01 カレンダー: the month grid and the selected day. Events and records are added in later steps.
struct CalendarScreen: View {
    @State private var shown = CalendarScreen.currentMonth()
    @State private var selected = DayKey(date: Date(), calendar: .current)

    private let calendar = Calendar.current

    private static func currentMonth() -> MonthRef {
        let today = DayKey(date: Date(), calendar: .current)
        return MonthRef(year: today.year, month: today.month)
    }

    private var today: DayKey { DayKey(date: Date(), calendar: calendar) }
    private var grid: MonthGrid { MonthGrid(year: shown.year, month: shown.month, calendar: calendar) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                MonthGridView(grid: grid, today: today, selected: $selected)
                DaySection(day: selected, isToday: selected == today, calendar: calendar)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .navigationTitle(Text(verbatim: "\(shown.year)年\(shown.month)月"))
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("今日") { showToday() }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("前の月", systemImage: "chevron.backward") { move(by: -1) }
                Button("次の月", systemImage: "chevron.forward") { move(by: 1) }
            }
        }
    }

    private func showToday() {
        let now = today
        shown = MonthRef(year: now.year, month: now.month)
        selected = now
    }

    private func move(by offset: Int) {
        let next = MonthGrid.shifted(year: shown.year, month: shown.month, by: offset)
        shown = MonthRef(year: next.year, month: next.month)
        // Keep a day selected in the month on screen: today if it is this month, otherwise the 1st.
        let now = today
        selected = (now.year == next.year && now.month == next.month)
            ? now : DayKey(year: next.year, month: next.month, day: 1)
    }
}

struct MonthRef: Equatable {
    var year: Int
    var month: Int
}

private struct MonthGridView: View {
    let grid: MonthGrid
    let today: DayKey
    @Binding var selected: DayKey

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(grid.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(verbatim: symbol)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
            }
            ForEach(Array(grid.weeks.joined().enumerated()), id: \.offset) { _, day in
                if let day {
                    DayCell(key: DayKey(year: grid.year, month: grid.month, day: day),
                            today: today, selected: $selected)
                } else {
                    Color.clear.frame(height: 44)
                }
            }
        }
    }
}

private struct DayCell: View {
    let key: DayKey
    let today: DayKey
    @Binding var selected: DayKey

    private var isToday: Bool { key == today }
    private var isSelected: Bool { key == selected }

    var body: some View {
        Button {
            selected = key
        } label: {
            Text(verbatim: String(key.day))
                .font(.body)
                .fontWeight(isToday ? .semibold : .regular)
                .foregroundStyle(isToday ? Color.white : Color.primary)
                .frame(width: 36, height: 36)
                .background {
                    if isToday {
                        Circle().fill(Color.accentColor)
                    } else if isSelected {
                        Circle().strokeBorder(Color.accentColor, lineWidth: 1.5)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: accessibilityText))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var accessibilityText: String {
        var text = "\(key.month)月\(key.day)日"
        if let weekday = key.weekday(calendar: .current) {
            text += " \(DayKey.weekdaySymbolsJa[weekday - 1])曜日"
        }
        if isToday { text += " 今日" }
        return text
    }
}

private struct DaySection: View {
    let day: DayKey
    let isToday: Bool
    let calendar: Calendar

    private var heading: String {
        var text = "\(day.month)月\(day.day)日"
        if let weekday = day.weekday(calendar: calendar) {
            text += "（\(DayKey.weekdaySymbolsJa[weekday - 1])）"
        }
        if isToday { text += "・今日" }
        return text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: heading)
                .font(.title3.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            ContentUnavailableView {
                Label("この日はまだ何もありません", systemImage: "calendar")
            } description: {
                Text("予定と記録は、このあとのバージョンで追加できるようになります。")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
        }
    }
}

#Preview {
    NavigationStack { CalendarScreen() }
}
