import SwiftData
import Foundation
import SQLite3

/// The single SwiftData container, shared by the app, the App Intents (Siri /
/// Shortcuts), and the interactive Quick Log widget.
///
/// The store lives in the shared **App Group** container so the widget extension
/// can write to the same database when you tap a chore. On first launch after
/// this change we migrate the previous (app-local) store into the App Group.
enum AppModelContainer {
    static let shared: ModelContainer = {
        migrateLocalStoreToAppGroupIfNeeded()
        let config = ModelConfiguration(url: appGroupStoreURL)
        do {
            return try ModelContainer(for: Participant.self, Chore.self, Completion.self,
                                      configurations: config)
        } catch {
            fatalError("Failed to create the ChoreQuest data store: \(error)")
        }
    }()

    /// The store URL inside the shared App Group container. A missing App Group is
    /// a hard configuration error in the app/widget — fail loudly rather than
    /// silently falling back to a per-process sandbox path (which would split the
    /// app's and widget's data). Tests run unsigned (no entitlement) → temp path.
    static var appGroupStoreURL: URL {
        if let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: WidgetSharedConfig.appGroup) {
            return container.appending(path: "ChoreQuest.store")
        }
        if NSClassFromString("XCTestCase") != nil {
            return FileManager.default.temporaryDirectory.appending(path: "ChoreQuestTests.store")
        }
        fatalError("App Group \(WidgetSharedConfig.appGroup) is unavailable — check the App Group entitlement on the app AND widget targets.")
    }

    private static func migrateLocalStoreToAppGroupIfNeeded() {
        let fm = FileManager.default
        let newURL = appGroupStoreURL
        guard !fm.fileExists(atPath: newURL.path) else { return }            // already migrated / fresh App Group store
        let oldURL = URL.applicationSupportDirectory.appending(path: "default.store")
        guard fm.fileExists(atPath: oldURL.path) else { return }             // fresh install, nothing to migrate
        migrateStore(from: oldURL, to: newURL)
    }

    /// Fold the old store's WAL into its main file, then copy only the durable
    /// files (`.store` + `-wal`; never the volatile `-shm`, which SQLite rebuilds).
    /// On any failure, remove the partial copy so the next launch retries.
    /// Exposed for testing.
    static func migrateStore(from oldURL: URL, to newURL: URL) {
        let fm = FileManager.default
        checkpointWAL(at: oldURL)
        for suffix in ["", "-wal"] {
            let src = URL(fileURLWithPath: oldURL.path + suffix)
            let dst = URL(fileURLWithPath: newURL.path + suffix)
            guard fm.fileExists(atPath: src.path) else { continue }
            do {
                try fm.copyItem(at: src, to: dst)
            } catch {
                try? fm.removeItem(at: URL(fileURLWithPath: newURL.path))
                try? fm.removeItem(at: URL(fileURLWithPath: newURL.path + "-wal"))
                print("ChoreQuest: store migration failed (\(suffix.isEmpty ? "store" : "wal")): \(error)")
                return
            }
        }
    }

    /// TRUNCATE-checkpoint so all committed data lives in the main `.store` file.
    private static func checkpointWAL(at url: URL) {
        var db: OpaquePointer?
        guard sqlite3_open(url.path, &db) == SQLITE_OK else {
            if db != nil { sqlite3_close(db) }
            return
        }
        sqlite3_wal_checkpoint_v2(db, nil, SQLITE_CHECKPOINT_TRUNCATE, nil, nil)
        sqlite3_close(db)
    }
}
