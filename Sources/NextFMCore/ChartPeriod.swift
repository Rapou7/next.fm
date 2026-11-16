import Foundation

public struct ChartPeriod: Identifiable, Sendable {
    public let start: Date
    public let end: Date
    public let count: Int
    public let cumulative: Int
    public var id: Date { start }
}

extension StatsEngine {
    // Keep one point per calendar day, including silent days and DST boundaries.
    static func chartPeriods(_ days: [ActivityDay], calendar: Calendar) -> [ChartPeriod] {
        var total = 0
        return days.map { day in
            total += day.count
            return ChartPeriod(start: day.date,
                end: calendar.date(byAdding: .day, value: 1, to: day.date)!,
                count: day.count, cumulative: total)
        }
    }
}
