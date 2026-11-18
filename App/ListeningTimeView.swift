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

    func lookup(_ candidates: ArraySlice<CatalogTrack>) async throws -> [CatalogTrack: CachedDuration] {
        guard Date.now >= retryAfter else { throw URLError(.resourceUnavailable) }
        var batch = Array(candidates.prefix(100))
        let encoder = JSONEncoder()
        var body = try encoder.encode(batch)
        while body.count > 65536 {
            if batch.count == 1 { return [batch[0]: CachedDuration(milliseconds: nil)] }
            batch.removeLast(batch.count / 2)
            body = try encoder.encode(batch)
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

struct ListeningTimeView: View {
    @Environment(AppModel.self) private var model
    @AppStorage("durationLookupsEnabled") private var enabled = false
    let interval: DateInterval
    @State private var minutes = 0
    @State private var covered = 0
    @State private var total = 0
    @State private var loading = false
    @State private var unavailable = false
    @State private var attempt = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if enabled {
                HStack {
                    Text("Estimated listening time").font(.headline)
                    if loading { ProgressView().controlSize(.small) }
                }
                if covered > 0 {
                    Text("\(minutes.formatted()) min").font(.title2.bold()).monospacedDigit()
                }
                Text("Duration available for \(covered.formatted()) of \(total.formatted()) scrobbles")
                    .font(.caption).foregroundStyle(.secondary)
                if unavailable {
                    Button("Lookup interrupted · retry") { attempt += 1 }
                }
            } else {
                Button("Estimate listening time") { enabled = true }
                Text("Looks up track, artist and album names in the next.fm catalog and saves durations on this device.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .task(id: "\(enabled)-\(attempt)") {
            guard enabled, let store = model.store else { return }
            loading = true
            unavailable = false
            do {
                var plan = try await store.durationPlan(history: model.history, interval: interval)
                try Task.checkCancellation()
                update(plan)
                var offset = 0
                while offset < plan.pending.count {
                    let batch = try await DurationCatalog.shared.lookup(plan.pending[offset...])
                    try Task.checkCancellation()
                    try await store.saveDurations(batch)
                    try Task.checkCancellation()
                    plan.include(batch)
                    offset += batch.count
                    update(plan)
                    if offset < plan.pending.count { try await Task.sleep(for: .milliseconds(650)) }
                }
            } catch { if !Task.isCancelled { unavailable = true } }
            if !Task.isCancelled { loading = false }
        }
    }

    private func update(_ plan: DurationPlan) {
        minutes = Int((Double(plan.milliseconds) / 60000).rounded())
        covered = plan.covered
        total = plan.total
    }
}
