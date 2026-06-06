import Foundation
import SwiftData

/// A single logged chore: who did what, when, and for how many points.
///
/// The `pointsAwarded`, `choreName`, and `choreEmoji` fields are **snapshots**
/// taken at the moment of completion. This is intentional: editing a chore's
/// point value or name later — or deleting the chore entirely — must not rewrite
/// history. The leaderboard and timeline always read these snapshots.
@Model
final class Completion {
    var uuid: UUID = UUID()
    /// The exact day + time the chore was done.
    var completedAt: Date = Date.now
    var pointsAwarded: Int = 0
    var choreName: String = ""
    var choreEmoji: String = "✅"

    // Sync metadata (CQ-12) — see SyncableModel.
    var updatedAt: Date = Date.now
    var deletedAt: Date?
    var householdID: UUID?

    /// The person who did it. Cascade-deleted with the participant.
    var participant: Participant?
    /// The originating chore, if it still exists (nullified on chore delete).
    var chore: Chore?

    init(
        uuid: UUID = UUID(),
        completedAt: Date = .now,
        pointsAwarded: Int,
        choreName: String,
        choreEmoji: String,
        participant: Participant?,
        chore: Chore?,
        updatedAt: Date = .now,
        deletedAt: Date? = nil,
        householdID: UUID? = nil
    ) {
        self.uuid = uuid
        self.completedAt = completedAt
        self.pointsAwarded = pointsAwarded
        self.choreName = choreName
        self.choreEmoji = choreEmoji
        self.participant = participant
        self.chore = chore
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.householdID = householdID
    }

    /// Convenience initializer that snapshots a chore's current values.
    convenience init(chore: Chore, participant: Participant, completedAt: Date = .now) {
        self.init(
            completedAt: completedAt,
            pointsAwarded: chore.points,
            choreName: chore.name,
            choreEmoji: chore.emoji,
            participant: participant,
            chore: chore
        )
    }
}

extension Completion: SyncableModel {}
