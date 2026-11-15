import SwiftUI
import NextFMCore

struct HistoryView: View {
    @Environment(AppModel.self) private var model
    @State private var search = ""
    @State private var limit = 100
    @State private var filterDay = false
    @State private var selectedDay = Date.now
    private var filtered: [Scrobble] {
        model.history.filter { item in
            (!filterDay || Calendar.current.isDate(item.date, inSameDayAs: selectedDay)) &&
            (search.isEmpty || item.track.localizedCaseInsensitiveContains(search) || item.artist.localizedCaseInsensitiveContains(search) || item.album.localizedCaseInsensitiveContains(search))
        }
    }
    private var groups: [(date: Date, items: [Scrobble])] {
        Dictionary(grouping: filtered.prefix(limit)) { Calendar.current.startOfDay(for: $0.date) }
            .map { (date: $0.key, items: $0.value) }.sorted { $0.date > $1.date }
    }
    var body: some View {
        List {
            Section {
                CoverageNotice()
                Toggle("Filter by day", isOn: $filterDay)
                if filterDay { DatePicker("Date", selection: $selectedDay, in: ...Date.now, displayedComponents: .date) }
            }
            if filtered.isEmpty {
                ContentUnavailableView("No matching scrobbles", systemImage: "clock", description: Text("Try a different search or date."))
            }
            ForEach(groups, id: \.date) { group in
                Section {
                    ForEach(group.items) { ScrobbleRow(item: $0) }
                } header: { Text(group.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())) }
            }
            if filtered.count > limit {
                Button("Load older scrobbles") { limit += 100 }.frame(maxWidth: .infinity)
            }
            Section { SyncStatusView() }
        }.listStyle(.insetGrouped).navigationTitle("History")
            .searchable(text: $search, prompt: "Track, artist, or album")
            .refreshable { model.startSync() }
            .onChange(of: search) { _, _ in limit = 100 }
            .onChange(of: selectedDay) { _, _ in limit = 100 }
    }
}
