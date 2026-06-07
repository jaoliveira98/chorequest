import Foundation
import SwiftData
import WidgetKit

/// Builds the widget snapshot from SwiftData and publishes it to the App Group,
/// then asks WidgetKit to refresh. Called whenever data changes (on launch /
/// foreground, after logging a chore, and after a cloud sync) so the home-screen
/// widgets stay in step with the app. Uses the same week/today math as the
/// Leaderboard so the numbers match.
enum WidgetUpdater {
    @MainActor
    static func refresh(_ context: ModelContext) {
        let weekStart = TimeRange.week.lowerBound
        let todayStart = DateUtils.startOfDay()

        let participants = ((try? context.fetch(FetchDescriptor<Participant>())) ?? [])
            .filter { !$0.isSoftDeleted }

        var standings: [WidgetSnapshot.Standing] = []
        var todayTotal = 0
        var weekTotal = 0

        for person in participants {
            let live = person.completions.filter { !$0.isSoftDeleted }
            let week = live
                .filter { completion in weekStart.map { completion.completedAt >= $0 } ?? true }
                .reduce(0) { $0 + $1.pointsAwarded }
            let today = live
                .filter { $0.completedAt >= todayStart }
                .reduce(0) { $0 + $1.pointsAwarded }
            standings.append(.init(id: person.uuid, name: person.name, emoji: person.emoji,
                                   colorHex: person.colorHex, weekPoints: week, todayPoints: today))
            weekTotal += week
            todayTotal += today
        }

        standings.sort { lhs, rhs in
            if lhs.weekPoints != rhs.weekPoints { return lhs.weekPoints > rhs.weekPoints }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }

        WidgetStore.save(WidgetSnapshot(generatedAt: .now, standings: standings,
                                        todayTotal: todayTotal, weekTotal: weekTotal))
        WidgetCenter.shared.reloadAllTimelines()
    }
}
