import Foundation

/// One instance per app model; revisions must change whenever its history changes.
public actor Analytics {
    public init() {}
    private var insightsCache: (revision: Int, calendar: Calendar, day: Date, validFrom: Date, expires: Date, value: HistoryInsights)?

    public func historyInsights(_ items: [Scrobble], revision: Int, now: Date = .now, calendar: Calendar = .current) throws -> HistoryInsights {
        try Task.checkCancellation()
        let day = calendar.startOfDay(for: now)
        if let cache = insightsCache, cache.revision == revision, cache.calendar == calendar,
           cache.day == day, now >= cache.validFrom, now < cache.expires {
            return cache.value
        }
        #if DEBUG
        let started = ContinuousClock.now
        defer { Diagnostics.shared.record("analytics.historyInsights", detail: "items=\(items.count)", since: started) }
        #endif
        try Task.checkCancellation()
        let value = StatsEngine.historyInsights(items, now: now, calendar: calendar)
        // Future-dated imports must become eligible even within the same day.
        let expires = items.lazy.map(\.date).filter { $0 > now }.min() ?? .distantFuture
        insightsCache = (revision, calendar, day, now, expires, value)
        return value
    }
    public func dashboard(_ items: [Scrobble], interval: DateInterval) throws -> DashboardStats {
        #if DEBUG
        let started = ContinuousClock.now
        defer { Diagnostics.shared.record("analytics.dashboard", detail: "items=\(items.count)", since: started) }
        #endif
        try Task.checkCancellation()
        return StatsEngine.dashboard(items, interval: interval)
    }
    public func summary(_ items: [Scrobble], now: Date = .now, calendar: Calendar = .current) -> ListeningSummary {
        #if DEBUG
        let started = ContinuousClock.now
        defer { Diagnostics.shared.record("analytics.summary", detail: "items=\(items.count)", since: started) }
        #endif
        return StatsEngine.summary(items, now: now, calendar: calendar)
    }
    public func historyIsUnchanged(_ items: [Scrobble], previous: [Scrobble],
                                   evaluatedAt: Date? = nil, now: Date = .now) -> Bool {
        guard items == previous else { return false }
        guard let evaluatedAt else { return true }
        // Identical stored events can produce different statistics as time passes.
        // Clock rollback also requires a fresh snapshot of eligible listening.
        guard now >= evaluatedAt else { return false }
        return !items.contains { $0.date > evaluatedAt && $0.date <= now }
    }
    public func entityProfile(_ items: [Scrobble], entity: RankedEntity,
                              interval: DateInterval, calendar: Calendar = .current) throws -> EntityProfile {
        var matching: [Scrobble] = []
        for (index, item) in items.enumerated() {
            if index.isMultiple(of: 256) { try Task.checkCancellation() }
            if entity.matches(item) { matching.append(item) }
        }
        try Task.checkCancellation()
        let stats = StatsEngine.dashboard(matching, interval: interval, calendar: calendar)
        let selected = StatsEngine.filter(matching, interval: interval).sorted { $0.date > $1.date }
        let related = StatsEngine.ranking(selected, kind: entity.kind == .tracks ? .albums : .tracks)
        let days = Dictionary(grouping: selected) { calendar.startOfDay(for: $0.date) }
            .map { HistoryDay(date: $0.key, items: $0.value) }.sorted { $0.date > $1.date }
        try Task.checkCancellation()
        return EntityProfile(stats: stats, items: selected, related: related, days: days)
    }
    public func ranking(_ items: [Scrobble], kind: EntityKind, interval: DateInterval?) -> [RankedEntity] {
        #if DEBUG
        let started = ContinuousClock.now
        defer { Diagnostics.shared.record("analytics.ranking", detail: "items=\(items.count)", since: started) }
        #endif
        guard !Task.isCancelled else { return [] }
        return StatsEngine.ranking(items, kind: kind, interval: interval)
    }
    public func historyGroups(_ items: [Scrobble], search: String, day: Date?,
                              calendar: Calendar = .current) throws -> [HistoryDay] {
        try Task.checkCancellation()
        let interval = day.flatMap { calendar.dateInterval(of: .day, for: $0) }
        var grouped: [Date: [Scrobble]] = [:]
        for (index, item) in items.enumerated() {
            if index.isMultiple(of: 256) { try Task.checkCancellation() }
            if let interval, !(item.date >= interval.start && item.date < interval.end) { continue }
            if !search.isEmpty && !item.track.localizedCaseInsensitiveContains(search)
                && !item.artist.localizedCaseInsensitiveContains(search)
                && !item.album.localizedCaseInsensitiveContains(search) { continue }
            grouped[calendar.startOfDay(for: item.date), default: []].append(item)
        }
        return grouped.map { HistoryDay(date: $0.key, items: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.date > $1.date }
    }
}

public struct HistoryDay: Sendable {
    public let date: Date
    public let items: [Scrobble]
}

public struct EntityProfile: Sendable {
    public let stats: DashboardStats
    public let items: [Scrobble]
    public let related: [RankedEntity]
    public let days: [HistoryDay]
}
