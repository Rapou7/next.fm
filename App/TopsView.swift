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
            LazyVStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 0) {
                    ForEach(EntityKind.allCases) { option in
                        Button { kind = option } label: {
                            VStack(spacing: 12) {
                                Text(option.rawValue).font(.subheadline.bold())
                                    .foregroundStyle(kind == option ? Theme.accent : Color.primary)
                                Capsule().fill(kind == option ? Theme.accent : Color.clear).frame(height: 3)
                            }.padding(.top, 12).frame(maxWidth: .infinity).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                            .accessibilityAddTraits(kind == option ? .isSelected : [])
                    }
                }
                CoverageNotice()
                if loading { ProgressView().frame(maxWidth: .infinity).padding(30) }
                else if rankings.isEmpty {
                    ContentUnavailableView("No scrobbles in this range", systemImage: "chart.bar", description: Text("Choose another range or continue importing your history."))
                } else {
                    ForEach(Array(rankings.prefix(visibleCount).enumerated()), id: \.element.id) { index, entity in
                        NavigationLink { EntityDetailView(entity: entity) } label: {
                            TopRankCard(entity: entity, rank: index + 1)
                        }.buttonStyle(.plain)
                    }
                    if rankings.count > visibleCount {
                        Button("Show more") { visibleCount += 100 }.frame(maxWidth: .infinity)
                    }
                }
            }.padding(.horizontal, 16).padding(.bottom, 16)
        }.background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Tops")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text("Tops").font(.headline)
                        Text(range == .custom ? "Custom dates" : rangeLabel(range))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                TimeRangeBar(selection: $range) { showDates = true }
                    .padding(.horizontal, 20).padding(.bottom, 8)
            }
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
    private func rangeLabel(_ range: ListeningRange) -> String {
        range == .thisYear ? String(Calendar.current.component(.year, from: .now)) : range.rawValue
    }
}
