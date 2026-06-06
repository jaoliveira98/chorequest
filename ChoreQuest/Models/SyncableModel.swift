import Foundation

/// Shared sync metadata for the models that will sync to the cloud (CQ-13).
///
/// Introduced locally in CQ-12: every row carries an `updatedAt` (the
/// last-write-wins key used later) and an optional `deletedAt` for **soft
/// deletes** — deleted rows are hidden everywhere but kept so the deletion can
/// propagate to other devices once sync exists.
protocol SyncableModel: AnyObject {
    var updatedAt: Date { get set }
    var deletedAt: Date? { get set }
}

extension SyncableModel {
    /// Whether this row is soft-deleted (hidden in the UI, retained for sync).
    var isSoftDeleted: Bool { deletedAt != nil }

    /// Advance the last-write-wins timestamp after a change.
    func touch(_ date: Date = .now) {
        updatedAt = date
    }

    /// Hide the row but keep it so the deletion can propagate.
    func softDelete(_ date: Date = .now) {
        deletedAt = date
        updatedAt = date
    }
}
