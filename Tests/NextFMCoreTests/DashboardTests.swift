import Foundation
import Testing
@testable import NextFMCore

@Test func dashboardCountsAndCumulativeAgreeWithScrobbles() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let start = Date(timeIntervalSince1970: 1_789_344_000)
    let items = (0..<3).map { index in
        Scrobble(track: "Song \(index)", artist: "Artist", album: "Album",
                 timestamp: Int(start.timeIntervalSince1970) + index * 86_400 + 3600)
    }
    let interval = DateInterval(start: start, end: start.addingTimeInterval(4 * 86_400))
    let stats = StatsEngine.dashboard(items, interval: interval, calendar: calendar)
    #expect(stats.count == 3)
    #expect(stats.tracks == 3)
    #expect(stats.artists == 1)
    #expect(stats.activeDays == 3)
    #expect(stats.calendarDays == 4)
    #expect(stats.average == 0.75)
    #expect(stats.cumulative.last?.count == 3)
    #expect(stats.hours.reduce(0) { $0 + $1.count } == 3)
    #expect(stats.weekdays.reduce(0) { $0 + $1.count } == 3)
    #expect(stats.months.reduce(0) { $0 + $1.count } == 3)
    #expect(stats.years.reduce(0) { $0 + $1.count } == 3)
}

@Test func emptyLifetimeHasNoPhantomHistory() {
    let stats = StatsEngine.dashboard([], interval: ListeningRange.lifetime.interval())
    #expect(stats.count == 0)
    #expect(stats.daily.count <= 1)
    #expect(stats.average == 0)
    #expect(stats.topTracks.isEmpty)
}
