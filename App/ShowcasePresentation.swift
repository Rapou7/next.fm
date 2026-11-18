import SwiftUI

extension View {
    @ViewBuilder func showcaseAnchor(_ id: String) -> some View {
        #if DEBUG
        self.id(id)
        #else
        self
        #endif
    }

    @ViewBuilder func showcaseScrolling(_ screen: String) -> some View {
        #if DEBUG
        modifier(ShowcaseScrolling(screen: screen))
        #else
        self
        #endif
    }
}

#if DEBUG
private struct ShowcaseScrolling: ViewModifier {
    let screen: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        ScrollViewReader { proxy in
            content.onReceive(NotificationCenter.default.publisher(for: .init("nextfm.showcase.scroll." + screen))) { notification in
                guard DebugTools.shared.showcase, let anchor = notification.object as? String else { return }
                // Build speed, travel quickly, then brake smoothly into the feature.
                withAnimation(reduceMotion ? nil : .timingCurve(0.65, 0, 0.2, 1, duration: 1.5)) {
                    proxy.scrollTo(anchor, anchor: .top)
                }
            }
        }
    }
}

struct ShowcaseIntro: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false
    private let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    private static let commitHash: String = {
        guard let url = Bundle.main.url(forResource: "BuildConfig", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(ShowcaseBuildInfo.self, from: data),
              let hash = config.commitHash, !hash.isEmpty else { return "unknown" }
        return String(hash.prefix(7))
    }()
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            Circle().fill(Theme.accent.opacity(0.12))
                .frame(width: 300, height: 300).blur(radius: 50)
                .scaleEffect(revealed ? 1.3 : 0.7)
            VStack(spacing: 24) {
                Image(systemName: "waveform")
                    .font(.system(size: 68, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 132, height: 132)
                    .background(Theme.accent.gradient, in: RoundedRectangle(cornerRadius: 36))
                    .shadow(color: Theme.accent.opacity(0.3), radius: 32, y: 14)
                    .scaleEffect(revealed ? 1 : 0.8)
                VStack(spacing: 10) {
                    Text("next.fm").font(.system(size: 46, weight: .bold, design: .rounded))
                    Text("Your music. A different perspective.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    VStack(spacing: 6) {
                        HStack(spacing: 4) {
                            Text("made by").foregroundStyle(.secondary)
                            Text("rapou7").bold().foregroundStyle(Theme.accent)
                        }.font(.subheadline)
                        Text("release v\(version) (#\(Self.commitHash))")
                            .font(.caption.monospaced()).foregroundStyle(.secondary)
                    }.padding(.top, 8)
                }.opacity(revealed ? 1 : 0)
                    .offset(y: revealed ? 0 : 16)
            }
        }
        .accessibilityElement(children: .combine)
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(duration: 0.8, bounce: 0.18)) { revealed = true }
        }
    }
}

private struct ShowcaseBuildInfo: Decodable {
    let commitHash: String?
}
#endif
