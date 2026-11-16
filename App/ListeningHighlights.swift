import SwiftUI
import NextFMCore

struct ListeningHighlights: View {
    let stats: DashboardStats
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(title: "Your listening habits")
            HStack(alignment: .top, spacing: 10) {
                DashboardMetric(title: "longest day streak", value: stats.longestStreak.formatted(), detail: "Within this period")
                if let day = stats.busiestDay {
                    DashboardMetric(title: "busiest day", value: day.count.formatted(), detail: day.date.formatted(date: .abbreviated, time: .omitted))
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
                    SectionHeading(title: "Monthly favorites", subtitle: "Most scrobbled within the selected range")
                    NavigationLink("All") {
                        ScrollView {
                            LazyVStack(spacing: 16) { ForEach(months, id: \.month) { MonthFavoritesCard(month: $0) } }.padding(16)
                        }.navigationTitle("Monthly favorites").background(Color(uiColor: .systemGroupedBackground))
                    }.font(.subheadline.bold())
                }
                ForEach(Array(months.prefix(3)), id: \.month) { MonthFavoritesCard(month: $0) }
            }
        }
    }
}

private struct MonthFavoritesCard: View {
    let month: MonthlyFavorites
    var body: some View {
        Surface {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(month.month.formatted(.dateTime.month(.wide).year())).font(.headline)
                    Spacer()
                    Text("\(month.scrobbles.formatted()) plays").font(.caption).foregroundStyle(.secondary)
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
                Text(entity.count.formatted()).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
            }
        }.buttonStyle(.plain)
    }
}
