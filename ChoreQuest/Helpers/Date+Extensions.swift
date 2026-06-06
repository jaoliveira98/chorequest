import Foundation

/// Date helpers for the leaderboard time ranges, the history day grouping, and
/// streak calculation. Uses the user's current calendar/locale.
enum DateUtils {
    static var calendar: Calendar { .current }

    static func startOfDay(_ date: Date = .now) -> Date {
        calendar.startOfDay(for: date)
    }

    static func startOfToday() -> Date {
        startOfDay()
    }

    /// First moment of the current week (honoring the locale's first weekday).
    static func startOfThisWeek() -> Date {
        calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? startOfToday()
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEE, MMM d")
        return formatter
    }()

    /// Time of day, e.g. "2:45 PM".
    static func time(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    /// A friendly header for a day: "Today", "Yesterday", or "Tuesday, Jun 4".
    static func dayHeader(for date: Date) -> String {
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return dayFormatter.string(from: date)
    }

    /// Counts consecutive days (ending today, or yesterday if nothing yet today)
    /// that contain activity. `activeDays` must be start-of-day dates.
    static func streak(activeDays: Set<Date>) -> Int {
        guard !activeDays.isEmpty else { return 0 }

        var cursor = startOfToday()
        if !activeDays.contains(cursor) {
            // A streak can still be "alive" if the last activity was yesterday.
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor),
                  activeDays.contains(yesterday) else {
                return 0
            }
            cursor = yesterday
        }

        var count = 0
        while activeDays.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }
}
