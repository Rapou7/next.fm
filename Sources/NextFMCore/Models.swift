import Foundation

public struct Scrobble: Codable, Identifiable, Hashable, Sendable {
    public let track: String
    public let artist: String
    public let album: String
    public let timestamp: Int
    public let artworkURL: URL?
    public var date: Date { Date(timeIntervalSince1970: Double(timestamp)) }
    public var id: String {
        // Length-prefixed components avoid collisions in names containing separators.
        [String(timestamp), artist, album, track].map { "\($0.utf8.count):\($0)" }.joined()
    }
    public init(track: String, artist: String, album: String, timestamp: Int, artworkURL: URL? = nil) {
        self.track = track; self.artist = artist; self.album = album
        self.timestamp = timestamp; self.artworkURL = artworkURL
    }
}

public struct NowPlaying: Sendable {
    public let track: String
    public let artist: String
    public let album: String
    public let artworkURL: URL?
    public init(track: String, artist: String, album: String, artworkURL: URL?) {
        self.track = track; self.artist = artist; self.album = album; self.artworkURL = artworkURL
    }
}

public enum EntityKind: String, CaseIterable, Identifiable, Sendable {
    case tracks = "Tracks", artists = "Artists", albums = "Albums"
    public var id: String { rawValue }
    public var icon: String {
        switch self { case .tracks: "music.note"; case .artists: "person.2.fill"; case .albums: "square.stack.fill" }
    }
}

public struct RankedEntity: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let count: Int
    public let artworkURL: URL?
    public let kind: EntityKind
    public func matches(_ scrobble: Scrobble) -> Bool { StatsEngine.key(scrobble, kind: kind) == id }
}

public enum ListeningRange: String, CaseIterable, Identifiable, Sendable {
    case fourWeeks = "4 weeks", sixMonths = "6 months", lifetime = "Lifetime"
    case today = "Today", thisWeek = "This week", thisYear = "This year", custom = "Custom dates"
    public var id: String { rawValue }
    public func interval(now: Date = .now, calendar: Calendar = .current, customStart: Date = .now, customEnd: Date = .now) -> DateInterval {
        let day = calendar.startOfDay(for: now)
        let end = now.addingTimeInterval(1)
        switch self {
        case .fourWeeks: return DateInterval(start: calendar.date(byAdding: .day, value: -27, to: day)!, end: end)
        case .sixMonths: return DateInterval(start: calendar.date(byAdding: .month, value: -6, to: day)!, end: end)
        case .lifetime: return DateInterval(start: Date(timeIntervalSince1970: 0), end: end)
        case .today: return DateInterval(start: day, end: end)
        case .thisWeek: return DateInterval(start: calendar.dateInterval(of: .weekOfYear, for: now)!.start, end: end)
        case .thisYear: return DateInterval(start: calendar.dateInterval(of: .year, for: now)!.start, end: end)
        case .custom:
            let start = calendar.startOfDay(for: min(customStart, customEnd))
            let last = calendar.startOfDay(for: max(customStart, customEnd))
            return DateInterval(start: start, end: calendar.date(byAdding: .day, value: 1, to: last)!)
        }
    }
}

public struct ActivityDay: Identifiable, Sendable {
    public let date: Date
    public let count: Int
    public var id: Date { date }
}

public struct ListeningSummary: Sendable {
    public let total: Int
    public let uniqueArtists: Int
    public let uniqueAlbums: Int
    public let activeDays: Int
    public let streak: Int
    public let previousTotal: Int
    public let days: [ActivityDay]
}

public struct SyncCheckpoint: Codable, Sendable {
    public var upperBound: Int
    public var nextPage: Int
    public var totalPages: Int
    public var isComplete: Bool
    public var refreshedThrough: Int
    public init(upperBound: Int, nextPage: Int = 1, totalPages: Int = 1, isComplete: Bool = false, refreshedThrough: Int = 0) {
        self.upperBound = upperBound; self.nextPage = nextPage; self.totalPages = totalPages
        self.isComplete = isComplete; self.refreshedThrough = refreshedThrough
    }
}
