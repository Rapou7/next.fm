import SwiftUI
import NextFMCore

struct TopsView: View {
    @Environment(AppModel.self) private var model
    @State private var kind: EntityKind = .tracks
    @State private var range: ListeningRange = .fourWeeks
    @State private var customStart = Calendar.current.date(byAdding: .month, value: -1, to: Date.now)!
    @State private var customEnd = Date.now
    @State private var showDates = false
    @State private var rankings: [RankedEntity] = []
    @State private var loading = true
    @State private var visibleCount = 100
    private var queryID: String { "\(model.revision)-\(kind)-\(range)-\(customStart)-\(customEnd)" }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                Picker("Rank by", selection: $kind) {
                    ForEach(EntityKind.allCases) { kind in Text(kind.rawValue).tag(kind) }
                }.pickerStyle(.segmented)
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your top \(kind.rawValue.lowercased())").font(.title2.bold())
                        Text(range == .custom ? "\(customStart.formatted(date: .abbreviated, time: .omitted)) – \(customEnd.formatted(date: .abbreviated, time: .omitted))" : rangeLabel(range))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("SCROBBLES").font(.system(size: 9, weight: .bold)).tracking(1).foregroundStyle(.secondary)
                }.padding(.top, 12)
                CoverageNotice()
                if loading { ProgressView().frame(maxWidth: .infinity).padding(30) }
                else if rankings.isEmpty {
                    ContentUnavailableView("No scrobbles in this range", systemImage: "chart.bar", description: Text("Choose another range or continue importing your history."))
                } else {
                    if let first = rankings.first { TopSpotlight(entity: first) }
                    ForEach(Array(rankings.prefix(visibleCount).enumerated()), id: \.element.id) { index, entity in
                        NavigationLink { EntityDetailView(entity: entity) } label: {
                            RankingRow(entity: entity, rank: index + 1, maximum: rankings.first?.count ?? 1)
                        }.buttonStyle(.plain)
                        Divider()
                    }
                    if rankings.count > visibleCount {
                        Button("Show more") { visibleCount += 100 }.frame(maxWidth: .infinity)
                    }
                }
            }.padding(20)
        }.background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Tops")
            .safeAreaInset(edge: .bottom) { rangeBar }
            .sheet(isPresented: $showDates) {
                NavigationStack {
                    Form {
                        DatePicker("From", selection: $customStart, in: ...Date.now, displayedComponents: .date)
                        DatePicker("Through", selection: $customEnd, in: customStart...max(customStart, Date.now), displayedComponents: .date)
                        Text("Both dates are included, using your device's timezone.").font(.caption).foregroundStyle(.secondary)
                    }.navigationTitle("Custom dates").navigationBarTitleDisplayMode(.inline)
                        .onChange(of: customStart) { _, start in if customEnd < start { customEnd = start } }
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Apply") { range = .custom; showDates = false } } }
                }.presentationDetents([.medium])
            }
            .task(id: queryID) {
                loading = true
                let results = await model.analytics.ranking(model.history, kind: kind,
                    interval: range.interval(customStart: customStart, customEnd: customEnd))
                guard !Task.isCancelled else { return }
                rankings = results; visibleCount = 100; loading = false
            }
    }
    private var rangeBar: some View {
        HStack(spacing: 4) {
            ForEach([ListeningRange.fourWeeks, .sixMonths, .lifetime]) { option in
                Button { range = option } label: {
                    Text(option.rawValue).font(.caption.weight(.semibold)).padding(.vertical, 12).frame(maxWidth: .infinity)
                        .foregroundStyle(range == option ? Color.white : Color.primary)
                        .background { if range == option { Capsule().fill(Theme.accent) } }
                }.buttonStyle(.plain)
            }
            Menu {
                ForEach([ListeningRange.today, .thisWeek, .thisYear]) { option in
                    Button(rangeLabel(option)) { range = option }
                }
                Divider()
                Button("Custom dates…", systemImage: "calendar") { showDates = true }
            } label: {
                Image(systemName: "chevron.down").font(.subheadline.bold()).frame(width: 40, height: 40)
                    .foregroundStyle([.today, .thisWeek, .thisYear, .custom].contains(range) ? Theme.accent : Color.primary)
            }.accessibilityLabel("More time ranges")
        }.padding(6).glassEffect(.regular, in: .capsule).padding(.horizontal, 20).padding(.bottom, 8)
    }
    private func rangeLabel(_ range: ListeningRange) -> String {
        range == .thisYear ? String(Calendar.current.component(.year, from: .now)) : range.rawValue
    }
}

struct TopSpotlight: View {
    let entity: RankedEntity
    var body: some View {
        NavigationLink { EntityDetailView(entity: entity) } label: {
            HStack(spacing: 18) {
                Artwork(url: entity.artworkURL, title: entity.title, size: 94, radius: 18)
                VStack(alignment: .leading, spacing: 7) {
                    Label("THE TOP SPOT", systemImage: "crown.fill").font(.caption2.bold()).tracking(1).foregroundStyle(Theme.accent)
                    Text(entity.title).font(.title3.bold()).foregroundStyle(.primary).lineLimit(2)
                    Text(entity.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    Text("\(entity.count.formatted()) scrobbles").font(.caption.bold()).foregroundStyle(.primary)
                }
                Spacer(minLength: 0)
            }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 26))
        }.buttonStyle(.plain)
    }
}
