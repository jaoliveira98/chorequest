import Foundation

/// The leaderboard's scoring window.
enum TimeRange: String, CaseIterable, Identifiable, Hashable {
    case today
    case week
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "Today"
        case .week: return "This Week"
        case .all: return "All Time"
        }
    }

    /// Completions on/after this instant count toward the score (nil = all time).
    var lowerBound: Date? {
        switch self {
        case .today: return DateUtils.startOfToday()
        case .week: return DateUtils.startOfThisWeek()
        case .all: return nil
        }
    }
}
