import Foundation

public struct SyncProgress: Sendable {
    public let page: Int
    public let totalPages: Int
    public let complete: Bool
}

public struct SyncService: Sendable {
    public let client: any RecentTracksClient
    public let store: HistoryStore
    public init(client: any RecentTracksClient, store: HistoryStore) { self.client = client; self.store = store }

    public func synchronize(user: String, progress: @Sendable (SyncProgress) async -> Void) async throws {
        let now = Int(Date.now.timeIntervalSince1970)
        var checkpoint = try await store.checkpoint(user: user) ?? SyncCheckpoint(upperBound: now)
        // Refresh the recent window first on repeat visits, even during a long initial import.
        if checkpoint.nextPage > 1 || checkpoint.isComplete {
            let from = max(0, (checkpoint.refreshedThrough > 0 ? checkpoint.refreshedThrough : checkpoint.upperBound) - 86_400)
            var pageNumber = 1
            while true {
                try Task.checkCancellation()
                let page = try await client.recent(user: user, page: pageNumber, from: from, to: now, limit: 200)
                try await store.save(page.scrobbles, user: user, checkpoint: checkpoint)
                if pageNumber >= page.totalPages { break }
                pageNumber += 1
                try await Task.sleep(for: .milliseconds(300))
            }
            checkpoint.refreshedThrough = now
            try await store.save([], user: user, checkpoint: checkpoint)
        }
        if checkpoint.isComplete {
            await progress(SyncProgress(page: checkpoint.totalPages, totalPages: checkpoint.totalPages, complete: true))
            return
        }
        // Freeze the upper bound so new plays do not shift pagination during a backfill.
        while !checkpoint.isComplete {
            try Task.checkCancellation()
            let page = try await client.recent(user: user, page: checkpoint.nextPage, from: nil, to: checkpoint.upperBound, limit: 200)
            checkpoint.totalPages = max(1, page.totalPages)
            let completedPage = checkpoint.nextPage
            checkpoint.nextPage += 1
            checkpoint.isComplete = completedPage >= checkpoint.totalPages
            if checkpoint.isComplete { checkpoint.refreshedThrough = max(checkpoint.refreshedThrough, checkpoint.upperBound) }
            try await store.save(page.scrobbles, user: user, checkpoint: checkpoint)
            await progress(SyncProgress(page: completedPage, totalPages: checkpoint.totalPages, complete: checkpoint.isComplete))
            if !checkpoint.isComplete { try await Task.sleep(for: .milliseconds(300)) }
        }
    }
}
