import Foundation
import SwiftData

extension ModelContext {
    /// Saves pending changes, surfacing failures instead of swallowing them.
    ///
    /// The whole point of ChoreQuest is to never lose data, so a failed write
    /// must not pass silently: it trips an assertion in debug builds (so it's
    /// caught during development) and logs in release builds.
    func saveChanges(_ caller: StaticString = #function) {
        guard hasChanges else { return }
        do {
            try save()
        } catch {
            assertionFailure("ChoreQuest: save failed in \(caller): \(error)")
            print("ChoreQuest: save failed in \(caller): \(error)")
        }
    }
}
