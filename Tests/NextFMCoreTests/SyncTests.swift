import Foundation
import Testing
@testable import NextFMCore

private actor InterruptedClient: RecentTracksClient {
    var shouldFail = true
    var backfillCalls: [(page: Int, upperBound: Int?)] = []
    func recent(user: String, page: Int, from: Int?, to: Int?, limit: Int) async throws -> RecentPage {
        if from != nil { return RecentPage(scrobbles: [], nowPlaying: nil, totalPages: 0, total: 0) }
        backfillCalls.append((page, to))
        if page == 2 && shouldFail {
            shouldFail = false
            throw LastFMError.http(500)
        }
        let item = Scrobble(track: "Song \(page)", artist: "Artist", album: "Album", timestamp: 1000 - page)
        return RecentPage(scrobbles: [item], nowPlaying: nil, totalPages: 2, total: 2)
    }
}

@Test func interruptedImportResumesWithTheOriginalSnapshot() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = try HistoryStore(url: directory.appendingPathComponent("sync.sqlite"))
    let client = InterruptedClient()
    let service = SyncService(client: client, store: store)
    do {
        try await service.synchronize(user: "user") { _ in }
        Issue.record("The interrupted page should fail")
    } catch { }
    let checkpoint = try await store.checkpoint(user: "user")
    #expect(checkpoint?.nextPage == 2)
    #expect(checkpoint?.isComplete == false)
    #expect(try await store.load(user: "user").count == 1)
    try await service.synchronize(user: "user") { _ in }
    #expect(try await store.load(user: "user").count == 2)
    #expect(try await store.checkpoint(user: "user")?.isComplete == true)
    let calls = await client.backfillCalls
    #expect(calls.map(\.page) == [1, 2, 2])
    #expect(Set(calls.compactMap(\.upperBound)).count == 1)
    await store.close()
}
