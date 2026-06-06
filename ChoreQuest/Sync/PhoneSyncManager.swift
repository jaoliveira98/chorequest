import Foundation
import SwiftData
import WatchConnectivity

/// iPhone side of the watch sync. Owns the `WCSession`, pushes the current
/// participants + active chores (+ today points) to the watch, and ingests
/// completions the watch logs — writing them into SwiftData on the main actor.
///
/// The phone is the single source of truth. A future phone↔phone cloud layer
/// plugs in behind this (the watch is unaffected).
@MainActor
final class PhoneSyncManager: NSObject, ObservableObject {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Build a snapshot from current data and push it to the watch (latest wins).
    func pushSnapshot() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        // Only push when there's actually a watch app to receive it — avoids
        // WCErrorCodeWatchAppNotInstalled (7006) log spam when no watch is set up.
        guard session.activationState == .activated,
              session.isPaired,
              session.isWatchAppInstalled else { return }
        do {
            let data = try WatchSyncWire.encode(makeSnapshot())
            try session.updateApplicationContext([WatchSyncWire.snapshotKey: data])
        } catch {
            print("ChoreQuest: failed to push snapshot to watch — \(error)")
        }
    }

    private func makeSnapshot() throws -> SyncSnapshot {
        let context = modelContainer.mainContext
        // Split fetch from filter (and use explicit keypath roots) so the Swift
        // type-checker doesn't choke on the chained generic expression.
        let fetchedParticipants = try context.fetch(
            FetchDescriptor<Participant>(sortBy: [SortDescriptor(\Participant.createdAt)])
        )
        let participants = fetchedParticipants.filter { !$0.isSoftDeleted }

        let fetchedChores = try context.fetch(
            FetchDescriptor<Chore>(sortBy: [SortDescriptor(\Chore.sortOrder), SortDescriptor(\Chore.createdAt)])
        )
        let chores = fetchedChores.filter { !$0.isArchived && !$0.isSoftDeleted }

        let startOfToday = DateUtils.startOfToday()
        let participantDTOs = participants.map { person in
            let todayPoints = person.completions.reduce(0) { sum, completion in
                (completion.completedAt >= startOfToday && !completion.isSoftDeleted) ? sum + completion.pointsAwarded : sum
            }
            return ParticipantDTO(
                uuid: person.uuid, name: person.name, emoji: person.emoji,
                colorHex: person.colorHex, points: todayPoints
            )
        }
        let choreDTOs = chores.map { chore in
            ChoreDTO(
                uuid: chore.uuid, name: chore.name, emoji: chore.emoji,
                points: chore.points, colorHex: chore.colorHex ?? Palette.defaultColor
            )
        }
        return SyncSnapshot(participants: participantDTOs, chores: choreDTOs, generatedAt: .now)
    }

    /// Insert a watch-logged completion into SwiftData (main actor).
    private func ingest(_ dto: CompletionDTO) {
        let context = modelContainer.mainContext
        do {
            // Idempotent: ignore a completion we already have (re-delivered transfer).
            let existing = try context.fetch(FetchDescriptor<Completion>())
            if existing.contains(where: { $0.uuid == dto.uuid }) { return }

            let participant = try context.fetch(FetchDescriptor<Participant>())
                .first { $0.uuid == dto.participantUUID }
            // Don't create an owner-less or deleted-owner completion.
            guard let participant, !participant.isSoftDeleted else { return }
            let chore = try context.fetch(FetchDescriptor<Chore>())
                .first { $0.uuid == dto.choreUUID }

            // Use the watch's snapshot fields so the record matches what was shown,
            // and survives even if the chore was since edited/deleted.
            let completion = Completion(
                uuid: dto.uuid,
                completedAt: dto.completedAt,
                pointsAwarded: dto.pointsAwarded,
                choreName: dto.choreName,
                choreEmoji: dto.choreEmoji,
                participant: participant,
                chore: chore
            )
            context.insert(completion)
            context.saveChanges()
            pushSnapshot() // reflect the new points back to the watch
        } catch {
            print("ChoreQuest: failed to ingest watch completion — \(error)")
        }
    }
}

extension PhoneSyncManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in self.pushSnapshot() }
    }

    // iOS-only required stubs.
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate so a newly paired watch keeps syncing.
        WCSession.default.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard let data = userInfo[WatchSyncWire.completionKey] as? Data else { return }
        do {
            let dto = try WatchSyncWire.decode(CompletionDTO.self, from: data)
            Task { @MainActor in self.ingest(dto) }
        } catch {
            print("ChoreQuest: failed to decode watch completion — \(error)")
        }
    }
}
