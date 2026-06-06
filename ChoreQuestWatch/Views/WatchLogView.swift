import SwiftUI
import WatchKit

/// The wrist logging screen: pick who's logging, tap a chore to log it.
struct WatchLogView: View {
    @EnvironmentObject private var sync: WatchSyncManager
    @AppStorage("watch.lastLoggerUUID") private var lastLoggerUUID = ""

    @State private var selectedUUID: UUID?
    @State private var confirmation: String?

    private var participants: [ParticipantDTO] { sync.snapshot.participants }
    private var chores: [ChoreDTO] { sync.snapshot.chores }

    private var selected: ParticipantDTO? {
        participants.first { $0.uuid == selectedUUID }
            ?? participants.first { $0.uuid.uuidString == lastLoggerUUID }
            ?? participants.first
    }

    var body: some View {
        NavigationStack {
            Group {
                if participants.isEmpty {
                    ContentUnavailableView(
                        "Open on iPhone",
                        systemImage: "iphone",
                        description: Text("Add people in ChoreQuest on your iPhone, then log from here.")
                    )
                } else {
                    content
                }
            }
            .navigationTitle("ChoreQuest")
            .overlay(alignment: .center) { confirmationPill }
            .task(id: participants.map(\.id)) {
                // Commit the resolved selection so it stays stable across snapshot
                // updates (and drop it if that person was removed).
                if selectedUUID == nil || !participants.contains(where: { $0.uuid == selectedUUID }) {
                    selectedUUID = selected?.uuid
                }
            }
        }
    }

    private var content: some View {
        List {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(participants) { person in
                            personChip(person)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .listRowInsets(EdgeInsets())
            } header: {
                if let selected {
                    Text("\(selected.name) · \(selected.points ?? 0) pts today")
                } else {
                    Text("Who's logging?")
                }
            }

            Section("Tap to log") {
                ForEach(chores) { chore in
                    Button {
                        log(chore)
                    } label: {
                        HStack(spacing: 8) {
                            Text(chore.emoji)
                            Text(chore.name).lineLimit(1)
                            Spacer()
                            Text("\(chore.points)")
                                .font(.caption.bold().monospacedDigit())
                                .foregroundStyle(Color(hex: chore.colorHex))
                        }
                    }
                }
            }
        }
    }

    private func personChip(_ person: ParticipantDTO) -> some View {
        let isSelected = selected?.uuid == person.uuid
        return Button {
            selectedUUID = person.uuid
            lastLoggerUUID = person.uuid.uuidString
            WKInterfaceDevice.current().play(.click)
        } label: {
            AvatarView(emoji: person.emoji, colorHex: person.colorHex, size: 38)
                .overlay(
                    Circle().strokeBorder(Color(hex: person.colorHex), lineWidth: isSelected ? 3 : 0)
                )
        }
        .buttonStyle(.plain)
    }

    private func log(_ chore: ChoreDTO) {
        guard let person = selected else { return }
        sync.log(participant: person, chore: chore)
        lastLoggerUUID = person.uuid.uuidString
        WKInterfaceDevice.current().play(.success)
        withAnimation { confirmation = "\(chore.emoji) +\(chore.points)" }
    }

    @ViewBuilder
    private var confirmationPill: some View {
        if let confirmation {
            Text(confirmation)
                .font(.headline)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .transition(.scale.combined(with: .opacity))
                .task(id: confirmation) {
                    try? await Task.sleep(for: .seconds(1.0))
                    withAnimation { self.confirmation = nil }
                }
        }
    }
}
