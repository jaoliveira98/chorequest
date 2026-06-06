import SwiftUI
import SwiftData

/// Ranks participants by points earned in the selected time range, with top-3
/// medals, all-time streaks, and animated totals.
struct LeaderboardView: View {
    @Query(sort: \Participant.createdAt, order: .forward)
    private var participants: [Participant]

    @EnvironmentObject private var cloud: CloudSyncManager

    @AppStorage("leaderboardRange") private var rangeRaw: String = TimeRange.week.rawValue

    @State private var showingStats = false

    private var range: TimeRange {
        TimeRange(rawValue: rangeRaw) ?? .week
    }

    private var activeParticipants: [Participant] {
        participants.filter { !$0.isSoftDeleted }
    }

    private struct Standing: Identifiable {
        let id: PersistentIdentifier
        let participant: Participant
        let points: Int
        let streak: Int
    }

    private var standings: [Standing] {
        let lower = range.lowerBound
        return activeParticipants
            .map { person in
                let liveCompletions = person.completions.filter { !$0.isSoftDeleted }
                let points = liveCompletions.reduce(0) { total, completion in
                    if let lower, completion.completedAt < lower { return total }
                    return total + completion.pointsAwarded
                }
                let activeDays = Set(liveCompletions.map { DateUtils.startOfDay($0.completedAt) })
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
                if activeParticipants.isEmpty {
                    emptyState
                } else {
                    leaderboardList
                }
            }
            .navigationTitle("Leaderboard")
            .toolbar {
                if !activeParticipants.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingStats = true
                        } label: {
                            Image(systemName: "chart.bar.xaxis")
                        }
                        .accessibilityLabel("Stats")
                    }
                }
            }
            .sheet(isPresented: $showingStats) {
                NavigationStack {
                    StatsView()
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Done") { showingStats = false }
                            }
                        }
                }
            }
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
        .refreshable { await cloud.sync() }
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
    let container = try! ModelContainer(
        for: Participant.self, Chore.self, Completion.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return LeaderboardView()
        .modelContainer(container)
        .environmentObject(CloudSyncManager(container: container))
}
