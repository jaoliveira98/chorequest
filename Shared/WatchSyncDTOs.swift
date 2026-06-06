import Foundation

// Plain Codable value types exchanged between the iPhone and the Apple Watch via
// WatchConnectivity. These deliberately use only Foundation — no SwiftData, no
// UIKit — so the file can be compiled into BOTH the iOS and watchOS targets.
// The SwiftData @Model classes never go to the watch; only these DTOs do.

/// A participant as shown on the watch. `points` is an optional "today" total the
/// phone computes and includes so the watch can show a little motivation.
struct ParticipantDTO: Codable, Identifiable, Hashable {
    let uuid: UUID
    let name: String
    let emoji: String
    let colorHex: String
    var points: Int?

    var id: UUID { uuid }
}

/// An active chore as shown on the watch. `colorHex` is non-optional here: the
/// phone collapses `chore.colorHex ?? Palette.defaultColor` before sending, so
/// the watch never needs the Palette.
struct ChoreDTO: Codable, Identifiable, Hashable {
    let uuid: UUID
    let name: String
    let emoji: String
    let points: Int
    let colorHex: String

    var id: UUID { uuid }
}

/// A completion logged on the watch, sent to the phone. Carries snapshot fields
/// so the phone can record it faithfully (and keep history even if the chore was
/// edited/deleted). `uuid` is generated on the watch and used by the phone for
/// idempotent de-duplication of re-delivered transfers.
struct CompletionDTO: Codable, Hashable {
    let uuid: UUID
    let participantUUID: UUID
    let choreUUID: UUID
    let completedAt: Date
    let pointsAwarded: Int
    let choreName: String
    let choreEmoji: String
}
