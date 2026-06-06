import SwiftUI
import SwiftData

/// The core fast-add flow: choose who's logging once, then tap chores to log
/// them — one tap per completion. Long-press a chore to log it for someone else.
/// Every log fires a haptic, a confetti burst, and a celebratory reward pill.
struct QuickLogView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query(sort: \Participant.createdAt, order: .forward)
    private var participants: [Participant]

    @Query(sort: [SortDescriptor(\Chore.sortOrder), SortDescriptor(\Chore.createdAt)])
    private var allChores: [Chore]

    /// Active (non-archived) chores shown in the quick-log grid. Filtering in
    /// code (rather than a #Predicate in the @Query) keeps the query expression
    /// simple enough for the Swift type-checker and matches ManageView.
    private var chores: [Chore] { allChores.filter { !$0.isArchived } }

    @AppStorage("lastLoggerUUID") private var lastLoggerUUID: String = ""

    @State private var selected: Participant?
    @State private var confettiTrigger = 0
    @State private var reward: Reward?
    @State private var showingNewChore = false
    @State private var showingNewParticipant = false

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 12)]

    private var nextChoreSortOrder: Int {
        (chores.map(\.sortOrder).max() ?? -1) + 1
    }

    var body: some View {
        NavigationStack {
            Group {
                if participants.isEmpty {
                    emptyPeoplePrompt
                } else {
                    content
                }
            }
            .navigationTitle("Log a Chore")
            .overlay { ConfettiView(trigger: confettiTrigger).ignoresSafeArea() }
            .overlay(alignment: .top) { rewardOverlay }
            .sheet(isPresented: $showingNewChore) {
                ChoreEditor(nextSortOrder: nextChoreSortOrder)
            }
            .sheet(isPresented: $showingNewParticipant) {
                ParticipantEditor()
            }
            .onAppear(perform: restoreSelection)
            // Key on membership (not just count) so deleting one person and
            // adding another between appearances still refreshes the selection.
            .onChange(of: participants.map(\.persistentModelID)) { _, _ in restoreSelection() }
        }
    }

    // MARK: - Main content

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Who's logging?")
                        .font(.headline)
                        .padding(.horizontal)
                    ParticipantChips(participants: participants, selection: $selected)
                }

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(chores) { chore in
                        ChoreTile(chore: chore) { log(chore) }
                            .contextMenu { assignMenu(for: chore) }
                    }
                    addChoreTile
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }

    @ViewBuilder
    private func assignMenu(for chore: Chore) -> some View {
        Section("Log for…") {
            ForEach(participants) { person in
                Button {
                    log(chore, for: person)
                } label: {
                    Label(person.name, systemImage: "person.fill")
                }
            }
        }
    }

    private var addChoreTile: some View {
        Button {
            showingNewChore = true
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 30, weight: .semibold))
                Text("Add chore")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.tint)
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        .tint.opacity(0.5),
                        style: StrokeStyle(lineWidth: 1.5, dash: [6])
                    )
            )
        }
        .buttonStyle(PressableButtonStyle())
    }

    @ViewBuilder
    private var rewardOverlay: some View {
        if let reward {
            RewardPingView(reward: reward)
                .padding(.top, 6)
                .transition(.scale(scale: 0.6).combined(with: .opacity))
                .task(id: reward.id) {
                    try? await Task.sleep(for: .seconds(1.0))
                    withAnimation(.easeOut(duration: 0.3)) { self.reward = nil }
                }
        }
    }

    private var emptyPeoplePrompt: some View {
        ContentUnavailableView {
            Label("Add your household", systemImage: "person.2.fill")
        } description: {
            Text("Add the people who'll be earning points, then tap chores to log them.")
        } actions: {
            Button {
                showingNewParticipant = true
            } label: {
                Label("Add your first person", systemImage: "person.badge.plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Logging

    private func log(_ chore: Chore, for participant: Participant? = nil) {
        // Resolve who gets the points. An explicit participant (long-press) is a
        // one-off and does not change the sticky selection.
        let who: Participant
        if let participant {
            who = participant
        } else if let selected {
            who = selected
        } else if let first = participants.first {
            who = first
            selected = first
        } else {
            return
        }

        context.insert(Completion(chore: chore, participant: who))
        context.saveChanges()

        if participant == nil {
            lastLoggerUUID = who.uuid.uuidString
        }

        Haptics.success()
        if !reduceMotion {
            confettiTrigger += 1
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            reward = Reward(emoji: chore.emoji, name: chore.name, points: chore.points)
        }
    }

    // MARK: - Selection persistence

    private func restoreSelection() {
        if let selected,
           participants.contains(where: { $0.persistentModelID == selected.persistentModelID }) {
            return
        }
        selected = participants.first { $0.uuid.uuidString == lastLoggerUUID }
            ?? participants.first
    }
}

#Preview {
    QuickLogView()
        .modelContainer(for: [Participant.self, Chore.self, Completion.self], inMemory: true)
}
