import Foundation
import NextFMCore
import SwiftUI

private final class CatalogRedirectPolicy: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

private actor DurationCatalog {
    static let shared = DurationCatalog()
    private let session: URLSession
    private var retryAfter = Date.distantPast
    private var nextRequest = ContinuousClock.now
    private var busy = false

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false
        config.urlCache = nil
        config.timeoutIntervalForRequest = 15
        session = URLSession(configuration: config, delegate: CatalogRedirectPolicy(), delegateQueue: nil)
    }

    private struct Reply: Decodable {
        struct Entry: Decodable {
            let status: String
            let duration_ms: Int?
        }
        let results: [Entry]
    }

    func resolve(_ candidates: ArraySlice<CatalogTrack>, store: HistoryStore) async throws -> [CatalogTrack: CachedDuration] {
        while busy { try await Task.sleep(for: .milliseconds(100)) }
        try Task.checkCancellation()
        busy = true
        defer { busy = false }
        let tracks = Array(candidates.prefix(100))
        let cached = try await store.cachedDurations(for: tracks)
        let pending = tracks.filter { cached[$0] == nil }
        guard !pending.isEmpty else { return cached }
        guard Date.now >= retryAfter else { throw URLError(.resourceUnavailable) }
        try await ContinuousClock().sleep(until: nextRequest)
        defer { nextRequest = ContinuousClock.now.advanced(by: .milliseconds(650)) }
        let results = try await lookup(pending)
        try await store.saveDurations(results)
        return cached.merging(results) { _, latest in latest }
    }

    private func lookup(_ batch: [CatalogTrack]) async throws -> [CatalogTrack: CachedDuration] {
        let body = try JSONEncoder().encode(batch)
        guard body.count <= 65536 else {
            if batch.count == 1 { return [batch[0]: CachedDuration(milliseconds: nil)] }
            let split = batch.count / 2
            // The caller advances by a full batch, so resolve both halves.
            let first = try await lookup(Array(batch[..<split]))
            try await Task.sleep(for: .milliseconds(650))
            let second = try await lookup(Array(batch[split...]))
            return first.merging(second) { _, latest in latest }
        }
        var request = URLRequest(url: URL(string: "https://nextfm.panxo.eu.org/v1/durations")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if http.statusCode == 429 || http.statusCode == 503 {
            let delay = Double(http.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 30
            retryAfter = Date.now.addingTimeInterval(max(1, min(86400, delay)))
        }
        guard http.statusCode == 200, data.count <= 65536 else { throw URLError(.badServerResponse) }
        let entries = try JSONDecoder().decode(Reply.self, from: data).results
        guard entries.count == batch.count else { throw URLError(.cannotParseResponse) }
        var result: [CatalogTrack: CachedDuration] = [:]
        for (track, entry) in zip(batch, entries) {
            switch entry.status {
            case "matched":
                guard let ms = entry.duration_ms, ms > 0, ms <= Int(UInt32.max) else {
                    throw URLError(.cannotParseResponse)
                }
                result[track] = CachedDuration(milliseconds: ms)
            case "missing", "invalid", "ambiguous":
                result[track] = CachedDuration(milliseconds: nil)
            default: throw URLError(.cannotParseResponse)
            }
        }
        return result
    }
}

struct ListeningDurationState {
    var breakdown = DurationBreakdown()
    var enabled = false
    var loading = false
    var unavailable = false
    var retry: () -> Void = {}
}

private struct ListeningDurationKey: EnvironmentKey {
    static var defaultValue: ListeningDurationState { ListeningDurationState() }
}

extension EnvironmentValues {
    var listeningDurations: ListeningDurationState {
        get { self[ListeningDurationKey.self] }
        set { self[ListeningDurationKey.self] = newValue }
    }
}

private struct ListeningDurationScope: ViewModifier {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("durationLookupsEnabled") private var enabled = false
    let history: [Scrobble]
    let interval: DateInterval
    let query: String
    let active: Bool
    let fetchMissing: Bool
    @State private var snapshot = ListeningDurationState()
    @State private var loadedQuery: String?
    @State private var attempt = 0

    func body(content: Content) -> some View {
        let show = enabled && !model.isDemo
        var state = show && loadedQuery == query ? snapshot : ListeningDurationState()
        state.enabled = show
        state.retry = { attempt += 1 }
        return content
            .environment(\.listeningDurations, state)
            .task(id: "\(query)-\(show)-\(active)-\(scenePhase)-\(attempt)") {
                guard show, active, scenePhase == .active, let store = model.store else { return }
                do {
                    var plan = try await store.durationPlan(history: history, interval: interval)
                    try Task.checkCancellation()
                    loadedQuery = query
                    snapshot = ListeningDurationState(breakdown: plan.breakdown, loading: fetchMissing && !plan.pending.isEmpty)
                    guard fetchMissing else { return }
                    for start in stride(from: 0, to: plan.pending.count, by: 100) {
                        let end = min(start + 100, plan.pending.count)
                        let batch = try await DurationCatalog.shared.resolve(plan.pending[start..<end], store: store)
                        try Task.checkCancellation()
                        plan.include(batch)
                        snapshot.breakdown = plan.breakdown
                    }
                    snapshot.loading = false
                } catch {
                    guard !Task.isCancelled else { return }
                    if loadedQuery != query { snapshot = ListeningDurationState() }
                    loadedQuery = query
                    snapshot.loading = false
                    snapshot.unavailable = true
                }
            }
    }
}

extension View {
    func listeningDurations(_ history: [Scrobble], interval: DateInterval = ListeningRange.lifetime.interval(),
                            query: String, active: Bool = true, fetchMissing: Bool = true) -> some View {
        modifier(ListeningDurationScope(history: history, interval: interval, query: query,
                                        active: active, fetchMissing: fetchMissing))
    }
}

extension EstimatedDuration {
    var minutesLabel: String? {
        guard covered > 0 else { return nil }
        guard milliseconds >= 60_000 else { return "<1 min est." }
        let minutes = Int((Double(milliseconds) / 60_000).rounded())
        return "\(minutes.formatted()) min est."
    }
}

func scrobbleLabel(_ count: Int, duration: EstimatedDuration?) -> String {
    let label = "\(count.formatted()) \(count == 1 ? "scrobble" : "scrobbles")"
    guard let duration, let minutes = duration.minutesLabel else { return label }
    if duration.covered < count { return "\(label) · \(minutes) (\(duration.covered.formatted()) matched)" }
    return "\(label) · \(minutes)"
}

struct ScrobbleMetric: View {
    @Environment(\.listeningDurations) private var durations
    let count: Int

    private var detail: String? {
        guard durations.enabled, count > 0 else { return nil }
        let total = durations.breakdown.total
        let coverage = "\(total.covered.formatted()) of \(count.formatted()) matched"
        guard let minutes = total.minutesLabel else { return coverage }
        return "\(minutes) · \(coverage)"
    }

    var body: some View {
        DashboardMetric(title: "scrobbles", value: count.formatted(), detail: detail)
    }
}

struct DurationLookupStatus: View {
    @Environment(\.listeningDurations) private var durations

    var body: some View {
        if durations.loading {
            ProgressView("Looking up track durations").font(.caption)
        } else if durations.unavailable {
            Button("Retry duration lookup", action: durations.retry).font(.caption.bold())
        }
    }
}

struct EnableListeningTime: View {
    @Environment(AppModel.self) private var model
    @AppStorage("durationLookupsEnabled") private var enabled = false

    var body: some View {
        if !enabled && !model.isDemo {
            VStack(alignment: .leading, spacing: 6) {
                Button("Estimate listening time") { enabled = true }
                Text("Looks up track, artist and album names in the next.fm catalog and saves durations on this device.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct RankedListeningLabel: View {
    @Environment(\.listeningDurations) private var durations
    let entity: RankedEntity

    var body: some View {
        Text(scrobbleLabel(entity.count, duration: durations.breakdown.estimate(for: entity)))
    }
}

struct DayListeningLabel: View {
    @Environment(\.listeningDurations) private var durations
    let day: Date
    let count: Int

    var body: some View {
        Text(scrobbleLabel(count, duration: durations.breakdown.days[day]))
    }
}

struct TrackDurationLabel: View {
    @Environment(\.listeningDurations) private var durations
    let item: Scrobble

    var body: some View {
        if let ms = durations.breakdown.tracks[CatalogTrack(item)] {
            Text(Duration.milliseconds(Int64(ms)).formatted(.time(pattern: .minuteSecond)))
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                .accessibilityLabel("Track duration \(Duration.milliseconds(Int64(ms)).formatted())")
        }
    }
}

struct StoredListeningCount: View {
    @Environment(\.listeningDurations) private var durations
    let count: Int

    var body: some View {
        LabeledContent("Stored scrobbles") {
            VStack(alignment: .trailing, spacing: 2) {
                Text(count.formatted())
                if let minutes = durations.breakdown.total.minutesLabel {
                    Text(minutes).font(.caption)
                    Text("\(durations.breakdown.total.covered.formatted()) matched").font(.caption2)
                }
            }
        }
    }
}
