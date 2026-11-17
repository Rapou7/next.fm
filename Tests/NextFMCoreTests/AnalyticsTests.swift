import Foundation
import Testing
@testable import NextFMCore

private func utcCalendar() -> Calendar {
    var result = Calendar(identifier: .gregorian)
    result.timeZone = TimeZone(secondsFromGMT: 0)!
    return result
}

@Test func entityProfilesSeparateNamesAndKeepRelatedMusicInSelectedRange() async throws {
    let analytics = Analytics()
    let calendar = utcCalendar()
    let start = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1))!
    func play(_ offset: Int, track: String = "Song", artist: String = "Artist", album: String = "Album") -> Scrobble {
        Scrobble(track: track, artist: artist, album: album, timestamp: Int(start.timeIntervalSince1970) + offset)
    }
    let old = play(-86400)
    let first = play(0)
    let second = play(60, album: "Compilation")
    let noAlbum = play(120, album: "")
    let otherTrack = play(180, track: "Other")
    let otherArtist = play(240, artist: "Other artist")
    let boundary = play(86400)
    let all = [boundary, otherArtist, noAlbum, old, otherTrack, first, second]
    let interval = DateInterval(start: start, duration: 86400)
    let song = RankedEntity(track: "Song", artist: "Artist", artworkURL: nil)
    let profile = try await analytics.entityProfile(all, entity: song, interval: interval, calendar: calendar)
    #expect(profile.stats.count == 3)
    #expect(profile.stats.firstScrobble == old.date)
    #expect(profile.items == [noAlbum, second, first])
    #expect(Set(profile.related.map(\.title)) == ["Album", "Compilation"])
    #expect(profile.related.allSatisfy { $0.kind == .albums && $0.count == 1 })
    #expect(profile.days.count == 1)
    #expect(profile.days.first?.items == profile.items)

    let album = RankedEntity(album: "Album", artist: "Artist")
    let albumProfile = try await analytics.entityProfile(all, entity: album, interval: interval, calendar: calendar)
    #expect(albumProfile.items == [otherTrack, first])
    #expect(Set(albumProfile.related.map(\.title)) == ["Song", "Other"])
    let artist = RankedEntity(artist: "Artist")
    let artistProfile = try await analytics.entityProfile(all, entity: artist, interval: interval, calendar: calendar)
    #expect(artistProfile.stats.count == 4)
    #expect(artistProfile.related.first?.count == 3)
    #expect(artist.matches(first) && !artist.matches(otherArtist))
    #expect(album.matches(first) && !album.matches(second))

    let empty = try await analytics.entityProfile([noAlbum], entity: song, interval: interval, calendar: calendar)
    #expect(empty.stats.count == 1 && empty.related.isEmpty)
    #expect(empty.items == [noAlbum])
}

@Test func cancelledEntityProfileDoesNotReturnResults() async {
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try await Analytics().entityProfile([], entity: RankedEntity(artist: "A"),
            interval: DateInterval(start: .now, duration: 1))
    }
    do {
        _ = try await task.value
        Issue.record("Cancelled profile calculation returned results")
    } catch { #expect(error is CancellationError) }
}

@Test func cachedInsightsRespectRevisionDayTimezoneAndFutureEvents() async throws {
    let analytics = Analytics()
    let calendar = utcCalendar()
    let day = calendar.date(from: DateComponents(year: 2026, month: 11, day: 16))!
    let now = day.addingTimeInterval(3600)
    let first = Scrobble(track: "First", artist: "A", album: "B", timestamp: Int(day.timeIntervalSince1970))
    let future = Scrobble(track: "Later", artist: "A", album: "B", timestamp: Int(now.timeIntervalSince1970) + 60)
    let initial = try await analytics.historyInsights([first, future], revision: 1, now: now, calendar: calendar)
    let repeated = try await analytics.historyInsights([first, future], revision: 1, now: now.addingTimeInterval(1), calendar: calendar)
    #expect(initial.daily.map(\.count) == [1])
    #expect(repeated.daily.map(\.count) == [1])
    let eligible = try await analytics.historyInsights([first, future], revision: 1, now: future.date, calendar: calendar)
    #expect(eligible.daily.map(\.count) == [2])
    let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
    let nextDay = try await analytics.historyInsights([first, future], revision: 1, now: tomorrow, calendar: calendar)
    #expect(nextDay.daily.map(\.count) == [2, 0])
    var shifted = calendar
    shifted.timeZone = TimeZone(secondsFromGMT: -7200)!
    let moved = try await analytics.historyInsights([first, future], revision: 1, now: tomorrow, calendar: shifted)
    #expect(moved.daily.first?.date == shifted.startOfDay(for: first.date))
    let changed = try await analytics.historyInsights([future], revision: 2, now: tomorrow, calendar: calendar)
    #expect(changed.daily.reduce(0) { $0 + $1.count } == 1)
    let disconnected = try await analytics.historyInsights([], revision: 3, now: tomorrow, calendar: calendar)
    #expect(disconnected.daily.isEmpty)
}

@Test func historyGroupingFiltersSortsAndRespectsDSTDayBoundary() async throws {
    let analytics = Analytics()
    var calendar = utcCalendar()
    calendar.timeZone = TimeZone(identifier: "Europe/Madrid")!
    let start = calendar.date(from: DateComponents(year: 2026, month: 10, day: 25))!
    let end = calendar.date(byAdding: .day, value: 1, to: start)!
    #expect(end.timeIntervalSince(start) == 25 * 3600)
    func play(_ date: Date, track: String, artist: String = "A", album: String = "B") -> Scrobble {
        Scrobble(track: track, artist: artist, album: album, timestamp: Int(date.timeIntervalSince1970))
    }
    let early = play(start, track: "Match")
    let late = play(end.addingTimeInterval(-1), track: "Other", album: "MATCH")
    let next = play(end, track: "Next", artist: "match")
    let items = [early, next, late]
    let filtered = try await analytics.historyGroups(items, search: "match", day: start, calendar: calendar)
    #expect(filtered.count == 1)
    #expect(filtered.first?.items == [late, early])
    let all = try await analytics.historyGroups(items, search: "match", day: nil, calendar: calendar)
    #expect(all.map(\.date) == [end, start])
    #expect(all.first?.items == [next])
    let none = try await analytics.historyGroups(items, search: "absent", day: nil, calendar: calendar)
    #expect(none.isEmpty)
    #expect(await analytics.historyIsUnchanged(items, previous: items))
    #expect(await !analytics.historyIsUnchanged(items, previous: [early, late]))
}
