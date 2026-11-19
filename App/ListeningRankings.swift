import SwiftUI
import NextFMCore

enum ListeningRankingOrder: String {
    static let storageKey = "listeningRankingOrder"
    case scrobbles
    case time
}

struct ListeningRankings<Content: View>: View {
    @AppStorage(ListeningRankingOrder.storageKey) private var order = ListeningRankingOrder.scrobbles
    @Environment(AppModel.self) private var model
    @Environment(\.listeningDurations) private var durations

    let entries: [RankedEntity]
    let query: String
    var isActive = true
    @ViewBuilder let content: ([RankedEntity], ListeningRankingOrder) -> Content

    @State private var timedEntries: [RankedEntity] = []
    @State private var timedQuery: String?

    private struct Request: Equatable {
        let query: String
        let count: Int
        let covered: Int
        let useTime: Bool
        let isActive: Bool
    }

    var body: some View {
        let breakdown = durations.breakdown
        let useTime = order == .time && durations.enabled
        let hasTimeRanking = useTime && breakdown.total.covered > 0
            && timedQuery == query && timedEntries.count == entries.count
        let request = Request(query: query, count: entries.count, covered: breakdown.total.covered,
                              useTime: useTime, isActive: isActive)
        content(hasTimeRanking ? timedEntries : entries, hasTimeRanking ? .time : .scrobbles)
            .task(id: request) {
                guard isActive, useTime, request.covered > 0, !entries.isEmpty else { return }
                do {
                    let result = try await model.analytics.timeRanking(entries, durations: breakdown)
                    try Task.checkCancellation()
                    timedEntries = result
                    timedQuery = query
                } catch { /* A newer ranking request replaces cancelled work. */ }
            }
    }
}
