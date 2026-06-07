import AppIntents

/// Registers ChoreQuest's actions with the Shortcuts app and Siri. Each appears
/// automatically as a ready-made shortcut and an "Add to Siri" phrase.
struct ChoreQuestShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogChoreIntent(),
            phrases: [
                "Log a chore in \(.applicationName)",
                "Log \(\.$chore) in \(.applicationName)",
                "Add a chore in \(.applicationName)"
            ],
            shortTitle: "Log Chore",
            systemImageName: "checklist"
        )
        AppShortcut(
            intent: GetPointsIntent(),
            phrases: [
                "Get points in \(.applicationName)",
                "How many points in \(.applicationName)",
                "Check \(.applicationName) points"
            ],
            shortTitle: "Get Points",
            systemImageName: "star.fill"
        )
        AppShortcut(
            intent: LeaderboardIntent(),
            phrases: [
                "Show the \(.applicationName) leaderboard",
                "Who's winning in \(.applicationName)",
                "\(.applicationName) standings"
            ],
            shortTitle: "Leaderboard",
            systemImageName: "trophy.fill"
        )
    }
}
