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
        .init(name: "Dishes",   emoji: "🍽️", points: 2, colorHex: "#4FC3F7"),
        .init(name: "Trash",    emoji: "🗑️", points: 1, colorHex: "#A1887F"),
        .init(name: "Vacuum",   emoji: "🧹", points: 2, colorHex: "#BA68C8"),
        .init(name: "Laundry",  emoji: "🧺", points: 3, colorHex: "#4DD0E1"),
        .init(name: "Cook",     emoji: "🍳", points: 3, colorHex: "#FF8A65"),
        .init(name: "Tidy up",  emoji: "🧸", points: 1, colorHex: "#F06292"),
        .init(name: "Bathroom", emoji: "🚽", points: 4, colorHex: "#4DB6AC"),
        .init(name: "Groceries",emoji: "🛒", points: 3, colorHex: "#81C784"),
        .init(name: "Pet care", emoji: "🐾", points: 2, colorHex: "#FFB74D"),
        .init(name: "Make bed", emoji: "🛏️", points: 1, colorHex: "#9575CD")
    ]

    /// Inserts the default chores exactly once (tracked by a UserDefaults flag so
    /// it never re-seeds, even if the user later deletes every chore).
    static func seedIfNeeded(context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: didSeedKey) else { return }

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

        do {
            try context.save()
            UserDefaults.standard.set(true, forKey: didSeedKey)
        } catch {
            // If saving failed, leave the flag unset so we retry next launch.
            print("ChoreQuest: failed to seed default chores — \(error)")
        }
    }
}
