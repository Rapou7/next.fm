import Foundation
import Testing
@testable import NextFMCore

@Test func nowPlayingDoesNotCountAsScrobble() throws {
    let json = ##"{"recenttracks":{"track":[{"name":"Live","artist":{"#text":"Artist"},"album":{"#text":"Album"},"@attr":{"nowplaying":"true"}},{"name":"Played","artist":{"#text":"Artist"},"album":{"#text":"Album"},"date":{"uts":"1794744000"}}],"@attr":{"totalPages":"1","total":"1"}}}"##
    let page = try LastFMClient.decode(Data(json.utf8))
    #expect(page.nowPlaying?.track == "Live")
    #expect(page.scrobbles.count == 1)
    #expect(page.scrobbles[0].track == "Played")
}

@Test func singleObjectAndMissingArtworkAreSupported() throws {
    let json = ##"{"recenttracks":{"track":{"name":"Played","artist":{"#text":"Artist"},"album":{"#text":""},"date":{"uts":"1794744000"},"image":[{"#text":""}]},"@attr":{"totalPages":"1","total":"1"}}}"##
    let page = try LastFMClient.decode(Data(json.utf8))
    #expect(page.scrobbles.count == 1)
    #expect(page.scrobbles[0].artworkURL == nil)
}

@Test func apiErrorsAreNotTreatedAsEmptyHistory() {
    #expect(throws: (any Error).self) {
        try LastFMClient.decode(Data(##"{"error":6,"message":"User not found"}"##.utf8))
    }
}

@Test func undatedTracksAreExcludedFromDatedStatistics() throws {
    let json = ##"{"recenttracks":{"track":[{"name":"Undated","artist":{"#text":"Artist"},"album":{"#text":"Album"}}],"@attr":{"totalPages":"1","total":"1"}}}"##
    #expect(try LastFMClient.decode(Data(json.utf8)).scrobbles.isEmpty)
}
