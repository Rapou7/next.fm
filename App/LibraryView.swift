import SwiftUI
import NextFMCore

struct LibraryView: View {
    @Environment(AppModel.self) private var model
    @State private var kind: EntityKind = .albums
    @State private var search = ""
    @State private var entities: [RankedEntity] = []
    @State private var limit = 100
    @State private var loadedQuery: Query?

    private struct Query: Equatable {
        let revision: Int
        let kind: EntityKind
    }
    private var query: Query { Query(revision: model.revision, kind: kind) }

    private var filtered: [RankedEntity] {
        search.isEmpty ? entities : entities.filter { $0.title.localizedCaseInsensitiveContains(search) || $0.subtitle.localizedCaseInsensitiveContains(search) }
    }
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Picker("Browse", selection: $kind) {
                        ForEach(EntityKind.allCases) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.segmented).id("library.top")
                    SectionHeading(title: "Made of your music.", subtitle: loadedQuery == query
                        ? "\(filtered.count.formatted()) \(kind.rawValue.lowercased()) in your imported history"
                        : "Your imported listening history")
                    CoverageNotice()
                    if loadedQuery != query {
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
                    proxy.scrollTo("library.top", anchor: .top)
                }
                .task(id: query) {
                    let requested = query
                    let results = await model.analytics.ranking(model.history, kind: requested.kind, interval: nil)
                    guard !Task.isCancelled, requested == query else { return }
                    entities = results; limit = 100; loadedQuery = requested
                }
        }
    }
}

struct EntityDetailView: View {
    let entity: RankedEntity

    var body: some View {
        ArtistProfileView(entity: entity)
            .id("\(entity.kind)-\(entity.id)")
    }
}
