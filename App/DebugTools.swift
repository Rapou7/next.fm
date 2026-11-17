#if DEBUG
import SwiftUI
import UIKit
import ReplayKit
import NextFMCore

@MainActor @Observable
final class DebugTools {
    static let shared = DebugTools()
    var showcase = ProcessInfo.processInfo.arguments.contains("--showcase")
    var appearance = 1
    var autoTour = true
    var intro = false
    var tourRunning = false
    private var tourTask: Task<Void, Never>?
    var busy = false
    var panel = false
    var share: DebugExport?
    var preview: VideoPreview?
    var message: String?

    func capture(video: Bool, model: AppModel) {
        guard !busy, !tourRunning else { return }
        busy = true
        panel = false
        message = nil
        // The task outlives the tools sheet, leaving time for its dismissal.
        tourTask = Task {
            do {
                try await Task.sleep(for: .seconds(3))
                if video {
                    let recorder = RPScreenRecorder.shared()
                    guard recorder.isAvailable else { throw CaptureError.videoUnavailable }
                    recorder.isMicrophoneEnabled = false
                    if autoTour { NotificationCenter.default.post(name: .init("nextfm.showcase.tab"), object: "Summary") }
                    try await startRecording(recorder)
                    Diagnostics.shared.record("capture.video.started")
                    if autoTour {
                        try await runTour()
                    } else {
                        try await Task.sleep(for: .seconds(20))
                    }
                    let controller = try await stopRecording(recorder)
                    if let controller { preview = VideoPreview(controller: controller) }
                    Diagnostics.shared.record("capture.video.finished")
                } else {
                    share = try screenshot(model: model)
                }
            } catch {
                if video && RPScreenRecorder.shared().isRecording { _ = try? await stopRecording(RPScreenRecorder.shared()) }
                Diagnostics.shared.failure("capture.failure", error: error)
                message = "Capture failed. \(error.localizedDescription)"
            }
            busy = false
        }
    }

