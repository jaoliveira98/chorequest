import SwiftUI
import SwiftData

/// Add or edit a chore. Pass `nil` to create a new one; `nextSortOrder` places a
/// freshly created chore at the end of the list.
struct ChoreEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private let chore: Chore?
    private let nextSortOrder: Int

    @State private var name: String
    @State private var emoji: String
    @State private var points: Int
    @State private var colorHex: String
    @State private var isArchived: Bool

    init(chore: Chore? = nil, nextSortOrder: Int = 0) {
        self.chore = chore
        self.nextSortOrder = nextSortOrder
        _name = State(initialValue: chore?.name ?? "")
        _emoji = State(initialValue: chore?.emoji ?? Palette.choreEmojis.first ?? "✅")
        _points = State(initialValue: chore?.points ?? 1)
        _colorHex = State(initialValue: chore?.colorHex ?? Palette.defaultColor)
        _isArchived = State(initialValue: chore?.isArchived ?? false)
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
                            Text(trimmedName.isEmpty ? "New chore" : trimmedName)
                                .font(.headline)
                                .foregroundStyle(trimmedName.isEmpty ? .secondary : .primary)
                            Text("\(points) \(points == 1 ? "point" : "points")")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.tint)
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                Section("Name") {
                    TextField("e.g. Dishes", text: $name)
                        .textInputAutocapitalization(.sentences)
                }

                Section("Points") {
                    Stepper(value: $points, in: 1...50) {
                        HStack {
                            Text("Worth")
                            Spacer()
                            Text("\(points)")
                                .font(.body.monospacedDigit().weight(.semibold))
                                .foregroundStyle(.tint)
                        }
                    }
                }

                Section("Icon") {
                    EmojiPicker(selection: $emoji, options: Palette.choreEmojis)
                }

                Section("Color") {
                    ColorSwatchPicker(selection: $colorHex)
                }

                if chore != nil {
                    Section {
                        Toggle("Archived", isOn: $isArchived)
                    } footer: {
                        Text("Archived chores are hidden from quick-log but keep their history.")
                    }
                }
            }
            .navigationTitle(chore == nil ? "New Chore" : "Edit Chore")
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
        if let chore {
            chore.name = trimmedName
            chore.emoji = emoji
            chore.points = points
            chore.colorHex = colorHex
            chore.isArchived = isArchived
        } else {
            context.insert(
                Chore(
                    name: trimmedName,
                    emoji: emoji,
                    points: points,
                    colorHex: colorHex,
                    sortOrder: nextSortOrder
                )
            )
        }
        try? context.save()
        dismiss()
    }
}

#Preview {
    ChoreEditor()
        .modelContainer(for: [Participant.self, Chore.self, Completion.self], inMemory: true)
}
