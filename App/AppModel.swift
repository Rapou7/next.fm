import Foundation
import Observation
import NextFMCore

@MainActor @Observable
final class AppModel {
    var displayUsername: String {
        #if DEBUG
        if DebugTools.shared.showcase { return "Your listening" }
        #endif
        return isDemo ? "Your listening" : username
    }
    var username = ""
    var apiKey = ""
    var isDemo = false
    var isConnected = false
    var history: [Scrobble] = []
    var nowPlaying: NowPlaying?
    var summary = StatsEngine.summary([])
    var syncProgress: Double = 0
    var syncMessage = "Ready to connect"
    var isSyncing = false
    var historyComplete = false
    var lastSynced: Date?
    var errorMessage: String?
    var revision = 0
    @ObservationIgnored let analytics = Analytics()
    @ObservationIgnored private var store: HistoryStore?
    @ObservationIgnored private var syncTask: Task<Void, Never>?
    @ObservationIgnored private var nowPlayingTask: Task<Void, Never>?
    @ObservationIgnored private var nowPlayingRequestID: UUID?
    @ObservationIgnored private var lastNowPlayingRefresh: Date?
    @ObservationIgnored private var historyCalendar: Calendar?
    @ObservationIgnored private var historyDay: Date?
    @ObservationIgnored private var didRestore = false
    @ObservationIgnored private var generation = UUID()

    init() {
        if let url = Bundle.main.url(forResource: "BuildConfig", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let config = try? JSONDecoder().decode(BuildConfig.self, from: data) { apiKey = config.lastFMAPIKey }
        if let saved = UserDefaults.standard.string(forKey: "lastFMAPIKey"), !saved.isEmpty { apiKey = saved }
    }

    func restore() async {
        guard !didRestore else { return }
        didRestore = true
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--showcase") {
            await showDemo(); return
        }
        #endif
        guard let user = UserDefaults.standard.string(forKey: "username"), !user.isEmpty else { return }
        username = user
        await connect(username: user, apiKey: apiKey)
    }

    func connect(username: String, apiKey: String) async {
        stopSync()
        self.username = username.trimmingCharacters(in: .whitespacesAndNewlines)
        self.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !self.username.isEmpty, !self.apiKey.isEmpty else {
            errorMessage = "Enter a Last.fm username and API key to connect."; return
        }
        isDemo = false; history = []; nowPlaying = nil; summary = StatsEngine.summary([])
        historyComplete = false; lastSynced = nil; errorMessage = nil; revision += 1
        do {
            if store == nil {
                let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                store = try HistoryStore(url: directory.appendingPathComponent("nextfm.sqlite"))
            }
            isConnected = true
            UserDefaults.standard.set(self.username, forKey: "username")
            UserDefaults.standard.set(self.apiKey, forKey: "lastFMAPIKey")
            try await reloadHistory()
            startSync()
        } catch { Diagnostics.shared.failure("model.failure", error: error); errorMessage = error.localizedDescription }
    }

    func showDemo() async {
        #if DEBUG
        let started = ContinuousClock.now
        defer { Diagnostics.shared.record("demo.ready", since: started) }
        #endif
        stopSync(); isDemo = true; isConnected = true; username = "Your listening, in focus"
        errorMessage = nil; nowPlaying = nil; historyComplete = true; lastSynced = nil
        history = DemoData.scrobbles()
        summary = await analytics.summary(history)
        syncMessage = "Demo · sample listening history"; revision += 1
    }

