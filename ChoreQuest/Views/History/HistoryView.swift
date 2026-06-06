import SwiftUI
import SwiftData

/// A reverse-chronological log of every completed chore, grouped by day, showing
/// the day and time each was done. Filterable by person; swipe to delete a
/// mistaken entry.
struct HistoryView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \Completion.completedAt, order: .reverse)
    private var completions: [Completion]

    @Query(sort: \Participant.createdAt, order: .forward)
    private var participants: [Participant]

    @EnvironmentObject private var cloud: CloudSyncManager

    @State private var filter: Participant?

    private var visibleCompletions: [Completion] {
        completions.filter { !$0.isSoftDeleted && !($0.participant?.isSoftDeleted ?? false) }
    }

    private var activeParticipants: [Participant] {
        participants.filter { !$0.isSoftDeleted }
    }

    private var filtered: [Completion] {
        guard let filter else { return visibleCompletions }
        return visibleCompletions.filter {
            $0.participant?.persistentModelID == filter.persistentModelID
        }
    }

    private var filterDisplayName: String {
        let name = filter?.name ?? ""
        return name.isEmpty ? "this person" : name
    }

    /// Completions bucketed by day, newest day first.
    private var grouped: [(day: Date, items: [Completion])] {
        let buckets = Dictionary(grouping: filtered) { DateUtils.startOfDay($0.completedAt) }
        return buckets.keys.sorted(by: >).map { day in
            (day, buckets[day] ?? [])
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if visibleCompletions.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        ParticipantChips(
                            participants: activeParticipants,
                            selection: $filter,
                            includeAllOption: true
                        )
                        .padding(.vertical, 8)

                        if filtered.isEmpty {
                            ContentUnavailableView(
                                "Nothing for \(filterDisplayName)",
                                systemImage: "person.crop.circle.badge.questionmark",
                                description: Text("No chores logged by this person yet.")
                            )
                            .frame(maxHeight: .infinity)
                        } else {
                            timeline
                        }
                    }
                }
            }
            .navigationTitle("History")
        }
    }

    private var timeline: some View {
        List {
            ForEach(grouped, id: \.day) { group in
                Section(DateUtils.dayHeader(for: group.day)) {
                    ForEach(group.items) { completion in
                        CompletionRow(completion: completion)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    delete(completion)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .refreshable { await cloud.sync() }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No chores logged yet",
            systemImage: "clock",
            description: Text("Log a chore from the Log tab and it'll appear here with the day and time it was done.")
        )
    }

    private func delete(_ completion: Completion) {
        completion.softDelete()
        context.saveChanges()
        cloud.requestSync()
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Participant.self, Chore.self, Completion.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return HistoryView()
        .modelContainer(container)
        .environmentObject(CloudSyncManager(container: container))
}
