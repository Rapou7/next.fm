import Foundation
import Testing
@testable import NextFMCore

@Test func durationCacheSeparatesAlbumsAndCountsOnlyEligiblePlays() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = try HistoryStore(url: directory.appendingPathComponent("test.sqlite"))
    let play = Scrobble(track: "Intro", artist: "Artist", album: "First", timestamp: 10, artworkURL: nil)
    let second = Scrobble(track: "Intro", artist: "Artist", album: "Second", timestamp: 11, artworkURL: nil)
    let excluded = Scrobble(track: "Intro", artist: "Artist", album: "First", timestamp: 12, artworkURL: nil)
    let history = [play, play, second, excluded]
    let interval = DateInterval(start: Date(timeIntervalSince1970: 10), end: Date(timeIntervalSince1970: 12))
    var plan = try await store.durationPlan(history: history, interval: interval)
    #expect(plan.pending.first == CatalogTrack(play))
    let results = [CatalogTrack(play): CachedDuration(milliseconds: 196500),
                   CatalogTrack(second): CachedDuration(milliseconds: nil)]
    plan.include(results)
    try await store.saveDurations(results)
    let cached = try await store.durationPlan(history: history, interval: interval)
    #expect(cached.total == 3)
    #expect(cached.covered == 2)
    #expect(cached.milliseconds == 393000)
    let firstAlbum = RankedEntity(album: "First", artist: "Artist", artworkURL: nil)
    let secondAlbum = RankedEntity(album: "Second", artist: "Artist", artworkURL: nil)
    let song = RankedEntity(track: "Intro", artist: "Artist", artworkURL: nil)
    #expect(cached.breakdown.estimate(for: firstAlbum)?.milliseconds == 393000)
    #expect(cached.breakdown.estimate(for: secondAlbum) == nil)
    #expect(cached.breakdown.estimate(for: song)?.covered == 2)
    let day = Calendar.current.startOfDay(for: play.date)
    #expect(cached.breakdown.days[day]?.milliseconds == 393000)
    let cachedBatch = try await store.cachedDurations(for: [CatalogTrack(play), CatalogTrack(second)])
    #expect(cachedBatch.count == 2)
    #expect(cachedBatch[CatalogTrack(play)]?.milliseconds == 196500)
    #expect(cachedBatch[CatalogTrack(second)]?.milliseconds == nil)
    #expect(plan.milliseconds == cached.milliseconds)
    plan.include(results)
    #expect(plan.covered == 2)
    #expect(cached.pending.isEmpty)
    try await store.saveDurations([CatalogTrack(second): CachedDuration(milliseconds: nil, checked: .distantPast)])
    let expired = try await store.durationPlan(history: history, interval: interval)
    #expect(expired.pending == [CatalogTrack(second)])
    await store.close()
}

@Test func timeRankingCanPromoteAnEntryOutsideTheScrobbleTopTen() throws {
    let shortTracks = (1...11).map {
        Scrobble(track: "Short \($0)", artist: "Artist", album: "Shorts", timestamp: 10)
    }
    let unmatched = Scrobble(track: "Unknown", artist: "Artist", album: "", timestamp: 10)
    let long = Scrobble(track: "Long", artist: "Another artist", album: "Longs", timestamp: 10)
    let outsideRange = Scrobble(track: unmatched.track, artist: unmatched.artist, album: unmatched.album, timestamp: 20)
    let history = shortTracks + shortTracks + [unmatched, unmatched, unmatched, long, outsideRange]
    let interval = DateInterval(start: Date(timeIntervalSince1970: 10), end: Date(timeIntervalSince1970: 20))
    var cache = Dictionary(uniqueKeysWithValues: shortTracks.map { (CatalogTrack($0), CachedDuration(milliseconds: 60_000)) })
    cache[CatalogTrack(long)] = CachedDuration(milliseconds: 600_000)
    let plan = DurationPlan(history: history, interval: interval, cache: cache)

    let scrobbleTopTen = StatsEngine.dashboard(history, interval: interval).topTracks
    #expect(scrobbleTopTen.count == 10)
    #expect(!scrobbleTopTen.contains { $0.title == long.track })
    let allTracks = StatsEngine.dashboard(history, interval: interval, includeAllRankings: true).topTracks
    let byTime = plan.breakdown.rankedByTime(allTracks)
    #expect(byTime.first?.title == long.track)
    #expect(byTime.last?.title == unmatched.track)
    #expect(byTime.last?.count == 3)
    #expect(byTime.filter { $0.title.hasPrefix("Short ") }.map(\.id) ==
        allTracks.filter { $0.title.hasPrefix("Short ") }.map(\.id))
}
