import SwiftUI
import NextFMCore

struct LibraryView: View {
    @Environment(AppModel.self) private var model
    @State private var kind: EntityKind = .albums
    @State private var search = ""
    @State private var entities: [RankedEntity] = []
    @State private var limit = 100
    @State private var loadedKind: EntityKind?

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
                if loadedKind != kind {
                    ProgressView("Loading \(kind.rawValue.lowercased())…")
                        .frame(maxWidth: .infinity).padding(40)
                } else if filtered.isEmpty {
                    if search.isEmpty {
                        ContentUnavailableView("No \(kind.rawValue.lowercased()) in library", systemImage: kind.icon,
                            description: Text("Continue importing your history or listen to more music."))
                    } else {
                        ContentUnavailableView.search(text: search)
                    }
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 18)], alignment: .leading, spacing: 24) {
                        ForEach(Array(filtered.prefix(limit).enumerated()), id: \.element.id) { index, entity in
                            NavigationLink { EntityDetailView(entity: entity) } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    GeometryReader { proxy in
                                        Artwork(url: entity.artworkURL, title: entity.title, size: proxy.size.width, radius: kind == .artists ? proxy.size.width / 2 : 20)
                                    }.aspectRatio(1, contentMode: .fit)
                                    Text(entity.title).font(.subheadline.bold()).foregroundStyle(.primary).lineLimit(1)
                                    Text(kind == .artists ? "\(entity.count.formatted()) scrobbles" : entity.subtitle)
                                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                            }.buttonStyle(.plain).showcaseAnchor("library.\(index)")
                        }
                    }
                    .id(kind)
                    if filtered.count > limit { Button("Show more") { limit += 100 }.frame(maxWidth: .infinity) }
                }
            }.padding(20)
        }.showcaseScrolling("Library").background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Library").searchable(text: $search, prompt: "Find your music")
            .onChange(of: search) { _, _ in limit = 100 }
            .onChange(of: kind) { _, _ in
                limit = 100
                loadedKind = nil
            }
            .task(id: "\(model.revision)-\(kind)") {
                loadedKind = nil
                let requested = kind
                let results = await model.analytics.ranking(model.history, kind: requested, interval: nil)
                guard !Task.isCancelled else { return }
                entities = results; limit = 100; loadedKind = requested
            }
    }
}

struct EntityDetailView: View {
    let entity: RankedEntity

    var body: some View {
        ArtistProfileView(entity: entity)
    }
}
