import Foundation

/// Small summary the iOS app writes to a shared App Group container for the
/// home-screen widgets to read. The widget runs in a separate process and can't
/// touch the app's SwiftData store directly, so the app publishes this snapshot
/// whenever data changes. Foundation-only so it compiles into both the app and
/// the widget extension.
enum WidgetSharedConfig {
    static let appGroup = "group.com.jaoliveira98.chorequest"
}

struct WidgetSnapshot: Codable {
    var generatedAt: Date
    var standings: [Standing]
    var todayTotal: Int
    var weekTotal: Int

    struct Standing: Codable, Identifiable, Hashable {
        var id: UUID
        var name: String
        var emoji: String
        var colorHex: String
        var weekPoints: Int
        var todayPoints: Int
    }

    static let empty = WidgetSnapshot(generatedAt: .distantPast, standings: [], todayTotal: 0, weekTotal: 0)

    /// Placeholder content for the widget gallery / first render.
    static let sample = WidgetSnapshot(
        generatedAt: .now,
        standings: [
            .init(id: UUID(), name: "João", emoji: "🦸", colorHex: "#F06292", weekPoints: 24, todayPoints: 6),
            .init(id: UUID(), name: "Sofia", emoji: "🐼", colorHex: "#4DB6AC", weekPoints: 19, todayPoints: 4)
        ],
        todayTotal: 10,
        weekTotal: 43
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
