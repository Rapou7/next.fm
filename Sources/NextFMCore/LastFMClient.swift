import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct RecentPage: Sendable {
    public let scrobbles: [Scrobble]
    public let nowPlaying: NowPlaying?
    public let totalPages: Int
    public let total: Int
}

public enum LastFMError: LocalizedError {
    case api(Int, String), invalidResponse, http(Int)
    public var errorDescription: String? {
        switch self {
        case let .api(_, message): message
        case .invalidResponse: "Last.fm returned an unreadable response. Try again shortly."
        case let .http(code): "Last.fm request failed (HTTP \(code)). Try again shortly."
        }
    }
}

public protocol RecentTracksClient: Sendable {
    func recent(user: String, page: Int, from: Int?, to: Int?, limit: Int) async throws -> RecentPage
}

public struct LastFMClient: RecentTracksClient {
    let apiKey: String
    let session: URLSession
    public init(apiKey: String, session: URLSession = .shared) { self.apiKey = apiKey; self.session = session }

    public func recent(user: String, page: Int = 1, from: Int? = nil, to: Int? = nil, limit: Int = 200) async throws -> RecentPage {
        var query = ["method": "user.getRecentTracks", "user": user, "api_key": apiKey,
                     "format": "json", "limit": String(limit), "page": String(page)]
        if let from { query["from"] = String(from) }
        if let to { query["to"] = String(to) }
        var components = URLComponents(string: "https://ws.audioscrobbler.com/2.0/")!
        components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 30
        request.setValue("next.fm/0.1", forHTTPHeaderField: "User-Agent")
        for attempt in 0..<4 {
            try Task.checkCancellation()
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else { throw LastFMError.invalidResponse }
                guard http.statusCode == 200 else { throw LastFMError.http(http.statusCode) }
                return try Self.decode(data)
            } catch {
                if Task.isCancelled { throw CancellationError() }
                let retry: Bool
                switch error {
                case LastFMError.api(let code, _): retry = [8, 11, 16, 29].contains(code)
                case LastFMError.http(let status): retry = status == 429 || status >= 500
                case is URLError: retry = true
                default: retry = false
                }
                guard retry && attempt < 3 else { throw error }
                try await Task.sleep(for: .seconds(2 << attempt))
            }
        }
        throw LastFMError.invalidResponse
    }

    public static func decode(_ data: Data) throws -> RecentPage {
        let decoder = JSONDecoder()
        if let error = try? decoder.decode(APIError.self, from: data) { throw LastFMError.api(error.error, error.message) }
        let response = try decoder.decode(Envelope.self, from: data).recenttracks
        let now = response.track.first { $0.attr?.nowplaying == "true" }
        let tracks = response.track.compactMap { item -> Scrobble? in
            guard item.attr?.nowplaying != "true", let raw = item.date?.uts, let timestamp = Int(raw), timestamp > 0 else { return nil }
            return Scrobble(track: item.name, artist: item.artist.text, album: item.album.text, timestamp: timestamp, artworkURL: item.artwork)
        }
        return RecentPage(scrobbles: tracks,
            nowPlaying: now.map { NowPlaying(track: $0.name, artist: $0.artist.text, album: $0.album.text, artworkURL: $0.artwork) },
            totalPages: Int(response.attr.totalPages) ?? 0, total: Int(response.attr.total) ?? 0)
    }
}

private struct APIError: Decodable { let error: Int; let message: String }
private struct Envelope: Decodable { let recenttracks: RecentTracks }
private struct RecentTracks: Decodable {
    let track: [APITrack]
    let attr: Attributes
    enum CodingKeys: String, CodingKey { case track; case attr = "@attr" }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        attr = try container.decode(Attributes.self, forKey: .attr)
        if let list = try? container.decode([APITrack].self, forKey: .track) { track = list }
        else if let single = try? container.decode(APITrack.self, forKey: .track) { track = [single] }
        else { throw LastFMError.invalidResponse }
    }
    struct Attributes: Decodable { let totalPages: String; let total: String }
}
private struct APITrack: Decodable {
    let name: String
    let artist: TextValue
    let album: TextValue
    let image: [ImageValue]?
    let date: Timestamp?
    let attr: Attributes?
    enum CodingKeys: String, CodingKey { case name, artist, album, image, date; case attr = "@attr" }
    var artwork: URL? {
        image?.reversed().compactMap { image -> URL? in
            guard !image.text.isEmpty, !image.text.contains("2a96cbd8b46e442fc41c2b86b821562f"),
                  let url = URL(string: image.text), url.scheme == "https" else { return nil }
            return url
        }.first
    }
    struct Timestamp: Decodable { let uts: String }
    struct Attributes: Decodable { let nowplaying: String? }
}
private struct TextValue: Decodable {
    let text: String
    enum CodingKeys: String, CodingKey { case text = "#text" }
}
private struct ImageValue: Decodable {
    let text: String
    enum CodingKeys: String, CodingKey { case text = "#text" }
}
