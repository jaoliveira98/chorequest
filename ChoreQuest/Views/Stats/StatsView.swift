import SwiftUI
import SwiftData
import Charts

/// Visual stats using Swift Charts: points per person and a daily trend over the
/// last 7 or 30 days.
struct StatsView: View {
    @Query(sort: \Participant.createdAt, order: .forward)
    private var participants: [Participant]

    @State private var windowDays = 7

    private var windowStart: Date {
        Calendar.current.date(
            byAdding: .day,
            value: -(windowDays - 1),
            to: DateUtils.startOfToday()
        ) ?? DateUtils.startOfToday()
    }

    private struct Total: Identifiable {
        let id: PersistentIdentifier
        let name: String
        let color: Color
        let points: Int
    }

    private struct DailyPoints: Identifiable {
        let id = UUID()
        let name: String
        let day: Date
        let points: Int
    }

    private var totals: [Total] {
        participants
            .map { person in
                let points = person.completions
                    .filter { $0.completedAt >= windowStart }
                    .reduce(0) { $0 + $1.pointsAwarded }
                return Total(id: person.persistentModelID, name: person.name,
                             color: Color(hex: person.colorHex), points: points)
            }
            .filter { $0.points > 0 }
            .sorted { $0.points > $1.points }
    }

    private var daily: [DailyPoints] {
        let calendar = Calendar.current
        var rows: [DailyPoints] = []
        for person in participants {
            let byDay = Dictionary(grouping: person.completions.filter { $0.completedAt >= windowStart }) {
                DateUtils.startOfDay($0.completedAt)
            }
            for offset in 0..<windowDays {
                guard let day = calendar.date(byAdding: .day, value: offset, to: windowStart) else { continue }
                let points = byDay[day]?.reduce(0) { $0 + $1.pointsAwarded } ?? 0
                rows.append(DailyPoints(name: person.name, day: day, points: points))
            }
        }
        return rows
    }

    private var hasData: Bool { !totals.isEmpty }

    var body: some View {
        Group {
            if !hasData {
                ContentUnavailableView(
                    "No data yet",
                    systemImage: "chart.bar.xaxis",
                    description: Text("Log some chores and your stats will appear here.")
                )
            } else {
                List {
                    Section("Points per person") {
                        Chart(totals) { total in
                            BarMark(
                                x: .value("Points", total.points),
                                y: .value("Person", total.name)
                            )
                            .foregroundStyle(total.color)
                            .annotation(position: .trailing) {
                                Text("\(total.points)")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .chartXAxis { AxisMarks(position: .bottom) }
                        .frame(height: max(120, CGFloat(totals.count) * 44))
                    }

                    Section("Daily points") {
                        Chart(daily) { row in
                            LineMark(
                                x: .value("Day", row.day, unit: .day),
                                y: .value("Points", row.points)
                            )
                            .foregroundStyle(by: .value("Person", row.name))
                            .symbol(by: .value("Person", row.name))
                            .interpolationMethod(.monotone)
                        }
                        .chartForegroundStyleScale(
                            domain: participants.map(\.name),
                            range: participants.map { Color(hex: $0.colorHex) }
                        )
                        .frame(height: 220)
                    }
                }
            }
        }
        .navigationTitle("Stats")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Picker("Window", selection: $windowDays) {
                    Text("7 days").tag(7)
                    Text("30 days").tag(30)
                }
                .pickerStyle(.segmented)
                .frame(width: 170)
            }
        }
    }
}

#Preview {
    NavigationStack {
        StatsView()
            .modelContainer(for: [Participant.self, Chore.self, Completion.self], inMemory: true)
    }
}
