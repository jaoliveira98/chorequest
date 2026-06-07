import AppIntents
import SwiftData

/// The action run when you tap a chore on the interactive Quick Log widget. It
/// logs the chore for the given person directly into the shared store, then
/// refreshes the widgets. Compiled into both the app and the widget extension;
/// the system runs it in the app's process. Hidden from the Shortcuts gallery
/// (it's a widget-button action, not a standalone shortcut).
struct QuickLogIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick Log a Chore"
    static var isDiscoverable: Bool { false }

    @Parameter(title: "Chore") var choreID: String
    @Parameter(title: "Person") var participantID: String

    init() {}
    init(choreID: UUID, participantID: UUID) {
        self.choreID = choreID.uuidString
        self.participantID = participantID.uuidString
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let context = AppModelContainer.shared.mainContext
        guard let choreUUID = UUID(uuidString: choreID),
              let personUUID = UUID(uuidString: participantID),
              let chore = (try? context.fetch(FetchDescriptor<Chore>()))?.first(where: { $0.uuid == choreUUID }),
              let person = (try? context.fetch(FetchDescriptor<Participant>()))?.first(where: { $0.uuid == personUUID })
        else {
            return .result()
        }
        context.insert(Completion(chore: chore, participant: person))
        try context.save()
        WidgetUpdater.refresh(context)
        return .result()
    }
}
