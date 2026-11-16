import SwiftUI
import NextFMCore

struct ScrobbleCalendar: View {
    let days: [ActivityDay]
    @State private var month: Date?
    @State private var selected: ActivityDay?
    private var calendar: Calendar { .current }
    private var availableMonths: [Date] {
        Array(Set(days.compactMap { calendar.dateInterval(of: .month, for: $0.date)?.start })).sorted()
    }
    private var displayedMonth: Date { month ?? availableMonths.last ?? .now }
    private var monthDays: [ActivityDay] { days.filter { calendar.isDate($0.date, equalTo: displayedMonth, toGranularity: .month) } }
    private var leadingSpaces: Int { (calendar.component(.weekday, from: displayedMonth) - calendar.firstWeekday + 7) % 7 }
    private var weekdayNames: [String] {
        let names = calendar.veryShortStandaloneWeekdaySymbols
        return (0..<7).map { names[(calendar.firstWeekday - 1 + $0) % 7] }
    }
    var body: some View {
        Surface {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeading(title: "Scrobble calendar", subtitle: "All imported history · tap a day")
                HStack {
                    monthButton(offset: -1, symbol: "chevron.left")
                    Spacer()
                    Text(displayedMonth.formatted(.dateTime.month(.wide).year())).font(.headline)
                    Spacer()
                    monthButton(offset: 1, symbol: "chevron.right")
                }
                let counts = Dictionary(uniqueKeysWithValues: monthDays.map { (calendar.component(.day, from: $0.date), $0) })
                let maximum = max(1, monthDays.map(\.count).max() ?? 1)
                let totalDays = calendar.range(of: .day, in: .month, for: displayedMonth)?.count ?? 0
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 5) {
                    ForEach(0..<7) { index in
                        Text(weekdayNames[index]).font(.caption2.bold()).foregroundStyle(.secondary)
                    }
                    ForEach(0..<(leadingSpaces + totalDays), id: \.self) { cell in
                        let number = cell - leadingSpaces + 1
                        if number <= 0 { Color.clear.frame(height: 36) }
                        else {
                            let day = counts[number]
                            Button { selected = day } label: {
                                Text(String(number)).font(.caption.weight(.semibold)).monospacedDigit()
                                    .frame(maxWidth: .infinity, minHeight: 36)
                                    .foregroundStyle(day == nil ? Color.secondary.opacity(0.35) : Color.primary)
                                    .background(color(day?.count, maximum: maximum), in: RoundedRectangle(cornerRadius: 7))
                            }.buttonStyle(.plain).disabled(day == nil)
                                .accessibilityLabel("\(displayedMonth.formatted(.dateTime.month())) \(number), \(day?.count ?? 0) scrobbles\(day == nil ? ", outside imported history" : "")")
                        }
                    }
                }
                HStack {
                    Text("\(monthDays.reduce(0) { $0 + $1.count }.formatted()) scrobbles").font(.caption.weight(.semibold))
                    Spacer()
                    Text("Less").font(.caption2).foregroundStyle(.secondary)
                    ForEach(0..<4) { level in
                        RoundedRectangle(cornerRadius: 3).fill(color(level, maximum: 3)).frame(width: 12, height: 12)
                    }
                    Text("More").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .onChange(of: availableMonths) { _, months in
            if let month, !months.contains(month) { self.month = months.last }
        }
        .sheet(item: $selected) { day in CalendarDayView(day: day) }
    }
    private func color(_ count: Int?, maximum: Int) -> Color {
        guard let count else { return .clear }
        return count == 0 ? Color.secondary.opacity(0.09) : Theme.accent.opacity(0.2 + 0.65 * Double(count) / Double(maximum))
    }
    private func monthButton(offset: Int, symbol: String) -> some View {
        let index = availableMonths.firstIndex(of: displayedMonth) ?? 0
        let next = index + offset
        return Button { month = availableMonths[next] } label: {
            Image(systemName: symbol).frame(width: 44, height: 44)
        }.buttonStyle(.plain).disabled(!availableMonths.indices.contains(next))
            .accessibilityLabel(offset < 0 ? "Previous month" : "Next month")
    }
}

private struct CalendarDayView: View {
    let day: ActivityDay
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var limit = 100
    private var items: [Scrobble] { model.history.filter { Calendar.current.isDate($0.date, inSameDayAs: day.date) } }
    var body: some View {
        NavigationStack {
            List {
                Section { Text("\(items.count.formatted()) scrobbles").font(.headline) }
                if items.isEmpty { ContentUnavailableView("A quiet day", systemImage: "moon", description: Text("No scrobbles in your imported history for this day.")) }
                ForEach(Array(items.prefix(limit))) { ScrobbleRow(item: $0) }
                if items.count > limit { Button("Show more") { limit += 100 } }
            }.navigationTitle(day.date.formatted(date: .abbreviated, time: .omitted))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
