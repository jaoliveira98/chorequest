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
        let now = Date()
        let entry = SnapshotEntry(date: now, snapshot: WidgetStore.load())
        // Refresh every 30 min as a fallback, but no later than the next midnight so
        // "today"/"this week" roll over promptly even if the app stays closed.
        let halfHour = now.addingTimeInterval(30 * 60)
        let nextMidnight = Calendar.current.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0, second: 0),
                                                     matchingPolicy: .nextTime) ?? halfHour
        completion(Timeline(entries: [entry], policy: .after(min(halfHour, nextMidnight))))
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
