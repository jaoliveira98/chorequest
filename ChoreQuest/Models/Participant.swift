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

    // Sync metadata (CQ-12) — see SyncableModel.
    var updatedAt: Date = Date.now
    var deletedAt: Date?
    var householdID: UUID?

    /// Deleting a participant removes their completion history (the leaderboard
    /// has no meaning for an owner-less completion). The UI confirms first.
    @Relationship(deleteRule: .cascade, inverse: \Completion.participant)
    var completions: [Completion] = []

    init(
        uuid: UUID = UUID(),
        name: String,
        emoji: String = "🙂",
        colorHex: String = "#7C5CFF",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        deletedAt: Date? = nil,
        householdID: UUID? = nil
    ) {
        self.uuid = uuid
        self.name = name
        self.emoji = emoji
        self.colorHex = colorHex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.householdID = householdID
    }

    /// Soft-delete this participant and all of their completions (mirrors the old
    /// cascade delete, but as soft deletes so it can propagate via sync).
    func softDeleteCascading(_ date: Date = .now) {
        for completion in completions { completion.softDelete(date) }
        softDelete(date)
    }
}

extension Participant: SyncableModel {}
