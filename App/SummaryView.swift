import SwiftUI
import Charts
import NextFMCore

struct SummaryView: View {
    @Environment(AppModel.self) private var model
    @State private var favorite: RankedEntity?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                NowPlayingCard()
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("YOUR LAST 4 WEEKS").font(.caption.weight(.bold)).tracking(1.6).foregroundStyle(.secondary)
                        Text("A rhythm of your own.").font(.title2.bold())
                    }
                    Spacer()
                }
                CoverageNotice()
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    MetricCard(title: "Scrobbles", value: model.summary.total, icon: "waveform", color: Theme.accent)
                    MetricCard(title: "Artists", value: model.summary.uniqueArtists, icon: "person.2.fill", color: Theme.violet)
                    MetricCard(title: "Albums", value: model.summary.uniqueAlbums, icon: "square.stack.fill", color: Theme.mint)
                    MetricCard(title: "Day streak", value: model.summary.streak, icon: "flame.fill", color: .orange)
                }
                Surface {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Listening activity").font(.headline)
                                Text("\(model.summary.activeDays) active days in the last 28").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chart.bar.fill").foregroundStyle(Theme.accent)
                        }
                        ActivityChart(days: model.summary.days)
                        if model.historyComplete && model.summary.previousTotal > 0 {
                            let change = (Double(model.summary.total) / Double(model.summary.previousTotal) - 1) * 100
                            Label("\(abs(change).formatted(.number.precision(.fractionLength(0))))% \(change >= 0 ? "more" : "fewer") scrobbles than the previous 4 weeks",
                                  systemImage: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                        }
                    }
                }
                if let favorite {
                    NavigationLink { EntityDetailView(entity: favorite) } label: {
                        Surface {
                            HStack(spacing: 18) {
                                Artwork(url: favorite.artworkURL, title: favorite.title, size: 100, radius: 18)
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("ON REPEAT").font(.caption2.bold()).tracking(1.5).foregroundStyle(Theme.accent)
                                    Text(favorite.title).font(.headline).foregroundStyle(.primary).lineLimit(2)
                                    Text(favorite.subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                                    Text("\(favorite.count.formatted()) scrobbles · 4 weeks").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                            }
                        }
                    }.buttonStyle(.plain)
                }
                if !model.history.isEmpty {
                    SectionHeading(title: "Recently played", subtitle: "The soundtrack, as it happened.")
                    Surface {
                        VStack(spacing: 12) {
                            ForEach(Array(model.history.prefix(5))) { item in ScrobbleRow(item: item) }
                        }
                    }
                } else if !model.isSyncing {
                    ContentUnavailableView("Your music starts here", systemImage: "music.note", description: Text("Refresh to load your Last.fm scrobbles."))
                }
                SyncStatusView()
            }.padding(.horizontal, 20).padding(.vertical, 16)
        }.background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Summary")
            .refreshable { model.startSync() }
            .task(id: model.revision) {
                favorite = await model.analytics.ranking(model.history, kind: .albums, interval: ListeningRange.fourWeeks.interval()).first
            }
    }
}

struct NowPlayingCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var track: String { model.nowPlaying?.track ?? model.history.first?.track ?? "Your next favorite awaits" }
    private var artist: String { model.nowPlaying?.artist ?? model.history.first?.artist ?? "Connect your listening history" }
    private var artwork: URL? {
        if let playing = model.nowPlaying { return playing.artworkURL }
        return model.history.first?.artworkURL
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 7) {
                    Image(systemName: model.nowPlaying == nil ? "clock" : "waveform")
                    Text(model.nowPlaying == nil ? "LAST PLAYED" : "CURRENTLY PLAYING").tracking(1.4)
                }.font(.caption2.bold()).padding(.horizontal, 12).padding(.vertical, 8)
                    .glassEffect(.regular, in: .capsule)
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 18))
                    : AnyLayout(HStackLayout(alignment: .center, spacing: 18))
                layout {
                    Artwork(url: artwork, title: track, size: 104, radius: 16)
                        .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(track).font(.title3.bold()).fixedSize(horizontal: false, vertical: true)
                        Text(artist).font(.subheadline).foregroundStyle(.white.opacity(0.72))
                            .fixedSize(horizontal: false, vertical: true)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 244, alignment: .leading)
        .background {
            // Artwork must not participate in the card's size calculation. A loaded
            // scaled-to-fill image can otherwise push foreground content out of bounds.
            GeometryReader { geometry in
                ZStack {
                    LinearGradient(colors: [Color(red: 0.28, green: 0.12, blue: 0.23), Color(red: 0.09, green: 0.08, blue: 0.18)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    if let artwork {
                        AsyncImage(url: artwork) { image in image.resizable().scaledToFill() } placeholder: { Color.clear }
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .blur(radius: 36).opacity(0.55).overlay(.black.opacity(0.25))
                    }
                }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 30)).foregroundStyle(.white)
            .environment(\.colorScheme, .dark)
            .accessibilityElement(children: .combine)
    }
}

struct MetricCard: View {
    let title: String
    let value: Int
    let icon: String
    let color: Color
    var body: some View {
        Surface {
            VStack(alignment: .leading, spacing: 13) {
                Image(systemName: icon).font(.headline).foregroundStyle(color)
                Text(value.formatted()).font(.system(size: 31, weight: .bold, design: .rounded)).minimumScaleFactor(0.6).lineLimit(1)
                Text(title).font(.subheadline).foregroundStyle(.secondary)
            }
        }.accessibilityElement(children: .combine)
    }
}

struct ActivityChart: View {
    let days: [ActivityDay]
    @State private var selectedDate: Date?
    private var selected: ActivityDay? {
        guard let selectedDate else { return nil }
        return days.first { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let selected {
                Text("\(selected.date.formatted(date: .abbreviated, time: .omitted)) · \(selected.count) scrobbles")
                    .font(.caption.monospacedDigit()).foregroundStyle(Theme.accent)
            }
            Chart(days) { day in
                BarMark(x: .value("Day", day.date, unit: .day), y: .value("Scrobbles", day.count))
                    .foregroundStyle(Theme.accent.gradient).cornerRadius(3)
                if let selected, selected.id == day.id {
                    RuleMark(x: .value("Selected day", selected.date, unit: .day)).foregroundStyle(.secondary.opacity(0.5))
                }
            }
            .chartXSelection(value: $selectedDate)
            .chartXAxis { AxisMarks(values: .stride(by: .day, count: 7)) { _ in AxisValueLabel(format: .dateTime.day().month(.abbreviated)) } }
            .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) }
            .frame(height: 170)
        }
    }
}

struct SyncStatusView: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if model.isSyncing { ProgressView(value: model.syncProgress).tint(Theme.accent) }
            HStack {
                Label(model.syncMessage, systemImage: model.isSyncing ? "arrow.down.circle" : "checkmark.circle")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                if !model.isDemo {
                    Button(model.isSyncing ? "Pause" : "Refresh") {
                        if model.isSyncing { model.stopSync() } else { model.startSync() }
                    }.font(.caption.bold())
                }
            }
            if let error = model.errorMessage { Text(error).font(.caption).foregroundStyle(Theme.accent) }
        }.padding(.bottom, 12)
    }
}
