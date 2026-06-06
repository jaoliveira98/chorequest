import SwiftUI

/// A short-lived celebratory pill shown when a chore is logged, e.g. "🍽️ Dishes +2".
struct Reward: Identifiable {
    let id = UUID()
    let emoji: String
    let name: String
    let points: Int
}

struct RewardPingView: View {
    let reward: Reward
    @State private var rise = false

    var body: some View {
        HStack(spacing: 8) {
            Text(reward.emoji)
                .font(.title3)
            Text(reward.name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Text("+\(reward.points)")
                .font(.subheadline.weight(.heavy).monospacedDigit())
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(.tint, in: Capsule())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.tint.opacity(0.3)))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        .offset(y: rise ? -12 : 18)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { rise = true }
        }
        .accessibilityLabel(Text("Logged \(reward.name), plus \(reward.points) points"))
    }
}

#Preview {
    RewardPingView(reward: Reward(emoji: "🍽️", name: "Dishes", points: 2))
}