    private func startRecording(_ recorder: RPScreenRecorder) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            recorder.startRecording { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
        }
    }

    private func stopRecording(_ recorder: RPScreenRecorder) async throws -> RPPreviewViewController? {
        try await withCheckedThrowingContinuation { continuation in
            recorder.stopRecording { controller, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: controller) }
            }
        }
    }

    func startTour() {
        guard !busy, !tourRunning else { return }
        showcase = true
        panel = false
        tourRunning = true
        tourTask = Task {
            defer { intro = false; tourRunning = false }
            do {
                try await Task.sleep(for: .seconds(1))
                try await runTour()
            } catch { Diagnostics.shared.record("showcase.stopped") }
        }
    }

    func stopTour() {
        tourTask?.cancel()
        tourTask = nil
        intro = false
    }

    private func runTour() async throws {
        tourRunning = true
        defer { intro = false; tourRunning = false }
        func command(_ channel: String, _ value: String) {
            NotificationCenter.default.post(name: .init("nextfm.showcase." + channel), object: value)
        }
        command("tab", "Summary")
        intro = true
        try await Task.sleep(for: .milliseconds(400))
        command("scroll.Summary", "hero")
        try await Task.sleep(for: .milliseconds(1800))
        withAnimation(UIAccessibility.isReduceMotionEnabled ? nil : .easeInOut(duration: 0.7)) { intro = false }
        try await Task.sleep(for: .milliseconds(1800))
        // The holds below total 40 seconds, excluding capture setup.
        // Each scroll accelerates and brakes over 1.5 seconds before a reading pause.
        for anchor in ["metrics", "calendar", "artists", "charts", "chart.hours", "favorites"] {
            command("scroll.Summary", anchor)
            try await Task.sleep(for: .milliseconds(2700))
        }
        command("tab", "Tops")
        try await Task.sleep(for: .seconds(1))
        for kind in ["Tracks", "Artists", "Albums"] {
            command("kind", kind)
            try await Task.sleep(for: .milliseconds(900))
            command("scroll.Tops", "rank.6")
            try await Task.sleep(for: .milliseconds(1800))
        }
        command("tab", "Search")
        try await Task.sleep(for: .milliseconds(1100))
        command("scroll.Search", "library.4")
        try await Task.sleep(for: .milliseconds(2400))
        command("tab", "History")
        try await Task.sleep(for: .milliseconds(900))
        command("history", "expand")
        try await Task.sleep(for: .milliseconds(2900))
        command("tab", "Summary")
        try await Task.sleep(for: .milliseconds(400))
        command("scroll.Summary", "hero")
        try await Task.sleep(for: .seconds(3))
    }

    private func screenshot(model: AppModel) throws -> DebugExport {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let window = scene.windows.first(where: \.isKeyWindow) else { throw CaptureError.noWindow }
        let started = ContinuousClock.now
        let format = UIGraphicsImageRendererFormat()
        format.scale = window.screen.scale
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds, format: format)
        var rendered = false
        let image = renderer.image { _ in
            rendered = window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        guard rendered, let png = image.pngData() else { throw CaptureError.noWindow }
        let directory = try exportDirectory()
        let file = directory.appendingPathComponent("screenshot.png")
        try png.write(to: file, options: .atomic)
        Diagnostics.shared.record("capture.screenshot", since: started)
        let info: [String: String] = [
            "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?",
            "build": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?",
            "system": UIDevice.current.systemVersion,
            "points": "\(window.bounds.width)x\(window.bounds.height)",
            "scale": "\(format.scale)",
            "appearance": window.traitCollection.userInterfaceStyle == .dark ? "dark" : "light",
            "textSize": window.traitCollection.preferredContentSizeCategory.rawValue,
            "locale": Locale.current.identifier,
            "timezone": TimeZone.current.identifier,
            "showcase": "\(showcase)", "demo": "\(model.isDemo)",
            "historyCount": "\(model.history.count)",
            "accent": AppAppearance.shared.accent.rawValue
        ]
        let metadata = directory.appendingPathComponent("rendering-context.json")
        try JSONSerialization.data(withJSONObject: info, options: [.prettyPrinted, .sortedKeys]).write(to: metadata)
        let logs = directory.appendingPathComponent("diagnostics.json")
        try Diagnostics.shared.export().write(to: logs)
        return DebugExport(files: [file, metadata, logs])
    }

    func exportLogs() {
        do {
            let url = try exportDirectory().appendingPathComponent("diagnostics.json")
            try Diagnostics.shared.export().write(to: url)
            share = DebugExport(files: [url])
        } catch { message = "Could not export diagnostics: \(error.localizedDescription)" }
    }

    private func exportDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("nextfm-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    enum CaptureError: LocalizedError {
        case noWindow, videoUnavailable
        var errorDescription: String? {
            switch self {
            case .noWindow: "No rendered app window is available."
            case .videoUnavailable: "Screen recording is unavailable on this device."
            }
        }
    }
}

struct DebugExport: Identifiable {
    let id = UUID()
    let files: [URL]
}

struct VideoPreview: Identifiable {
    let id = UUID()
    let controller: RPPreviewViewController
}

struct DebugHost<Content: View>: View {
    @ViewBuilder var content: Content
    @Bindable private var tools = DebugTools.shared
    var body: some View {
        content
            .preferredColorScheme(tools.showcase ? (tools.appearance == 1 ? .dark : .light) : nil)
            .overlay { if tools.intro { ShowcaseIntro().transition(.opacity) } }
            .sheet(isPresented: $tools.panel) { NavigationStack { DebugToolsView() } }
            .sheet(item: $tools.share) { export in DebugShareSheet(files: export.files) }
            .sheet(item: $tools.preview) { video in DebugVideoPreview(controller: video.controller) }
            .alert("Debug capture", isPresented: Binding(get: { tools.message != nil }, set: { if !$0 { tools.message = nil } })) {
                Button("OK") { tools.message = nil }
            } message: { Text(tools.message ?? "") }
    }
}

