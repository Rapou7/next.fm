import SwiftUI
import NextFMCore

struct SummaryView: View {
    @Environment(AppModel.self) private var model
    @State private var range: ListeningRange = .fourWeeks
    @State private var customStart = Calendar.current.date(byAdding: .month, value: -1, to: Date.now)!
    @State private var customEnd = Date.now
    @State private var showDates = false
    @State private var stats: DashboardStats?
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                profileHeader
                compactPlaying
                CoverageNotice()
                if let stats {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeading(title: "Listening stats")
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            DashboardMetric(title: "scrobbles", value: stats.count.formatted())
                            DashboardMetric(title: "different tracks", value: stats.tracks.formatted())
                            DashboardMetric(title: "different artists", value: stats.artists.formatted())
                            DashboardMetric(title: "different albums", value: stats.albums.formatted())
                            DashboardMetric(title: "days listened", value: stats.activeDays.formatted())
                            DashboardMetric(title: "scrobbles per day", value: stats.average.formatted(.number.precision(.fractionLength(1))))
                        }
                    }
                    musicShelf("Top artists", entities: stats.topArtists)
                    musicShelf("Top tracks", entities: stats.topTracks)
                    musicShelf("Top albums", entities: stats.topAlbums)
                    ListeningCharts(stats: stats)
                } else { ProgressView().frame(maxWidth: .infinity).padding() }
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeading(title: "Recently played")
                    ForEach(Array(model.history.prefix(8))) { item in ScrobbleRow(item: item) }
                }
                SyncStatusView()
            }.padding(.horizontal, 16).padding(.vertical, 16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Summary")
        .refreshable { model.startSync() }
        .safeAreaInset(edge: .bottom) {
            TimeRangeBar(selection: $range) { showDates = true }
                .padding(.horizontal, 16).padding(.bottom, 8)
        }
        .sheet(isPresented: $showDates) {
            NavigationStack {
                Form {
                    DatePicker("From", selection: $customStart, in: ...Date.now, displayedComponents: .date)
                    DatePicker("Through", selection: $customEnd, in: customStart...max(customStart, Date.now), displayedComponents: .date)
                }.navigationTitle("Custom dates").navigationBarTitleDisplayMode(.inline)
                    .onChange(of: customStart) { _, start in if customEnd < start { customEnd = start } }
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Apply") { range = .custom; showDates = false } } }
            }.presentationDetents([.medium])
        }
        .task(id: "\(model.revision)-\(range)-\(customStart)-\(customEnd)") {
            stats = nil
            let result = await model.analytics.dashboard(model.history,
                interval: range.interval(customStart: customStart, customEnd: customEnd))
            guard !Task.isCancelled else { return }
            stats = result
        }
    }

    private var profileHeader: some View {
        HStack(spacing: 16) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 54)).foregroundStyle(Theme.accent.gradient)
            VStack(alignment: .leading, spacing: 4) {
                Text(model.isDemo ? "Your listening" : model.username).font(.title.bold())
                Text(rangeTitle).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }.padding(.vertical, 8)
    }

    private var rangeTitle: String {
        if range == .custom { return "\(customStart.formatted(date: .abbreviated, time: .omitted)) – \(customEnd.formatted(date: .abbreviated, time: .omitted))" }
        if range == .thisYear { return String(Calendar.current.component(.year, from: .now)) }
        return range.rawValue
    }

    private var compactPlaying: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(model.nowPlaying == nil ? "Last played" : "Currently playing",
                  systemImage: model.nowPlaying == nil ? "clock" : "waveform")
                .font(.title3.bold())
            let item = model.history.first
            HStack(spacing: 12) {
                Artwork(url: model.nowPlaying != nil ? model.nowPlaying?.artworkURL : item?.artworkURL,
                        title: model.nowPlaying?.track ?? item?.track ?? "Music", size: 56, radius: 9)
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.nowPlaying?.track ?? item?.track ?? "Your next favorite awaits")
                        .font(.headline).fixedSize(horizontal: false, vertical: true)
                    Text(model.nowPlaying?.artist ?? item?.artist ?? "Your history will appear here")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func musicShelf(_ title: String, entities: [RankedEntity]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            NavigationLink { DashboardRankingView(title: title, entities: entities) } label: {
                HStack {
                    Text(title).font(.title2.bold()).foregroundStyle(.primary)
                    Spacer()
                    Text("Top 10").font(.subheadline.weight(.semibold))
                }
            }.buttonStyle(.plain)
            if entities.isEmpty { Text("No scrobbles in this range").font(.subheadline).foregroundStyle(.secondary) }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(Array(entities.enumerated()), id: \.element.id) { index, entity in
                        NavigationLink { EntityDetailView(entity: entity) } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Artwork(url: entity.artworkURL, title: entity.title, size: 108, radius: entity.kind == .artists ? 54 : 12)
                                Text("\(index + 1). \(entity.title)").font(.subheadline.bold()).foregroundStyle(.primary).lineLimit(1)
                                Text("\(entity.count.formatted()) scrobbles").font(.caption).foregroundStyle(.secondary)
                            }.frame(width: 108, alignment: .leading)
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct DashboardMetric: View {
    let title: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value).font(.system(.title, design: .rounded).bold()).foregroundStyle(Theme.accent)
                .lineLimit(1).minimumScaleFactor(0.65)
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
        }.frame(maxWidth: .infinity, minHeight: 68, alignment: .leading).padding(16)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
            .accessibilityElement(children: .combine)
    }
}

private struct DashboardRankingView: View {
    let title: String
    let entities: [RankedEntity]
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(Array(entities.enumerated()), id: \.element.id) { index, entity in
                    NavigationLink { EntityDetailView(entity: entity) } label: {
                        TopRankCard(entity: entity, rank: index + 1)
                    }.buttonStyle(.plain)
                }
            }.padding(16)
        }.background(Color(uiColor: .systemGroupedBackground)).navigationTitle(title)
    }
}
