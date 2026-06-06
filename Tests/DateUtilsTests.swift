import XCTest
@testable import ChoreQuest

final class DateUtilsTests: XCTestCase {
    private var calendar: Calendar { Calendar.current }

    /// A start-of-day date `offset` days from today.
    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: DateUtils.startOfToday())!
    }

    func testStreakIsZeroWithNoActivity() {
        XCTAssertEqual(DateUtils.streak(activeDays: []), 0)
    }

    func testStreakCountsTodayOnly() {
        XCTAssertEqual(DateUtils.streak(activeDays: [day(0)]), 1)
    }

    func testStreakCountsConsecutiveDaysEndingToday() {
        XCTAssertEqual(DateUtils.streak(activeDays: [day(0), day(-1), day(-2)]), 3)
    }

    func testStreakStaysAliveWhenLastActivityWasYesterday() {
        // Nothing today yet, but yesterday and the day before are active.
        XCTAssertEqual(DateUtils.streak(activeDays: [day(-1), day(-2)]), 2)
    }

    func testStreakIsBrokenWhenNothingTodayOrYesterday() {
        XCTAssertEqual(DateUtils.streak(activeDays: [day(-2), day(-3)]), 0)
    }

    func testStreakStopsAtFirstGap() {
        // today + yesterday, then a gap at -2, with activity again at -3.
        XCTAssertEqual(DateUtils.streak(activeDays: [day(0), day(-1), day(-3)]), 2)
    }

    func testStartOfThisWeekIsNotAfterNow() {
        XCTAssertLessThanOrEqual(DateUtils.startOfThisWeek(), .now)
    }
}
