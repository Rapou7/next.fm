import Foundation
import Testing
@testable import NextFMCore

@Test func durationCacheSeparatesAlbumsAndCountsOnlyEligiblePlays() async throws {
    let store = try HistoryStore(url: URL(fileURLWithPath: ":memory:"))
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
    #expect(plan.milliseconds == cached.milliseconds)
    #expect(cached.pending.isEmpty)
    try await store.saveDurations([CatalogTrack(second): CachedDuration(milliseconds: nil, checked: .distantPast)])
    let expired = try await store.durationPlan(history: history, interval: interval)
    #expect(expired.pending == [CatalogTrack(second)])
    await store.close()
}
