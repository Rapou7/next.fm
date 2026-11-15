import SwiftUI
import Charts
import NextFMCore

enum ListeningChartKind: String, CaseIterable, Identifiable {
    case daily = "Daily", cumulative = "Cumulative", hours = "Listening clock"
    case weekdays = "Scrobbles by day of the week", months = "Scrobbles by month", years = "Scrobbles by year"
    var id: String { rawValue }
}

struct ListeningCharts: View {
    let stats: DashboardStats
    @State private var expanded: ListeningChartKind?
    var body: some View {
        VStack(spacing: 28) {
            ForEach(ListeningChartKind.allCases) { kind in
                Surface {
                    VStack(alignment: .leading, spacing: 24) {
                        HStack {
                            Text(kind.rawValue).font(.title3.bold())
                            Spacer()
                            Button { expanded = kind } label: {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .frame(width: 44, height: 44)
                            }.buttonStyle(.glass).accessibilityLabel("Expand \(kind.rawValue)")
                        }
                        ListeningChart(stats: stats, kind: kind).frame(height: kind == .hours ? 260 : 220)
                    }
                }
            }
        }
        .sheet(item: $expanded) { kind in
            NavigationStack {
                ListeningChart(stats: stats, kind: kind).padding(24)
                    .navigationTitle(kind.rawValue).navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { expanded = nil } } }
            }
        }
    }
}

struct ListeningChart: View {
    let stats: DashboardStats
    let kind: ListeningChartKind
    @State private var selectedDate: Date?
    private var buckets: [CountBucket] {
        switch kind { case .weekdays: stats.weekdays; case .months: stats.months; case .years: stats.years; default: stats.hours }
    }
    var body: some View {
        switch kind {
        case .daily, .cumulative:
            VStack(alignment: .leading, spacing: 8) {
                let points = kind == .daily ? stats.daily : stats.cumulative
                if let selectedDate, let point = points.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }) {
                    Text("\(point.date.formatted(date: .abbreviated, time: .omitted)) · \(point.count.formatted()) scrobbles")
                        .font(.caption).foregroundStyle(Theme.accent)
                }
                Chart(points) { point in
                    if kind == .daily {
                        BarMark(x: .value("Date", point.date, unit: .day), y: .value("Scrobbles", point.count))
                            .foregroundStyle(Theme.accent.gradient)
                    } else {
                        AreaMark(x: .value("Date", point.date), y: .value("Scrobbles", point.count))
                            .foregroundStyle(LinearGradient(colors: [Theme.accent.opacity(0.25), .clear], startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("Date", point.date), y: .value("Scrobbles", point.count)).foregroundStyle(Theme.accent)
                    }
                }.chartXSelection(value: $selectedDate)
                    .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) }
                    .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
            }
        case .hours:
            ZStack {
                Chart(stats.hours) { hour in
                    SectorMark(angle: .value("Hour", 1), innerRadius: .ratio(0.3),
                               outerRadius: .ratio(0.34 + 0.66 * Double(hour.count) / Double(max(1, stats.hours.map(\.count).max() ?? 1))), angularInset: 1.5)
                        .foregroundStyle(Theme.accent.gradient)
                        .annotation(position: .overlay) {
                            if hour.id % 6 == 0 { Text(hour.label).font(.caption2.bold()).foregroundStyle(.primary) }
                        }
                }
                Image(systemName: "clock").font(.title2).foregroundStyle(Theme.accent)
            }.accessibilityLabel("Listening by hour. Longer segments indicate more scrobbles.")
        default:
            ScrollView(.horizontal, showsIndicators: false) {
                Chart(buckets) { bucket in
                    BarMark(x: .value("Period", bucket.label), y: .value("Scrobbles", bucket.count))
                        .cornerRadius(6).foregroundStyle(Theme.accent.gradient)
                        .annotation(position: .top) {
                            Text(bucket.count.formatted(.number.notation(.compactName)))
                                .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                        }
                }.chartYAxis(.hidden).chartXAxis { AxisMarks { _ in AxisValueLabel() } }
                    .frame(width: max(260, CGFloat(buckets.count) * 38)).padding(.top, 14)
            }
        }
    }
}