struct DebugToolsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Bindable private var tools = DebugTools.shared
    @State private var recording = Diagnostics.shared.isEnabled
    @State private var entries: [Diagnostics.Entry] = []
    private var autoTourLabel: String { tools.autoTour ? "Record animated showcase tour" : "Record 20-second video" }
    var body: some View {
        Form {
            Section("Diagnostics") {
                Toggle("Record timings and errors", isOn: $recording)
                    .onChange(of: recording) { _, value in Diagnostics.shared.isEnabled = value }
                Text("Keeps the latest 2,000 events in memory, including API attempts, retries, sync, database work, analytics and screen visits. No API keys, usernames, request URLs or track names are logged.")
                    .font(.caption)
                Button("Share logs") {
                    dismiss()
                    Task { try? await Task.sleep(for: .seconds(1)); tools.exportLogs() }
                }
                Button("Clear logs", role: .destructive) { Diagnostics.shared.clear(); entries = [] }
            }
            Section("Showcase") {
                Toggle("Showcase mode (hide username)", isOn: $tools.showcase)
                Button("Use demo data instead") { Task { await model.showDemo(); tools.showcase = true } }
                Picker("Appearance", selection: $tools.appearance) {
                    Text("Light").tag(0); Text("Dark").tag(1)
                }.disabled(!tools.showcase)
                Text("Uses your current listening data and artwork and masks your username. Exit via Account > Debug tools. Demo data is optional; reconnect from Account afterward to restore your profile.")
                    .font(.caption)
            }
            Section("Automatic feature tour") {
                Button("Play animated showcase") { dismiss(); tools.startTour() }
                    .disabled(!model.isConnected || tools.busy || tools.tourRunning)
                Button("Stop tour") { tools.stopTour() }.disabled(!tools.tourRunning && !tools.busy)
                Text("About 40 seconds: animated intro, Summary highlights and charts, smooth ranking scrolls, artwork library, expanded history and a return to Summary. Reduce Motion is respected. Works with your own screen recorder.").font(.caption)
            }
            Section("Capture") {
                Text("Capture starts 3 seconds after closing this sheet. Navigate to the view you want first. Screenshots include logs and layout context for feedback; screenshots of your account contain visible listening data.")
                    .font(.caption)
                Button("Capture screenshot + feedback files") {
                    dismiss(); tools.capture(video: false, model: model)
                }.disabled(tools.busy || tools.tourRunning)
                Toggle("Automatically tour the four tabs", isOn: $tools.autoTour)
                Button(autoTourLabel) {
                    dismiss(); tools.capture(video: true, model: model)
                }.disabled(tools.busy || tools.tourRunning || !tools.showcase || !model.isConnected)
                Text("Video: use portrait orientation. With the tour on, the full choreography is recorded automatically; otherwise record 20 seconds manually. Review and share in the system preview. Microphone is off. Retry after the first permission prompt for a clean take.")
                    .font(.caption)
            }
            Section("Recent events") {
                Button("Refresh events") { entries = Array(Diagnostics.shared.snapshot().suffix(40).reversed()) }
                ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                    VStack(alignment: .leading) {
                        Text(entry.event).font(.caption.monospaced())
                        Text(entry.detail + (entry.milliseconds.map { String(format: " · %.1f ms", $0) } ?? ""))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Debug tools")
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        .onAppear { entries = Array(Diagnostics.shared.snapshot().suffix(40).reversed()) }
    }
}

private struct DebugShareSheet: UIViewControllerRepresentable {
    let files: [URL]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: files, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

private struct DebugVideoPreview: UIViewControllerRepresentable {
    let controller: RPPreviewViewController
    @Environment(\.dismiss) private var dismiss
    func makeCoordinator() -> Coordinator { Coordinator(dismiss: { dismiss() }) }
    func makeUIViewController(context: Context) -> RPPreviewViewController {
        controller.previewControllerDelegate = context.coordinator
        return controller
    }
    func updateUIViewController(_ controller: RPPreviewViewController, context: Context) {}
    final class Coordinator: NSObject, RPPreviewViewControllerDelegate {
        let dismiss: () -> Void
        init(dismiss: @escaping () -> Void) { self.dismiss = dismiss }
        func previewControllerDidFinish(_ previewController: RPPreviewViewController) { dismiss() }
    }
}
#endif
