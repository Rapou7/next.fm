import Foundation

/// Browsable history, independent of the dashboard's selected comparison period.
public struct HistoryInsights: Sendable {
    public let daily: [ActivityDay]
    /// Newest first, using all imported events in each month (through now).
    public let monthlyFavorites: [MonthlyFavorites]
}

extension StatsEngine {
    public static func historyInsights(_ items: [Scrobble], now: Date = .now,
                                       calendar: Calendar = .current) -> HistoryInsights {
        let imported = items.filter { $0.date <= now }
        let grouped = Dictionary(grouping: imported) { calendar.startOfDay(for: $0.date) }
        var daily: [ActivityDay] = []
        if var day = grouped.keys.min() {
            let today = calendar.startOfDay(for: now)
            while day <= today {
                daily.append(ActivityDay(date: day, count: grouped[day]?.count ?? 0))
                guard let next = calendar.date(byAdding: .day, value: 1, to: day), next > day else { break }
                day = next
            }
        }
        let months = Dictionary(grouping: imported) { calendar.dateInterval(of: .month, for: $0.date)!.start }
        let favorites = months.keys.sorted(by: >).map { month in
            let entries = months[month]!
            return MonthlyFavorites(month: month, scrobbles: entries.count,
                artist: ranking(entries, kind: .artists).first,
                album: ranking(entries, kind: .albums).first,
                track: ranking(entries, kind: .tracks).first)
        }
        return HistoryInsights(daily: daily, monthlyFavorites: favorites)
    }
}
