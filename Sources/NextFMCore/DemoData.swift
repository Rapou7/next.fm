import Foundation

public enum DemoData {
    public static func scrobbles(now: Date = .now, calendar: Calendar = .current) -> [Scrobble] {
        let records = [
            ("Everything In Its Right Place", "Radiohead", "Kid A"),
            ("BIRDS OF A FEATHER", "Billie Eilish", "HIT ME HARD AND SOFT"),
            ("Nights", "Frank Ocean", "Blonde"),
            ("Instant Crush", "Daft Punk", "Random Access Memories"),
            ("My Love Mine All Mine", "Mitski", "The Land Is Inhospitable and So Are We"),
            ("Let It Happen", "Tame Impala", "Currents"),
            ("So Hot You're Hurting My Feelings", "Caroline Polachek", "Pang"),
            ("Space Song", "Beach House", "Depression Cherry")
        ]
        let today = calendar.startOfDay(for: now)
        var result: [Scrobble] = []
        for day in 0..<210 {
            let start = calendar.date(byAdding: .day, value: -day, to: today)!
            let count = day % 17 == 0 && day > 7 ? 0 : 8 + ((day * 13 + 19) % 54)
            for index in 0..<count {
                let record = records[(index * 3 + day + index / 7) % records.count]
                let date = start.addingTimeInterval(Double(8 * 3600 + index * 260))
                guard date <= now else { continue }
                result.append(Scrobble(track: record.0, artist: record.1, album: record.2, timestamp: Int(date.timeIntervalSince1970)))
            }
        }
        return result.sorted { $0.timestamp > $1.timestamp }
    }
}
