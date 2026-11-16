import SwiftUI
import NextFMCore

struct ArtistProfileView: View {
    @Environment(AppModel.self) private var model
    let entity: RankedEntity
    @State private var range: ListeningRange = .lifetime
    @State private var customStart = Calendar.current.date(byAdding: .month, value: -1, to: Date.now)!
    @State private var customEnd = Date.now
    @State private var draftStart = Date.now
    @State private var draftEnd = Date.now
    @State private var showDates = false
    @State private var showTracks = false
    @State private var stats: DashboardStats?
    @State private var tracks: [RankedEntity] = []
    @State private var items: [Scrobble] = []
    @State private var displayedRangeTitle = "Lifetime"
    @State private var isUpdating = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                VStack(spacing: 16) {
                    Artwork(url: entity.artworkURL, title: entity.title, size: 210, radius: entity.kind == .artists ? 105 : 28)
                        .shadow(color: .black.opacity(0.15), radius: 24, y: 12)
                    Text(entity.title).font(.largeTitle.bold()).multilineTextAlignment(.center)
                    if entity.kind == .artists {
                        Text("Your listening history").font(.subheadline).foregroundStyle(.secondary)
                    } else {
                        if !entity.subtitle.isEmpty {
                            NavigationLink {
                                EntityDetailView(entity: RankedEntity(artist: entity.subtitle, artworkURL: entity.artworkURL))
                            } label: {
                                HStack(spacing: 4) {
                                    Text(entity.subtitle)
                                    Image(systemName: "chevron.right").font(.caption.bold())
                                }
                                .font(.title3.weight(.medium))
                                .foregroundStyle(Theme.accent)
                            }
                            .buttonStyle(.plain)
                        }
                        Text("Your listening history").font(.subheadline).foregroundStyle(.secondary)
                    }
                }.frame(maxWidth: .infinity).padding(.vertical, 12)
                CoverageNotice()
                if let stats {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            SectionHeading(title: "Listening stats", subtitle: displayedRangeTitle)
                            if isUpdating { ProgressView().accessibilityLabel("Updating listening statistics") }
                        }
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            DashboardMetric(title: "scrobbles", value: stats.count.formatted())
                            if entity.kind == .artists {
                                DashboardMetric(title: "different tracks", value: stats.tracks.formatted())
                                DashboardMetric(title: "different albums", value: stats.albums.formatted())
                            } else if entity.kind == .albums {
                                DashboardMetric(title: "different tracks", value: stats.tracks.formatted())
                            } else if entity.kind == .tracks && stats.albums > 1 {
                                DashboardMetric(title: "different albums", value: stats.albums.formatted())
                            }
                            DashboardMetric(title: "scrobbles per day", value: stats.average.formatted(.number.precision(.fractionLength(1))))
                            DashboardMetric(title: "days scrobbled", value: stats.activeDays.formatted(),
                                            detail: "\(stats.daysScrobbledPercentage.formatted(.number.precision(.fractionLength(1))))% of \(stats.calendarDays.formatted()) days")
                            DashboardMetric(title: "longest day streak", value: stats.longestStreak.formatted(), detail: "Within this period")
                        }
                        if let first = items.last, let last = items.first {
                            Surface {
                                VStack(spacing: 14) {
                                    LabeledContent("First in this period", value: first.date.formatted(date: .abbreviated, time: .shortened))
                                    LabeledContent("Most recent", value: last.date.formatted(date: .abbreviated, time: .shortened))
                                }.font(.subheadline)
                            }
                        }
                    }
                    if items.isEmpty {
                        ContentUnavailableView("No listening in this range", systemImage: entity.kind.icon,
                                               description: Text("Choose another period to explore this \(entity.kind == .artists ? "artist" : (entity.kind == .albums ? "album" : "song"))."))
                    } else {
                        if !tracks.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                SectionHeading(
                                    title: entity.kind == .tracks ? "Albums" : (entity.kind == .albums ? "Essential tracks" : "Most scrobbled"),
                                    subtitle: entity.kind == .tracks ? "Appears on" : "Top songs · \(displayedRangeTitle)"
                                )
                                .padding(.bottom, 8)
                                ForEach(Array(tracks.prefix(3).enumerated()), id: \.element.id) { index, track in
                                    NavigationLink { EntityDetailView(entity: track) } label: {
                                        TopRankCard(entity: track, rank: index + 1)
                                    }.buttonStyle(.plain)
                                }
                                if tracks.count > 3 {
                                    Button { showTracks = true } label: {
                                        Label(entity.kind == .tracks ? "See all albums" : (entity.kind == .albums ? "See all album tracks" : "See all top songs"),
                                              systemImage: "arrow.up.left.and.arrow.down.right")
                                            .font(.subheadline.weight(.semibold))
                                            .frame(maxWidth: .infinity, minHeight: 44)
                                    }.buttonStyle(.glass).padding(.top, 8)
                                }
                            }
                        }
                        ArtistRecentListening(items: items)
                        ListeningCharts(stats: stats)
                    }
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding()
                }
            }.padding(16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(entity.title).navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            TimeRangeBar(selection: $range) {
                draftStart = customStart; draftEnd = customEnd; showDates = true
            }.padding(.horizontal, 16).padding(.bottom, 8)
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
        .fullScreenCover(isPresented: $showTracks) {
            ArtistTopSongsView(title: entity.title, rangeTitle: displayedRangeTitle, items: tracks, kind: entity.kind)
        }
        .task(id: "\(model.revision)-\(range)-\(customStart)-\(customEnd)") {
            isUpdating = true
            let title = rangeTitle
            let interval = range.interval(customStart: customStart, customEnd: customEnd)
            let entityItems = model.history.filter { entity.matches($0) }
            do {
                let result = try await model.analytics.dashboard(entityItems, interval: interval)
                let ranking = await model.analytics.ranking(entityItems, kind: entity.kind == .tracks ? .albums : .tracks, interval: interval)
                guard !Task.isCancelled else { return }
                items = StatsEngine.filter(entityItems, interval: interval).sorted { $0.date > $1.date }
                tracks = ranking
                stats = result
                displayedRangeTitle = title
                isUpdating = false
            } catch { if !Task.isCancelled { isUpdating = false } }
        }
    }

    private var rangeTitle: String {
        if range == .custom {
            return "\(customStart.formatted(date: .abbreviated, time: .omitted)) – \(customEnd.formatted(date: .abbreviated, time: .omitted))"
        }
        if range == .thisYear { return String(Calendar.current.component(.year, from: .now)) }
        if range == .lifetime && !model.historyComplete { return "All imported history" }
        return range.rawValue
    }
}

