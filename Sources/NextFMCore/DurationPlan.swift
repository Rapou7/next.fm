import Foundation

public struct CatalogTrack: Hashable, Codable, Sendable {
    public let artist: String
    public let title: String
    public let album: String

    public init(_ play: Scrobble) {
        artist = play.artist
        title = play.track
        album = play.album
    }
}

public struct CachedDuration: Codable, Sendable {
    public let milliseconds: Int?
    public let checked: Date

    public init(milliseconds: Int?, checked: Date = .now) {
        self.milliseconds = milliseconds
        self.checked = checked
    }
}

public struct EstimatedDuration: Sendable {
    public var milliseconds: Int64 = 0
    public var covered = 0

    public init() {}

    public mutating func add(_ other: Self) {
        milliseconds += other.milliseconds
        covered += other.covered
    }
}

public struct DurationBreakdown: Sendable {
    public private(set) var total = EstimatedDuration()
    public private(set) var days: [Date: EstimatedDuration] = [:]
    public private(set) var hours: [Int: EstimatedDuration] = [:]
    public private(set) var weekdays: [Int: EstimatedDuration] = [:]
    public private(set) var months: [Int: EstimatedDuration] = [:]
    public private(set) var years: [Int: EstimatedDuration] = [:]
    public private(set) var tracks: [CatalogTrack: Int] = [:]
    private var entities: [EntityKind: [String: EstimatedDuration]] = [:]

    public init() {}

    public func estimate(for entity: RankedEntity) -> EstimatedDuration? {
        entities[entity.kind]?[entity.id]
    }

    public func rankedByTime(_ scrobbleRanking: [RankedEntity]) -> [RankedEntity] {
        let timed = scrobbleRanking.enumerated().map { index, entity in
            (index: index, entity: entity, milliseconds: estimate(for: entity)?.milliseconds ?? 0)
        }
        return timed.sorted {
            if $0.milliseconds != $1.milliseconds { return $0.milliseconds > $1.milliseconds }
            return $0.index < $1.index
        }.map(\.entity)
    }

    public func estimate(from start: Date, to end: Date) -> EstimatedDuration {
        var result = EstimatedDuration()
        for (day, estimate) in days where day >= start && day < end {
            result.add(estimate)
        }
        return result
    }

    mutating func include(_ track: CatalogTrack, plays: [Scrobble], milliseconds: Int, calendar: Calendar) {
        guard let first = plays.first else { return }
        tracks[track] = milliseconds
        var estimate = EstimatedDuration()
        estimate.covered = plays.count
        estimate.milliseconds = Int64(milliseconds) * Int64(plays.count)
        total.add(estimate)
        for kind in EntityKind.allCases {
            let id = StatsEngine.key(first, kind: kind)
            entities[kind, default: [:]][id, default: EstimatedDuration()].add(estimate)
        }
        var playEstimate = EstimatedDuration()
        playEstimate.covered = 1
        playEstimate.milliseconds = Int64(milliseconds)
        for play in plays {
            let date = play.date
            days[calendar.startOfDay(for: date), default: EstimatedDuration()].add(playEstimate)
            hours[calendar.component(.hour, from: date), default: EstimatedDuration()].add(playEstimate)
            weekdays[(calendar.component(.weekday, from: date) + 5) % 7, default: EstimatedDuration()].add(playEstimate)
            let components = calendar.dateComponents([.year, .month], from: date)
            if let year = components.year, let month = components.month {
                years[year, default: EstimatedDuration()].add(playEstimate)
                months[year * 100 + month, default: EstimatedDuration()].add(playEstimate)
            }
        }
    }
}

public struct DurationPlan: Sendable {
    public private(set) var breakdown = DurationBreakdown()
    public var milliseconds: Int64 { breakdown.total.milliseconds }
    public var covered: Int { breakdown.total.covered }
    public let total: Int
    public let pending: [CatalogTrack]
    private var unresolved: [CatalogTrack: [Scrobble]]
    private let calendar: Calendar

    public init(history: [Scrobble], interval: DateInterval,
                cache: [CatalogTrack: CachedDuration], now: Date = .now, calendar: Calendar = .current) {
        let selected = history.filter { $0.date >= interval.start && $0.date < interval.end && $0.date <= now }
        let groups = Dictionary(grouping: selected, by: CatalogTrack.init)
        self.calendar = calendar
        total = selected.count
        unresolved = groups.filter { track, _ in
            guard let entry = cache[track] else { return true }
            return entry.milliseconds == nil && now.timeIntervalSince(entry.checked) >= 7 * 86400
        }
        pending = unresolved.keys.sorted { groups[$0, default: []].count > groups[$1, default: []].count }
        for (track, plays) in groups {
            if let ms = cache[track]?.milliseconds {
                breakdown.include(track, plays: plays, milliseconds: ms, calendar: calendar)
            }
        }
    }

    public mutating func include(_ results: [CatalogTrack: CachedDuration]) {
        for (track, result) in results {
            guard let plays = unresolved.removeValue(forKey: track), let ms = result.milliseconds else { continue }
            breakdown.include(track, plays: plays, milliseconds: ms, calendar: calendar)
        }
    }
}
