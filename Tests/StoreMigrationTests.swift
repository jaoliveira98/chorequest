import XCTest
import SwiftData
@testable import ChoreQuest

/// Exercises the App Group store migration (checkpoint + copy) against real
/// on-disk stores, asserting no data is lost — the path the in-memory tests
/// never touch.
final class StoreMigrationTests: XCTestCase {
    func testMigratePreservesData() throws {
        let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let oldURL = dir.appending(path: "old.store")
        let newURL = dir.appending(path: "new.store")

        // Write data into the "old" store (this leaves data in the WAL).
        do {
            let container = try ModelContainer(
                for: Participant.self, Chore.self, Completion.self,
                configurations: ModelConfiguration(url: oldURL))
            let context = ModelContext(container)
            let alex = Participant(name: "Alex")
            let dishes = Chore(name: "Dishes", points: 3)
            context.insert(alex)
            context.insert(dishes)
            context.insert(Completion(chore: dishes, participant: alex))
            try context.save()
        } // container released → store closed

        AppModelContainer.migrateStore(from: oldURL, to: newURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: newURL.path), "migrated store should exist")

        // Re-open the migrated store and confirm everything survived.
        let migrated = try ModelContainer(
            for: Participant.self, Chore.self, Completion.self,
            configurations: ModelConfiguration(url: newURL))
        let context = ModelContext(migrated)
        let people = try context.fetch(FetchDescriptor<Participant>())
        let chores = try context.fetch(FetchDescriptor<Chore>())
        let completions = try context.fetch(FetchDescriptor<Completion>())

        XCTAssertEqual(people.count, 1)
        XCTAssertEqual(people.first?.name, "Alex")
        XCTAssertEqual(chores.first?.points, 3)
        XCTAssertEqual(completions.count, 1)
        XCTAssertEqual(completions.first?.pointsAwarded, 3)
    }
}
