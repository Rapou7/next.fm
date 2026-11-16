import SwiftUI
import NextFMCore

struct SummaryView: View {
    @Environment(AppModel.self) private var model
    @State private var range: ListeningRange = .fourWeeks
    @State private var customStart = Calendar.current.date(byAdding: .month, value: -1, to: Date.now)!
    @State private var customEnd = Date.now
    @State private var showDates = false
    @State private var draftStart = Date.now
    @State private var draftEnd = Date.now
    @State private var stats: DashboardStats?
    @State private var historyInsights: HistoryInsights?
    @State private var displayedRangeTitle = "4 weeks"
    @State private var isUpdating = false
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                profileHeader.showcaseAnchor("hero")
                compactPlaying
                CoverageNotice()
                if let stats {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            SectionHeading(title: "Listening stats", subtitle: displayedRangeTitle)
                            if isUpdating { ProgressView().accessibilityLabel("Updating statistics") }
                        }
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            DashboardMetric(title: "scrobbles", value: stats.count.formatted())
                            DashboardMetric(title: "different tracks", value: stats.tracks.formatted())
                            DashboardMetric(title: "different artists", value: stats.artists.formatted())
                            DashboardMetric(title: "different albums", value: stats.albums.formatted())
                            DashboardMetric(title: "days scrobbled", value: stats.activeDays.formatted(),
                                            detail: "\(stats.daysScrobbledPercentage.formatted(.number.precision(.fractionLength(2))))% of \(stats.calendarDays.formatted()) days")
                            DashboardMetric(title: "scrobbles per day", value: stats.average.formatted(.number.precision(.fractionLength(1))))
                        }
                    }
                    .showcaseAnchor("metrics")
                    if let historyInsights {
                        ScrobbleCalendar(days: historyInsights.daily).showcaseAnchor("calendar")
                    }
                    ListeningHighlights(stats: stats, rangeTitle: displayedRangeTitle)
                    musicShelf("Top artists", entities: stats.topArtists).showcaseAnchor("artists")
                    musicShelf("Top tracks", entities: stats.topTracks)
                    musicShelf("Top albums", entities: stats.topAlbums)
                    ListeningCharts(stats: stats).showcaseAnchor("charts")
                    if let historyInsights {
                        MonthlyFavoritesSection(months: historyInsights.monthlyFavorites).showcaseAnchor("favorites")
                    }
                } else { ProgressView().frame(maxWidth: .infinity).padding() }
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeading(title: "Recently played")
                    ForEach(Array(model.history.prefix(8))) { item in
                        NavigationLink {
                            EntityDetailView(entity: RankedEntity(track: item.track, artist: item.artist, artworkURL: item.artworkURL))
                        } label: {
                            HStack(spacing: 8) {
                                ScrobbleRow(item: item)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            }.contentShape(Rectangle())
                        }.buttonStyle(.plain)
                            .accessibilityHint("Show song listening details")
                    }
                }
                SyncStatusView()
            }.padding(.horizontal, 16).padding(.vertical, 16)
        }
        .showcaseScrolling("Summary")
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Summary")
        .refreshable { model.startSync() }
        .safeAreaInset(edge: .bottom) {
            TimeRangeBar(selection: $range) {
                draftStart = customStart; draftEnd = customEnd; showDates = true
            }
                .padding(.horizontal, 16).padding(.bottom, 8)
        }
        .sheet(isPresented: $showDates) {
            NavigationStack {
                Form {
                    DatePicker("From", selection: $draftStart, in: ...Date.now, displayedComponents: .date)
                    DatePicker("Through", selection: $draftEnd, in: draftStart...max(draftStart, Date.now), displayedComponents: .date)
                }.navigationTitle("Custom dates").navigationBarTitleDisplayMode(.inline)
                    .onChange(of: draftStart) { _, start in if draftEnd < start { draftEnd = start } }
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showDates = false } }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Apply") { customStart = draftStart; customEnd = draftEnd; range = .custom; showDates = false }
                        }
                    }
            }.presentationDetents([.medium])
        }
        .task(id: model.revision) {
            do {
                let result = try await model.analytics.historyInsights(model.history)
                guard !Task.isCancelled else { return }
                historyInsights = result
            } catch { /* A newer history revision replaces cancelled work. */ }
        }
        .task(id: "\(model.revision)-\(range)-\(customStart)-\(customEnd)") {
            isUpdating = true
            let title = rangeTitle
            do {
                let result = try await model.analytics.dashboard(model.history,
                    interval: range.interval(customStart: customStart, customEnd: customEnd))
                guard !Task.isCancelled else { return }
                stats = result; displayedRangeTitle = title; isUpdating = false
            } catch { if !Task.isCancelled { isUpdating = false } }
        }
    }

    private var profileHeader: some View {
        HStack(spacing: 16) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 54)).foregroundStyle(Theme.accent.gradient)
            VStack(alignment: .leading, spacing: 4) {
                Text(model.displayUsername).font(.title.bold())
                if let first = model.history.last?.date {
                    Text(model.historyComplete
                         ? "Scrobbling since \(first.formatted(date: .abbreviated, time: .omitted))"
                         : "History loaded since \(first.formatted(date: .abbreviated, time: .omitted))")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    Text("Finding your first scrobble…").font(.subheadline).foregroundStyle(.secondary)
                }
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
            HStack(spacing: 8) {
                if model.nowPlaying != nil { NowPlayingIndicator() }
                else { Image(systemName: "clock").foregroundStyle(.secondary) }
                Text(model.nowPlaying == nil ? "Last played" : "Currently playing")
            }.font(.title3.bold())
            if let playing = model.nowPlaying {
                NavigationLink {
                    EntityDetailView(entity: RankedEntity(track: playing.track, artist: playing.artist, artworkURL: playing.artworkURL))
                } label: { playingRow }.buttonStyle(.plain)
                    .accessibilityHint("Show song listening details")
            } else { playingRow }
        }
    }

    private var playingRow: some View {
            let item = model.history.first
            return HStack(spacing: 12) {
                Artwork(url: model.nowPlaying != nil ? model.nowPlaying?.artworkURL : item?.artworkURL,
                        title: model.nowPlaying?.track ?? item?.track ?? "Music", size: 56, radius: 9)
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.nowPlaying?.track ?? item?.track ?? "Your next favorite awaits")
                        .font(.headline).fixedSize(horizontal: false, vertical: true)
                    Text(model.nowPlaying?.artist ?? item?.artist ?? "Your history will appear here")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if model.nowPlaying != nil {
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }
            }.contentShape(Rectangle())
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
    var detail: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value).font(.system(.title2, design: .rounded).bold()).foregroundStyle(Theme.accent)
                .lineLimit(1).minimumScaleFactor(0.65)
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
            if let detail { Text(detail).font(.caption).foregroundStyle(.secondary) }
        }.frame(maxWidth: .infinity, minHeight: 54, alignment: .leading).padding(12)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
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
