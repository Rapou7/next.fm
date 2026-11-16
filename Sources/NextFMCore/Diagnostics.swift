import Foundation

/// A bounded, process-local recorder. Callers must only supply nonpersonal metadata.
public final class Diagnostics: @unchecked Sendable {
    public static let shared = Diagnostics()
    private let lock = NSLock()
    private var entries: [Entry] = []
    private var recording: Bool
    private let capacity: Int

    public struct Entry: Codable, Sendable {
        public let date: Date
        public let event: String
        public let detail: String
        public let milliseconds: Double?
    }

    public init(capacity: Int = 2_000, enabled: Bool = Diagnostics.defaultEnabled) {
        self.capacity = max(1, capacity)
        self.recording = enabled && Self.defaultEnabled
    }

    public static var defaultEnabled: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    public var isEnabled: Bool {
        get { lock.withLock { recording } }
        set { lock.withLock { recording = newValue && Self.defaultEnabled } }
    }

    public func record(_ event: String, detail: String = "", since start: ContinuousClock.Instant? = nil) {
        guard Self.defaultEnabled else { return }
        let elapsed = start.map { start in
            let parts = start.duration(to: .now).components
            return Double(parts.seconds) * 1_000 + Double(parts.attoseconds) / 1e15
        }
        lock.withLock {
            guard recording else { return }
            entries.append(Entry(date: .now, event: event, detail: detail, milliseconds: elapsed))
            if entries.count > capacity { entries.removeFirst(entries.count - capacity) }
        }
    }

    /// Never log error descriptions, URLs, bodies, or NSError userInfo (these can contain credentials).
    public func failure(_ event: String, error: any Error) {
        guard Self.defaultEnabled else { return }
        let code: String
        switch error {
        case is CancellationError: code = "cancelled"
        case let LastFMError.api(value, _): code = "lastfm=\(value)"
        case let LastFMError.http(value): code = "http=\(value)"
        case is LastFMError: code = "invalid-response"
        case let error as URLError: code = "network=\(error.code.rawValue)"
        case is DecodingError: code = "decoding"
        default: code = "operation-failed"
        }
        record(event, detail: code)
    }

    public func snapshot() -> [Entry] { lock.withLock { entries } }
    public func clear() { lock.withLock { entries.removeAll() } }

    public func export() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(snapshot())
    }
}
