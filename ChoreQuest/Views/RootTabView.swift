import SwiftUI

/// The root tab bar.
/// - Leaderboard (CQ-4)
/// - Log — the quick-add flow, the heart of the app (CQ-3)
/// - History (CQ-4)
/// - Manage — people & chores (CQ-2)
struct RootTabView: View {
    var body: some View {
        TabView {
            LeaderboardView()
                .tabItem { Label("Leaderboard", systemImage: "trophy.fill") }

            QuickLogView()
                .tabItem { Label("Log", systemImage: "plus.circle.fill") }

            HistoryView()
                .tabItem { Label("History", systemImage: "clock.fill") }

            ManageView()
                .tabItem { Label("Manage", systemImage: "slider.horizontal.3") }
        }
    }
}

#Preview {
    RootTabView()
        .modelContainer(for: [Participant.self, Chore.self, Completion.self], inMemory: true)
}
