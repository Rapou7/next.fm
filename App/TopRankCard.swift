import SwiftUI
import NextFMCore

struct TopRankCard: View {
    let entity: RankedEntity
    let rank: Int
    @ScaledMetric(relativeTo: .body) private var artworkSize = 46

    var body: some View {
        HStack(spacing: 10) {
            Text("#\(rank)")
                .font(.system(.headline, design: .rounded).bold())
                .monospacedDigit().foregroundStyle(.primary)
                .frame(width: 38, alignment: .center)
                .accessibilityLabel("Rank \(rank)")
            HStack(spacing: 10) {
                Artwork(url: entity.artworkURL, title: entity.title, size: min(72, artworkSize), radius: entity.kind == .artists ? 24 : 6)
                VStack(alignment: .leading, spacing: 3) {
                    Text(entity.title).font(.subheadline.bold()).foregroundStyle(.primary).lineLimit(1)
                    Text(entity.kind == .artists
                         ? "\(entity.count.formatted()) scrobbles"
                         : "\(entity.count.formatted()) scrobbles · \(entity.subtitle)")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .padding(9)
            .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.65), in: RoundedRectangle(cornerRadius: 17))
        }.accessibilityElement(children: .combine)
    }
}