private struct ArtistTopSongsView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let rangeTitle: String
    let items: [RankedEntity]
    let kind: EntityKind
    @State private var limit = 100

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    SectionHeading(title: title, subtitle: "\(rangeTitle) · \(items.count.formatted()) \(kind == .tracks ? "albums" : "songs")")
                        .padding(.bottom, 12)
                    CoverageNotice()
                    ForEach(Array(items.prefix(limit).enumerated()), id: \.element.id) { index, item in
                        NavigationLink { EntityDetailView(entity: item) } label: {
                            TopRankCard(entity: item, rank: index + 1)
                        }.buttonStyle(.plain)
                    }
                    if items.count > limit {
                        Button("Show more \(kind == .tracks ? "albums" : "songs")") { limit += 100 }.frame(maxWidth: .infinity, minHeight: 44)
                    }
                }.padding(16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(kind == .tracks ? "Albums" : (kind == .albums ? "Album tracks" : "Top songs")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

private struct ArtistRecentListening: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let items: [Scrobble]
    @State private var expandedDays: Set<Date> = []
    @State private var limit = 7

    private var groups: [(date: Date, items: [Scrobble])] {
        Dictionary(grouping: items) { Calendar.current.startOfDay(for: $0.date) }
            .map { (date: $0.key, items: $0.value) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        let days = groups
        LazyVStack(alignment: .leading, spacing: 8) {
            SectionHeading(title: "Recent listening").padding(.bottom, 8)
            ForEach(days.prefix(limit), id: \.date) { group in
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                        if expandedDays.contains(group.date) { expandedDays.remove(group.date) }
                        else { expandedDays.insert(group.date) }
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(dayTitle(group.date)).font(.subheadline.bold()).foregroundStyle(.primary)
                            Text("\(group.items.count.formatted()) scrobbles").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.down").font(.caption.weight(.semibold))
                            .rotationEffect(.degrees(expandedDays.contains(group.date) ? 180 : 0))
                            .foregroundStyle(.secondary)
                    }.frame(minHeight: 44).contentShape(Rectangle())
                }.buttonStyle(.plain)
                    .accessibilityValue(expandedDays.contains(group.date) ? "Expanded" : "Collapsed")
                    .accessibilityHint("Show or hide this day's scrobbles")
                if expandedDays.contains(group.date) {
                    ForEach(group.items) { item in
                        NavigationLink {
                            EntityDetailView(entity: RankedEntity(track: item.track, artist: item.artist, artworkURL: item.artworkURL))
                        } label: { HistoryTrackRow(item: item) }.buttonStyle(.plain)
                    }
                }
            }
            if days.count > limit {
                Button("Load older days") { limit += 7 }.frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .onChange(of: items.map(\.id)) { _, _ in limit = 7; expandedDays = [] }
    }

    private func dayTitle(_ date: Date) -> String {
        let formatted = date.formatted(.dateTime.weekday(.wide).month(.wide).day().year())
        if Calendar.current.isDateInToday(date) { return "Today (\(formatted))" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday (\(formatted))" }
        return formatted
    }
}
