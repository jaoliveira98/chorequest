import SwiftUI

/// A single tappable chore in the quick-log grid. One tap logs it.
struct ChoreTile: View {
    let chore: Chore
    let action: () -> Void

    private var color: Color { Color(hex: chore.colorHex ?? Palette.defaultColor) }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(chore.emoji)
                    .font(.system(size: 40))
                Text(chore.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.primary)
                Text("\(chore.points) \(chore.points == 1 ? "pt" : "pts")")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(color)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .padding(.horizontal, 6)
            .background(color.opacity(0.16), in: RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(color.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(Text("\(chore.name), \(chore.points) points"))
        .accessibilityHint(Text("Double-tap to log. Touch and hold to log for someone else."))
    }
}

#Preview {
    ChoreTile(chore: Chore(name: "Dishes", emoji: "🍽️", points: 2, colorHex: "#4FC3F7")) {}
        .frame(width: 120)
        .padding()
}
