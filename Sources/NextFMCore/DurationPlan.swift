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

public struct DurationPlan: Sendable {
    public var milliseconds: Int64 = 0
    public var covered = 0
    public var total = 0
    public let counts: [CatalogTrack: Int]
    public let pending: [CatalogTrack]

    public init(history: [Scrobble], interval: DateInterval,
                cache: [CatalogTrack: CachedDuration], now: Date = .now) {
        var counts: [CatalogTrack: Int] = [:]
        for play in history where play.date >= interval.start && play.date < interval.end && play.date <= now {
            counts[CatalogTrack(play), default: 0] += 1
        }
        self.counts = counts
        var missing: [CatalogTrack] = []
        for (track, count) in counts {
            total += count
            if let ms = cache[track]?.milliseconds {
                milliseconds += Int64(ms) * Int64(count)
                covered += count
            } else if cache[track].map({ now.timeIntervalSince($0.checked) < 7 * 86400 }) != true {
                missing.append(track)
            }
        }
        pending = missing.sorted { counts[$0, default: 0] > counts[$1, default: 0] }
    }

    public mutating func include(_ results: [CatalogTrack: CachedDuration]) {
        for (track, result) in results {
            guard let ms = result.milliseconds, let count = counts[track] else { continue }
            milliseconds += Int64(ms) * Int64(count)
            covered += count
        }
    }
}
