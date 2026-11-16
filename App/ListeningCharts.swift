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
                            if kind == .daily || kind == .cumulative {
                                Button { expanded = kind } label: {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        .font(.subheadline.weight(.semibold))
                                        .frame(width: 32, height: 32)
                                }.buttonStyle(.glass).buttonBorderShape(.circle)
                                    .controlSize(.small).frame(minWidth: 44, minHeight: 44)
                                    .accessibilityLabel("Expand \(kind.rawValue)")
                            }
                        }
                        ListeningChart(stats: stats, kind: kind)
                            .quickAppear()
                    }
                }.showcaseAnchor("chart." + kind.id.lowercased().replacingOccurrences(of: "listening clock", with: "hours"))
            }
        }
        .fullScreenCover(item: $expanded) { kind in
            NavigationStack {
                ListeningChart(stats: stats, kind: kind, isExpanded: true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(24)
                    .navigationTitle(kind.rawValue).navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { expanded = nil } } }
            }
        }
    }
}

struct ListeningChart: View {
    let stats: DashboardStats
    let kind: ListeningChartKind
    var isExpanded = false
    private var buckets: [CountBucket] {
        switch kind { case .weekdays: stats.weekdays; case .months: stats.months; case .years: stats.years; default: stats.hours }
    }
    var body: some View {
        if stats.count == 0 {
            ContentUnavailableView("No listening in this range", systemImage: "chart.bar",
                                   description: Text("Choose another period to explore your listening patterns."))
                .frame(height: isExpanded ? nil : 220)
        } else {
        switch kind {
        case .daily, .cumulative:
            ListeningTimelineChart(points: stats.chartPeriods,
                                   cumulative: kind == .cumulative,
                                   chartHeight: isExpanded ? nil : 220)
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
            .frame(height: isExpanded ? nil : 220)
        }
        }
    }
}

private struct ListeningTimelineChart: View {
    let points: [ChartPeriod]
    let cumulative: Bool
    let chartHeight: CGFloat?
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
            if let selected {
                selectionReadout(for: selected)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
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
                    TimelineDrawing(points: points, cumulative: cumulative, maximum: maximum,
                                    selectedID: selected?.id)
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
            .frame(height: chartHeight)
            .frame(maxHeight: chartHeight == nil ? .infinity : nil)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: selected?.id)
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: selected != nil)
        .sensoryFeedback(.selection, trigger: selected?.id)
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.35)) { appeared = true }
        }
        .onChange(of: points.first?.start) { selectedDate = nil }
        .onChange(of: points.last?.end) { selectedDate = nil }
        .onChange(of: cumulative) { selectedDate = nil }
        .transaction { if reduceMotion { $0.animation = nil } }
    }

    private func selectionReadout(for point: ChartPeriod) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label(for: point)).font(.caption).foregroundStyle(.secondary)
                Text("\(count(for: point).formatted()) scrobbles")
                    .font(.subheadline.weight(.semibold)).monospacedDigit()
                    .contentTransition(.identity)
            }
            .animation(nil, value: point.id)
            Spacer(minLength: 0)
            Button { selectedDate = nil } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary).frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Clear chart selection")
        }
        .padding(.leading, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .contain)
    }
}

// One drawing layer instead of thousands of individually laid-out Chart marks.
// Every daily value is drawn; no aggregation or sampling is applied.
private struct TimelineDrawing: View {
    let points: [ChartPeriod]
    let cumulative: Bool
    let maximum: Double
    let selectedID: Date?

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
                var outlines = Path()
                var selection = Path()
                for point in points where point.count > 0 {
                    let left = x(point.start)
                    let slot = x(point.end) - left
                    // Leave a real visual gutter without shrinking dense lifetime
                    // histories into invisible slivers. Keep actual dates unchanged.
                    let gap = slot > 2 ? min(3, slot * 0.22) : 0
                    let width = min(32, max(0.25, slot - gap))
                    let rect = CGRect(x: left + (slot - width) / 2, y: y(point.count),
                                      width: width,
                                      height: size.height - y(point.count))
                    let radius = min(4, min(rect.width / 3, rect.height / 2))
                    let bar = RoundedRectangle(cornerRadius: radius).path(in: rect)
                    path.addPath(bar)
                    if slot > 2 { outlines.addPath(bar) }
                    if point.id == selectedID { selection.addPath(bar) }
                }
                let fill = GraphicsContext.Shading.linearGradient(
                    Gradient(colors: [Theme.accent, Theme.accent.opacity(0.75)]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height))
                var bars = context
                bars.opacity = selectedID == nil ? 1 : 0.3
                bars.fill(path, with: fill)
                bars.stroke(outlines, with: .color(.primary.opacity(0.22)), lineWidth: 0.65)
                if selectedID != nil {
                    context.fill(selection, with: fill)
                    context.stroke(selection, with: .color(.primary.opacity(0.45)), lineWidth: 1)
                }
            }
        }
    }
}
