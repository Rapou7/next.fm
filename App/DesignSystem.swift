import SwiftUI
import Observation
import NextFMCore

enum AccentColorOption: String, CaseIterable, Identifiable {
    case rose, orange, green, teal, blue, violet

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var color: Color {
        switch self {
        case .rose: Color(red: 1, green: 0.23, blue: 0.38)
        case .orange: Color(red: 1, green: 0.50, blue: 0.18)
        case .green: Color(red: 0.25, green: 0.82, blue: 0.65)
        case .teal: Color(red: 0.15, green: 0.72, blue: 0.78)
        case .blue: Color(red: 0.25, green: 0.52, blue: 1)
        case .violet: Color(red: 0.62, green: 0.48, blue: 1)
        }
    }
}

@MainActor @Observable
final class AppAppearance {
    static let shared = AppAppearance()
    private static let accentKey = "accentColor"

    var accent: AccentColorOption {
        didSet { UserDefaults.standard.set(accent.rawValue, forKey: Self.accentKey) }
    }

    private init() {
        accent = UserDefaults.standard.string(forKey: Self.accentKey)
            .flatMap(AccentColorOption.init(rawValue:)) ?? .rose
    }
}

enum Theme {
    // Reading observable state here keeps existing themed views in sync with Settings.
    @MainActor static var accent: Color { AppAppearance.shared.accent.color }
    static let mint = Color(red: 0.25, green: 0.82, blue: 0.65)
    static let violet = Color(red: 0.62, green: 0.48, blue: 1)
}

struct Surface<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 26))
    }
}

struct Artwork: View {
    let url: URL?
    let title: String
    var size: CGFloat = 56
    var radius: CGFloat = 12
    private var hue: Double { Double(title.utf8.reduce(0) { ($0 + Int($1)) % 360 }) / 360 }
    var body: some View {
        AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: {
            ZStack {
                LinearGradient(colors: [Color(hue: hue, saturation: 0.55, brightness: 0.7),
                                        Color(hue: hue + 0.12, saturation: 0.65, brightness: 0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle().stroke(.white.opacity(0.13), lineWidth: size * 0.1).padding(size * 0.13)
                Image(systemName: "music.note").font(.system(size: size * 0.29, weight: .medium)).foregroundStyle(.white.opacity(0.8))
            }
        }
        .frame(width: size, height: size).clipShape(RoundedRectangle(cornerRadius: radius))
        .accessibilityHidden(true)
    }
}

struct SectionHeading: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.title2.bold())
            if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(.secondary) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ScrobbleRow: View {
    let item: Scrobble
    var body: some View {
        HStack(spacing: 12) {
            Artwork(url: item.artworkURL, title: item.album)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.track).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(item.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 4)
            Text(item.date, style: .time).font(.caption).foregroundStyle(.tertiary)
        }.padding(.vertical, 3).accessibilityElement(children: .combine)
    }
}

struct RankingRow: View {
    let entity: RankedEntity
    let rank: Int
    let maximum: Int
    var body: some View {
        HStack(spacing: 12) {
            Text(rank.formatted()).font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(rank <= 3 ? Theme.accent : .secondary).frame(width: 26)
            Artwork(url: entity.artworkURL, title: entity.title, size: 58, radius: entity.kind == .artists ? 29 : 12)
            VStack(alignment: .leading, spacing: 6) {
                Text(entity.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary).lineLimit(1)
                Text(entity.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                GeometryReader { proxy in
                    Capsule().fill(Theme.accent.opacity(0.16))
                    Capsule().fill(Theme.accent.gradient)
                        .frame(width: max(3, proxy.size.width * CGFloat(entity.count) / CGFloat(max(1, maximum))))
                }.frame(height: 3)
            }
            Text(entity.count.formatted()).font(.subheadline.monospacedDigit().bold()).foregroundStyle(.primary)
        }.padding(.vertical, 8).accessibilityElement(children: .combine)
    }
}

struct CoverageNotice: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        if model.isDemo {
            Label("Demo data", systemImage: "sparkles").font(.caption.weight(.medium)).foregroundStyle(Theme.violet)
        } else if !model.historyComplete {
            Label("Based on imported history · totals may grow", systemImage: "arrow.down.circle")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

// Animate only compositing, never the chart data or layout itself.
private struct QuickAppearance: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(reduceMotion || appeared ? 1 : 0.7)
            .onAppear {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) {
                    appeared = true
                }
            }
            .onDisappear { appeared = false }
    }
}

extension View {
    func quickAppear() -> some View { modifier(QuickAppearance()) }
}
