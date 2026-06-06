import SwiftUI
import SwiftData

/// Ranks participants by points earned in the selected time range, with top-3
/// medals, all-time streaks, and animated totals.
struct LeaderboardView: View {
    @Query(sort: \Participant.createdAt, order: .forward)
    private var participants: [Participant]

    @AppStorage("leaderboardRange") private var rangeRaw: String = TimeRange.week.rawValue

    private var range: TimeRange {
        TimeRange(rawValue: rangeRaw) ?? .week
    }

    private struct Standing: Identifiable {
        let id: PersistentIdentifier
        let participant: Participant
        let points: Int
        let streak: Int
    }

    private var standings: [Standing] {
        let lower = range.lowerBound
        return participants
            .map { person in
                let points = person.completions.reduce(0) { total, completion in
                    if let lower, completion.completedAt < lower { return total }
                    return total + completion.pointsAwarded
                }
                let activeDays = Set(person.completions.map { DateUtils.startOfDay($0.completedAt) })
                return Standing(
                    id: person.persistentModelID,
                    participant: person,
                    points: points,
                    streak: DateUtils.streak(activeDays: activeDays)
                )
            }
            .sorted { lhs, rhs in
                if lhs.points != rhs.points { return lhs.points > rhs.points }
                return lhs.participant.name.localizedCaseInsensitiveCompare(rhs.participant.name) == .orderedAscending
            }
    }

    var body: some View {
        NavigationStack {
            Group {
                if participants.isEmpty {
                    emptyState
                } else {
                    leaderboardList
                }
            }
            .navigationTitle("Leaderboard")
        }
    }

    private var leaderboardList: some View {
        List {
            Section {
                Picker("Range", selection: Binding(
                    get: { range },
                    set: { rangeRaw = $0.rawValue }
                )) {
                    ForEach(TimeRange.allCases) { range in
                        Text(range.title).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
            }

            Section {
                ForEach(Array(standings.enumerated()), id: \.element.id) { index, standing in
                    LeaderboardRow(
                        rank: index + 1,
                        participant: standing.participant,
                        points: standing.points,
                        streak: standing.streak,
                        highlightTop: standing.points > 0
                    )
                }
            }
        }
        // Animate rank reordering both when the range changes and when points
        // change from a new log or a deleted completion.
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: standings.map(\.points))
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No one's playing yet",
            systemImage: "trophy",
            description: Text("Add people in the Manage tab, then log a few chores to start the competition.")
        )
    }
}

#Preview {
    LeaderboardView()
        .modelContainer(for: [Participant.self, Chore.self, Completion.self], inMemory: true)
}
