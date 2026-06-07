import SwiftData

/// The single SwiftData container, shared by the app and the App Intents (Siri /
/// Shortcuts). Intents may run in a background launch of the app, so they need
/// the same on-disk store the UI uses.
enum AppModelContainer {
    static let shared: ModelContainer = {
        do {
            return try ModelContainer(for: Participant.self, Chore.self, Completion.self)
        } catch {
            fatalError("Failed to create the ChoreQuest data store: \(error)")
        }
    }()
}
