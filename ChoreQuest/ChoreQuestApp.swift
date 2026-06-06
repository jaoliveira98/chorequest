import SwiftUI
import SwiftData

/// App entry point.
///
/// Owns the SwiftData `ModelContainer` (the on-device store), seeds default
/// chores on first launch, and owns the `PhoneSyncManager` that mirrors data to
/// (and receives logs from) a paired Apple Watch. All data stays local; the
/// phone is the source of truth.
@main
struct ChoreQuestApp: App {
    let container: ModelContainer
    @StateObject private var sync: PhoneSyncManager
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let container: ModelContainer
        do {
            container = try ModelContainer(
                for: Participant.self, Chore.self, Completion.self
            )
        } catch {
            fatalError("Failed to create the ChoreQuest data store: \(error)")
        }
        self.container = container
        Seeder.seedIfNeeded(context: container.mainContext)
        _sync = StateObject(wrappedValue: PhoneSyncManager(modelContainer: container))
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(sync)
                .task { sync.activate() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { sync.pushSnapshot() }
                }
        }
        .modelContainer(container)
    }
}
