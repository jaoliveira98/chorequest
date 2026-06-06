import XCTest
import SwiftData
@testable import ChoreQuest

/// Unit tests for the cloud-sync merge logic (last-write-wins + tombstones).
/// These run against an in-memory store and don't touch the network.
@MainActor
final class CloudSyncMergeTests: XCTestCase {
    private func makeManager() throws -> (CloudSyncManager, ModelContainer) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Participant.self, Chore.self, Completion.self, configurations: config
        )
        return (CloudSyncManager(container: container), container)
    }

    func testMergeInsertsNewParticipant() throws {
        let (manager, container) = try makeManager()
        let hid = UUID()
        manager.mergeParticipant(RemoteParticipant(
            uuid: UUID(), householdId: hid, name: "Alex", emoji: "🦸",
            colorHex: "#7C5CFF", createdAt: .now, updatedAt: .now, deletedAt: nil))

        let all = try container.mainContext.fetch(FetchDescriptor<Participant>())
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.name, "Alex")
        XCTAssertEqual(all.first?.householdID, hid)
    }

    func testMergeAppliesNewerAndSkipsOlder() throws {
        let (manager, container) = try makeManager()
        let hid = UUID(); let uuid = UUID()
        let early = Date(timeIntervalSince1970: 1_000)
        let late = Date(timeIntervalSince1970: 2_000)

        func row(_ name: String, _ updated: Date) -> RemoteParticipant {
            RemoteParticipant(uuid: uuid, householdId: hid, name: name, emoji: "🙂",
                              colorHex: "#fff", createdAt: early, updatedAt: updated, deletedAt: nil)
        }
        manager.mergeParticipant(row("Old", early))
        manager.mergeParticipant(row("New", late))   // newer wins
        manager.mergeParticipant(row("Stale", early)) // older ignored

        let all = try container.mainContext.fetch(FetchDescriptor<Participant>())
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.name, "New")
    }

    func testMergePropagatesTombstone() throws {
        let (manager, container) = try makeManager()
        let hid = UUID(); let uuid = UUID()
        let early = Date(timeIntervalSince1970: 1_000)
        let late = Date(timeIntervalSince1970: 2_000)

        manager.mergeChore(RemoteChore(uuid: uuid, householdId: hid, name: "Dishes", emoji: "🍽️",
                                       points: 2, colorHex: nil, isArchived: false, sortOrder: 0,
                                       createdAt: early, updatedAt: early, deletedAt: nil))
        manager.mergeChore(RemoteChore(uuid: uuid, householdId: hid, name: "Dishes", emoji: "🍽️",
                                       points: 2, colorHex: nil, isArchived: false, sortOrder: 0,
                                       createdAt: early, updatedAt: late, deletedAt: late))

        let chore = try container.mainContext.fetch(FetchDescriptor<Chore>()).first
        XCTAssertTrue(chore?.isSoftDeleted ?? false)
    }

    func testMergeDoesNotResurrectOnEqualTimestamp() throws {
        let (manager, container) = try makeManager()
        let hid = UUID(); let uuid = UUID()
        let t = Date(timeIntervalSince1970: 5_000)
        // Local row is soft-deleted at t…
        manager.mergeChore(RemoteChore(uuid: uuid, householdId: hid, name: "X", emoji: "🧪", points: 1,
                                       colorHex: nil, isArchived: false, sortOrder: 0,
                                       createdAt: t, updatedAt: t, deletedAt: t))
        // …an incoming ACTIVE copy with the SAME updated_at must not revive it.
        manager.mergeChore(RemoteChore(uuid: uuid, householdId: hid, name: "X", emoji: "🧪", points: 1,
                                       colorHex: nil, isArchived: false, sortOrder: 0,
                                       createdAt: t, updatedAt: t, deletedAt: nil))

        let chore = try container.mainContext.fetch(FetchDescriptor<Chore>()).first
        XCTAssertTrue(chore?.isSoftDeleted ?? false, "equal-timestamp active row must not resurrect a delete")
    }

    func testMergeCompletionLinksByUUID() throws {
        let (manager, container) = try makeManager()
        let hid = UUID()
        let person = Participant(name: "Alex", householdID: hid)
        let chore = Chore(name: "Dishes", points: 2, householdID: hid)
        container.mainContext.insert(person)
        container.mainContext.insert(chore)

        manager.mergeCompletion(
            RemoteCompletion(uuid: UUID(), householdId: hid, completedAt: .now, pointsAwarded: 2,
                             choreName: "Dishes", choreEmoji: "🍽️", participantUuid: person.uuid,
                             choreUuid: chore.uuid, updatedAt: .now, deletedAt: nil),
            participants: [person.uuid: person],
            chores: [chore.uuid: chore])

        let completion = try container.mainContext.fetch(FetchDescriptor<Completion>()).first
        XCTAssertEqual(completion?.participant?.uuid, person.uuid)
        XCTAssertEqual(completion?.chore?.uuid, chore.uuid)
        XCTAssertEqual(completion?.pointsAwarded, 2)
    }
}
