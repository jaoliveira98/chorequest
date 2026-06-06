import SwiftUI

/// A friendly, intentional-looking placeholder used while a screen is being
/// built out. Even the empty shell should feel like ChoreQuest, not a blank
/// page — so it leans on the accent color, SF Symbols, and a soft gradient.
struct PlaceholderScreen: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: systemImage)
                    .font(.system(size: 64, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)
                    .padding(28)
                    .background(.tint.opacity(0.12), in: Circle())

                VStack(spacing: 8) {
                    Text(title)
                        .font(.system(.title, design: .rounded).bold())
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 40)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.08), .clear],
                    startPoint: .top,
                    endPoint: .center
                )
                .ignoresSafeArea()
            )
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    PlaceholderScreen(
        title: "Leaderboard",
        message: "See who's winning. Coming soon.",
        systemImage: "trophy.fill"
    )
}
