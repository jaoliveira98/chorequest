import SwiftUI

/// Horizontal avatar selector. Used in two places:
/// - **Log** as a sticky "who's logging?" picker (no "All" option).
/// - **History** as a filter, where `includeAllOption` adds a leading "All" chip
///   (selection `nil` = everyone).
struct ParticipantChips: View {
    let participants: [Participant]
    @Binding var selection: Participant?
    /// When true, shows a leading "All" chip that sets `selection` to nil.
    var includeAllOption: Bool = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                if includeAllOption { allChip }
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

    private var isAllSelected: Bool { selection == nil }

    private var allChip: some View {
        Button {
            selection = nil
            Haptics.selection()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.tint)
                    .frame(width: 56, height: 56)
                    .background(Color.accentColor.opacity(0.18), in: Circle())
                    .overlay(
                        Circle().strokeBorder(
                            Color.accentColor,
                            lineWidth: isAllSelected ? 3 : 0
                        )
                    )
                Text("All")
                    .font(.caption.weight(isAllSelected ? .semibold : .regular))
                    .lineLimit(1)
                    .foregroundStyle(isAllSelected ? .primary : .secondary)
            }
            .frame(width: 72)
            .scaleEffect(isAllSelected ? 1.06 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isAllSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("All"))
        .accessibilityAddTraits(isAllSelected ? [.isSelected] : [])
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
