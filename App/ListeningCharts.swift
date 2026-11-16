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
        // Lifetime can contain years of daily marks. Create each chart only
        // when it approaches the viewport, rather than laying out all charts
        // when the Summary statistics change.
        LazyVStack(spacing: 28) {
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
                            .quickAppear()
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
            ListeningTimelineChart(points: stats.chartPeriods,
                                   cumulative: kind == .cumulative)
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

private struct ListeningTimelineChart: View {
    let points: [ChartPeriod]
    let cumulative: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedDate: Date?
    @State private var appeared = false

    // Periods are sorted. Scrubbing years of history should not scan
    // the entire series every time the finger moves.
    private var selectedIndex: Int? {
        guard let selectedDate, !points.isEmpty else { return nil }
        var lower = 0
        var upper = points.count
        while lower < upper {
            let middle = (lower + upper) / 2
            let isBefore = cumulative ? points[middle].end < selectedDate : points[middle].end <= selectedDate
            if isBefore { lower = middle + 1 } else { upper = middle }
        }
        let index = min(lower, points.count - 1)
        if cumulative, index > 0,
           abs(points[index - 1].end.timeIntervalSince(selectedDate)) < abs(points[index].end.timeIntervalSince(selectedDate)) {
            return index - 1
        }
        return index
    }

    // Match the center of a period bar or the endpoint of the cumulative line.
    private func markerDate(for point: ChartPeriod) -> Date {
        cumulative ? point.end : point.start.addingTimeInterval(point.end.timeIntervalSince(point.start) / 2)
    }

    private func count(for point: ChartPeriod) -> Int {
        cumulative ? point.cumulative : point.count
    }

    private func label(for point: ChartPeriod) -> String {
        let lastDay = Calendar.current.startOfDay(for: point.end.addingTimeInterval(-1))
        let start = point.start.formatted(date: .abbreviated, time: .omitted)
        guard !Calendar.current.isDate(point.start, inSameDayAs: lastDay) else { return start }
        return "\(start) – \(lastDay.formatted(date: .abbreviated, time: .omitted))"
    }

    private var maximum: Double {
        Double(max(1, cumulative ? (points.last?.cumulative ?? 0) : (points.map(\.count).max() ?? 0))) * 1.05
    }

    var body: some View {
        let selected = selectedIndex.map { points[$0] }
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: selected == nil ? "hand.draw" : "scope")
                    .foregroundStyle(Theme.accent)
                    .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(selected.map { label(for: $0) }
                         ?? "Touch and drag to explore")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(selected.map { "\(count(for: $0).formatted()) scrobbles" }
                         ?? (cumulative ? "Running total in this range" : "Scrobbles each day"))
                        .font(.subheadline.weight(.semibold)).monospacedDigit()
                        .contentTransition(reduceMotion ? .identity : .numericText())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    selectedDate = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary).frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear chart selection")
                .opacity(selected == nil ? 0 : 1)
                .disabled(selected == nil)
                .accessibilityHidden(selected == nil)
            }
            .frame(minHeight: 44, alignment: .top)
            .accessibilityElement(children: .contain)

            Chart {
                if let selected {
                    RuleMark(x: .value("Selected date", markerDate(for: selected)))
                        .foregroundStyle(Theme.accent.opacity(0.65))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        .accessibilityHidden(true)
                    PointMark(x: .value("Selected date", markerDate(for: selected)),
                              y: .value("Scrobbles", count(for: selected)))
                        .symbolSize(150)
                        .foregroundStyle(Theme.accent.opacity(0.2))
                        .accessibilityHidden(true)
                    PointMark(x: .value("Selected date", markerDate(for: selected)),
                              y: .value("Scrobbles", count(for: selected)))
                        .symbolSize(50)
                        .foregroundStyle(Theme.accent)
                        .accessibilityHidden(true)
                }
            }
            .chartXScale(domain: (points.first?.start ?? .now)...(points.last?.end ?? .now))
            .chartYScale(domain: 0...maximum)
            .chartPlotStyle { plot in
                plot.background {
                    TimelineDrawing(points: points, cumulative: cumulative, maximum: maximum)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .chartXSelection(value: $selectedDate)
            .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) }
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(cumulative ? "Cumulative scrobbles" : "Daily scrobbles")
            .accessibilityValue(selected.map { "\(label(for: $0)), \(count(for: $0)) scrobbles" }
                                 ?? "Swipe up or down to select a day")
            .accessibilityAdjustableAction { direction in
                guard !points.isEmpty else { return }
                switch direction {
                case .increment: selectedDate = markerDate(for: points[min((selectedIndex ?? -1) + 1, points.count - 1)])
                case .decrement: selectedDate = markerDate(for: points[max((selectedIndex ?? points.count) - 1, 0)])
                @unknown default: break
                }
            }
            .opacity(appeared || reduceMotion ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 8)
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: selected?.id)
        .sensoryFeedback(.selection, trigger: selected?.id)
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.35)) { appeared = true }
        }
        .onChange(of: points.first?.start) { selectedDate = nil }
        .onChange(of: points.last?.end) { selectedDate = nil }
        .onChange(of: cumulative) { selectedDate = nil }
        .transaction { if reduceMotion { $0.animation = nil } }
    }
}

// One drawing layer instead of thousands of individually laid-out Chart marks.
// Every daily value is drawn; no aggregation or sampling is applied.
private struct TimelineDrawing: View {
    let points: [ChartPeriod]
    let cumulative: Bool
    let maximum: Double

    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            guard let first = points.first, let last = points.last else { return }
            let duration = last.end.timeIntervalSince(first.start)
            guard duration > 0 else { return }
            func x(_ date: Date) -> CGFloat {
                CGFloat(date.timeIntervalSince(first.start) / duration) * size.width
            }
            func y(_ count: Int) -> CGFloat {
                size.height * (1 - CGFloat(Double(count) / maximum))
            }
            var path = Path()
            if cumulative {
                path.move(to: CGPoint(x: 0, y: size.height))
                for point in points {
                    path.addLine(to: CGPoint(x: x(point.end), y: y(point.cumulative)))
                }
                context.stroke(path, with: .color(Theme.accent), lineWidth: 2)
                path.addLine(to: CGPoint(x: size.width, y: size.height))
                path.closeSubpath()
                context.fill(path, with: .linearGradient(
                    Gradient(colors: [Theme.accent.opacity(0.25), .clear]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            } else {
                for point in points where point.count > 0 {
                    let left = x(point.start)
                    path.addRect(CGRect(x: left, y: y(point.count),
                        width: max(0.5, x(point.end) - left),
                        height: size.height - y(point.count)))
                }
                context.fill(path, with: .color(Theme.accent))
            }
        }
    }
}
