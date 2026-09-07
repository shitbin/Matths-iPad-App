import Foundation

@main
enum StudentFlowDomainCases {
    static var count = 0
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        precondition(condition(), message); count += 1
    }
    static func main() throws {
        let now = Date(timeIntervalSince1970: 10_000)
        var journey = FirstLearningJourney(slot: "acct-a", startedAt: now)
        check(journey.isValid, "new journey valid")
        check(!journey.finish(now: now), "intro alone cannot COMPLETE")
        check(!journey.beginChecks(), "checks require lesson and generated questions")
        journey.selectGoal(.review)
        check(journey.goal == .review && journey.stage == .diagnosis, "goal persists and advances")
        journey.selectGoal(.school)
        check(journey.goal == .review, "late goal event cannot rewind state")
        journey.answerDiagnosis(7)
        check(journey.stage == .diagnosis, "one diagnostic is not enough")
        journey.answerDiagnosis(2)
        check(journey.stage == .lesson && journey.diagnosticCorrectCount == 1, "diagnostic chooses scaffold, not official mastery")
        journey.answerDiagnosis(3)
        check(journey.diagnosticAnswers.count == 2, "diagnosis cannot be submitted twice")
        check(!journey.prepare(conceptID: "c", seed: 5, problemIDs: ["a", "b"], baselineProgress: 0, now: now), "short practice rejected")
        check(!journey.prepare(conceptID: "c", seed: 5, problemIDs: ["a", "a", "b"], baselineProgress: 0, now: now), "duplicate question identities rejected")
        check(journey.prepare(conceptID: "c", seed: 5, problemIDs: ["a", "b", "c"], baselineProgress: 0, now: now), "exact 3 prepared")
        check(!journey.canCompleteTutorial, "prepared content is not completed work")
        check(journey.beginChecks(), "explicit read starts checks")
        check(!journey.recordAnswer(slot: "acct-b", conceptID: "c", problemID: "a", correct: true), "other account rejected")
        check(!journey.recordAnswer(slot: "acct-a", conceptID: "other", problemID: "a", correct: true), "other concept rejected")
        check(!journey.recordAnswer(slot: "acct-a", conceptID: "c", problemID: "outside", correct: true), "other question rejected")
        check(journey.recordAnswer(slot: "acct-a", conceptID: "c", problemID: "a", correct: true), "genuine first answer recorded")
        check(!journey.recordAnswer(slot: "acct-a", conceptID: "c", problemID: "a", correct: false), "replayed answer never changes result")
        let disk = try JSONEncoder().encode(journey)
        var resumed = try JSONDecoder().decode(FirstLearningJourney.self, from: disk)
        check(resumed == journey && resumed.isValid, "cold restart preserves stage, seed, answer and owner")
        check(resumed.answeredCount == 1 && resumed.correctCount == 1, "resume counts already answered once")
        check(!resumed.confirmServer(progress: 100, now: now), "server progress alone cannot finish unanswered lesson")
        _ = resumed.recordAnswer(slot: "acct-a", conceptID: "c", problemID: "b", correct: false)
        _ = resumed.recordAnswer(slot: "acct-a", conceptID: "c", problemID: "c", correct: true)
        check(resumed.stage == .awaitingSync && resumed.answeredCount == 3, "3 genuine answers await confirmation")
        check(!resumed.canCompleteTutorial && !resumed.finish(now: now), "local 3 answers do not manufacture official receipt")
        check(!resumed.confirmServer(progress: 101, now: now), "bad server progress rejected")
        check(resumed.confirmServer(progress: 54, now: now), "fresh server projection records actual progress")
        check(resumed.canCompleteTutorial && resumed.confirmedProgress == 54, "result is 54, never forced 100 or PASS")
        check(resumed.finish(now: now), "COMPLETE only after server-confirmed session")
        check(resumed.pendingTutorialAction == "COMPLETE" && resumed.completedAt == now, "completion outbox durable")
        check(!resumed.finish(now: now), "completion action cannot replay via invalid stage")
        var skipped = FirstLearningJourney(slot: "acct-a")
        skipped.skip()
        check(skipped.pendingTutorialAction == "SKIP" && skipped.stage == .skipped && skipped.isValid, "skip distinct from success")
        var corrupt = journey
        corrupt.schemaVersion = 100
        check(!corrupt.isValid, "unknown version rejected")
        corrupt = journey; corrupt.checkedAnswers["fake"] = true
        check(!corrupt.isValid, "foreign check cannot survive decoding")
        corrupt = journey; corrupt.stage = .completed
        check(!corrupt.isValid, "corrupt completed claim rejected")

        func candidate(_ id: String, _ kind: TodayActionCandidate.Kind) -> TodayActionCandidate {
            .init(id: id, kind: kind, title: id, reason: "reason", action: "open", minutes: nil,
                  destination: .learn, source: .navigation)
        }
        let school = candidate("canonical", .curriculum), review = candidate("review", .review), exam = candidate("exam", .assessment)
        let choices = [school, review, exam]
        check(TodayActionResolver.resolve(choices, goal: .school, now: now)?.id == "canonical", "school preference selects canonical course only")
        check(TodayActionResolver.resolve(choices, goal: .review, now: now)?.id == "review", "review preference affects Today")
        check(TodayActionResolver.resolve(choices, goal: .examination, now: now)?.id == "exam", "exam goal shows assessment entrance")
        check(TodayActionResolver.resolve(choices, goal: .measure, now: now)?.id == "exam", "measurement goal shows evaluation")
        let timed = candidate("ongoing", .timedWork)
        for goal in LearningGoal.allCases {
            check(TodayActionResolver.resolve(choices + [timed], goal: goal, now: now)?.id == "ongoing", "goal cannot override ongoing timed work")
        }
        var cached = timed; cached.freshness = .current; cached.fetchedAt = now.addingTimeInterval(-301)
        check(cached.presentation(at: now).freshness == .cached, "5-minute snapshot expires for presentation")
        check(TodayActionResolver.resolve([cached, school], now: now)?.id == "canonical", "stale permission does not outrank valid learning")
        check(cached.presentation(at: now).visibleAction == "최신 상태 확인", "stale CTA promises check, not start")
        cached.fetchedAt = now.addingTimeInterval(1)
        check(cached.presentation(at: now).freshness == .cached, "wall clock rollback is not fresh authority")
        var deadlineA = candidate("a", .deadline), deadlineB = candidate("b", .deadline)
        deadlineA.deadline = now.addingTimeInterval(90); deadlineB.deadline = now.addingTimeInterval(20)
        check(TodayActionResolver.resolve([deadlineA, deadlineB], now: now)?.id == "b", "earlier deadline sorts first without local expiry")
        check(TodayActionResolver.resolve([], now: now) == nil, "empty input has no fabricated activity")
        check(LearningGoal(legacyTitle: "시험 대비하기") == .examination, "old preference migrates")
        check(TodayActivityPolicy.canOfferWeekly(status: "in_progress", eligibilityAllowed: false, canEnterRoom: false), "existing attempt can open current-state check without promising new access")
        check(TodayActivityPolicy.canOfferWeekly(status: "lobby", eligibilityAllowed: true, canEnterRoom: true), "eligible lobby offered without local clock")
        check(TodayActivityPolicy.canOfferWeekly(status: "new", eligibilityAllowed: true, canEnterRoom: true), "eligible new attempt offered")
        for state in ["submitted", "expired", "unknown"] {
            check(!TodayActivityPolicy.canOfferWeekly(status: state, eligibilityAllowed: true, canEnterRoom: true), "terminal/unknown is not new work")
        }
        check(!TodayActivityPolicy.canOfferWeekly(status: "new", eligibilityAllowed: false, canEnterRoom: true), "no entitlement means no new weekly candidate")
        check(!TodayActivityPolicy.canOfferWeekly(status: "new", eligibilityAllowed: true, canEnterRoom: false), "closed server room never offered")
        check(TodayActivityPolicy.canOfferArena(matchStatus: "IN_PROGRESS", attemptStatus: "IN_PROGRESS", integrity: "CLEAR", actions: ["SAVE_ANSWER"]), "own active attempt and command are eligible")
        check(TodayActivityPolicy.canOfferArena(matchStatus: "IN_PROGRESS", attemptStatus: "IN_PROGRESS", integrity: "CLEAR", actions: nil), "legacy missing command list retains existing behavior")
        check(!TodayActivityPolicy.canOfferArena(matchStatus: "IN_PROGRESS", attemptStatus: "SUBMITTED", integrity: "CLEAR", actions: ["SAVE_ANSWER"]), "opponent still playing does not reopen mine")
        check(!TodayActivityPolicy.canOfferArena(matchStatus: "IN_PROGRESS", attemptStatus: "IN_PROGRESS", integrity: "HELD", actions: ["SAVE_ANSWER"]), "held match never opens play")
        check(!TodayActivityPolicy.canOfferArena(matchStatus: "IN_PROGRESS", attemptStatus: "IN_PROGRESS", integrity: "CLEAR", actions: []), "explicit server command denial beats legacy fallback")
        check(!TodayActivityPolicy.canOfferArena(matchStatus: "SETTLED", attemptStatus: "IN_PROGRESS", integrity: "CLEAR", actions: ["SAVE_ANSWER"]), "terminal shared match not reopened")
        for id in ["", "../admin", "a?token=b", "a/b", "a#x", "a%2Fb", String(repeating: "a", count: 129)] {
            check(!TodayActivityPolicy.isSafeServerID(id), "unsafe native target rejected")
        }
        check(TodayActivityPolicy.isSafeServerID("demo-match_123"), "known fixture/UUID/Mongo identifiers supported")
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("journey-cases-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("receipt.json")
        try FirstLearningJourneyPersistence.save(resumed, to: file)
        let restored = try FirstLearningJourneyPersistence.load(from: file, slot: "acct-a")
        check(restored == resumed, "atomic receipt survives a real disk round trip")
        do {
            _ = try FirstLearningJourneyPersistence.load(from: file, slot: "acct-b")
            preconditionFailure("foreign owner accepted")
        } catch { count += 1 }
        let existing = try Data(contentsOf: file)
        do {
            try FirstLearningJourneyPersistence.save(corrupt, to: file)
            preconditionFailure("invalid receipt overwritten")
        } catch { count += 1 }
        let afterInvalidWrite = try Data(contentsOf: file)
        check(existing == afterInvalidWrite, "invalid write preserves previous valid file")
        do {
            try FirstLearningJourneyPersistence.save(resumed, to: folder)
            preconditionFailure("directory write was accepted")
        } catch { count += 1 }
        let malformed = folder.appendingPathComponent("malformed.json")
        try Data("{broken}".utf8).write(to: malformed)
        do {
            _ = try FirstLearningJourneyPersistence.load(from: malformed, slot: "acct-a")
            preconditionFailure("malformed receipt was accepted")
        } catch { count += 1 }
        let badBytes = try Data(contentsOf: malformed)
        check(badBytes == Data("{broken}".utf8), "failed decode never destroys recovery evidence")
        print("Student flow domain: \(count) behavioral checks passed")
    }
}
