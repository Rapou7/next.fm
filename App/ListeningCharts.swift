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
    private var visibleKinds: [ListeningChartKind] {
        ListeningChartKind.allCases.filter { kind in
            switch kind {
            case .months: stats.showMonthlyChart
            case .years: stats.showYearlyChart
            default: true
            }
        }
    }
    var body: some View {
        VStack(spacing: 28) {
            ForEach(visibleKinds) { kind in
                Surface {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(kind.rawValue).font(.title3.bold())
                            Spacer()
                            Button { expanded = kind } label: {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(width: 32, height: 32)
                            }.buttonStyle(.glass).buttonBorderShape(.circle)
                                .controlSize(.small).frame(minWidth: 44, minHeight: 44)
                                .accessibilityLabel("Expand \(kind.rawValue)")
                        }
                        ListeningChart(stats: stats, kind: kind).frame(height: kind == .hours ? 290 : 220)
                    }
                }
            }
        }
        .sheet(item: $expanded) { kind in
            NavigationStack {
                ListeningChart(stats: stats, kind: kind)
                    .frame(maxHeight: kind == .hours ? 420 : 360).padding(24)
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
        if stats.count == 0 {
            ContentUnavailableView("No listening in this range", systemImage: "chart.bar",
                                   description: Text("Choose another period to explore your listening patterns."))
        } else {
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
            ListeningClock(hours: stats.hours)
        default:
            GeometryReader { geometry in
                let width = max(geometry.size.width - 8, CGFloat(buckets.count) * (kind == .months ? 62 : 38))
                ScrollView(.horizontal, showsIndicators: false) {
                    Chart(buckets) { bucket in
                        BarMark(x: .value("Period", bucket.label), y: .value("Scrobbles", bucket.count))
                            .cornerRadius(6).foregroundStyle(Theme.accent.gradient)
                            .annotation(position: .top) {
                                if bucket.count > 0 {
                                    Text(bucket.count.formatted(.number.notation(.compactName)))
                                        .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                                }
                            }
                        }
                    .chartYScale(domain: 0...Double(max(1, buckets.map(\.count).max() ?? 1)) * 1.2)
                    .chartYAxis(.hidden).chartXAxis { AxisMarks { _ in AxisValueLabel() } }
                    .frame(width: width, height: max(1, geometry.size.height - 12))
                    .padding(.horizontal, 4).padding(.top, 6)
                }
            }
        }
        }
    }
}
