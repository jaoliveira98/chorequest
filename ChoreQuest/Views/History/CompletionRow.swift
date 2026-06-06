import SwiftUI

/// One logged chore in the history timeline: what, who, when, and how many points.
struct CompletionRow: View {
    let completion: Completion

    private var choreColor: Color {
        Color(hex: completion.chore?.colorHex ?? Palette.defaultColor)
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(completion.choreEmoji)
                .font(.title3)
                .frame(width: 40, height: 40)
                .background(choreColor.opacity(0.18), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(completion.choreName)
                    .font(.body.weight(.medium))
                HStack(spacing: 4) {
                    if let person = completion.participant {
                        Text(person.emoji)
                        Text(person.name)
                    } else {
                        Text("Someone")
                    }
                    Text("·")
                    Text(DateUtils.time(completion.completedAt))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text("+\(completion.pointsAwarded)")
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(.tint)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(
            "\(completion.choreName), by \(completion.participant?.name ?? "someone"), at \(DateUtils.time(completion.completedAt)), \(completion.pointsAwarded) points"
        ))
    }
}
