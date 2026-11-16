import Foundation

public struct CountBucket: Identifiable, Sendable {
    public let id: Int
    public let label: String
    public let count: Int
}

public struct MonthlyFavorites: Identifiable, Sendable {
    public let month: Date
    public let scrobbles: Int
    public let artist: RankedEntity?
    public let album: RankedEntity?
    public let track: RankedEntity?
    public var id: Date { month }
}

public struct DashboardStats: Sendable {
    public let chartPeriods: [ChartPeriod]
    public let count: Int
    public let tracks: Int
    public let artists: Int
    public let albums: Int
    public let activeDays: Int
    public let calendarDays: Int
    /// Earliest event in all imported history, independent of the selected range.
    public let firstScrobble: Date?
    public let longestStreak: Int
    public let busiestDay: ActivityDay?
    public let daily: [ActivityDay]
    public let cumulative: [ActivityDay]
    public let hours: [CountBucket]
    public let weekdays: [CountBucket]
    public let months: [CountBucket]
    public let years: [CountBucket]
    public let topArtists: [RankedEntity]
    public let topTracks: [RankedEntity]
    public let topAlbums: [RankedEntity]
    public var average: Double { Double(count) / Double(max(1, calendarDays)) }
    public var daysScrobbledPercentage: Double { Double(activeDays) / Double(max(1, calendarDays)) * 100 }
    public var showMonthlyChart: Bool { calendarDays > 31 && months.count > 1 }
    public var showYearlyChart: Bool { calendarDays > 366 && years.count > 1 }
}

extension StatsEngine {
    public static func dashboard(_ items: [Scrobble], interval: DateInterval, calendar: Calendar = .current) -> DashboardStats {
        let selected = filter(items, interval: interval)
        let grouped = Dictionary(grouping: selected) { calendar.startOfDay(for: $0.date) }
        let firstScrobble = items.min { $0.timestamp < $1.timestamp }?.date
        // Do not count days before the first known scrobble as silent days.
        // Use ALL history here, so a quiet beginning of a selected range still counts.
        let start = calendar.startOfDay(for: max(interval.start, firstScrobble ?? interval.end))
        let end = calendar.startOfDay(for: interval.end.addingTimeInterval(-1))
        var daily: [ActivityDay] = []
        var cursor = start
        while firstScrobble != nil && cursor <= end {
            daily.append(ActivityDay(date: cursor, count: grouped[cursor]?.count ?? 0))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor), next > cursor else { break }
            cursor = next
        }
        var total = 0
        var streak = 0
        var longestStreak = 0
        let cumulative = daily.map { day in
            total += day.count
            streak = day.count > 0 ? streak + 1 : 0
            longestStreak = max(longestStreak, streak)
            return ActivityDay(date: day.date, count: total)
        }
        var hours = Array(repeating: 0, count: 24)
        var weekdays = Array(repeating: 0, count: 7)
        var monthItems: [Date: [Scrobble]] = [:]
        var years: [Int: Int] = [:]
        for item in selected {
            hours[calendar.component(.hour, from: item.date)] += 1
            weekdays[(calendar.component(.weekday, from: item.date) + 5) % 7] += 1
            let month = calendar.dateInterval(of: .month, for: item.date)!.start
            monthItems[month, default: []].append(item)
            years[calendar.component(.year, from: item.date), default: 0] += 1
        }
        let weekdayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM yyyy"
        var months: [CountBucket] = []
        if let firstDay = daily.first, let lastDay = daily.last {
            var month = calendar.dateInterval(of: .month, for: firstDay.date)!.start
            while month <= lastDay.date {
                let components = calendar.dateComponents([.year, .month], from: month)
                months.append(CountBucket(id: components.year! * 100 + components.month!,
                    label: formatter.string(from: month), count: monthItems[month]?.count ?? 0))
                guard let next = calendar.date(byAdding: .month, value: 1, to: month), next > month else { break }
                month = next
            }
            for year in calendar.component(.year, from: firstDay.date)...calendar.component(.year, from: lastDay.date) {
                if years[year] == nil { years[year] = 0 }
            }
        }
        return DashboardStats(chartPeriods: chartPeriods(daily, calendar: calendar), count: selected.count,
            tracks: Set(selected.map { key($0, kind: .tracks) }).count,
            artists: Set(selected.map(\.artist)).count,
            albums: Set(selected.filter { !$0.album.trimmingCharacters(in: .whitespaces).isEmpty }.map { key($0, kind: .albums) }).count,
            activeDays: grouped.count, calendarDays: daily.count, firstScrobble: firstScrobble,
            longestStreak: longestStreak,
            busiestDay: daily.filter { $0.count > 0 }.max { $0.count < $1.count },
            daily: daily, cumulative: cumulative,
            hours: hours.enumerated().map { CountBucket(id: $0.offset, label: String($0.offset), count: $0.element) },
            weekdays: weekdays.enumerated().map { CountBucket(id: $0.offset, label: weekdayNames[$0.offset], count: $0.element) },
            months: months,
            years: years.keys.sorted().map { CountBucket(id: $0, label: String($0), count: years[$0]!) },
            topArtists: Array(ranking(selected, kind: .artists).prefix(10)),
            topTracks: Array(ranking(selected, kind: .tracks).prefix(10)),
            topAlbums: Array(ranking(selected, kind: .albums).prefix(10)))
    }
}
