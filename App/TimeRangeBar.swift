import SwiftUI
import NextFMCore
import UIKit

/// A glass selector whose additional choices grow above the main row.
struct TimeRangeBar: View {
    @Binding var selection: ListeningRange
    let openCustomDates: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = false

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            VStack(spacing: 8) {
                if isExpanded {
                    HStack(spacing: 4) {
                        rangePicker([.today, .thisWeek, .thisYear])
                        Button(action: openCustomDates) {
                            Image(systemName: "calendar")
                                .font(.title3.weight(.medium))
                                .frame(width: 48, height: 52)
                                .foregroundStyle(selection == .custom ? Theme.accent : Color.primary)
                                .glassEffect(selection == .custom ? .regular.tint(Theme.accent.opacity(0.08)).interactive() : .identity,
                                             in: .capsule)
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Custom date range")
                        .accessibilityAddTraits(selection == .custom ? .isSelected : [])
                    }
                    .padding(5)
                    .glassEffect(.regular, in: .capsule)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                HStack(spacing: 4) {
                    rangePicker([.fourWeeks, .sixMonths, .lifetime])
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
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }

    private var isAdditionalRangeSelected: Bool {
        [.today, .thisWeek, .thisYear, .custom].contains(selection)
    }

    private func rangePicker(_ options: [ListeningRange]) -> some View {
        TimeRangeSegments(selection: $selection, options: options, accent: UIColor(Theme.accent))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
    }
}

/// Each row can have no selected segment when the active range is elsewhere.
private struct TimeRangeSegments: UIViewRepresentable {
    @Binding var selection: ListeningRange
    let options: [ListeningRange]
    let accent: UIColor
    @ScaledMetric(relativeTo: .subheadline) private var titleSize: CGFloat = 15

    private var titles: [String] {
        options.map { option in
            option == .thisYear ? String(Calendar.current.component(.year, from: .now)) : option.rawValue
        }
    }

    func makeUIView(context: Context) -> UISegmentedControl {
        let control = UISegmentedControl(items: titles)
        control.addTarget(context.coordinator, action: #selector(Coordinator.selectRange(_:)), for: .valueChanged)
        return control
    }

    func updateUIView(_ control: UISegmentedControl, context: Context) {
        context.coordinator.onSelect = { index in
            guard options.indices.contains(index) else { return }
            selection = options[index]
        }
        for (index, title) in titles.enumerated() where control.titleForSegment(at: index) != title {
            control.setTitle(title, forSegmentAt: index)
        }
        let index = options.firstIndex(of: selection) ?? UISegmentedControl.noSegment
        if control.selectedSegmentIndex != index {
            control.selectedSegmentIndex = index
        }
        let font = UIFont.systemFont(ofSize: min(19, titleSize), weight: .semibold)
        let selectedAttributes = control.titleTextAttributes(for: .selected)
        let displayedFont = selectedAttributes?[.font] as? UIFont
        let displayedAccent = selectedAttributes?[.foregroundColor] as? UIColor
        if displayedFont != font || displayedAccent != accent {
            control.setTitleTextAttributes([.font: font], for: .normal)
            control.setTitleTextAttributes([.font: font, .foregroundColor: accent], for: .selected)
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UISegmentedControl, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite,
              let height = proposal.height, height.isFinite else { return nil }
        return CGSize(width: width, height: height)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        var onSelect: (Int) -> Void = { _ in }

        @MainActor @objc func selectRange(_ control: UISegmentedControl) {
            onSelect(control.selectedSegmentIndex)
        }
    }
}
