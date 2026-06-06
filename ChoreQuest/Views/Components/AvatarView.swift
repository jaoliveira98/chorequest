import SwiftUI

/// A circular avatar showing an emoji on a tinted background. Reused across the
/// Manage, Leaderboard, Log, and History screens.
struct AvatarView: View {
    let emoji: String
    let colorHex: String
    var size: CGFloat = 44

    var body: some View {
        Text(emoji)
            .font(.system(size: size * 0.52))
            .minimumScaleFactor(0.5)
            .frame(width: size, height: size)
            .background(Color(hex: colorHex).opacity(0.22), in: Circle())
            .overlay(
                Circle().strokeBorder(Color(hex: colorHex).opacity(0.55), lineWidth: 1.5)
            )
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack {
        AvatarView(emoji: "🦸", colorHex: "#7C5CFF")
        AvatarView(emoji: "🐼", colorHex: "#4FC3F7", size: 64)
        AvatarView(emoji: "🦊", colorHex: "#FF8A65", size: 32)
    }
    .padding()
}
