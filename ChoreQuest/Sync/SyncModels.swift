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

// MARK: - Row DTOs (snake_case columns via the encoder strategy)
// Property names avoid all-caps acronyms so .convertToSnakeCase maps cleanly
// (e.g. householdId -> household_id, participantUuid -> participant_uuid).

struct RemoteParticipant: Codable {
    var uuid: UUID
    var householdId: UUID
    var name: String
    var emoji: String
    var colorHex: String
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
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
}

/// Returned by the create_household / join_household RPCs.
struct RemoteHousehold: Codable {
    var id: UUID
    var inviteCode: String
    var createdAt: Date
}
