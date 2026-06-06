import SwiftUI

/// Horizontal "who's logging?" selector. The chosen person sticks so multiple
/// chores can be logged in a row with a single tap each.
struct ParticipantChips: View {
    let participants: [Participant]
    @Binding var selection: Participant?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(participants) { person in
                    chip(person)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
    }

    private func isSelected(_ person: Participant) -> Bool {
        selection?.persistentModelID == person.persistentModelID
    }

    private func chip(_ person: Participant) -> some View {
        Button {
            selection = person
            Haptics.selection()
        } label: {
            VStack(spacing: 6) {
                AvatarView(emoji: person.emoji, colorHex: person.colorHex, size: 56)
                    .overlay(
                        Circle().strokeBorder(
                            Color(hex: person.colorHex),
                            lineWidth: isSelected(person) ? 3 : 0
                        )
                    )
                Text(person.name)
                    .font(.caption.weight(isSelected(person) ? .semibold : .regular))
                    .lineLimit(1)
                    .foregroundStyle(isSelected(person) ? .primary : .secondary)
            }
            .frame(width: 72)
            .scaleEffect(isSelected(person) ? 1.06 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected(person))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(person.name))
        .accessibilityAddTraits(isSelected(person) ? [.isSelected] : [])
    }
}
