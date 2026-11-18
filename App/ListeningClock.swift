import SwiftUI
import NextFMCore

/// Hour sectors share one fixed inner radius and a stable circular reference grid.
/// This avoids SectorMark scaling each sector's hole with its outer radius.
struct ListeningClock: View {
    let hours: [CountBucket]
    @Environment(\.listeningDurations) private var durations
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedHour: Int?
    @State private var appeared = false

    private var maximum: Int { max(1, hours.map(\.count).max() ?? 1) }
    private func count(for hour: Int) -> Int { hours.first { $0.id == hour }?.count ?? 0 }
    private func hourLabel(_ hour: Int) -> String {
        "\(String(format: "%02d", hour)):00–\(String(format: "%02d", (hour + 1) % 24)):00"
    }
    private var detail: String {
        guard let selectedHour else { return "24 hours. Longer bars mean more scrobbles." }
        return "\(hourLabel(selectedHour)), \(hourListening(selectedHour))"
    }

    private func hourListening(_ hour: Int) -> String {
        scrobbleLabel(count(for: hour), duration: durations.breakdown.hours[hour])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let selectedHour {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(hourLabel(selectedHour)) · local time")
                            .font(.caption).foregroundStyle(.secondary)
                        Text(hourListening(selectedHour))
                            .font(.subheadline.weight(.semibold)).monospacedDigit()
                            .contentTransition(.identity)
                    }
                    .animation(nil, value: selectedHour)
                    Spacer(minLength: 0)
                    Button { self.selectedHour = nil } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary).frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear hour selection")
                }
                .padding(.leading, 12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
            GeometryReader { geometry in
                let side = min(geometry.size.width, geometry.size.height)
                let radius = side * 0.47
                let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                ZStack {
                    ZStack {
                        ForEach(0..<24, id: \.self) { hour in
                            ClockSector(hour: hour, fraction: 1)
                                .fill(selectedHour == hour ? Theme.accent.opacity(0.12) : Color.primary.opacity(0.055))
                            if count(for: hour) > 0 {
                                ClockSector(hour: hour, fraction: Double(count(for: hour)) / Double(maximum))
                                    .fill(Theme.accent.gradient)
                                    .overlay {
                                        ClockSector(hour: hour, fraction: Double(count(for: hour)) / Double(maximum))
                                            .stroke(Color.primary.opacity(0.22), style: StrokeStyle(lineWidth: 0.65, lineJoin: .round))
                                    }
                                    .opacity(selectedHour == nil || selectedHour == hour ? 1 : 0.3)
                            }
                            if selectedHour == hour {
                                ClockSector(hour: hour, fraction: 1)
                                    .stroke(Theme.accent.opacity(0.85), style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
                            }
                        }
                    }
                    .frame(width: side, height: side)
                    .position(center)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: selectedHour)
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
            .frame(height: 290)
            .opacity(appeared || reduceMotion ? 1 : 0)
            .scaleEffect(appeared || reduceMotion ? 1 : 0.96)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Listening clock")
            .accessibilityValue(detail)
            .accessibilityHint("Swipe up or down to explore each hour.")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: selectedHour = ((selectedHour ?? -1) + 1) % 24
                case .decrement: selectedHour = ((selectedHour ?? 24) + 23) % 24
                @unknown default: break
                }
            }
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: selectedHour != nil)
        .sensoryFeedback(.selection, trigger: selectedHour)
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) { appeared = true }
        }
        .onChange(of: hours.map(\.count)) { selectedHour = nil }
        .transaction { if reduceMotion { $0.animation = nil } }
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
