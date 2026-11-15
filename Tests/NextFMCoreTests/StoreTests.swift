import Foundation
import Testing
@testable import NextFMCore

@Test func overlappingPagesAreIdempotentAndProfilesAreIsolated() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("test.sqlite")
    let store = try HistoryStore(url: url)
    let item = Scrobble(track: "Song", artist: "Artist", album: "Album", timestamp: 100)
    let checkpoint = SyncCheckpoint(upperBound: 200, nextPage: 2, totalPages: 10)
    try await store.save([item], user: "User", checkpoint: checkpoint)
    try await store.save([item], user: "user", checkpoint: checkpoint)
    #expect(try await store.load(user: "USER").count == 1)
    #expect(try await store.load(user: "other").isEmpty)
    await store.close()
    let reopened = try HistoryStore(url: url)
    #expect(try await reopened.checkpoint(user: "User")?.nextPage == 2)
    #expect(try await reopened.load(user: "user").first?.track == "Song")
    await reopened.close()
}
