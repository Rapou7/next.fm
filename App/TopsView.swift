import SwiftUI
import NextFMCore

struct TopsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var kind: EntityKind = .tracks
    @State private var range: ListeningRange = .fourWeeks
    @State private var customStart = Calendar.current.date(byAdding: .month, value: -1, to: Date.now)!
    @State private var customEnd = Date.now
    @State private var showDates = false
    @State private var draftStart = Date.now
    @State private var draftEnd = Date.now
    private var queryID: String { "\(model.revision)-\(range)-\(customStart.timeIntervalSince1970)-\(customEnd.timeIntervalSince1970)" }
    var body: some View {
        VStack(spacing: 8) {
                HStack(spacing: 0) {
                    ForEach(EntityKind.allCases) { option in
                        Button {
                            withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) { kind = option }
                        } label: {
                            VStack(spacing: 12) {
                                Text(option.rawValue).font(.subheadline.bold())
                                    .foregroundStyle(kind == option ? Theme.accent : Color.primary)
                                Capsule().fill(kind == option ? Theme.accent : Color.clear).frame(height: 3)
                            }.padding(.top, 12).frame(maxWidth: .infinity).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                            .accessibilityAddTraits(kind == option ? .isSelected : [])
                    }
                }.padding(.horizontal, 16)
                CoverageNotice().frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16)
                // Each page owns its vertical scroll position and cached ranking.
                // The pager fills the available screen, with the range controls outside it.
                TabView(selection: $kind) {
                    ForEach(EntityKind.allCases) { category in
                        TopsRankingPage(kind: category, queryID: queryID,
                            interval: range.interval(customStart: customStart, customEnd: customEnd),
                            isActive: category == kind)
                            .tag(category)
                    }
                }.tabViewStyle(.page(indexDisplayMode: .never))
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
                TimeRangeBar(selection: $range) {
                    draftStart = customStart; draftEnd = customEnd; showDates = true
                }
                    .padding(.horizontal, 20).padding(.bottom, 8)
            }
            .sheet(isPresented: $showDates) {
                NavigationStack {
                    Form {
                        DatePicker("From", selection: $draftStart, in: ...Date.now, displayedComponents: .date)
                        DatePicker("Through", selection: $draftEnd, in: draftStart...max(draftStart, Date.now), displayedComponents: .date)
                        Text("Both dates are included, using your device's timezone.").font(.caption).foregroundStyle(.secondary)
                    }.navigationTitle("Custom dates").navigationBarTitleDisplayMode(.inline)
                        .onChange(of: draftStart) { _, start in if draftEnd < start { draftEnd = start } }
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showDates = false } }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Apply") {
                                    customStart = draftStart; customEnd = draftEnd
                                    range = .custom; showDates = false
                                }
                            }
                        }
                }.presentationDetents([.medium])
            }
            #if DEBUG
            .onReceive(NotificationCenter.default.publisher(for: .init("nextfm.showcase.kind"))) { notification in
                if let name = notification.object as? String, let option = EntityKind.allCases.first(where: { $0.rawValue == name }) {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.6)) { kind = option }
                }
            }
            #endif
            .sensoryFeedback(.selection, trigger: kind)
    }
    private func rangeLabel(_ range: ListeningRange) -> String {
        range == .thisYear ? String(Calendar.current.component(.year, from: .now)) : range.rawValue
    }
}

private struct TopsRankingPage: View {
    @Environment(AppModel.self) private var model
    let kind: EntityKind
    let queryID: String
    let interval: DateInterval
    let isActive: Bool
    @State private var rankings: [RankedEntity] = []
    @State private var loadedQueryID: String?
    @State private var visibleCount = 100

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if loadedQueryID != queryID {
                    ProgressView("Loading \(kind.rawValue.lowercased())…")
                        .frame(maxWidth: .infinity).padding(30)
                } else if rankings.isEmpty {
                    ContentUnavailableView("No scrobbles in this range", systemImage: "chart.bar",
                        description: Text("Choose another range or continue importing your history."))
                } else {
                    ForEach(Array(rankings.prefix(visibleCount).enumerated()), id: \.element.id) { index, entity in
                        NavigationLink { EntityDetailView(entity: entity) } label: {
                            TopRankCard(entity: entity, rank: index + 1)
                        }.buttonStyle(.plain).showcaseAnchor("rank.\(index)")
                    }
                    if rankings.count > visibleCount {
                        Button("Show more") { visibleCount += 100 }
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
            }.padding(.horizontal, 16).padding(.bottom, 16)
        }
        .showcaseScrolling("Tops")
        .id(queryID)
        .task(id: "\(queryID)-\(isActive)") {
            // Adjacent native pages are preloaded. Only calculate the visible one,
            // and reuse its result on return until the data or range changes.
            guard isActive, loadedQueryID != queryID else { return }
            let requestedQuery = queryID
            let results = await model.analytics.ranking(model.history, kind: kind, interval: interval)
            guard !Task.isCancelled else { return }
            rankings = results; visibleCount = 100; loadedQueryID = requestedQuery
        }
    }
}
