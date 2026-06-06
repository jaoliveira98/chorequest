import Foundation
import WatchConnectivity

/// Apple Watch side of the sync. Receives the participants + chores snapshot from
/// the paired iPhone (cached locally so it survives relaunches), and sends logged
/// completions back to the phone reliably via `transferUserInfo`.
@MainActor
final class WatchSyncManager: NSObject, ObservableObject {
    @Published private(set) var snapshot: SyncSnapshot = .empty

    private let cacheKey = "watch.cachedSnapshot"

    override init() {
        super.init()
        loadCache()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Queue a completion for delivery to the phone. `transferUserInfo` is FIFO,
    /// persists across launches, and delivers when the phone is next reachable.
    func log(participant: ParticipantDTO, chore: ChoreDTO) {
        let dto = CompletionDTO(
            uuid: UUID(),
            participantUUID: participant.uuid,
            choreUUID: chore.uuid,
            completedAt: .now,
            pointsAwarded: chore.points,
            choreName: chore.name,
            choreEmoji: chore.emoji
        )
        do {
            let data = try WatchSyncWire.encode(dto)
            WCSession.default.transferUserInfo([WatchSyncWire.completionKey: data])
        } catch {
            print("ChoreQuestWatch: failed to send completion — \(error)")
        }
    }

    private func apply(_ data: Data) {
        guard let snap = try? WatchSyncWire.decode(SyncSnapshot.self, from: data) else { return }
        snapshot = snap
        UserDefaults.standard.set(data, forKey: cacheKey)
    }

    private func loadCache() {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let snap = try? WatchSyncWire.decode(SyncSnapshot.self, from: data) {
            snapshot = snap
        }
    }
}

extension WatchSyncManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        // Apply any context the system already cached before the delegate was set.
        let cached = session.receivedApplicationContext
        if let data = cached[WatchSyncWire.snapshotKey] as? Data {
            Task { @MainActor in self.apply(data) }
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        guard let data = applicationContext[WatchSyncWire.snapshotKey] as? Data else { return }
        Task { @MainActor in self.apply(data) }
    }
}
