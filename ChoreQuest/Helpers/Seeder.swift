import Foundation
import SwiftData

/// Seeds a starter set of common chores on first launch so the app feels alive
/// immediately and quick-logging works right away. Participants are intentionally
/// not seeded — the user adds their own household.
enum Seeder {
    private static let didSeedKey = "didSeedDefaultChores.v1"

    struct SeedChore {
        let name: String
        let emoji: String
        let points: Int
        let colorHex: String
    }

    static let defaultChores: [SeedChore] = [
        .init(name: "Dog pad",      emoji: "🐕", points: 1, colorHex: "#A1887F"),
        .init(name: "Pet care",     emoji: "🐾", points: 2, colorHex: "#FFB74D"),
        .init(name: "Feed dog",     emoji: "🦴", points: 1, colorHex: "#BA68C8"),
        .init(name: "Dishes",       emoji: "🍽️", points: 2, colorHex: "#4FC3F7"),
        .init(name: "Store dishes", emoji: "🗄️", points: 1, colorHex: "#4DD0E1"),
        .init(name: "Make bed",     emoji: "🛏️", points: 1, colorHex: "#9575CD"),
        .init(name: "Cook",         emoji: "🍳", points: 3, colorHex: "#FF8A65"),
        .init(name: "Tidy up",      emoji: "🧸", points: 1, colorHex: "#F06292"),
        .init(name: "Laundry",      emoji: "🧺", points: 1, colorHex: "#4DD0E1"),
        .init(name: "Hang Clothes", emoji: "👕", points: 2, colorHex: "#4DB6AC"),
        .init(name: "House clean",  emoji: "🧹", points: 2, colorHex: "#BA68C8"),
        .init(name: "Trash",        emoji: "🗑️", points: 2, colorHex: "#90A4AE"),
        .init(name: "Admin",        emoji: "🗂️", points: 2, colorHex: "#7C5CFF"),
        .init(name: "Groceries",    emoji: "🛒", points: 2, colorHex: "#81C784"),
        .init(name: "Bathroom",     emoji: "🚽", points: 4, colorHex: "#26A69A")
    ]

    /// Inserts the default chores exactly once (tracked by a UserDefaults flag so
    /// it never re-seeds, even if the user later deletes every chore).
    ///
    /// `defaults` is injectable so tests can use an isolated suite.
    static func seedIfNeeded(context: ModelContext, defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: didSeedKey) else { return }

        insertDefaultChores(into: context)

        do {
            try context.save()
            defaults.set(true, forKey: didSeedKey)
        } catch {
            // If saving failed, leave the flag unset so we retry next launch.
            print("ChoreQuest: failed to seed default chores — \(error)")
        }
    }

    /// Deletes every existing chore and re-inserts the current default set.
    /// Logged completions are preserved (their chore link nullifies; the chore
    /// name/emoji/points snapshots on each completion keep history readable).
    /// Used by Manage's "Reset chores to defaults" so the new defaults can be
    /// applied to an already-seeded install without reinstalling.
    static func resetChores(context: ModelContext) {
        do {
            // Soft-delete existing chores (so the removal propagates via sync)
            // and skip ones already gone.
            for chore in try context.fetch(FetchDescriptor<Chore>()) where !chore.isSoftDeleted {
                chore.softDelete()
            }
            insertDefaultChores(into: context)
            try context.save()
        } catch {
            context.rollback()
            print("ChoreQuest: failed to reset chores — \(error)")
        }
    }

    private static func insertDefaultChores(into context: ModelContext) {
        for (index, seed) in defaultChores.enumerated() {
            context.insert(
                Chore(
                    name: seed.name,
                    emoji: seed.emoji,
                    points: seed.points,
                    colorHex: seed.colorHex,
                    sortOrder: index
                )
            )
        }
    }
}
