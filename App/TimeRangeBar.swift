import SwiftUI
import NextFMCore

/// A tab-style glass selector whose additional choices grow above the main row.
struct TimeRangeBar: View {
    @Binding var selection: ListeningRange
    let openCustomDates: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = false
    @State private var rowWidth: CGFloat = 1
    @Namespace private var highlight

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            VStack(spacing: 8) {
                if isExpanded {
                    HStack(spacing: 0) {
                        ForEach([ListeningRange.today, .thisWeek, .thisYear]) { option in
                            rangeButton(option)
                        }
                        Button(action: openCustomDates) {
                            Image(systemName: "calendar")
                                .font(.title3.weight(.medium))
                                .frame(width: 48, height: 52)
                                .foregroundStyle(selection == .custom ? Theme.accent : Color.primary)
                                .background { selectionHighlight(for: .custom) }
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Custom date range")
                        .accessibilityAddTraits(selection == .custom ? .isSelected : [])
                    }
                    .padding(5)
                    .glassEffect(.regular, in: .capsule)
                    .simultaneousGesture(dragSelection(for: [.today, .thisWeek, .thisYear]))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                HStack(spacing: 0) {
                    ForEach([ListeningRange.fourWeeks, .sixMonths, .lifetime]) { option in
                        rangeButton(option)
                    }
                    Button {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.85)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.subheadline.bold())
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            .frame(width: 48, height: 52)
                            .foregroundStyle(isAdditionalRangeSelected ? Theme.accent : Color.primary)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isExpanded ? "Hide more time ranges" : "Show more time ranges")
                    .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
                }
                .padding(5)
                .glassEffect(.regular, in: .capsule)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { rowWidth = $0 }
                .simultaneousGesture(dragSelection(for: [.fourWeeks, .sixMonths, .lifetime]))
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }

    private var isAdditionalRangeSelected: Bool {
        [.today, .thisWeek, .thisYear, .custom].contains(selection)
    }

    private func rangeButton(_ option: ListeningRange) -> some View {
        Button {
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.2)) { selection = option }
        } label: {
            Text(option == .thisYear ? String(Calendar.current.component(.year, from: .now)) : option.rawValue)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1).minimumScaleFactor(0.8)
                .padding(.horizontal, 4)
                .frame(maxWidth: .infinity, minHeight: 52)
                .foregroundStyle(selection == option ? Theme.accent : Color.primary)
                .background { selectionHighlight(for: option) }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selection == option ? .isSelected : [])
    }

    @ViewBuilder
    private func selectionHighlight(for option: ListeningRange) -> some View {
        if selection == option {
            Capsule().fill(.clear)
                .glassEffect(.regular.tint(Theme.accent.opacity(0.08)).interactive(), in: .capsule)
                .glassEffectID("selection", in: highlight)
        }
    }

    private func dragSelection(for options: [ListeningRange]) -> some Gesture {
        // Keep native button taps and glass interaction intact; only horizontal
        // drags starting within the three range cells slide the selection.
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                let width = max(1, rowWidth - 10 - 48)
                guard value.startLocation.x >= 5, value.startLocation.x < width + 5,
                      abs(value.translation.width) > abs(value.translation.height) else { return }
                let index = min(options.count - 1, max(0, Int((value.location.x - 5) / (width / CGFloat(options.count)))))
                guard selection != options[index] else { return }
                withAnimation(reduceMotion ? nil : .interactiveSpring(response: 0.22, dampingFraction: 0.85)) {
                    selection = options[index]
                }
            }
    }
}