    func startSync() {
        guard !isDemo, !isSyncing, let store else { return }
        let token = generation
        let user = username
        let client = LastFMClient(apiKey: apiKey)
        isSyncing = true; errorMessage = nil; syncMessage = "Checking recent listening…"
        syncTask = Task {
            do {
                await refreshNowPlaying()
                try Task.checkCancellation()
                guard token == generation else { return }
                let service = SyncService(client: client, store: store)
                try await service.synchronize(user: user) { [weak self] progress in
                    await self?.receive(progress, token: token)
                }
                try Task.checkCancellation()
                guard token == generation else { return }
                try await reloadHistory()
                lastSynced = .now
                syncMessage = "Up to date"
                #if DEBUG
                Diagnostics.shared.record("sync.complete", detail: "items=\(history.count)")
                #endif
            } catch is CancellationError {
                #if DEBUG
                Diagnostics.shared.record("sync.cancelled")
                #endif
                if token == generation { syncMessage = "Import paused · tap to resume" }
            } catch {
                #if DEBUG
                Diagnostics.shared.failure("sync.failure", error: error)
                #endif
                if token == generation {
                    errorMessage = error.localizedDescription
                    syncMessage = "Sync interrupted · your history is saved"
                }
            }
            if token == generation { isSyncing = false }
        }
    }

    private func receive(_ progress: SyncProgress, token: UUID) async {
        guard token == generation else { return }
        syncProgress = Double(progress.page) / Double(max(1, progress.totalPages))
        syncMessage = progress.complete ? "Finishing import…" : "Importing history · \(progress.page) of \(progress.totalPages) pages"
        // The sync task reloads once after completion. Publishing here as well
        // repeats the full database read and invalidates every dashboard twice.
        if !progress.complete && (progress.page == 1 || progress.page % 10 == 0) {
            do { try await reloadHistory() } catch { Diagnostics.shared.failure("model.failure", error: error); errorMessage = error.localizedDescription }
        }
    }

    private func reloadHistory() async throws {
        guard let store else { return }
        let token = generation
        let user = username
        let items = try await store.load(user: user)
        let checkpoint = try await store.checkpoint(user: user)
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: .now)
        let unchanged = await analytics.historyIsUnchanged(items, previous: history)
        guard token == generation else { return }
        historyComplete = checkpoint?.isComplete == true
        // Checkpoints can advance without changing any scrobbles. Keep the
        // published revision stable so all tabs retain their derived results.
        if unchanged && historyCalendar == calendar && historyDay == day { return }
        let stats = await analytics.summary(items)
        guard token == generation else { return }
        history = items; summary = stats; historyCalendar = calendar; historyDay = day
        revision += 1
    }

    func refreshNowPlaying() async {
        guard isConnected, !isDemo, !apiKey.isEmpty, !Task.isCancelled else { return }
        if let task = nowPlayingTask { await task.value; return }
        if let lastNowPlayingRefresh, Date.now.timeIntervalSince(lastNowPlayingRefresh) < 10 { return }
        let token = generation
        let requestID = UUID()
        let user = username
        let client = LastFMClient(apiKey: apiKey)
        nowPlayingRequestID = requestID
        let task = Task {
            defer {
                if nowPlayingRequestID == requestID {
                    nowPlayingTask = nil; nowPlayingRequestID = nil
                }
            }
            do {
                let page = try await client.recent(user: user, limit: 1)
                try Task.checkCancellation()
                guard token == generation else { return }
                nowPlaying = page.nowPlaying
                lastNowPlayingRefresh = .now
            } catch {
                if !Task.isCancelled && !(error is CancellationError) {
                    Diagnostics.shared.failure("nowPlaying.failure", error: error)
                }
            }
        }
        nowPlayingTask = task
        await task.value
    }

    func stopSync() {
        nowPlayingTask?.cancel(); nowPlayingTask = nil; nowPlayingRequestID = nil; lastNowPlayingRefresh = nil
        syncTask?.cancel(); syncTask = nil; generation = UUID(); isSyncing = false
        syncMessage = "Import paused · tap to resume"
    }

    func disconnect() {
        stopSync(); isConnected = false; isDemo = false; history = []; nowPlaying = nil
        username = ""; summary = StatsEngine.summary([]); revision += 1; errorMessage = nil
        UserDefaults.standard.removeObject(forKey: "username")
    }
}

private struct BuildConfig: Decodable { let lastFMAPIKey: String }
