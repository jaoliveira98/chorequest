import Foundation

/// Small summary the iOS app writes to a shared App Group container for the
/// home-screen widgets to read. The widget runs in a separate process and can't
/// touch the app's SwiftData store directly, so the app publishes this snapshot
/// whenever data changes. Foundation-only so it compiles into both the app and
/// the widget extension.
enum WidgetSharedConfig {
    static let appGroup = "group.com.jaoliveira98.chorequest"
}

struct WidgetSnapshot: Codable, Equatable {
    var generatedAt: Date
    var standings: [Standing]
    var todayTotal: Int
    var weekTotal: Int
    var chores: [Chore] = []   // active chores, for the Quick Log widget's buttons

    // Equality ignores generatedAt so the app can skip re-publishing (and waking
    // WidgetKit) when the actual content hasn't changed.
    static func == (lhs: WidgetSnapshot, rhs: WidgetSnapshot) -> Bool {
        lhs.standings == rhs.standings && lhs.todayTotal == rhs.todayTotal
            && lhs.weekTotal == rhs.weekTotal && lhs.chores == rhs.chores
    }

    struct Standing: Codable, Identifiable, Hashable {
        var id: UUID
        var name: String
        var emoji: String
        var colorHex: String
        var weekPoints: Int
        var todayPoints: Int
    }

    struct Chore: Codable, Identifiable, Hashable {
        var id: UUID
        var name: String
        var emoji: String
        var points: Int
        var colorHex: String?
    }

    static let empty = WidgetSnapshot(generatedAt: .distantPast, standings: [], todayTotal: 0, weekTotal: 0, chores: [])

    /// Placeholder content for the widget gallery / first render.
    static let sample = WidgetSnapshot(
        generatedAt: .now,
        standings: [
            .init(id: UUID(), name: "João", emoji: "🦸", colorHex: "#F06292", weekPoints: 24, todayPoints: 6),
            .init(id: UUID(), name: "Sofia", emoji: "🐼", colorHex: "#4DB6AC", weekPoints: 19, todayPoints: 4)
        ],
        todayTotal: 10,
        weekTotal: 43,
        chores: [
            .init(id: UUID(), name: "Dishes", emoji: "🍽️", points: 2, colorHex: "#4FC3F7"),
            .init(id: UUID(), name: "Dog pad", emoji: "🧼", points: 1, colorHex: "#81C784"),
            .init(id: UUID(), name: "Trash", emoji: "🗑️", points: 2, colorHex: "#A1887F"),
            .init(id: UUID(), name: "Cook", emoji: "🍳", points: 3, colorHex: "#FF8A65")
        ]
    )
}

/// Read/write the snapshot via the shared App Group. Foundation-only (no WidgetKit)
/// so both targets can use it; the app calls `WidgetCenter.reloadAllTimelines()`
/// separately after saving.
enum WidgetStore {
    private static let key = "widget.snapshot.v1"

    static func save(_ snapshot: WidgetSnapshot) {
        guard let defaults = UserDefaults(suiteName: WidgetSharedConfig.appGroup),
              let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    static func load() -> WidgetSnapshot {
        guard let defaults = UserDefaults(suiteName: WidgetSharedConfig.appGroup),
              let data = defaults.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else {
            return .empty
        }
        return snapshot
    }
}
