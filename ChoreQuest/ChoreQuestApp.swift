import SwiftUI

/// App entry point.
///
/// CQ-1 sets up the buildable shell only. The SwiftData `ModelContainer` and
/// first-launch seeding are wired up in CQ-2.
@main
struct ChoreQuestApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
    }
}
