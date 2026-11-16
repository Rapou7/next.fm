import Foundation
import Testing
@testable import NextFMCore

private func utcCalendar() -> Calendar {
    var result = Calendar(identifier: .gregorian)
    result.timeZone = TimeZone(secondsFromGMT: 0)!
    return result
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
