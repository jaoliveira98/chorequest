import Foundation

/// JSON coding shared by all Supabase requests: snake_case column mapping and a
/// tolerant Postgres `timestamptz` parser (Postgres returns microsecond
/// precision with a `+00:00` offset, which the stock `.iso8601` strategy chokes on).
enum SupabaseCoding {
    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .custom { date, enc in
            var c = enc.singleValueContainer()
            try c.encode(writeFormatter.string(from: date))
        }
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { dec in
            let s = try dec.singleValueContainer().decode(String.self)
            if let date = parseDate(s) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: dec.codingPath,
                                                    debugDescription: "Unparseable date: \(s)"))
        }
        return decoder
    }

    private static let writeFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// ISO8601 string for query filters (e.g. `updated_at=gt.<iso>`).
    static func isoString(_ date: Date) -> String { writeFormatter.string(from: date) }

    /// Tries a few formats so Postgres micros / millis / no-fraction all parse.
    static func parseDate(_ s: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: s) { return d }
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: s) { return d }
        for format in [
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX"
        ] {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.timeZone = TimeZone(secondsFromGMT: 0)
            df.dateFormat = format
            if let d = df.date(from: s) { return d }
        }
        return nil
    }
}

private extension KeyedEncodingContainer {
    /// Always writes the key, encoding `nil` as an explicit JSON `null` rather
    /// than omitting it. PostgREST bulk upsert rejects a batch whose objects have
    /// different key sets (PGRST102 "All object keys must match"), which happens
    /// the moment one row has a non-nil optional (e.g. `deleted_at` after a
    /// delete) while others don't. Emitting every column on every row keeps the
    /// key set uniform.
    mutating func encodeAlways<T: Encodable>(_ value: T?, forKey key: Key) throws {
        if let value { try encode(value, forKey: key) } else { try encodeNil(forKey: key) }
    }
}

// MARK: - Row DTOs (snake_case columns via the encoder strategy)
// Property names avoid all-caps acronyms so .convertToSnakeCase maps cleanly
// (e.g. householdId -> household_id, participantUuid -> participant_uuid).
// Each defines an explicit encode(to:) so EVERY column is present on EVERY row
// (null where empty) — see encodeAlways above.

struct RemoteParticipant: Codable {
    var uuid: UUID
    var householdId: UUID
    var name: String
    var emoji: String
    var colorHex: String
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case uuid, householdId, name, emoji, colorHex, createdAt, updatedAt, deletedAt
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(uuid, forKey: .uuid)
        try c.encode(householdId, forKey: .householdId)
        try c.encode(name, forKey: .name)
        try c.encode(emoji, forKey: .emoji)
        try c.encode(colorHex, forKey: .colorHex)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encodeAlways(deletedAt, forKey: .deletedAt)
    }
}

struct RemoteChore: Codable {
    var uuid: UUID
    var householdId: UUID
    var name: String
    var emoji: String
    var points: Int
    var colorHex: String?
    var isArchived: Bool
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case uuid, householdId, name, emoji, points, colorHex, isArchived, sortOrder, createdAt, updatedAt, deletedAt
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(uuid, forKey: .uuid)
        try c.encode(householdId, forKey: .householdId)
        try c.encode(name, forKey: .name)
        try c.encode(emoji, forKey: .emoji)
        try c.encode(points, forKey: .points)
        try c.encodeAlways(colorHex, forKey: .colorHex)
        try c.encode(isArchived, forKey: .isArchived)
        try c.encode(sortOrder, forKey: .sortOrder)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encodeAlways(deletedAt, forKey: .deletedAt)
    }
}

struct RemoteCompletion: Codable {
    var uuid: UUID
    var householdId: UUID
    var completedAt: Date
    var pointsAwarded: Int
    var choreName: String
    var choreEmoji: String
    var participantUuid: UUID?
    var choreUuid: UUID?
    var updatedAt: Date
    var deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case uuid, householdId, completedAt, pointsAwarded, choreName, choreEmoji, participantUuid, choreUuid, updatedAt, deletedAt
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(uuid, forKey: .uuid)
        try c.encode(householdId, forKey: .householdId)
        try c.encode(completedAt, forKey: .completedAt)
        try c.encode(pointsAwarded, forKey: .pointsAwarded)
        try c.encode(choreName, forKey: .choreName)
        try c.encode(choreEmoji, forKey: .choreEmoji)
        try c.encodeAlways(participantUuid, forKey: .participantUuid)
        try c.encodeAlways(choreUuid, forKey: .choreUuid)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encodeAlways(deletedAt, forKey: .deletedAt)
    }
}

/// Returned by the create_household / join_household RPCs.
struct RemoteHousehold: Codable {
    var id: UUID
    var inviteCode: String
    var createdAt: Date
}
