import SwiftUI
import NextFMCore

struct ListeningHighlights: View {
    @Environment(\.listeningDurations) private var durations
    let stats: DashboardStats
    let rangeTitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(title: "Your listening habits", subtitle: rangeTitle)
            HStack(alignment: .top, spacing: 10) {
                DashboardMetric(title: "longest day streak", value: stats.longestStreak.formatted(), detail: "Within this period")
                if let day = stats.busiestDay {
                    DashboardMetric(title: "busiest day", value: day.date.formatted(date: .abbreviated, time: .omitted),
                                    detail: scrobbleLabel(day.count, duration: durations.breakdown.days[day.date]))
                }
            }
        }
    }
}

struct MonthlyFavoritesSection: View {
    let months: [MonthlyFavorites]
    var body: some View {
        if !months.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    SectionHeading(title: "Monthly favorites", subtitle: "All imported history · current month so far")
                    NavigationLink("All") {
                        ScrollView {
                            LazyVStack(spacing: 16) { ForEach(months, id: \.month) { MonthlyListeningCard(month: $0) } }.padding(16)
                        }.navigationTitle("Monthly favorites").background(Theme.background)
                    }.font(.subheadline.bold())
                }
                ForEach(Array(months.prefix(3)), id: \.month) { MonthlyListeningCard(month: $0) }
            }
        }
    }
}

private struct MonthlyListeningCard: View {
    @Environment(AppModel.self) private var model
    let month: MonthlyFavorites

    var body: some View {
        let interval = Calendar.current.dateInterval(of: .month, for: month.month) ?? ListeningRange.lifetime.interval()
        MonthFavoritesCard(month: month)
            .listeningDurations(model.history, interval: interval, query: "month-\(model.revision)-\(month.month)")
    }
}

private struct MonthFavoritesCard: View {
    @Environment(\.listeningDurations) private var durations
    let month: MonthlyFavorites
    var body: some View {
        Surface {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(month.month.formatted(.dateTime.month(.wide).year())).font(.headline)
                    Spacer()
                    Text(scrobbleLabel(month.scrobbles, duration: durations.breakdown.total))
                        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
                }
                if let artist = month.artist { favorite(artist, label: "Artist") }
                if let album = month.album { favorite(album, label: "Album") }
                if let track = month.track { favorite(track, label: "Track") }
            }
        }
    }
    private func favorite(_ entity: RankedEntity, label: String) -> some View {
        NavigationLink { EntityDetailView(entity: entity) } label: {
            HStack(spacing: 10) {
                Artwork(url: entity.artworkURL, title: entity.title, size: 42, radius: entity.kind == .artists ? 21 : 7)
                VStack(alignment: .leading, spacing: 3) {
                    Text(label.uppercased()).font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.accent)
                    Text(entity.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary).lineLimit(1)
                    if entity.kind != .artists { Text(entity.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
                }
                Spacer(minLength: 0)
                RankedListeningLabel(entity: entity).font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
            }
        }.buttonStyle(.plain)
    }
}
