import Foundation
import SwiftData

/// A person who can complete chores and earn points. There's no limit on how
/// many participants you can add.
///
/// `uuid` is a stable identifier we control (used for JSON backup/restore in
/// CQ-5). We deliberately do **not** name it `id` — SwiftData's `PersistentModel`
/// already supplies `Identifiable` conformance via its persistent identifier.
@Model
final class Participant {
    var uuid: UUID = UUID()
    var name: String = ""
    /// An emoji used as the avatar.
    var emoji: String = "🙂"
    /// Hex string like "#7C5CFF" for the avatar's accent color.
    var colorHex: String = "#7C5CFF"
    var createdAt: Date = Date.now

    /// Deleting a participant removes their completion history (the leaderboard
    /// has no meaning for an owner-less completion). The UI confirms first.
    @Relationship(deleteRule: .cascade, inverse: \Completion.participant)
    var completions: [Completion] = []

    init(
        name: String,
        emoji: String = "🙂",
        colorHex: String = "#7C5CFF",
        createdAt: Date = .now
    ) {
        self.uuid = UUID()
        self.name = name
        self.emoji = emoji
        self.colorHex = colorHex
        self.createdAt = createdAt
    }
}
