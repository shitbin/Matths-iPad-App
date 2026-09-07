import Foundation

@main enum TeacherAttendanceWritePlanCases {
    typealias Value = ServerAPI.TeacherAttendanceRecord.Value
    static func main() throws {
        let recordID = "0123456789abcdef01234567"
        let original = ServerAPI.TeacherAttendanceEntry.Attendance(id: recordID, updatedAt: "2026-09-07T01:00:00.000Z",
            status: "PRESENT", checkedInAt: nil, source: "MANUAL", note: "기존 메모")
        var roster = ServerAPI.TeacherAttendanceRoster(dateKey: "2026-09-07", todayKey: "2026-09-07", classes: [],
            selectedClass: nil, session: nil, roster: [
                .init(id: "membership-A", student: .init(id: "student-A"), attendance: original),
                .init(id: "membership-B", student: .init(id: "student-B"), attendance: nil),
            ], counts: .init(TOTAL: 2, PRESENT: 1, LATE: 0, ABSENT: 0, EXCUSED: 0, UNRECORDED: 1),
            truncated: false, conditionalWriteVersion: 1)
        let baseline: [String: Value] = ["membership-A": .init(status: "PRESENT", note: "기존 메모"),
            "membership-B": .init(status: "", note: "")]
        var edited = baseline
        edited["membership-B"] = .init(status: "ABSENT", note: "  사유\n 확인  ")
        let records = try ServerAPI.changedTeacherAttendanceRecords(roster: roster, baseline: baseline, edited: edited)
        precondition(records.count == 1 && records[0].studentUserID == "student-B", "untouched student A must never be in the POST")
        precondition(records[0].note == "사유 확인")
        precondition(records[0].expectedState == .init(recordID: nil, updatedAt: nil, status: nil, note: ""))
        let encoded = try JSONSerialization.data(withJSONObject: records.map(\.requestBody))
        let body = try JSONSerialization.jsonObject(with: encoded) as! [[String: Any]]
        let absent = body[0]["expectedState"] as! [String: Any]
        precondition(absent["recordId"] is NSNull && absent["updatedAt"] is NSNull && absent["status"] is NSNull)
        precondition(absent["note"] as? String == "")

        edited = baseline
        edited["membership-A"] = .init(status: "LATE", note: "수정 메모")
        let changed = try ServerAPI.changedTeacherAttendanceRecords(roster: roster, baseline: baseline, edited: edited)
        precondition(changed.count == 1)
        precondition(changed[0].expectedState?.recordID == recordID)
        precondition(changed[0].expectedState?.updatedAt == original.updatedAt)
        precondition(changed[0].expectedState?.status == "PRESENT")
        precondition(changed[0].expectedState?.note == "기존 메모", "guard must contain server baseline, not edited values")

        edited = baseline
        edited["membership-A"] = .init(status: "", note: "")
        let clear = try ServerAPI.changedTeacherAttendanceRecords(roster: roster, baseline: baseline, edited: edited)
        precondition(clear.count == 1 && clear[0].status == "" && clear[0].expectedState?.recordID == recordID)
        edited = baseline
        edited["membership-A"] = .init(status: "PRESENT", note: " 기존   메모 ")
        let normalizedUnchanged = try ServerAPI.changedTeacherAttendanceRecords(roster: roster, baseline: baseline, edited: edited)
        precondition(normalizedUnchanged.isEmpty,
                     "whitespace-only note edits must not rewrite a row")

        roster.conditionalWriteVersion = nil
        let legacy = try ServerAPI.changedTeacherAttendanceRecords(roster: roster, baseline: baseline,
            edited: ["membership-B": .init(status: "LATE", note: "")])
        precondition(legacy.count == 1 && legacy[0].expectedState == nil)
        precondition(legacy[0].requestBody["expectedState"] == nil, "old server gets changed rows but no fabricated conditional support")
        roster.conditionalWriteVersion = 1
        roster.roster[0].attendance?.id = nil
        do {
            _ = try ServerAPI.changedTeacherAttendanceRecords(roster: roster, baseline: baseline,
                edited: ["membership-A": .init(status: "LATE", note: "")])
            preconditionFailure("malformed supported metadata must not be guessed as a missing row")
        } catch let error as ServerAPIError { precondition(error.code == "ATTENDANCE_EXPECTED_STATE_INVALID") }

        // After HTTP409, refreshing compares fresh server state against the
        // unchanged local baseline: it keeps the draft, flags a collision, and
        // uses the new server baseline only after explicit local resolution.
        let fresh: [String: Value] = ["membership-A": .init(status: "EXCUSED", note: "관리자 보정"), "membership-B": baseline["membership-B"]!]
        let local: [String: Value] = ["membership-A": .init(status: "LATE", note: "내 초안"), "membership-B": baseline["membership-B"]!]
        let merged = StaffDraftMerge(server: fresh, baseline: baseline, edited: local)
        precondition(merged.values["membership-A"] == local["membership-A"])
        precondition(merged.conflicts == ["membership-A"])
        precondition(merged.values["membership-B"] == fresh["membership-B"])
        print("Native attendance write plan PASS: changed rows only, exact guarded baseline, missing-row nulls, conditional clear, normalization, legacy fallback, malformed metadata rejection, conflict draft preservation.")
    }
}
