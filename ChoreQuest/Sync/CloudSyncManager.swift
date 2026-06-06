import Foundation
import SwiftData

/// Orchestrates cross-phone sync with Supabase. The SwiftData store stays the
/// local source of truth and the app works offline; this pushes the household's
/// rows up and pulls remote changes down, merging last-write-wins by `updatedAt`
/// with soft-delete tombstones. Each sync re-upserts all household rows
/// (idempotent) and pulls only rows newer than a stored per-table cursor.
@MainActor
final class CloudSyncManager: ObservableObject {
    enum Status: Equatable { case idle, syncing, error }

    @Published private(set) var status: Status = .idle
    @Published private(set) var lastSyncedAt: Date?
    @Published private(set) var errorMessage: String?
    /// The household invite code to share (nil when not linked).
    @Published private(set) var householdCode: String?

    private let container: ModelContainer
    private let client = SupabaseClient.shared
    private let defaults = UserDefaults.standard
    private var isSyncing = false

    // Persisted keys
    private let kHouseholdID = "cloud.householdID"
    private let kInviteCode  = "cloud.inviteCode"
    private let kEnsuredUser = "cloud.ensuredUserID"
    private func kCursor(_ table: String) -> String { "cloud.pulled.\(table)" }

    init(container: ModelContainer) {
        self.container = container
        self.householdCode = defaults.string(forKey: kInviteCode)
    }

    var isLinked: Bool { householdID != nil }

    private var householdID: UUID? {
        get { (defaults.string(forKey: kHouseholdID)).flatMap(UUID.init) }
        set { defaults.set(newValue?.uuidString, forKey: kHouseholdID) }
    }

    private var context: ModelContext { container.mainContext }

    // MARK: - Household create / join / leave

    func createHousehold() async {
        await run {
            let row = try await self.client.householdRPC("create_household")
            self.setHousehold(id: row.id, code: row.inviteCode, resetCursors: true)
            // This phone's current data becomes the shared data.
            self.stampAllLocalRows(with: row.id)
            self.context.saveChanges()
            try await self.pushAll(householdID: row.id)
            try await self.pull(householdID: row.id)
        }
    }

    /// Joining adopts the household's data: this phone's pre-join local data is
    /// replaced by what the household already has.
    func joinHousehold(code: String) async {
        await run {
            let row = try await self.client.householdRPC("join_household", args: ["code": code])
            self.wipeLocalData()
            self.context.saveChanges()
            self.setHousehold(id: row.id, code: row.inviteCode, resetCursors: true)
            try await self.pull(householdID: row.id) // full pull (cursors reset)
        }
    }

    func leaveHousehold() async {
        householdID = nil
        defaults.removeObject(forKey: kInviteCode)
        defaults.removeObject(forKey: kEnsuredUser)
        for table in ["participants", "chores", "completions"] { defaults.removeObject(forKey: kCursor(table)) }
        householdCode = nil
        await client.signOut()
        status = .idle
        errorMessage = nil
    }

    // MARK: - Sync

    func sync() async {
        guard householdID != nil else { return }
        await run {
            guard let hid = self.householdID else { return }
            try await self.pushAll(householdID: hid)
            try await self.pull(householdID: hid)
        }
    }

    /// Wraps a unit of work with session setup, membership healing, status, and
    /// single-flight guarding.
    private func run(_ work: @escaping () async throws -> Void) async {
        guard !isSyncing else { return }
        isSyncing = true
        status = .syncing
        do {
            try await client.ensureSession()
            try await ensureMembership()
            try await work()
            lastSyncedAt = .now
            errorMessage = nil
            status = .idle
        } catch {
            errorMessage = error.localizedDescription
            status = .error
        }
        isSyncing = false
    }

    /// If the (possibly refreshed/new) anonymous user isn't yet a member of the
    /// stored household, re-join by the saved code. Idempotent and self-healing.
    private func ensureMembership() async throws {
        guard let code = defaults.string(forKey: kInviteCode) else { return }
        let userID = await client.currentUserId?.uuidString
        guard userID != defaults.string(forKey: kEnsuredUser) else { return }
        let row = try await client.householdRPC("join_household", args: ["code": code])
        householdID = row.id
        defaults.set(userID, forKey: kEnsuredUser)
    }

