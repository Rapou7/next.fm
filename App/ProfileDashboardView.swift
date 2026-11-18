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
    @State private var displayedInterval: DateInterval?
    @State private var displayedQuery = ""
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
                        SummaryMetricsGrid(stats: stats)
                    }
                    .showcaseAnchor("metrics")
                    EnableListeningTime()
                    DurationLookupStatus()
                    if let historyInsights {
                        ScrobbleCalendar(days: historyInsights.daily).showcaseAnchor("calendar")
                    }
                    ListeningHighlights(stats: stats, rangeTitle: displayedRangeTitle)
                    DashboardShelf(title: "Top artists", entities: stats.topArtists).showcaseAnchor("artists")
                    DashboardShelf(title: "Top tracks", entities: stats.topTracks)
                    DashboardShelf(title: "Top albums", entities: stats.topAlbums)
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
                .listeningDurations(Array(model.history.prefix(8)), query: "recent-\(model.revision)")
                SyncStatusView()
            }.padding(.horizontal, 16).padding(.vertical, 16)
        }
        .listeningDurations(model.history, interval: displayedInterval ?? range.interval(),
                            query: displayedQuery, active: displayedInterval != nil && !isUpdating)
        .showcaseScrolling("Summary")
        .background(Theme.background)
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
                }
                .scrollContentBackground(.hidden)
                .background(Theme.background)
                .navigationTitle("Custom dates").navigationBarTitleDisplayMode(.inline)
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
                let result = try await model.analytics.historyInsights(model.history, revision: model.revision)
                guard !Task.isCancelled else { return }
                historyInsights = result
            } catch { /* A newer history revision replaces cancelled work. */ }
        }
        .task(id: "\(model.revision)-\(model.historyComplete)-\(range)-\(customStart)-\(customEnd)") {
            isUpdating = true
            let title = rangeTitle
            do {
                let interval = range.interval(customStart: customStart, customEnd: customEnd)
                let query = "\(model.revision)-\(range)-\(customStart)-\(customEnd)"
                let result = try await model.analytics.dashboard(model.history, interval: interval)
                guard !Task.isCancelled else { return }
                stats = result; displayedRangeTitle = title; isUpdating = false
                displayedInterval = interval; displayedQuery = query
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
                    if model.summary.streak > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(Theme.accent)
                                .accessibilityHidden(true)
                            Text("\(Text("\(model.summary.streak.formatted())-day").foregroundStyle(Theme.accent)) streak")
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .font(.subheadline.weight(.semibold))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Current listening streak: \(model.summary.streak) days")
                    }
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
            } else if let item = model.history.first {
                NavigationLink {
                    EntityDetailView(entity: RankedEntity(track: item.track, artist: item.artist, artworkURL: item.artworkURL))
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
                if model.nowPlaying != nil || model.history.first != nil {
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }
            }.contentShape(Rectangle())
    }

}

private struct DashboardShelf: View {
    @Environment(\.listeningDurations) private var durations
    let title: String
    let entities: [RankedEntity]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            NavigationLink {
                DashboardRankingView(title: title, entities: entities)
                    .environment(\.listeningDurations, durations)
            } label: {
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
                                RankedListeningLabel(entity: entity).font(.caption).foregroundStyle(.secondary)
                            }.frame(width: 108, alignment: .leading)
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct SummaryMetricsGrid: View {
    @Environment(\.listeningDurations) private var durations
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption) private var tileHeight: CGFloat = 84
    let stats: DashboardStats

    private var estimate: EstimatedDuration { durations.breakdown.total }

    private func estimatedValue(unit: Double, precision: Int) -> String {
        guard estimate.covered > 0 else { return "—" }
        let value = Double(estimate.milliseconds) / unit
        return value.formatted(.number.precision(.fractionLength(0...precision)))
    }

    private var mostActiveHour: String {
        guard let peak = stats.hours.max(by: { $0.count < $1.count }), peak.count > 0 else { return "—" }
        return String(format: "%02d:00", peak.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 8), count: 3), spacing: 8) {
                tile("Scrobbles", stats.count.formatted())
                tile("Minutes", estimatedValue(unit: 60_000, precision: 0))
                tile("Hours", estimatedValue(unit: 3_600_000, precision: 1))

                tile("Tracks", stats.tracks.formatted())
                tile("Artists", stats.artists.formatted())
                tile("Albums", stats.albums.formatted())

                tile("Days scrobbled", stats.activeDays.formatted(),
                     detail: "\(stats.daysScrobbledPercentage.formatted(.number.precision(.fractionLength(2))))% of \(stats.calendarDays.formatted()) days")
                tile("Scrobbles per day", stats.average.formatted(.number.precision(.fractionLength(1))))
                tile("Most active hour", mostActiveHour)
            }
            if durations.enabled, stats.count > 0 {
                Text("Time estimates · \(estimate.covered.formatted()) of \(stats.count.formatted()) scrobbles matched")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func tile(_ title: String, _ value: String, detail: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(.title3, design: .rounded).bold())
                .monospacedDigit().foregroundStyle(Theme.accent)
                .lineLimit(1).minimumScaleFactor(0.55)
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2).minimumScaleFactor(0.75)
            if let detail {
                Text(detail)
                    .font(.caption2).foregroundStyle(.secondary)
                    .lineLimit(2).minimumScaleFactor(0.85)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .frame(maxWidth: .infinity, minHeight: tileHeight, maxHeight: tileHeight, alignment: .topLeading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
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
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
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
        }.background(Theme.background).navigationTitle(title)
    }
}
