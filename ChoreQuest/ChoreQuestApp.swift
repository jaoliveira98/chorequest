import SwiftUI
import SwiftData

/// App entry point.
///
/// Owns the SwiftData `ModelContainer` (the on-device store) and seeds the
/// default chores on first launch. All data lives locally — nothing is synced
/// or uploaded.
@main
struct ChoreQuestApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: Participant.self, Chore.self, Completion.self
            )
        } catch {
            fatalError("Failed to create the ChoreQuest data store: \(error)")
        }
        Seeder.seedIfNeeded(context: container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(container)
    }
}
