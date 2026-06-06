import XCTest
import SwiftData
@testable import ChoreQuest

final class ModelAndBackupTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Participant.self, Chore.self, Completion.self,
            configurations: config
        )
        return ModelContext(container)
    }

    func testCompletionSnapshotSurvivesChoreEdits() throws {
        let context = try makeContext()
        let person = Participant(name: "Alex")
        let chore = Chore(name: "Dishes", emoji: "🍽️", points: 2)
        context.insert(person)
        context.insert(chore)
        let completion = Completion(chore: chore, participant: person)
        context.insert(completion)
        try context.save()

        // Edit the chore after the fact — history must not change.
        chore.points = 99
        chore.name = "Renamed"
        chore.emoji = "❓"
        try context.save()

        XCTAssertEqual(completion.pointsAwarded, 2)
        XCTAssertEqual(completion.choreName, "Dishes")
        XCTAssertEqual(completion.choreEmoji, "🍽️")
    }

    func testDeletingParticipantCascadesCompletions() throws {
        let context = try makeContext()
        let person = Participant(name: "Alex")
        let chore = Chore(name: "Dishes", points: 2)
        context.insert(person)
        context.insert(chore)
        context.insert(Completion(chore: chore, participant: person))
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Completion>()), 1)
        context.delete(person)
        try context.save()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Completion>()), 0)
    }

    func testDeletingChoreKeepsCompletionViaSnapshot() throws {
        let context = try makeContext()
        let person = Participant(name: "Alex")
        let chore = Chore(name: "Dishes", points: 2)
        context.insert(person)
        context.insert(chore)
        let completion = Completion(chore: chore, participant: person)
        context.insert(completion)
        try context.save()

        context.delete(chore)
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Completion>()), 1)
        let fetched = try context.fetch(FetchDescriptor<Completion>()).first
        XCTAssertNil(fetched?.chore)               // relationship nullified
        XCTAssertEqual(fetched?.choreName, "Dishes") // snapshot preserved
        XCTAssertEqual(fetched?.pointsAwarded, 2)
    }

    func testBackupRoundTripPreservesDataAndIdentity() throws {
        let context = try makeContext()
        let person = Participant(name: "Alex", emoji: "🦸", colorHex: "#4FC3F7")
        let chore = Chore(name: "Dishes", emoji: "🍽️", points: 2, colorHex: "#4FC3F7")
        context.insert(person)
        context.insert(chore)
        context.insert(Completion(chore: chore, participant: person))
        try context.save()

        let data = try Backup.export(from: context)

        // Restore into a different store that already has junk data.
        let restoreContext = try makeContext()
        restoreContext.insert(Participant(name: "ShouldBeWiped"))
        try restoreContext.save()

        let summary = try Backup.restore(from: data, into: restoreContext)
        XCTAssertEqual(summary.participants, 1)
        XCTAssertEqual(summary.chores, 1)
        XCTAssertEqual(summary.completions, 1)

        let people = try restoreContext.fetch(FetchDescriptor<Participant>())
        XCTAssertEqual(people.count, 1)
        XCTAssertEqual(people.first?.name, "Alex")
        XCTAssertEqual(people.first?.uuid, person.uuid) // identity preserved

        let completions = try restoreContext.fetch(FetchDescriptor<Completion>())
        XCTAssertEqual(completions.first?.participant?.name, "Alex") // relinked by uuid
        XCTAssertEqual(completions.first?.chore?.name, "Dishes")
        XCTAssertEqual(completions.first?.pointsAwarded, 2)
    }

    func testRestoreFromInvalidDataLeavesExistingDataIntact() throws {
        let context = try makeContext()
        context.insert(Participant(name: "Keep me"))
        try context.save()

        let garbage = Data("not a valid backup".utf8)
        XCTAssertThrowsError(try Backup.restore(from: garbage, into: context))

        // The bad file is rejected at decode time, before any data is touched.
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Participant>()), 1)
    }

    func testSeederSeedsExactlyOnce() throws {
        let context = try makeContext()
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!

        Seeder.seedIfNeeded(context: context, defaults: defaults)
        let seededCount = try context.fetchCount(FetchDescriptor<Chore>())
        XCTAssertEqual(seededCount, Seeder.defaultChores.count)

        // Running again must not duplicate.
        Seeder.seedIfNeeded(context: context, defaults: defaults)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Chore>()), seededCount)
    }
}
