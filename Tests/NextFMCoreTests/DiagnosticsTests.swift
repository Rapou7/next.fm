import Foundation
import Testing
@testable import NextFMCore

struct DiagnosticsTests {
    #if DEBUG
    @Test func boundedRecordingAndExport() throws {
        let log = Diagnostics(capacity: 2, enabled: true)
        log.record("first")
        log.record("second", since: .now)
        log.record("third")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let entries = try decoder.decode([Diagnostics.Entry].self, from: log.export())
        #expect(entries.map(\.event) == ["second", "third"])
        #expect(entries[0].milliseconds! >= 0)
        log.isEnabled = false
        log.record("disabled")
        #expect(log.snapshot().count == 2)
        log.clear()
        #expect(log.snapshot().isEmpty)
    }

    @Test func errorsExcludeSensitiveDescriptionsAndURLs() throws {
        let log = Diagnostics(enabled: true)
        log.failure("api", error: LastFMError.api(10, "secret-api-key private-username"))
        log.failure("network", error: URLError(.timedOut, userInfo: [NSURLErrorFailingURLErrorKey: URL(string: "https://example.com/?api_key=secret-api-key")!]))
        log.failure("unknown", error: NSError(domain: "private-username", code: 1, userInfo: [NSLocalizedDescriptionKey: "secret-api-key"]))
        let exported = String(decoding: try log.export(), as: UTF8.self)
        #expect(!exported.contains("secret-api-key"))
        #expect(!exported.contains("private-username"))
        #expect(!exported.contains("https://"))
        #expect(log.snapshot().map(\.detail) == ["lastfm=10", "network=-1001", "operation-failed"])
    }

    @Test func concurrentWritersStayBounded() async {
        let log = Diagnostics(capacity: 50, enabled: true)
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<20 {
                group.addTask { for _ in 0..<100 { log.record("event") } }
            }
        }
        #expect(log.snapshot().count == 50)
    }
    #else
    @Test func releaseCannotEnableRecording() throws {
        let log = Diagnostics(enabled: true)
        log.isEnabled = true
        log.record("must-not-be-collected")
        log.failure("must-not-be-collected", error: LastFMError.http(500))
        #expect(!log.isEnabled)
        #expect(log.snapshot().isEmpty)
        #expect(try JSONDecoder().decode([Diagnostics.Entry].self, from: log.export()).isEmpty)
    }
    #endif
}
