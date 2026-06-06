import Foundation

/// The snapshot the phone pushes to the watch (latest-state-wins) so the watch
/// can render the logging UI.
struct SyncSnapshot: Codable, Hashable {
    var participants: [ParticipantDTO]
    var chores: [ChoreDTO]
    var generatedAt: Date

    static let empty = SyncSnapshot(participants: [], chores: [], generatedAt: .distantPast)
}

/// Wire format shared by both sides: the dictionary keys used in
/// `updateApplicationContext` / `transferUserInfo`, and one agreed JSON config so
/// the phone and watch always encode/decode dates the same way. Values are sent
/// as `Data` (plist-safe) under a single key to avoid type-erasure issues.
enum WatchSyncWire {
    static let snapshotKey = "snapshot"
    static let completionKey = "completion"

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    static func encode<T: Encodable>(_ value: T) throws -> Data {
        try makeEncoder().encode(value)
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try makeDecoder().decode(type, from: data)
    }
}
