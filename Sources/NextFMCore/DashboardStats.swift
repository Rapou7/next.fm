import Foundation

public struct CountBucket: Identifiable, Sendable {
    public let id: Int
    public let label: String
    public let count: Int
}

public struct DashboardStats: Sendable {
    public let count: Int
    public let tracks: Int
    public let artists: Int
    public let albums: Int
    public let activeDays: Int
    public let calendarDays: Int
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
}

extension StatsEngine {
    public static func dashboard(_ items: [Scrobble], interval: DateInterval, calendar: Calendar = .current) -> DashboardStats {
        let selected = filter(items, interval: interval)
        let grouped = Dictionary(grouping: selected) { calendar.startOfDay(for: $0.date) }
        // Lifetime begins at the first actual event, rather than January 1970.
        let start = calendar.startOfDay(for: interval.start.timeIntervalSince1970 == 0
            ? (selected.map(\.date).min() ?? interval.end) : interval.start)
        let end = calendar.startOfDay(for: interval.end.addingTimeInterval(-1))
        var daily: [ActivityDay] = []
        var cursor = start
        while cursor <= end {
            daily.append(ActivityDay(date: cursor, count: grouped[cursor]?.count ?? 0))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor), next > cursor else { break }
            cursor = next
        }
        var total = 0
        let cumulative = daily.map { day in
            total += day.count
            return ActivityDay(date: day.date, count: total)
        }
        var hours = Array(repeating: 0, count: 24)
        var weekdays = Array(repeating: 0, count: 7)
        var months = Array(repeating: 0, count: 12)
        var years: [Int: Int] = [:]
        for item in selected {
            hours[calendar.component(.hour, from: item.date)] += 1
            weekdays[(calendar.component(.weekday, from: item.date) + 5) % 7] += 1
            months[calendar.component(.month, from: item.date) - 1] += 1
            years[calendar.component(.year, from: item.date), default: 0] += 1
        }
        let weekdayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return DashboardStats(count: selected.count,
            tracks: Set(selected.map { key($0, kind: .tracks) }).count,
            artists: Set(selected.map(\.artist)).count,
            albums: Set(selected.filter { !$0.album.trimmingCharacters(in: .whitespaces).isEmpty }.map { key($0, kind: .albums) }).count,
            activeDays: grouped.count, calendarDays: daily.count, daily: daily, cumulative: cumulative,
            hours: hours.enumerated().map { CountBucket(id: $0.offset, label: String($0.offset), count: $0.element) },
            weekdays: weekdays.enumerated().map { CountBucket(id: $0.offset, label: weekdayNames[$0.offset], count: $0.element) },
            months: months.enumerated().map { CountBucket(id: $0.offset, label: monthNames[$0.offset], count: $0.element) },
            years: years.keys.sorted().map { CountBucket(id: $0, label: String($0), count: years[$0]!) },
            topArtists: Array(ranking(selected, kind: .artists).prefix(10)),
            topTracks: Array(ranking(selected, kind: .tracks).prefix(10)),
            topAlbums: Array(ranking(selected, kind: .albums).prefix(10)))
    }
}
