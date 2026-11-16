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
    #expect(stats.firstScrobble == nil)
    #expect(stats.daysScrobbledPercentage == 0)
    #expect(!stats.showMonthlyChart)
    #expect(!stats.showYearlyChart)
}

private func statsCalendar(_ zone: String = "UTC") -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: zone)!
    return calendar
}

private func statsDate(_ year: Int, _ month: Int, _ day: Int, calendar: Calendar = statsCalendar()) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day))!
}

private func statsPlay(_ date: Date, track: String = "Song", artist: String = "Artist", album: String = "Album") -> Scrobble {
    Scrobble(track: track, artist: artist, album: album, timestamp: Int(date.timeIntervalSince1970))
}

@Test func daysScrobbledPercentageClipsOnlyBeforeAccountHistory() {
    let items = [statsPlay(statsDate(2026, 11, 3)), statsPlay(statsDate(2026, 11, 5))]
    let stats = StatsEngine.dashboard(items,
        interval: DateInterval(start: statsDate(2026, 11, 1), end: statsDate(2026, 11, 7)), calendar: statsCalendar())
    #expect(stats.calendarDays == 4) // Nov 3–6 inclusive, not Nov 1–6.
    #expect(stats.activeDays == 2)
    #expect(stats.daysScrobbledPercentage == 50)
    #expect(stats.firstScrobble == statsDate(2026, 11, 3))

    let quietStart = StatsEngine.dashboard(items,
        interval: DateInterval(start: statsDate(2026, 11, 4), end: statsDate(2026, 11, 7)), calendar: statsCalendar())
    #expect(quietStart.calendarDays == 3) // The silent Nov 4 is included.
    #expect(quietStart.activeDays == 1)
    #expect(quietStart.firstScrobble == statsDate(2026, 11, 3))
}

@Test func monthsRemainChronologicalAcrossYearsAndFillSilentMonths() {
    let items = [statsPlay(statsDate(2025, 12, 10)), statsPlay(statsDate(2026, 2, 1))]
    let stats = StatsEngine.dashboard(items,
        interval: DateInterval(start: statsDate(2025, 12, 1), end: statsDate(2026, 3, 1)), calendar: statsCalendar())
    #expect(stats.months.map(\.id) == [202512, 202601, 202602])
    #expect(stats.months.map(\.label) == ["Dec 2025", "Jan 2026", "Feb 2026"])
    #expect(stats.months.map(\.count) == [1, 0, 1])
    #expect(stats.showMonthlyChart)
    #expect(!stats.showYearlyChart)
}

@Test func fourWeekRangeDoesNotShowMonthlyOrYearlyChartsEvenAcrossNewYear() {
    let items = [statsPlay(statsDate(2025, 12, 20)), statsPlay(statsDate(2026, 1, 10))]
    let stats = StatsEngine.dashboard(items,
        interval: DateInterval(start: statsDate(2025, 12, 20), end: statsDate(2026, 1, 17)), calendar: statsCalendar())
    #expect(stats.calendarDays == 28)
    #expect(stats.months.count == 2)
    #expect(stats.years.count == 2)
    #expect(!stats.showMonthlyChart)
    #expect(!stats.showYearlyChart)
    let lifetime = StatsEngine.dashboard(items,
        interval: DateInterval(start: Date(timeIntervalSince1970: 0), end: statsDate(2027, 1, 1)), calendar: statsCalendar())
    #expect(lifetime.showYearlyChart)
}

@Test func monthlyFavoritesRespectSelectedDaysAndEntityIdentity() {
    let items = [
        statsPlay(statsDate(2026, 1, 1), artist: "Before range"),
        statsPlay(statsDate(2026, 1, 2), artist: "Before range"),
        statsPlay(statsDate(2026, 1, 20), track: "Favorite", artist: "Selected artist"),
        statsPlay(statsDate(2026, 1, 21), track: "Favorite", artist: "Selected artist"),
        statsPlay(statsDate(2026, 2, 1), track: "New favorite", artist: "February artist", album: "")
    ]
    let stats = StatsEngine.dashboard(items,
        interval: DateInterval(start: statsDate(2026, 1, 15), end: statsDate(2026, 2, 2)), calendar: statsCalendar())
    #expect(stats.monthlyFavorites.count == 2)
    #expect(stats.monthlyFavorites[0].month == statsDate(2026, 2, 1))
    #expect(stats.monthlyFavorites[0].album == nil)
    #expect(stats.monthlyFavorites[1].artist?.title == "Selected artist")
    #expect(stats.monthlyFavorites[1].track?.title == "Favorite")
    #expect(stats.monthlyFavorites[1].track?.count == 2)
}

@Test func dashboardStreakAndPercentageUseCalendarDaysAcrossDST() {
    let calendar = statsCalendar("Europe/Madrid")
    let items = (28...30).map { statsPlay(statsDate(2026, 3, $0, calendar: calendar)) }
    let stats = StatsEngine.dashboard(items,
        interval: DateInterval(start: statsDate(2026, 3, 28, calendar: calendar), end: statsDate(2026, 4, 1, calendar: calendar)), calendar: calendar)
    #expect(stats.calendarDays == 4)
    #expect(stats.daysScrobbledPercentage == 75)
    #expect(stats.longestStreak == 3)
    #expect(stats.busiestDay?.count == 1)
}

@Test func rangeBeforeFirstScrobbleHasZeroEligibleDays() {
    let stats = StatsEngine.dashboard([statsPlay(statsDate(2026, 11, 10))],
        interval: DateInterval(start: statsDate(2026, 11, 1), end: statsDate(2026, 11, 5)), calendar: statsCalendar())
    #expect(stats.calendarDays == 0)
    #expect(stats.daysScrobbledPercentage == 0)
    #expect(stats.monthlyFavorites.isEmpty)
    #expect(stats.busiestDay == nil)
}
