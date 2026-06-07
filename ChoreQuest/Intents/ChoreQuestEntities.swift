import AppIntents
import SwiftData

// Entities + a period enum so chores, people, and a timeframe can be picked as
// parameters in the Shortcuts app and Siri.

struct ChoreEntity: AppEntity {
    let id: UUID
    let name: String
    let emoji: String
    let points: Int

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Chore" }
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(emoji) \(name)", subtitle: "\(points) pts")
    }
    static var defaultQuery = ChoreQuery()
}

struct ChoreQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [ChoreEntity] {
        allChores().filter { identifiers.contains($0.id) }
    }

    @MainActor
    func suggestedEntities() async throws -> [ChoreEntity] { allChores() }

    @MainActor
    private func allChores() -> [ChoreEntity] {
        let context = AppModelContainer.shared.mainContext
        let descriptor = FetchDescriptor<Chore>(sortBy: [SortDescriptor(\Chore.sortOrder)])
        let chores = (try? context.fetch(descriptor)) ?? []
        return chores
            .filter { !$0.isSoftDeleted && !$0.isArchived }
            .map { ChoreEntity(id: $0.uuid, name: $0.name, emoji: $0.emoji, points: $0.points) }
    }
}

struct ParticipantEntity: AppEntity {
    let id: UUID
    let name: String
    let emoji: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Person" }
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(emoji) \(name)")
    }
    static var defaultQuery = ParticipantQuery()
}

struct ParticipantQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [ParticipantEntity] {
        allParticipants().filter { identifiers.contains($0.id) }
    }

    @MainActor
    func suggestedEntities() async throws -> [ParticipantEntity] { allParticipants() }

    @MainActor
    private func allParticipants() -> [ParticipantEntity] {
        let context = AppModelContainer.shared.mainContext
        let descriptor = FetchDescriptor<Participant>(sortBy: [SortDescriptor(\Participant.createdAt)])
        let people = (try? context.fetch(descriptor)) ?? []
        return people
            .filter { !$0.isSoftDeleted }
            .map { ParticipantEntity(id: $0.uuid, name: $0.name, emoji: $0.emoji) }
    }
}

/// Reuse the Leaderboard's timeframe (today / this week / all time) as a Shortcuts parameter.
extension TimeRange: AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Time Period" }
    static var caseDisplayRepresentations: [TimeRange: DisplayRepresentation] {
        [.today: "Today", .week: "This Week", .all: "All Time"]
    }
}
