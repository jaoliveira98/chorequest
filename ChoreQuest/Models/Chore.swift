import Foundation
import SwiftData

/// A type of chore that can be completed (e.g. "Dishes"). This is the template;
/// each time someone does it, a `Completion` is logged.
///
/// `points` defaults to 1 but is fully customizable per chore so bigger jobs can
/// be worth more — the core of the "game".
@Model
final class Chore {
    var uuid: UUID = UUID()
    var name: String = ""
    var emoji: String = "✅"
    var points: Int = 1
    /// Optional accent color; when nil the UI falls back to the app accent.
    var colorHex: String?
    /// Archived chores are hidden from the quick-log grid but keep their history.
    var isArchived: Bool = false
    /// Manual ordering for the quick-log grid (lower = earlier).
    var sortOrder: Int = 0
    var createdAt: Date = Date.now

    /// Deleting a chore keeps past completions readable thanks to the snapshot
    /// fields on `Completion`; this relationship is nullified, not cascaded.
    @Relationship(inverse: \Completion.chore)
    var completions: [Completion] = []

    init(
        name: String,
        emoji: String = "✅",
        points: Int = 1,
        colorHex: String? = nil,
        isArchived: Bool = false,
        sortOrder: Int = 0,
        createdAt: Date = .now
    ) {
        self.uuid = UUID()
        self.name = name
        self.emoji = emoji
        self.points = points
        self.colorHex = colorHex
        self.isArchived = isArchived
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }
}
