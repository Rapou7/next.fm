import SwiftUI
import NextFMCore

struct HistoryView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var search = ""
    @State private var limit = 30
    @State private var expandedDays: Set<Date> = []
    @State private var selectedDay: Date?
    @State private var dateDraft = Date.now
    @State private var showsDatePicker = false

    @State private var groups: [HistoryDay] = []
    @State private var isLoading = true
    private struct Query: Equatable {
        let revision: Int
        let search: String
        let day: Date?
        let calendar: Calendar
    }
    private var query: Query {
        Query(revision: model.revision, search: search,
              day: selectedDay, calendar: .current)
    }

    var body: some View {
        let days = groups
        List {
            Section {
                CoverageNotice()
            }
            if isLoading { ProgressView("Loading history") }
            if days.isEmpty && !isLoading {
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
        #if DEBUG
        .onReceive(NotificationCenter.default.publisher(for: .init("nextfm.showcase.history"))) { _ in
            if let first = days.first {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.7)) { expandedDays.insert(first.date) }
            }
        }
        #endif
        .listStyle(.plain)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("History")
        .safeAreaInset(edge: .top, spacing: 0) {
            historySearchBar
        }
        .sheet(isPresented: $showsDatePicker) {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 16) {
                        DatePicker("Date", selection: $dateDraft, in: ...Date.now, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                        Button("Show all history") {
                            selectedDay = nil
                            showsDatePicker = false
                        }
                        .frame(minHeight: 44)
                    }
                    .padding()
                }
                .navigationTitle("Select date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showsDatePicker = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            let day = Calendar.current.startOfDay(for: dateDraft)
                            expandedDays.insert(day)
                            selectedDay = day
                            showsDatePicker = false
                        }
                    }
                }
            }
            .tint(Theme.accent)
        }
        .refreshable { model.startSync() }
        .task(id: query) {
            isLoading = true
            groups = []
            let request = query
            do {
                if !request.search.isEmpty { try await Task.sleep(for: .milliseconds(200)) }
                let result = try await model.analytics.historyGroups(model.history, search: request.search,
                    day: request.day, calendar: request.calendar)
                try Task.checkCancellation()
                groups = result; isLoading = false
            } catch { if !Task.isCancelled { isLoading = false } }
        }
        .onChange(of: search) { _, _ in limit = 30 }
        .onChange(of: selectedDay) { _, _ in limit = 30 }
    }

    private var historySearchBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    dateDraft = selectedDay ?? .now
                    showsDatePicker = true
                } label: {
                    Image(systemName: "calendar")
                        .font(.title3)
                        .foregroundStyle(Theme.accent)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Select date")
                .accessibilityValue(selectedDay?.formatted(date: .complete, time: .omitted) ?? "All history")

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    TextField("Track, artist, or album", text: $search)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .accessibilityLabel("Search history")
                    if !search.isEmpty {
                        Button {
                            search = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding(.leading, 12)
                .padding(.trailing, search.isEmpty ? 12 : 0)
                .frame(minHeight: 44)
                .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
            }
            if let selectedDay {
                Button {
                    self.selectedDay = nil
                } label: {
                    Label(selectedDay.formatted(date: .abbreviated, time: .omitted), systemImage: "xmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(Theme.accent)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear selected date, \(selectedDay.formatted(date: .complete, time: .omitted))")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func dayTitle(_ date: Date) -> String {
        let formatted = date.formatted(.dateTime.weekday(.wide).month(.wide).day().year())
        if Calendar.current.isDateInToday(date) { return "Today (\(formatted))" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday (\(formatted))" }
        return formatted
    }
}

struct HistoryTrackRow: View {
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
