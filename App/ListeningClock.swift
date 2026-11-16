import SwiftUI
import NextFMCore

/// Hour sectors share one fixed inner radius and a stable circular reference grid.
/// This avoids SectorMark scaling each sector's hole with its outer radius.
struct ListeningClock: View {
    let hours: [CountBucket]
    @State private var selectedHour: Int?

    private var maximum: Int { max(1, hours.map(\.count).max() ?? 1) }
    private func count(for hour: Int) -> Int { hours.first { $0.id == hour }?.count ?? 0 }
    private var detail: String {
        if let selectedHour {
            return "\(String(format: "%02d", selectedHour)):00–\(String(format: "%02d", (selectedHour + 1) % 24)):00 · \(count(for: selectedHour).formatted()) scrobbles"
        }
        return "Tap an hour to explore · local time"
    }

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                let side = min(geometry.size.width, geometry.size.height)
                let radius = side * 0.47
                let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                ZStack {
                    ZStack {
                        ForEach(0..<24, id: \.self) { hour in
                            ClockSector(hour: hour, fraction: 1)
                                .fill(Color.primary.opacity(0.055))
                            if count(for: hour) > 0 {
                                ClockSector(hour: hour, fraction: Double(count(for: hour)) / Double(maximum))
                                    .fill(selectedHour == hour ? Theme.mint.gradient : Theme.accent.gradient)
                            }
                        }
                    }
                    .frame(width: side, height: side)
                    .position(center)
                    ForEach([0, 6, 12, 18], id: \.self) { hour in
                        let angle = Double(hour) / 24 * 2 * Double.pi - Double.pi / 2
                        Text(String(format: "%02d", hour))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .position(x: center.x + cos(angle) * radius * 0.29,
                                      y: center.y + sin(angle) * radius * 0.29)
                    }
                    Image(systemName: "clock").font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Theme.accent).position(center)
                }
                .contentShape(Circle().path(in: CGRect(x: center.x - side / 2, y: center.y - side / 2, width: side, height: side)))
                .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                    let dx = value.location.x - center.x
                    let dy = value.location.y - center.y
                    guard hypot(dx, dy) > radius * 0.42, hypot(dx, dy) <= radius else { return }
                    let angle = (atan2(dy, dx) + Double.pi / 2 + 2 * Double.pi).truncatingRemainder(dividingBy: 2 * Double.pi)
                    selectedHour = Int((angle / (2 * Double.pi) * 24).rounded()) % 24
                })
            }
            Text(detail).font(.caption).foregroundStyle(.secondary)
                .lineLimit(2).multilineTextAlignment(.center).frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Listening clock")
        .accessibilityValue(selectedHour == nil ? "24 hours. Longer bars mean more scrobbles." : detail)
        .accessibilityHint("Swipe up or down to explore each hour.")
        .accessibilityAdjustableAction { direction in
            let current = selectedHour ?? 0
            switch direction {
            case .increment: selectedHour = (current + 1) % 24
            case .decrement: selectedHour = (current + 23) % 24
            @unknown default: break
            }
        }
        .sensoryFeedback(.selection, trigger: selectedHour)
    }
}

private struct ClockSector: Shape {
    let hour: Int
    let fraction: Double

    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width, rect.height) * 0.47
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let inner = radius * 0.42
        let outer = inner + (radius - inner) * min(1, max(0, fraction))
        let angle = Double(hour) * 15 - 90
        let start = Angle.degrees(angle - 6.5)
        let end = Angle.degrees(angle + 6.5)
        var path = Path()
        path.addArc(center: center, radius: outer, startAngle: start, endAngle: end, clockwise: false)
        path.addArc(center: center, radius: inner, startAngle: end, endAngle: start, clockwise: true)
        path.closeSubpath()
        return path
    }
}
