import XCTest
@testable import ChoreQuest

/// Guards against PGRST102 "All object keys must match": every row in a bulk
/// upsert must serialize the SAME keys, with `null` (not omission) for empty
/// optionals. Regression test for deletes failing to sync.
final class SyncEncodingTests: XCTestCase {
    private func objects(_ data: Data) throws -> [[String: Any]] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
    }

    func testChoreBatchHasUniformKeysWithExplicitNulls() throws {
        let hid = UUID()
        let deleted = RemoteChore(uuid: UUID(), householdId: hid, name: "A", emoji: "🧪", points: 1,
                                  colorHex: "#fff", isArchived: false, sortOrder: 0,
                                  createdAt: Date(timeIntervalSince1970: 1), updatedAt: Date(timeIntervalSince1970: 2),
                                  deletedAt: Date(timeIntervalSince1970: 3))
        let active = RemoteChore(uuid: UUID(), householdId: hid, name: "B", emoji: "🧪", points: 1,
                                 colorHex: nil, isArchived: false, sortOrder: 1,
                                 createdAt: Date(timeIntervalSince1970: 1), updatedAt: Date(timeIntervalSince1970: 2),
                                 deletedAt: nil)
        let rows = try objects(try SupabaseCoding.encoder().encode([deleted, active]))
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(Set(rows[0].keys), Set(rows[1].keys), "all objects must share the same keys (PGRST102)")
        XCTAssertTrue(rows[1]["deleted_at"] is NSNull)
        XCTAssertTrue(rows[1]["color_hex"] is NSNull)
        XCTAssertEqual(rows[0]["color_hex"] as? String, "#fff")
    }

    func testParticipantBatchHasUniformKeys() throws {
        let hid = UUID()
        let a = RemoteParticipant(uuid: UUID(), householdId: hid, name: "A", emoji: "🙂", colorHex: "#fff",
                                  createdAt: Date(timeIntervalSince1970: 1), updatedAt: Date(timeIntervalSince1970: 2),
                                  deletedAt: Date(timeIntervalSince1970: 3))
        let b = RemoteParticipant(uuid: UUID(), householdId: hid, name: "B", emoji: "🙂", colorHex: "#000",
                                  createdAt: Date(timeIntervalSince1970: 1), updatedAt: Date(timeIntervalSince1970: 2),
                                  deletedAt: nil)
        let rows = try objects(try SupabaseCoding.encoder().encode([a, b]))
        XCTAssertEqual(Set(rows[0].keys), Set(rows[1].keys))
        XCTAssertTrue(rows[1]["deleted_at"] is NSNull)
    }

    func testCompletionBatchHasUniformKeysWithNullRefs() throws {
        let hid = UUID()
        let linked = RemoteCompletion(uuid: UUID(), householdId: hid, completedAt: Date(timeIntervalSince1970: 1),
                                      pointsAwarded: 2, choreName: "X", choreEmoji: "🧪",
                                      participantUuid: UUID(), choreUuid: UUID(),
                                      updatedAt: Date(timeIntervalSince1970: 2), deletedAt: Date(timeIntervalSince1970: 3))
        let bare = RemoteCompletion(uuid: UUID(), householdId: hid, completedAt: Date(timeIntervalSince1970: 1),
                                    pointsAwarded: 2, choreName: "X", choreEmoji: "🧪",
                                    participantUuid: nil, choreUuid: nil,
                                    updatedAt: Date(timeIntervalSince1970: 2), deletedAt: nil)
        let rows = try objects(try SupabaseCoding.encoder().encode([linked, bare]))
        XCTAssertEqual(Set(rows[0].keys), Set(rows[1].keys))
        for key in ["participant_uuid", "chore_uuid", "deleted_at"] {
            XCTAssertTrue(rows[1][key] is NSNull, "\(key) should be explicit null")
        }
    }
}
