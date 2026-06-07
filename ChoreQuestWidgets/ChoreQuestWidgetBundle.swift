import WidgetKit
import SwiftUI

/// Home-screen widgets for ChoreQuest. They read the snapshot the app publishes
/// to the shared App Group (see WidgetSnapshot / WidgetUpdater) — no SwiftData in
/// the extension. The app calls WidgetCenter.reloadAllTimelines() on changes; the
/// timeline below also refreshes periodically as a fallback.
@main
struct ChoreQuestWidgetBundle: WidgetBundle {
    var body: some Widget {
        LeaderboardWidget()
        TodayWidget()
    }
}

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: Date(), snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        let loaded = WidgetStore.load()
        let snapshot = (context.isPreview || loaded.standings.isEmpty) ? .sample : loaded
        completion(SnapshotEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let entry = SnapshotEntry(date: Date(), snapshot: WidgetStore.load())
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
