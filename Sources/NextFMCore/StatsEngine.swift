import Foundation

public enum StatsEngine {
    public static func key(_ item: Scrobble, kind: EntityKind) -> String {
        let parts: [String]
        switch kind {
        case .artists: parts = [item.artist]
        case .albums: parts = [item.artist, item.album]
        case .tracks: parts = [item.artist, item.track]
        }
        return parts.map { "\($0.utf8.count):\($0)" }.joined()
    }

    public static func filter(_ items: [Scrobble], interval: DateInterval) -> [Scrobble] {
        items.filter { $0.date >= interval.start && $0.date < interval.end }
    }

    public static func ranking(_ items: [Scrobble], kind: EntityKind, interval: DateInterval? = nil) -> [RankedEntity] {
        var groups: [String: (sample: Scrobble, count: Int)] = [:]
        for item in items {
            if let interval, !(item.date >= interval.start && item.date < interval.end) { continue }
            if kind == .albums && item.album.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            let id = key(item, kind: kind)
            if var group = groups[id] {
                group.count += 1
                if group.sample.artworkURL == nil && item.artworkURL != nil { group.sample = item }
                groups[id] = group
            } else { groups[id] = (item, 1) }
        }
        return groups.map { id, group in
            let item = group.sample
            return RankedEntity(id: id, title: kind == .artists ? item.artist : (kind == .albums ? item.album : item.track),
                                subtitle: kind == .artists ? "Artist" : item.artist, count: group.count,
                                artworkURL: group.sample.artworkURL, kind: kind)
        }.sorted { $0.count == $1.count ? $0.id < $1.id : $0.count > $1.count }
    }

    public static func summary(_ items: [Scrobble], now: Date = .now, calendar: Calendar = .current) -> ListeningSummary {
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -27, to: today)!
        let previous = calendar.date(byAdding: .day, value: -28, to: start)!
        let recent = items.filter { $0.date >= start && $0.date <= now }
        let buckets = Dictionary(grouping: recent) { calendar.startOfDay(for: $0.date) }
        let days = (0..<28).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: start)!
            return ActivityDay(date: date, count: buckets[date]?.count ?? 0)
        }
        let allDays = Set(items.filter { $0.date <= now }.map { calendar.startOfDay(for: $0.date) })
        var cursor = allDays.contains(today) ? today : calendar.date(byAdding: .day, value: -1, to: today)!
        var streak = 0
        while allDays.contains(cursor) {
            streak += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
        }
        return ListeningSummary(total: recent.count, uniqueArtists: Set(recent.map(\.artist)).count,
            uniqueAlbums: Set(recent.filter { !$0.album.isEmpty }.map { key($0, kind: .albums) }).count,
            activeDays: buckets.count, streak: streak,
            previousTotal: items.filter { $0.date >= previous && $0.date < start }.count, days: days)
    }
}
