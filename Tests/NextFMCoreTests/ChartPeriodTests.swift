import Foundation
import Testing
@testable import NextFMCore

@Test func chartPeriodsPreserveEveryDayAndTotals() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Madrid")!
    let start = calendar.date(from: DateComponents(year: 2020, month: 1, day: 1))!
    let days = (0..<4001).map {
        ActivityDay(date: calendar.date(byAdding: .day, value: $0, to: start)!, count: $0 % 7)
    }
    let periods = StatsEngine.chartPeriods(days, calendar: calendar)
    #expect(periods.count == days.count)
    #expect(periods.map(\.count) == days.map(\.count))
    #expect(periods.first?.start == start)
    #expect(periods.last?.end == calendar.date(byAdding: .day, value: 4001, to: start))
    #expect(periods.reduce(0) { $0 + $1.count } == days.reduce(0) { $0 + $1.count })
    #expect(periods.last?.cumulative == days.reduce(0) { $0 + $1.count })
    for index in 1..<periods.count {
        #expect(periods[index - 1].end == periods[index].start)
    }
    let short = StatsEngine.chartPeriods(Array(days.prefix(28)), calendar: calendar)
    #expect(short.map(\.count) == days.prefix(28).map(\.count))
    #expect(StatsEngine.chartPeriods([], calendar: calendar).isEmpty)
}
