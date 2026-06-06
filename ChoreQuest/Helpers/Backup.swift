import Foundation
import SwiftData

/// JSON backup of the entire on-device database. This is the user's insurance
/// against data loss (e.g. if the app is ever deleted under a free Apple ID).
///
/// Relationships are encoded by `uuid` so a restored backup rebuilds the exact
/// same graph. Completions also carry their snapshot fields, so history survives
/// even if the originating chore no longer exists.
enum Backup {
    static let version = 1

    struct File: Codable {
        var version: Int
        var exportedAt: Date
        var participants: [ParticipantDTO]
        var chores: [ChoreDTO]
        var completions: [CompletionDTO]
    }

    struct ParticipantDTO: Codable {
        var uuid: UUID
        var name: String
        var emoji: String
        var colorHex: String
        var createdAt: Date
    }

    struct ChoreDTO: Codable {
        var uuid: UUID
        var name: String
        var emoji: String
        var points: Int
        var colorHex: String?
        var isArchived: Bool
        var sortOrder: Int
        var createdAt: Date
    }

    struct CompletionDTO: Codable {
        var uuid: UUID
        var completedAt: Date
        var pointsAwarded: Int
        var choreName: String
        var choreEmoji: String
        var participantUUID: UUID?
        var choreUUID: UUID?
    }

    // MARK: - Export

    static func export(from context: ModelContext) throws -> Data {
        // Back up live data only — soft-deleted rows are tombstones, not content.
        let participants = try context.fetch(FetchDescriptor<Participant>()).filter { !$0.isSoftDeleted }
        let chores = try context.fetch(FetchDescriptor<Chore>()).filter { !$0.isSoftDeleted }
        let completions = try context.fetch(FetchDescriptor<Completion>()).filter { !$0.isSoftDeleted }

        let file = File(
            version: version,
            exportedAt: .now,
            participants: participants.map {
                ParticipantDTO(uuid: $0.uuid, name: $0.name, emoji: $0.emoji,
                               colorHex: $0.colorHex, createdAt: $0.createdAt)
            },
            chores: chores.map {
                ChoreDTO(uuid: $0.uuid, name: $0.name, emoji: $0.emoji, points: $0.points,
                         colorHex: $0.colorHex, isArchived: $0.isArchived,
                         sortOrder: $0.sortOrder, createdAt: $0.createdAt)
            },
            completions: completions.map {
                CompletionDTO(uuid: $0.uuid, completedAt: $0.completedAt,
                              pointsAwarded: $0.pointsAwarded, choreName: $0.choreName,
                              choreEmoji: $0.choreEmoji,
                              participantUUID: $0.participant?.uuid, choreUUID: $0.chore?.uuid)
            }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(file)
    }

    // MARK: - Restore (replace-all)

    struct RestoreSummary {
        var participants: Int
        var chores: Int
        var completions: Int
    }

    /// Decodes a backup and **replaces** all current data with it. Returns counts
    /// of what was imported. Throws on malformed/incompatible files.
    ///
    /// This is atomic: decoding happens first (a bad file never touches the
    /// store), and the wipe + rebuild are staged on the context as a single unit
    /// committed by one `save()`. If anything fails, `rollback()` discards every
    /// staged change, leaving the existing data exactly as it was.
    @discardableResult
    static func restore(from data: Data, into context: ModelContext) throws -> RestoreSummary {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let file = try decoder.decode(File.self, from: data)

        guard file.version <= Backup.version else {
            throw BackupError.unsupportedVersion(file.version)
        }

        do {
            // Stage deletion of existing rows individually (not a batch delete) so
            // a rollback can undo them if the save fails partway through.
            for completion in try context.fetch(FetchDescriptor<Completion>()) {
                context.delete(completion)
            }
            for chore in try context.fetch(FetchDescriptor<Chore>()) {
                context.delete(chore)
            }
            for participant in try context.fetch(FetchDescriptor<Participant>()) {
                context.delete(participant)
            }

            // Rebuild, indexing by uuid so relationships can be relinked.
            var participantsByUUID: [UUID: Participant] = [:]
            for dto in file.participants {
                let participant = Participant(uuid: dto.uuid, name: dto.name, emoji: dto.emoji,
                                              colorHex: dto.colorHex, createdAt: dto.createdAt)
                context.insert(participant)
                participantsByUUID[dto.uuid] = participant
            }

            var choresByUUID: [UUID: Chore] = [:]
            for dto in file.chores {
                let chore = Chore(uuid: dto.uuid, name: dto.name, emoji: dto.emoji, points: dto.points,
                                  colorHex: dto.colorHex, isArchived: dto.isArchived,
                                  sortOrder: dto.sortOrder, createdAt: dto.createdAt)
                context.insert(chore)
                choresByUUID[dto.uuid] = chore
            }

            for dto in file.completions {
                let completion = Completion(
                    uuid: dto.uuid,
                    completedAt: dto.completedAt,
                    pointsAwarded: dto.pointsAwarded,
                    choreName: dto.choreName,
                    choreEmoji: dto.choreEmoji,
                    participant: dto.participantUUID.flatMap { participantsByUUID[$0] },
                    chore: dto.choreUUID.flatMap { choresByUUID[$0] }
                )
                context.insert(completion)
            }

            try context.save()
        } catch {
            // Nothing was persisted — discard the staged wipe/rebuild and keep
            // the user's existing data intact.
            context.rollback()
            throw error
        }

        return RestoreSummary(
            participants: file.participants.count,
            chores: file.chores.count,
            completions: file.completions.count
        )
    }

    enum BackupError: LocalizedError {
        case unsupportedVersion(Int)

        var errorDescription: String? {
            switch self {
            case .unsupportedVersion(let version):
                return "This backup was made by a newer version of ChoreQuest (format \(version))."
            }
        }
    }
}
