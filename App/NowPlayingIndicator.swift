import SwiftUI

struct NowPlayingIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion || scenePhase != .active)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<4) { bar in
                    let phase = time * (3.1 + Double(bar) * 0.45) + Double(bar) * 1.8
                    Capsule().fill(Theme.accent)
                        .frame(width: 3, height: reduceMotion ? CGFloat(8 + bar * 3) : CGFloat(6 + (sin(phase) + 1) * 7))
                }
            }.frame(width: 20, height: 22)
        }.accessibilityHidden(true)
    }
}
