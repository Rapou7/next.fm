import SwiftUI
import NextFMCore

struct TopRankCard: View {
    let entity: RankedEntity
    let rank: Int
    let lastRank: Int
    @ScaledMetric(relativeTo: .body) private var artworkSize = 46

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Text("#\(lastRank)").hidden()
                Text("#\(rank)")
                    .accessibilityLabel("Rank \(rank)")
            }
            .font(.system(.headline, design: .rounded).bold())
            .monospacedDigit().foregroundStyle(.primary)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .frame(minWidth: 38)
            HStack(spacing: 10) {
                Artwork(url: entity.artworkURL, title: entity.title, size: min(72, artworkSize), radius: entity.kind == .artists ? 24 : 6)
                VStack(alignment: .leading, spacing: 3) {
                    Text(entity.title).font(.subheadline.bold()).foregroundStyle(.primary).lineLimit(1)
                    if entity.kind != .artists {
                        Text(entity.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    RankedListeningLabel(entity: entity)
                        .font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .padding(9)
            .background(Theme.surface.opacity(0.65), in: RoundedRectangle(cornerRadius: 17))
        }.accessibilityElement(children: .combine)
    }
}
