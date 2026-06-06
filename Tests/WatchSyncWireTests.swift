import XCTest
@testable import ChoreQuest

/// Locks the phone↔watch wire contract so a future encoder change can't silently
/// break sync. These types are pure Foundation (compiled into the app module).
final class WatchSyncWireTests: XCTestCase {
    func testSnapshotRoundTrips() throws {
        let snapshot = SyncSnapshot(
            participants: [
                ParticipantDTO(uuid: UUID(), name: "Alex", emoji: "🦸", colorHex: "#7C5CFF", points: 7),
                ParticipantDTO(uuid: UUID(), name: "Sam", emoji: "🐼", colorHex: "#4FC3F7", points: nil)
            ],
            chores: [
                ChoreDTO(uuid: UUID(), name: "Dishes", emoji: "🍽️", points: 2, colorHex: "#4FC3F7")
            ],
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let data = try WatchSyncWire.encode(snapshot)
        let decoded = try WatchSyncWire.decode(SyncSnapshot.self, from: data)

        XCTAssertEqual(decoded, snapshot)
        XCTAssertEqual(decoded.participants.first?.points, 7)
        XCTAssertNil(decoded.participants.last?.points) // optional points survives nil
    }

    func testCompletionRoundTripsWithDateFidelity() throws {
        let dto = CompletionDTO(
            uuid: UUID(),
            participantUUID: UUID(),
            choreUUID: UUID(),
            completedAt: Date(timeIntervalSince1970: 1_699_999_999),
            pointsAwarded: 3,
            choreName: "Cook",
            choreEmoji: "🍳"
        )

        let data = try WatchSyncWire.encode(dto)
        let decoded = try WatchSyncWire.decode(CompletionDTO.self, from: data)

        XCTAssertEqual(decoded, dto)
        // iso8601 is second-resolution; assert the timestamp is preserved to the second.
        XCTAssertEqual(
            decoded.completedAt.timeIntervalSince1970,
            dto.completedAt.timeIntervalSince1970,
            accuracy: 1.0
        )
    }
}
