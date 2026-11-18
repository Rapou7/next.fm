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
