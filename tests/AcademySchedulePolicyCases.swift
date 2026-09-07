import Foundation

@main enum AcademySchedulePolicyCases {
    static func main() {
        let webLabels = ["일", "월", "화", "수", "목", "금", "토"]
        for day in 0...6 {
            precondition(AcademySchedulePolicy.weekdayLabel(day) == webLabels[day])
            precondition(AcademySchedulePolicy.validWeekdays([day]))
        }
        precondition([1, 4].compactMap(AcademySchedulePolicy.weekdayLabel).joined(separator: "·") == "월·목")
        precondition(AcademySchedulePolicy.defaultWeekdays == [1])
        precondition(!AcademySchedulePolicy.validWeekdays([]))
        precondition(!AcademySchedulePolicy.validWeekdays([1, 7]))
        precondition(AcademySchedulePolicy.weekdayLabel(-1) == nil)
        precondition(AcademySchedulePolicy.weekdayLabel(7) == nil)
        for late in 0...120 {
            precondition(!AcademySchedulePolicy.attendanceWindowIsValid(late: late, close: late))
            precondition(!AcademySchedulePolicy.attendanceWindowIsValid(late: late, close: late - 1))
            precondition(AcademySchedulePolicy.attendanceWindowIsValid(late: late, close: late + 1))
        }
        print("Academy schedule: web Sunday-zero mapping and strict late/close boundaries passed")
    }
}
