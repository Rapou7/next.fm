import SwiftUI
import NextFMCore

struct HistoryView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var search = ""
    @State private var limit = 30
    @State private var expandedDays: Set<Date> = []
    @State private var filterDay = false
    @State private var selectedDay = Date.now

    private var groups: [(date: Date, items: [Scrobble])] {
        let filtered = model.history.filter { item in
            (!filterDay || Calendar.current.isDate(item.date, inSameDayAs: selectedDay)) &&
            (search.isEmpty || item.track.localizedCaseInsensitiveContains(search) || item.artist.localizedCaseInsensitiveContains(search) || item.album.localizedCaseInsensitiveContains(search))
        }
        return Dictionary(grouping: filtered) { Calendar.current.startOfDay(for: $0.date) }
            .map { (date: $0.key, items: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        let days = groups
        List {
            Section {
                CoverageNotice()
                Toggle("Filter by day", isOn: $filterDay)
                if filterDay { DatePicker("Date", selection: $selectedDay, in: ...Date.now, displayedComponents: .date) }
            }
            if days.isEmpty {
                ContentUnavailableView("No matching scrobbles", systemImage: "clock", description: Text("Try a different search or date."))
            }
            ForEach(days.prefix(limit), id: \.date) { group in
                Section {
                    Button {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                            if expandedDays.contains(group.date) {
                                expandedDays.remove(group.date)
                            } else {
                                expandedDays.insert(group.date)
                            }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(dayTitle(group.date)).font(.subheadline.bold())
                                    .foregroundStyle(.primary)
                                Text("\(group.items.count.formatted()) scrobbles")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.semibold))
                                .rotationEffect(.degrees(expandedDays.contains(group.date) ? 180 : 0))
                                .foregroundStyle(.secondary)
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(expandedDays.contains(group.date) ? "Expanded" : "Collapsed")
                    .accessibilityHint("Show or hide this day's scrobbles")
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                    if expandedDays.contains(group.date) {
                        ForEach(group.items) { item in
                            HistoryTrackRow(item: item)
                                .listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 16))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }
                    }
                }
            }
            if days.count > limit {
                Button("Load older days") { limit += 30 }.frame(maxWidth: .infinity)
            }
            Section { SyncStatusView() }
        }
        .listStyle(.plain)
        .navigationTitle("History")
        .searchable(text: $search, prompt: "Track, artist, or album")
        .refreshable { model.startSync() }
        .onChange(of: search) { _, _ in limit = 30 }
        .onChange(of: selectedDay) { _, _ in limit = 30 }
        .onChange(of: filterDay) { _, _ in limit = 30 }
    }

    private func dayTitle(_ date: Date) -> String {
        let formatted = date.formatted(.dateTime.weekday(.wide).month(.wide).day().year())
        if Calendar.current.isDateInToday(date) { return "Today (\(formatted))" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday (\(formatted))" }
        return formatted
    }
}

private struct HistoryTrackRow: View {
    let item: Scrobble

    var body: some View {
        HStack(spacing: 10) {
            Artwork(url: item.artworkURL, title: item.album, size: 40, radius: 8)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.track).font(.subheadline.weight(.semibold)).lineLimit(2)
                Text(item.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 4)
            Text(item.date, style: .time).font(.caption).foregroundStyle(.secondary)
                .fixedSize()
        }
        .padding(10)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}
