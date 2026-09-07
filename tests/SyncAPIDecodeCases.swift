import Foundation

private struct ProgressEnvelope: Decodable {
    var progress: [ServerAPI.RemoteConceptProgress]
}

private struct WrongNotesEnvelope: Decodable {
    var entries: [ServerAPI.RemoteWrongNote]
}

@main
struct SyncAPIDecodeCases {
    static func decode<T: Decodable>(_ json: String, as type: T.Type) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }

    static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fputs("FAIL: \(message)\n", stderr)
            exit(1)
        }
    }

    static func main() throws {
        let progress = try decode(
            """
            {"progress":[{"courseId":"common-math-1","unitId":"polynomials","conceptId":"polynomial-arithmetic","completedTopicIndexes":[0,1],"completionPercent":90,"masteryGate":{"requiredDistinctTypes":5,"correctTypeIds":["a","b"],"userCompleted":false},"lastStudiedAt":"2026-08-04T00:00:00.000Z"}]}
            """,
            as: ProgressEnvelope.self
        )
        require(progress.progress.first?.completedTopicIndexes == [0, 1], "progress contract")

        let wrong = try decode(
            """
            {"entries":[{"attemptId":"66a000000000000000000001","clientAttemptId":"client-1","statement":"x+1=2","answer":"1","steps":["x=1"],"typeKey":"linear","seed":"42","myAnswer":"0","divergenceStep":1,"errorType":"sign-error","srsStage":1,"wrongCount":2,"nextReviewAt":null,"reviewStatus":"completed","createdAt":"2026-08-04T01:00:00.000Z","choices":["0","1"],"isTex":true}]}
            """,
            as: WrongNotesEnvelope.self
        )
        require(wrong.entries.first?.reviewStatus == "completed", "wrong-note status contract")
        require(wrong.entries.first?.wrongCount == 2, "wrong-note counter contract")

        let reviewBody = ServerAPI.reviewResultBody(
            correct: false,
            srsStage: 1,
            wrongCount: 2,
            nextReviewAt: "2026-08-05T15:00:00.000Z",
            clientEventId: "review-op-1"
        )
        require(
            reviewBody["clientEventId"] as? String == "review-op-1",
            "review retry must carry its durable idempotency key"
        )
        require(
            reviewBody["correct"] as? Bool == false,
            "wrong review must not be hard-coded as correct"
        )

        let dashboard = try decode(
            """
            {"dashboard":{"generatedAt":"2026-08-04T01:00:00.000Z","stats":{"weeklyStudyMinutes":12,"weeklyStudyDetail":"지난 기간보다 +2분","todayStudyMinutes":4,"activeStudyDays":3,"averageStudyMinutes":4,"weeklySolvedProblems":8,"weeklySolvedDetail":"지난 기간보다 +1문제","correctRate":75,"correctRateDetail":"지난 기간보다 +5%p"},"weeklyActivity":{"days":[{"dateKey":"2026-08-04","label":"오늘","minutes":4,"isToday":true}],"maxMinutes":10}}}
            """,
            as: ServerAPI.DashboardActivityResponse.self
        )
        require(dashboard.dashboard.stats.weeklySolvedProblems == 8, "dashboard stats contract")
        require(dashboard.dashboard.weeklyActivity.days.first?.isToday == true, "dashboard days contract")

        let legacyRulebook = try decode(
            """
            {"schemaVersion":"GOAT_ARENA_RULEBOOK_V1","revision":"FINAL_LOGIC_V1_4","generatedAt":"2026-08-10T00:00:00.000Z","source":"SERVER_ACTIVE_POLICY","divisions":{"sub":{"division":"SUB","title":"Unranked 경기 규정","eyebrow":"공식 경기 규정","intro":"소개","summary":[],"rules":[]},"main":{"division":"MAIN","title":"Ranked 경기 규정","eyebrow":"공식 경기 규정","intro":"소개","summary":[],"rules":[]}}}
            """,
            as: ServerAPI.GoatArenaRulebookDocument.self
        )
        require(
            legacyRulebook.divisions.sub.upcomingPolicy == nil,
            "legacy rulebook without upcoming policy remains decodable"
        )

        let upcomingRulebook = try decode(
            """
            {"schemaVersion":"GOAT_ARENA_RULEBOOK_V1","revision":"FINAL_LOGIC_V1_4","generatedAt":"2026-08-10T00:00:00.000Z","source":"SERVER_ACTIVE_POLICY","divisions":{"sub":{"division":"SUB","title":"Unranked 경기 규정","eyebrow":"공식 경기 규정","intro":"소개","summary":[],"rules":[],"upcomingPolicy":{"displayName":"9월 Unranked 정책","effectiveFrom":"2026-09-10T00:00:00.000Z","priceAmount":29000}},"main":{"division":"MAIN","title":"Ranked 경기 규정","eyebrow":"공식 경기 규정","intro":"소개","summary":[],"rules":[],"upcomingPolicy":{"displayName":"9월 Ranked 정책","effectiveFrom":"2026-09-10T00:00:00.000Z","policyVersionCode":"MAIN-2026-09"}}}}
            """,
            as: ServerAPI.GoatArenaRulebookDocument.self
        )
        require(
            upcomingRulebook.divisions.main.upcomingPolicy?.policyVersionCode == "MAIN-2026-09",
            "V1 rulebook safely decodes optional upcoming policy notice"
        )

        let codeOnlyError = try decode(
            #"{"code":"GOAT_ARENA_INTERNAL_MACHINE_CODE"}"#,
            as: ServerAPIError.self
        )
        require(
            codeOnlyError.errorDescription
                == "요청을 처리하지 못했습니다. 잠시 후 다시 시도해 주세요.",
            "machine-only server codes must not be exposed as localized UI copy"
        )
        require(
            codeOnlyError.code == "GOAT_ARENA_INTERNAL_MACHINE_CODE",
            "machine code must remain available for typed client branching"
        )

        let readableError = try decode(
            #"{"code":"IGNORED_CODE","message":"다시 로그인해 주세요."}"#,
            as: ServerAPIError.self
        )
        require(
            readableError.errorDescription == "다시 로그인해 주세요.",
            "human-readable server messages must remain visible"
        )

        let legacyAcademyWeek = #"{"id":"week-1","academicYear":2026,"weekNumber":1,"title":"1주차","lessonSummary":"수업","concepts":[],"assignmentTitle":"과제","assignmentInstructions":"풀어 주세요","dueAt":null,"files":[]}"#
        let oldWeek = try decode(legacyAcademyWeek, as: ServerAPI.AcademyWeek.self)
        require(oldWeek.assignmentOmr == nil && oldWeek.submissions == nil, "legacy week without assignment fields remains decodable")
        let legacyWeekResponse = """
        {"academy":{"id":"academy-1","name":"학원"},"academyClass":{"id":"class-1","name":"반"},"week":\(legacyAcademyWeek)}
        """
        let oldWeekResponse = try decode(legacyWeekResponse, as: ServerAPI.AcademyWeekResponse.self)
        require(oldWeekResponse.submission == nil && oldWeekResponse.serverTime == nil, "legacy week envelope does not require new optional receipt/time")
        let assignmentJSON = #"{"enabled":true,"questionCount":2,"sections":[{"startNumber":1,"endNumber":1,"answerType":"MULTIPLE_CHOICE","choiceCount":9},{"startNumber":2,"endNumber":2,"answerType":"SHORT_ANSWER","choiceCount":5}],"questions":[{"number":1,"answerType":"MULTIPLE_CHOICE","choiceCount":9,"answer":""},{"number":2,"answerType":"SHORT_ANSWER","choiceCount":5,"answer":""}],"configuredAt":"2026-09-07T00:00:00Z","missedSubmissionsFinalizedAt":null,"answerKey":["9","x=2"]}"#
        let submissionJSON = #"{"id":"submission-1","weekId":"week-1","answers":["9","x=2"],"answerModes":["MULTIPLE_CHOICE","SHORT_ANSWER"],"answeredCount":2,"correctByQuestion":[true,false],"correctCount":1,"questionCount":2,"scorePercent":50,"status":"SUBMITTED","submittedAt":"2026-09-07T00:01:00Z","gradedAt":"2026-09-07T00:01:00Z","autoZeroedAt":null,"answerKeyConfiguredAt":"2026-09-07T00:00:00Z","student":{"id":"student-1","name":"검증 학생","email":"fixture@example.invalid"}}"#
        var newWeekObject = try JSONSerialization.jsonObject(with: Data(legacyAcademyWeek.utf8)) as! [String: Any]
        newWeekObject["assignmentOmr"] = try JSONSerialization.jsonObject(with: Data(assignmentJSON.utf8))
        newWeekObject["submissions"] = [try JSONSerialization.jsonObject(with: Data(submissionJSON.utf8))]
        let newWeekData = try JSONSerialization.data(withJSONObject: newWeekObject)
        let newWeek = try JSONDecoder().decode(ServerAPI.AcademyWeek.self, from: newWeekData)
        require(newWeek.assignmentOmr?.isValid == true && newWeek.assignmentOmr?.answerKey == ["9", "x=2"], "teacher week decodes real mixed OMR and answer key")
        require(newWeek.submissions?.first?.isValid == true && newWeek.submissions?.first?.student?.id == "student-1", "teacher week decodes graded roster receipt")
        var newEnvelope = try JSONSerialization.jsonObject(with: Data(legacyWeekResponse.utf8)) as! [String: Any]
        newEnvelope["week"] = newWeekObject
        newEnvelope["submission"] = try JSONSerialization.jsonObject(with: Data(submissionJSON.utf8))
        newEnvelope["serverTime"] = "2026-09-07T00:02:00Z"
        let newResponse = try JSONDecoder().decode(ServerAPI.AcademyWeekResponse.self, from: JSONSerialization.data(withJSONObject: newEnvelope))
        require(newResponse.submission?.answers == ["9", "x=2"] && newResponse.serverTime == "2026-09-07T00:02:00Z", "student week receives own receipt and authoritative clock")
        newWeekObject["assignmentOmr"] = NSNull(); newWeekObject["submissions"] = NSNull()
        let disabledWeek = try JSONDecoder().decode(ServerAPI.AcademyWeek.self, from: JSONSerialization.data(withJSONObject: newWeekObject))
        require(disabledWeek.assignmentOmr == nil && disabledWeek.submissions == nil, "explicit null clears an optional assignment rather than inventing a draft")

        print("Sync API Swift decode cases passed")
        print("- progress, wrong-note cursor/review, durable review payload, dashboard, and V1 rulebook decode")
        print("- legacy/null/new AcademyWeek and AcademyWeekResponse, mixed OMR, teacher answer key, roster receipt and server clock")
    }
}
