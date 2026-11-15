import Foundation
import Testing
@testable import NextFMCore

private func calendar() -> Calendar {
    var result = Calendar(identifier: .gregorian)
    result.timeZone = TimeZone(identifier: "Europe/Madrid")!
    result.firstWeekday = 2
    return result
}
private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
    calendar().date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
}
private func play(_ title: String = "Song", artist: String = "Artist", album: String = "Album", at date: Date) -> Scrobble {
    Scrobble(track: title, artist: artist, album: album, timestamp: Int(date.timeIntervalSince1970))
}

@Test func rankingUsesScrobblesAndSeparatesArtists() {
    let now = date(2026, 11, 15)
    let items = [play(at: now), play(at: now.addingTimeInterval(-200)), play(artist: "Other", at: now)]
    let tops = StatsEngine.ranking(items, kind: .tracks)
    #expect(tops.count == 2)
    #expect(tops[0].count == 2)
    #expect(tops[0].subtitle == "Artist")
}

@Test func missingAlbumsDoNotBecomeRankedAlbums() {
    let items = [play(album: "", at: .now), play(album: "  ", at: .now), play(at: .now)]
    #expect(StatsEngine.ranking(items, kind: .albums).count == 1)
    #expect(StatsEngine.ranking(items, kind: .tracks)[0].count == 3)
}

@Test func customDatesAreInclusiveAndDSTSafe() {
    let range = ListeningRange.custom.interval(calendar: calendar(), customStart: date(2026, 3, 29), customEnd: date(2026, 3, 29))
    #expect(range.duration == 23 * 3600)
    let items = [play(at: range.start), play(at: range.end.addingTimeInterval(-1)), play(at: range.end)]
    #expect(StatsEngine.filter(items, interval: range).count == 2)
}

@Test func fourWeeksMeansTwentyEightCalendarDays() {
    let now = date(2026, 11, 15)
    let range = ListeningRange.fourWeeks.interval(now: now, calendar: calendar())
    #expect(calendar().dateComponents([.day], from: range.start, to: calendar().startOfDay(for: now)).day == 27)
}

@Test func streakCrossesDaylightSavingAndAllowsTodayToBeEmpty() {
    let items = [play(at: date(2026, 3, 28)), play(at: date(2026, 3, 29)), play(at: date(2026, 3, 30))]
    let summary = StatsEngine.summary(items, now: date(2026, 3, 31), calendar: calendar())
    #expect(summary.streak == 3)
    #expect(summary.days.count == 28)
    #expect(summary.total == 3)
}

@Test func rankingFiltersBeforeAggregating() {
    let now = date(2026, 11, 15)
    let items = [play(at: now), play("Old favorite", at: date(2025, 1, 1))]
    let ranking = StatsEngine.ranking(items, kind: .tracks, interval: ListeningRange.today.interval(now: now, calendar: calendar()))
    #expect(ranking.count == 1)
    #expect(ranking.first?.title == "Song")
}

@Test func summarySeparatesPreviousPeriod() {
    let now = date(2026, 11, 15)
    let items = [play(at: now), play(at: date(2026, 10, 10)), play(at: date(2025, 1, 1))]
    let summary = StatsEngine.summary(items, now: now, calendar: calendar())
    #expect(summary.total == 1)
    #expect(summary.previousTotal == 1)
}
