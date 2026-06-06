import SwiftUI

/// watchOS app entry point. Owns the WatchConnectivity manager that mirrors data
/// from — and sends logs to — the paired iPhone. The phone is the source of
/// truth; the watch keeps a light cached snapshot so it works before the phone
/// connects.
@main
struct ChoreQuestWatchApp: App {
    @StateObject private var sync = WatchSyncManager()

    var body: some Scene {
        WindowGroup {
            WatchLogView()
                .environmentObject(sync)
                .task { sync.activate() }
        }
    }
}
