import SwiftUI
import NextFMCore

struct LibraryView: View {
    @Environment(AppModel.self) private var model
    @State private var kind: EntityKind = .albums
    @State private var search = ""
    @State private var entities: [RankedEntity] = []
    @State private var limit = 100
    private var filtered: [RankedEntity] {
        search.isEmpty ? entities : entities.filter { $0.title.localizedCaseInsensitiveContains(search) || $0.subtitle.localizedCaseInsensitiveContains(search) }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Picker("Browse", selection: $kind) {
                    ForEach(EntityKind.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented)
                SectionHeading(title: "Made of your music.", subtitle: "\(filtered.count.formatted()) \(kind.rawValue.lowercased()) in your imported history")
                CoverageNotice()
                if filtered.isEmpty {
                    ContentUnavailableView.search(text: search)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 18)], alignment: .leading, spacing: 24) {
                        ForEach(Array(filtered.prefix(limit))) { entity in
                            NavigationLink { EntityDetailView(entity: entity) } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    GeometryReader { proxy in
                                        Artwork(url: entity.artworkURL, title: entity.title, size: proxy.size.width, radius: kind == .artists ? proxy.size.width / 2 : 20)
                                    }.aspectRatio(1, contentMode: .fit)
                                    Text(entity.title).font(.subheadline.bold()).foregroundStyle(.primary).lineLimit(1)
                                    Text(kind == .artists ? "\(entity.count.formatted()) scrobbles" : entity.subtitle)
                                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                            }.buttonStyle(.plain)
                        }
                    }
                    if filtered.count > limit { Button("Show more") { limit += 100 }.frame(maxWidth: .infinity) }
                }
            }.padding(20)
        }.background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Library").searchable(text: $search, prompt: "Find your music")
            .onChange(of: search) { _, _ in limit = 100 }
            .task(id: "\(model.revision)-\(kind)") {
                let results = await model.analytics.ranking(model.history, kind: kind, interval: nil)
                guard !Task.isCancelled else { return }
                entities = results; limit = 100
            }
    }
}

struct EntityDetailView: View {
    @Environment(AppModel.self) private var model
    let entity: RankedEntity
    @State private var items: [Scrobble] = []
    @State private var summary = StatsEngine.summary([])
    @State private var tracks: [RankedEntity] = []
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(spacing: 16) {
                    Artwork(url: entity.artworkURL, title: entity.title, size: 210, radius: entity.kind == .artists ? 105 : 28)
                        .shadow(color: .black.opacity(0.15), radius: 24, y: 12)
                    Text(entity.title).font(.title.bold()).multilineTextAlignment(.center)
                    Text(entity.subtitle).foregroundStyle(.secondary)
                    Text("\(items.count.formatted()) lifetime scrobbles").font(.headline).foregroundStyle(Theme.accent)
                    CoverageNotice()
                }.frame(maxWidth: .infinity).padding(.vertical, 12)
                Surface {
                    VStack(alignment: .leading, spacing: 20) {
                        SectionHeading(title: "The last 4 weeks")
                        ActivityChart(days: summary.days)
                    }
                }
                if let first = items.last, let last = items.first {
                    Surface {
                        VStack(spacing: 14) {
                            LabeledContent("First scrobble", value: first.date.formatted(date: .abbreviated, time: .omitted))
                            LabeledContent("Most recent", value: last.date.formatted(date: .abbreviated, time: .omitted))
                        }.font(.subheadline)
                    }
                }
                if entity.kind != .tracks && !tracks.isEmpty {
                    SectionHeading(title: "Essential tracks", subtitle: "Your most scrobbled")
                    ForEach(Array(tracks.prefix(10).enumerated()), id: \.element.id) { index, track in
                        NavigationLink { EntityDetailView(entity: track) } label: {
                            RankingRow(entity: track, rank: index + 1, maximum: tracks.first?.count ?? 1)
                        }.buttonStyle(.plain)
                    }
                }
                SectionHeading(title: "Recent listening")
                ForEach(Array(items.prefix(20))) { ScrobbleRow(item: $0) }
            }.padding(20)
        }.background(Color(uiColor: .systemGroupedBackground)).navigationBarTitleDisplayMode(.inline)
            .task(id: model.revision) {
                items = model.history.filter { entity.matches($0) }
                summary = await model.analytics.summary(items)
                tracks = await model.analytics.ranking(items, kind: .tracks, interval: nil)
            }
    }
}