    // MARK: - Push (all household rows; idempotent upserts)

    private func pushAll(householdID hid: UUID) async throws {
        let participants = try context.fetch(FetchDescriptor<Participant>())
            .filter { $0.householdID == hid }
            .map { RemoteParticipant(uuid: $0.uuid, householdId: hid, name: $0.name, emoji: $0.emoji,
                                  colorHex: $0.colorHex, createdAt: $0.createdAt,
                                  updatedAt: $0.updatedAt, deletedAt: $0.deletedAt) }
        try await client.upsert(participants, into: "participants")

        let chores = try context.fetch(FetchDescriptor<Chore>())
            .filter { $0.householdID == hid }
            .map { RemoteChore(uuid: $0.uuid, householdId: hid, name: $0.name, emoji: $0.emoji,
                            points: $0.points, colorHex: $0.colorHex, isArchived: $0.isArchived,
                            sortOrder: $0.sortOrder, createdAt: $0.createdAt,
                            updatedAt: $0.updatedAt, deletedAt: $0.deletedAt) }
        try await client.upsert(chores, into: "chores")

        let completions = try context.fetch(FetchDescriptor<Completion>())
            .filter { $0.householdID == hid }
            .map { RemoteCompletion(uuid: $0.uuid, householdId: hid, completedAt: $0.completedAt,
                                 pointsAwarded: $0.pointsAwarded, choreName: $0.choreName,
                                 choreEmoji: $0.choreEmoji, participantUuid: $0.participant?.uuid,
                                 choreUuid: $0.chore?.uuid,
                                 updatedAt: $0.updatedAt, deletedAt: $0.deletedAt) }
        try await client.upsert(completions, into: "completions")
    }

    // MARK: - Pull (rows newer than the cursor) + merge LWW

    private func pull(householdID hid: UUID) async throws {
        let pRows = try await client.select(RemoteParticipant.self, from: "participants",
                                            query: pullQuery(hid, table: "participants"))
        for row in pRows { mergeParticipant(row) }
        advanceCursor("participants", rows: pRows.map(\.updatedAt))

        let cRows = try await client.select(RemoteChore.self, from: "chores",
                                            query: pullQuery(hid, table: "chores"))
        for row in cRows { mergeChore(row) }
        advanceCursor("chores", rows: cRows.map(\.updatedAt))

        // Build uuid maps so completions can relink locally.
        let participantsByUUID = Dictionary(
            (try context.fetch(FetchDescriptor<Participant>())).map { ($0.uuid, $0) },
            uniquingKeysWith: { a, _ in a })
        let choresByUUID = Dictionary(
            (try context.fetch(FetchDescriptor<Chore>())).map { ($0.uuid, $0) },
            uniquingKeysWith: { a, _ in a })

        let xRows = try await client.select(RemoteCompletion.self, from: "completions",
                                            query: pullQuery(hid, table: "completions"))
        for row in xRows {
            mergeCompletion(row, participants: participantsByUUID, chores: choresByUUID)
        }
        advanceCursor("completions", rows: xRows.map(\.updatedAt))

        context.saveChanges()
    }

    private func pullQuery(_ hid: UUID, table: String) -> [URLQueryItem] {
        let cursor = (defaults.object(forKey: kCursor(table)) as? Date) ?? .distantPast
        return [
            URLQueryItem(name: "household_id", value: "eq.\(hid.uuidString)"),
            URLQueryItem(name: "updated_at", value: "gt.\(SupabaseCoding.isoString(cursor))"),
            URLQueryItem(name: "order", value: "updated_at.asc")
        ]
    }

    private func advanceCursor(_ table: String, rows updatedAts: [Date]) {
        if let maxDate = updatedAts.max() {
            defaults.set(maxDate, forKey: kCursor(table))
        }
    }

    // MARK: - Merge helpers (last-write-wins by updatedAt)

    private func existing<T: PersistentModel>(_ type: T.Type, uuidKeyPath: (T) -> UUID, uuid: UUID) -> T? {
        (try? context.fetch(FetchDescriptor<T>()))?.first { uuidKeyPath($0) == uuid }
    }

