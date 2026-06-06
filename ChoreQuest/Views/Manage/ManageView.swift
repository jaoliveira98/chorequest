import SwiftUI
import SwiftData

/// Manage the household: add/edit/delete people, and add/edit/archive/reorder
/// chores. This is where the data behind the game lives.
struct ManageView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \Participant.createdAt, order: .forward)
    private var participants: [Participant]

    @Query(sort: [SortDescriptor(\Chore.sortOrder), SortDescriptor(\Chore.createdAt)])
    private var chores: [Chore]

    @State private var showingNewParticipant = false
    @State private var editingParticipant: Participant?
    @State private var showingNewChore = false
    @State private var editingChore: Chore?
    @State private var participantPendingDelete: Participant?

    private var activeChores: [Chore] { chores.filter { !$0.isArchived } }
    private var archivedChores: [Chore] { chores.filter { $0.isArchived } }

    /// Places a new chore after the current highest order so it lands at the end
    /// of the grid (sortOrder is only meaningful among active chores — see
    /// `moveChores`).
    private var nextChoreSortOrder: Int {
        (chores.map(\.sortOrder).max() ?? -1) + 1
    }

    var body: some View {
        NavigationStack {
            List {
                peopleSection
                choresSection
                if !archivedChores.isEmpty { archivedSection }
            }
            .navigationTitle("Manage")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { EditButton() }
            }
            .sheet(isPresented: $showingNewParticipant) { ParticipantEditor() }
            .sheet(item: $editingParticipant) { ParticipantEditor(participant: $0) }
            .sheet(isPresented: $showingNewChore) { ChoreEditor(nextSortOrder: nextChoreSortOrder) }
            .sheet(item: $editingChore) { ChoreEditor(chore: $0) }
            .confirmationDialog(
                "Delete this person?",
                isPresented: Binding(
                    get: { participantPendingDelete != nil },
                    set: { if !$0 { participantPendingDelete = nil } }
                ),
                presenting: participantPendingDelete
            ) { person in
                Button("Delete \(person.name) & history", role: .destructive) {
                    delete(person)
                }
                Button("Cancel", role: .cancel) { }
            } message: { person in
                Text("This also removes all of \(person.name)'s logged chores. This can't be undone.")
            }
        }
    }

    // MARK: - People

    private var peopleSection: some View {
        Section {
            if participants.isEmpty {
                Text("Add the people in your household to start earning points.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            ForEach(participants) { person in
                Button {
                    editingParticipant = person
                } label: {
                    HStack(spacing: 12) {
                        AvatarView(emoji: person.emoji, colorHex: person.colorHex, size: 40)
                        Text(person.name).foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        participantPendingDelete = person
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            Button {
                showingNewParticipant = true
            } label: {
                Label("Add person", systemImage: "person.badge.plus")
            }
        } header: {
            Text("People")
        }
    }

    // MARK: - Chores

    private var choresSection: some View {
        Section {
            ForEach(activeChores) { chore in
                Button {
                    editingChore = chore
                } label: {
                    choreRow(chore)
                }
                .swipeActions(edge: .leading) {
                    Button {
                        setArchived(chore, true)
                    } label: {
                        Label("Archive", systemImage: "archivebox")
                    }
                    .tint(.orange)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        delete(chore)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .onMove(perform: moveChores)

            Button {
                showingNewChore = true
            } label: {
                Label("Add chore", systemImage: "plus.circle")
            }
        } header: {
            HStack {
                Text("Chores")
                Spacer()
                Text("\(activeChores.count)").foregroundStyle(.secondary)
            }
        } footer: {
            Text("Swipe to archive or delete. Tap Edit to drag and reorder.")
        }
    }

    private var archivedSection: some View {
        Section("Archived") {
            ForEach(archivedChores) { chore in
                choreRow(chore)
                    .foregroundStyle(.secondary)
                    .swipeActions(edge: .leading) {
                        Button {
                            setArchived(chore, false)
                        } label: {
                            Label("Restore", systemImage: "arrow.uturn.backward")
                        }
                        .tint(.green)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            delete(chore)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
    }

    private func choreRow(_ chore: Chore) -> some View {
        HStack(spacing: 12) {
            AvatarView(emoji: chore.emoji, colorHex: chore.colorHex ?? Palette.defaultColor, size: 40)
            Text(chore.name).foregroundStyle(.primary)
            Spacer()
            Text("\(chore.points) \(chore.points == 1 ? "pt" : "pts")")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(.tint)
        }
    }

    // MARK: - Mutations

    private func moveChores(from offsets: IndexSet, to destination: Int) {
        // Renumber the active chores densely; archived chores keep their own
        // order, which is fine since the two are always shown in separate lists.
        var reordered = activeChores
        reordered.move(fromOffsets: offsets, toOffset: destination)
        for (index, chore) in reordered.enumerated() {
            chore.sortOrder = index
        }
        context.saveChanges()
    }

    private func setArchived(_ chore: Chore, _ archived: Bool) {
        chore.isArchived = archived
        context.saveChanges()
    }

    private func delete(_ chore: Chore) {
        context.delete(chore)
        context.saveChanges()
    }

    private func delete(_ person: Participant) {
        context.delete(person)
        context.saveChanges()
        participantPendingDelete = nil
    }
}

#Preview {
    ManageView()
        .modelContainer(for: [Participant.self, Chore.self, Completion.self], inMemory: true)
}
