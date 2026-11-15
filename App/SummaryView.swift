import SwiftUI
import Charts
import NextFMCore

struct ActivityChart: View {
    let days: [ActivityDay]
    @State private var selectedDate: Date?
    private var selected: ActivityDay? {
        guard let selectedDate else { return nil }
        return days.first { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let selected {
                Text("\(selected.date.formatted(date: .abbreviated, time: .omitted)) · \(selected.count) scrobbles")
                    .font(.caption.monospacedDigit()).foregroundStyle(Theme.accent)
            }
            Chart(days) { day in
                BarMark(x: .value("Day", day.date, unit: .day), y: .value("Scrobbles", day.count))
                    .foregroundStyle(Theme.accent.gradient).cornerRadius(3)
                if let selected, selected.id == day.id {
                    RuleMark(x: .value("Selected day", selected.date, unit: .day)).foregroundStyle(.secondary.opacity(0.5))
                }
            }
            .chartXSelection(value: $selectedDate)
            .chartXAxis { AxisMarks(values: .stride(by: .day, count: 7)) { _ in AxisValueLabel(format: .dateTime.day().month(.abbreviated)) } }
            .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) }
            .frame(height: 170)
        }
    }
}

struct SyncStatusView: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if model.isSyncing { ProgressView(value: model.syncProgress).tint(Theme.accent) }
            HStack {
                Label(model.syncMessage, systemImage: model.isSyncing ? "arrow.down.circle" : "checkmark.circle")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                if !model.isDemo {
                    Button(model.isSyncing ? "Pause" : "Refresh") {
                        if model.isSyncing { model.stopSync() } else { model.startSync() }
                    }.font(.caption.bold())
                }
            }
            if let error = model.errorMessage { Text(error).font(.caption).foregroundStyle(Theme.accent) }
        }.padding(.bottom, 12)
    }
}