    private func mergeParticipant(_ row: RemoteParticipant) {
        if let local = existing(Participant.self, uuidKeyPath: { $0.uuid }, uuid: row.uuid) {
            guard row.updatedAt > local.updatedAt else { return }
            local.name = row.name; local.emoji = row.emoji; local.colorHex = row.colorHex
            local.updatedAt = row.updatedAt; local.deletedAt = row.deletedAt; local.householdID = row.householdId
        } else {
            context.insert(Participant(uuid: row.uuid, name: row.name, emoji: row.emoji,
                                       colorHex: row.colorHex, createdAt: row.createdAt,
                                       updatedAt: row.updatedAt, deletedAt: row.deletedAt,
                                       householdID: row.householdId))
        }
    }

    private func mergeChore(_ row: RemoteChore) {
        if let local = existing(Chore.self, uuidKeyPath: { $0.uuid }, uuid: row.uuid) {
            guard row.updatedAt > local.updatedAt else { return }
            local.name = row.name; local.emoji = row.emoji; local.points = row.points
            local.colorHex = row.colorHex; local.isArchived = row.isArchived; local.sortOrder = row.sortOrder
            local.updatedAt = row.updatedAt; local.deletedAt = row.deletedAt; local.householdID = row.householdId
        } else {
            context.insert(Chore(uuid: row.uuid, name: row.name, emoji: row.emoji, points: row.points,
                                 colorHex: row.colorHex, isArchived: row.isArchived, sortOrder: row.sortOrder,
                                 createdAt: row.createdAt, updatedAt: row.updatedAt,
                                 deletedAt: row.deletedAt, householdID: row.householdId))
        }
    }

    private func mergeCompletion(_ row: RemoteCompletion,
                                 participants: [UUID: Participant],
                                 chores: [UUID: Chore]) {
        let participant = row.participantUuid.flatMap { participants[$0] }
        let chore = row.choreUuid.flatMap { chores[$0] }
        if let local = existing(Completion.self, uuidKeyPath: { $0.uuid }, uuid: row.uuid) {
            guard row.updatedAt > local.updatedAt else { return }
            local.completedAt = row.completedAt; local.pointsAwarded = row.pointsAwarded
            local.choreName = row.choreName; local.choreEmoji = row.choreEmoji
            local.participant = participant; local.chore = chore
            local.updatedAt = row.updatedAt; local.deletedAt = row.deletedAt; local.householdID = row.householdId
        } else {
            context.insert(Completion(uuid: row.uuid, completedAt: row.completedAt,
                                      pointsAwarded: row.pointsAwarded, choreName: row.choreName,
                                      choreEmoji: row.choreEmoji, participant: participant, chore: chore,
                                      updatedAt: row.updatedAt, deletedAt: row.deletedAt,
                                      householdID: row.householdId))
        }
    }

    // MARK: - Local data helpers

    private func setHousehold(id: UUID, code: String, resetCursors: Bool) {
        householdID = id
        defaults.set(code, forKey: kInviteCode)
        householdCode = code
        if resetCursors {
            for table in ["participants", "chores", "completions"] { defaults.removeObject(forKey: kCursor(table)) }
        }
    }

    private func stampAllLocalRows(with hid: UUID) {
        let now = Date.now
        for p in (try? context.fetch(FetchDescriptor<Participant>())) ?? [] { p.householdID = hid; p.touch(now) }
        for c in (try? context.fetch(FetchDescriptor<Chore>())) ?? [] { c.householdID = hid; c.touch(now) }
        for x in (try? context.fetch(FetchDescriptor<Completion>())) ?? [] { x.householdID = hid; x.touch(now) }
    }

    private func wipeLocalData() {
        for x in (try? context.fetch(FetchDescriptor<Completion>())) ?? [] { context.delete(x) }
        for c in (try? context.fetch(FetchDescriptor<Chore>())) ?? [] { context.delete(c) }
        for p in (try? context.fetch(FetchDescriptor<Participant>())) ?? [] { context.delete(p) }
    }
}
