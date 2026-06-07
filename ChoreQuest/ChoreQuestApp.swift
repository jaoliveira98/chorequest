import SwiftUI
import SwiftData

/// App entry point.
///
/// Owns the SwiftData `ModelContainer` (local source of truth), seeds default
/// chores on first launch, and owns the sync managers: `PhoneSyncManager` (Apple
/// Watch) and `CloudSyncManager` (cross-phone sync via Supabase). Both run on
/// foreground; the app keeps working offline regardless.
@main
struct ChoreQuestApp: App {
    let container = AppModelContainer.shared
    @StateObject private var watchSync: PhoneSyncManager
    @StateObject private var cloudSync: CloudSyncManager
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Shared with the App Intents (Siri / Shortcuts) so both use one store.
        let container = AppModelContainer.shared
        Seeder.seedIfNeeded(context: container.mainContext)
        _watchSync = StateObject(wrappedValue: PhoneSyncManager(modelContainer: container))
        _cloudSync = StateObject(wrappedValue: CloudSyncManager(container: container))
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(watchSync)
                .environmentObject(cloudSync)
                .task {
                    watchSync.activate()
                    WidgetUpdater.refresh(container.mainContext)
                    await cloudSync.sync()
                    cloudSync.startAutoSync()
                }
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active:
                        watchSync.pushSnapshot()
                        WidgetUpdater.refresh(container.mainContext)
                        Task { await cloudSync.sync() }
                        cloudSync.startAutoSync()
                    case .background, .inactive:
                        cloudSync.stopAutoSync()
                    @unknown default:
                        break
                    }
                }
        }
        .modelContainer(container)
    }
}
