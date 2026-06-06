import SwiftUI

/// The root tab bar. Tabs are filled in by later tickets:
/// - Leaderboard (CQ-4)
/// - History (CQ-4)
/// - Manage (CQ-2)
///
/// The prominent "Log a chore" quick-add flow (CQ-3) is reachable from
/// Leaderboard and is the heart of the app.
struct RootTabView: View {
    var body: some View {
        TabView {
            PlaceholderScreen(
                title: "Leaderboard",
                message: "See who's winning. Coming in CQ-4.",
                systemImage: "trophy.fill"
            )
            .tabItem { Label("Leaderboard", systemImage: "trophy.fill") }

            PlaceholderScreen(
                title: "History",
                message: "Every chore, with the day and time it was done. Coming in CQ-4.",
                systemImage: "clock.fill"
            )
            .tabItem { Label("History", systemImage: "clock.fill") }

            PlaceholderScreen(
                title: "Manage",
                message: "Add people and chores. Coming in CQ-2.",
                systemImage: "slider.horizontal.3"
            )
            .tabItem { Label("Manage", systemImage: "slider.horizontal.3") }
        }
    }
}

#Preview {
    RootTabView()
}
