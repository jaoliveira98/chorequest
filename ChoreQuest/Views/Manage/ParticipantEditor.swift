import SwiftUI
import SwiftData

/// Add or edit a participant. Pass `nil` to create a new one.
struct ParticipantEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private let participant: Participant?

    @State private var name: String
    @State private var emoji: String
    @State private var colorHex: String

    init(participant: Participant? = nil) {
        self.participant = participant
        _name = State(initialValue: participant?.name ?? "")
        _emoji = State(initialValue: participant?.emoji ?? Palette.avatarEmojis.first ?? "🙂")
        _colorHex = State(initialValue: participant?.colorHex ?? Palette.defaultColor)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 10) {
                            AvatarView(emoji: emoji, colorHex: colorHex, size: 80)
                            Text(trimmedName.isEmpty ? "New person" : trimmedName)
                                .font(.headline)
                                .foregroundStyle(trimmedName.isEmpty ? .secondary : .primary)
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                Section("Name") {
                    TextField("e.g. Alex", text: $name)
                        .textInputAutocapitalization(.words)
                }

                Section("Avatar") {
                    EmojiPicker(selection: $emoji, options: Palette.avatarEmojis)
                }

                Section("Color") {
                    ColorSwatchPicker(selection: $colorHex)
                }
            }
            .navigationTitle(participant == nil ? "New Person" : "Edit Person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    private func save() {
        if let participant {
            participant.name = trimmedName
            participant.emoji = emoji
            participant.colorHex = colorHex
        } else {
            context.insert(Participant(name: trimmedName, emoji: emoji, colorHex: colorHex))
        }
        try? context.save()
        dismiss()
    }
}

#Preview {
    ParticipantEditor()
        .modelContainer(for: [Participant.self, Chore.self, Completion.self], inMemory: true)
}
