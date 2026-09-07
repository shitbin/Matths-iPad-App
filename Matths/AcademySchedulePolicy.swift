import Foundation

/// Shared web/API convention, not Calendar.component(.weekday): Sunday is 0.
enum AcademySchedulePolicy {
    static let weekdayLabels = ["일", "월", "화", "수", "목", "금", "토"]
    static let defaultWeekdays = [1]
    static func weekdayLabel(_ day: Int) -> String? {
        weekdayLabels.indices.contains(day) ? weekdayLabels[day] : nil
    }
    static func validWeekdays(_ days: [Int]) -> Bool {
        !days.isEmpty && days.allSatisfy { weekdayLabels.indices.contains($0) }
    }
    static func attendanceWindowIsValid(late: Int, close: Int) -> Bool { close > late }
}
