import Foundation

extension AppStore {
    private var todayOfficialAttempt: AssessmentAttemptV2? {
        attemptsV2.attempts.filter { $0.serverBacked == true && $0.submittedAt == nil && !$0.isServerCancelled }
            .sorted { $0.createdAt < $1.createdAt }.first
    }
    var todayReviewIDs: [String] {
        wrongNotes.filter {
            !$0.isMastered && ($0.nextReviewAt ?? .distantPast) <= Date()
                && (authProvider != "server" || $0.serverAttemptId != nil)
        }.map(\.id)
    }
    var todayActionCandidates: [TodayActionCandidate] {
        var values = TodayActivityStore.shared.candidates.filter { candidate in
            if case .officialAssessment(let id) = candidate.destination {
                return !attemptsV2.attempts.contains { $0.id == id && $0.isServerCancelled }
            }
            return true
        }
        if !values.contains(where: { $0.source == .serverAssessment }), let attempt = todayOfficialAttempt {
            values.append(.init(id: attempt.id, kind: .timedWork, title: attempt.title,
                                reason: "시작한 공식 평가가 있어요. 저장한 답안에서 이어가세요.",
                                action: "평가 상태 확인", minutes: nil,
                                destination: .officialAssessment(attempt.id), source: .serverAssessment,
                                freshness: .cached))
        }
        if !values.contains(where: { $0.destination == .academyAttendance }),
           let attendance = todayAcademyAttendance, attendance.canCheckIn {
            values.append(.init(id: attendance.session.id, kind: .academy, title: "학원 수업 출석 확인",
                                reason: "학원에서 출석 확인을 받고 있어요. 수업 화면에서 상태를 확인하세요.",
                                action: "수업 출석 확인", minutes: nil,
                                destination: .academyAttendance, source: .serverAcademy, freshness: .cached))
        }
        if !todayReviewIDs.isEmpty {
            values.append(.init(id: "review", kind: .review, title: "오늘 복습할 오답 \(min(todayReviewIDs.count, 5))개",
                                reason: todayReviewIDs.count > 5 ? "먼저 5개만 복습해요. 나머지는 기록에서 이어갈 수 있어요." : "복습 예정일이 된 문제부터 다시 풀어봐요.", action: "복습 시작", minutes: nil,
                                destination: .review, source: .durableReview))
        }
        if let (course, _, concept) = nextLearningConcept {
            values.append(.init(id: concept.id, kind: .curriculum, title: concept.title,
                                reason: "\(course.title)에서 이어서 학습할 차례예요.",
                                action: "학습 시작", minutes: concept.lesson?.estimatedMinutes,
                                destination: .concept(concept.id), source: .canonicalLearning))
        }
        if authProvider == "server" {
            values.append(.init(id: "assessment-options", kind: .assessment, title: "공식 평가로 실력 확인",
                                reason: "응시 가능한 범위와 기존 평가 기록을 확인하세요.", action: "평가 범위 확인", minutes: nil,
                                destination: .assessments, source: .navigation))
        }
        values.append(.init(id: "explore", kind: .explore, title: "어떤 수학을 공부할까요?",
                            reason: "공개된 과정과 평가를 학습에서 확인하세요.", action: "학습 살펴보기", minutes: nil,
                            destination: .learn, source: .navigation))
        return values
    }
    var resolvedTodayAction: TodayActionCandidate? {
        TodayActionResolver.resolve(todayActionCandidates, goal: FirstLearningJourneyStore.shared.goal)
    }

}
