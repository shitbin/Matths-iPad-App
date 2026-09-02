import Foundation

enum DemoAdminUsersFixtures {
    static let users = #"""
    {
      "schemaVersion":"ADMIN_USERS_NATIVE_V1",
      "users":{
        "items":[
          {"id":"demo-user-1","entityType":"USER","name":"김민준","realName":"김민준","email":"student@example.com","role":"student","school":{"code":"S1","name":"매쓰고등학교","region":"서울"},"university":null,"schoolGrade":11,"educationStatus":"enrolled","isActive":true,"accountStatus":"active","accountStatusReason":"","suspendedUntil":null,"warningCount":1,"totalStudySeconds":18300,"totalConnectedSeconds":32200,"currentStreak":5,"longestStreak":12,"lastStudyDate":"2026-09-02","lastLoginAt":"2026-09-02T07:30:00.000Z","createdAt":"2026-03-03T01:00:00.000Z","teacherAccessExpiresAt":null,"identityVerificationStatus":"verified","identityDuplicateAlertedAt":null,"parentChildCount":0,"arenaActivityLevel":{"level":3,"totalMatches":12,"matchesToNext":4,"isMaxLevel":false}},
          {"id":"demo-user-2","entityType":"USER","name":"이선생","realName":"이상윤","email":"teacher@example.com","role":"teacher","school":null,"university":null,"schoolGrade":null,"educationStatus":"","isActive":true,"accountStatus":"active","accountStatusReason":"","suspendedUntil":null,"warningCount":0,"totalStudySeconds":0,"totalConnectedSeconds":5400,"currentStreak":0,"longestStreak":0,"lastStudyDate":null,"lastLoginAt":"2026-09-02T06:00:00.000Z","createdAt":"2026-08-01T01:00:00.000Z","teacherAccessExpiresAt":"2027-08-31T14:59:59.999Z","identityVerificationStatus":"","identityDuplicateAlertedAt":null,"parentChildCount":0,"arenaActivityLevel":null}
        ],
        "schools":[{"code":"S1","name":"매쓰고등학교"}],
        "filter":{"query":"","schoolCode":"","grade":"","state":"","role":""},
        "pagination":{"page":1,"total":2,"totalPages":1,"perPage":20,"hasPrevious":false,"hasNext":false}
      }
    }
    """#

    static let detail = #"""
    {
      "schemaVersion":"ADMIN_USERS_NATIVE_V1",
      "detail":{
        "user":{"id":"demo-user-1","entityType":"USER","name":"김민준","realName":"김민준","email":"student@example.com","role":"student","school":{"code":"S1","name":"매쓰고등학교","region":"서울"},"university":null,"schoolGrade":11,"educationStatus":"enrolled","isActive":true,"accountStatus":"active","accountStatusReason":"","suspendedUntil":null,"warningCount":1,"totalStudySeconds":18300,"totalConnectedSeconds":32200,"currentStreak":5,"longestStreak":12,"lastStudyDate":"2026-09-02","lastLoginAt":"2026-09-02T07:30:00.000Z","createdAt":"2026-03-03T01:00:00.000Z","teacherAccessExpiresAt":null,"identityVerificationStatus":"verified","identityDuplicateAlertedAt":null,"parentChildCount":0,"arenaActivityLevel":{"level":3,"totalMatches":12,"matchesToNext":4,"isMaxLevel":false}},
        "streak":{"current":5,"longest":12,"lastStudyDate":"2026-09-02"},
        "learning":{"currentConcept":{"id":"progress-1","courseTitle":"공통수학2","unitTitle":"함수","conceptTitle":"합성함수","status":"in-progress","completionPercent":64,"lastStudiedAt":"2026-09-02T07:00:00.000Z"},"progressCount":18,"completedCount":11,"totalAttempts":124,"correctAttempts":96,"correctRate":77,"progress":[]},
        "packageAccess":{"packageType":"LEARNING_PACKAGE","label":"29일 학습권 패키지","availableLearningDays":21,"paybackScoreDays":4,"endsAt":"2026-09-30T14:59:59.999Z"},
        "arenaActivityLevel":{"level":3,"totalMatches":12,"matchesToNext":4,"isMaxLevel":false},
        "identityMatches":[],
        "assessments":[{"id":"assessment-1","title":"공통수학2 중간 평가","status":"submitted","scorePercent":82,"answeredCount":20,"startedAt":"2026-08-30T05:00:00.000Z","submittedAt":"2026-08-30T05:42:00.000Z"}],
        "records":[{"id":"record-1","kind":"notification","title":"결제 확인 완료","detail":"29일권을 확인했습니다.","status":"read","createdAt":"2026-09-02T06:00:00.000Z"}]
      }
    }
    """#

    static let sanctions = #"""
    {"schemaVersion":"ADMIN_USERS_NATIVE_V1","sanctions":{"items":[{"id":"sanction-1","action":"user.warning-count","actionLabel":"경고 횟수 변경","detail":"게시판 운영 정책 위반","actor":{"id":"admin-1","name":"운영자","nickname":"관리자","email":"admin@example.com"},"target":{"id":"demo-user-1","name":"김민준","nickname":"김민준","email":"student@example.com"},"createdAt":"2026-09-02T05:00:00.000Z"}],"pagination":{"page":1,"total":1,"totalPages":1,"perPage":20,"hasPrevious":false,"hasNext":false}}}
    """#

    static let audit = #"""
    {"schemaVersion":"ADMIN_USERS_NATIVE_V1","audit":{"items":[{"id":"audit-1","action":"user.package-access","actionLabel":"이용권·Division 권한 변경","detail":"고객 지원 처리","actor":{"id":"admin-1","name":"운영자","nickname":"관리자","email":"admin@example.com"},"target":{"id":"demo-user-1","name":"김민준","nickname":"김민준","email":"student@example.com"},"createdAt":"2026-09-02T04:00:00.000Z"}],"admins":[{"id":"admin-1","name":"운영자","nickname":"관리자","email":"admin@example.com"}],"filter":{"adminUserId":"","query":""},"pagination":{"page":1,"total":1,"totalPages":1,"perPage":20,"hasPrevious":false,"hasNext":false}}}
    """#

    static func activity(kind: String) -> String {
        let rows: String
        switch kind {
        case "assessments":
            rows = #"{"id":"assessment-1","kind":"assessments","title":"공통수학2 중간 평가","subtitle":"unit · common-math-2 · functions","detail":"점수 82 · 2520000ms","status":"submitted","metadata":"","attemptId":"assessment-1","occurredAt":"2026-08-30T05:42:00.000Z"}"#
        case "problems":
            rows = #"{"id":"problem-1","kind":"problems","title":"함수 f(x)의 값을 구하세요.","subtitle":"공통수학2 · 함수 · 합성함수","detail":"제출 4 · 정답 4 · 18000ms","status":"correct","metadata":"","attemptId":"learning-attempt-1","occurredAt":"2026-09-02T07:12:00.000Z"}"#
        case "quick":
            rows = #"{"id":"quick-1","kind":"quick","title":"그래프의 교점을 눈으로 찾으세요.","subtitle":"3점 · 함수 · 기본","detail":"제출 2 · 정답 2 · 12000ms","status":"correct","metadata":"두 그래프가 만나는 x좌표를 확인합니다.","attemptId":"","occurredAt":"2026-09-02T07:10:00.000Z"}"#
        case "community":
            rows = #"{"id":"community-1","kind":"community","title":"합성함수 질문입니다","subtitle":"질문 게시판","detail":"풀이의 두 번째 줄이 이해되지 않습니다.","status":"published","metadata":"","attemptId":"","occurredAt":"2026-09-01T10:00:00.000Z"}"#
        case "moderation":
            rows = #"{"id":"moderation-1","kind":"moderation","title":"user.warning-count","subtitle":"운영자","detail":"게시판 운영 정책 위반","status":"","metadata":"{\"warningCount\":1}","attemptId":"","occurredAt":"2026-09-02T05:00:00.000Z"}"#
        default:
            rows = #"{"id":"learning-1","kind":"learning","title":"problem_submitted","subtitle":"공통수학2 · 함수 · 합성함수","detail":"유형 1 · 단계 2 · 18000ms","status":"correct","metadata":"{\"source\":\"native\"}","attemptId":"learning-attempt-1","occurredAt":"2026-09-02T07:12:00.000Z"}"#
        }
        return #"{"schemaVersion":"ADMIN_USERS_NATIVE_V1","activity":{"user":\#(userObject),"kind":"\#(kind)","items":[\#(rows)],"pagination":{"page":1,"total":1,"totalPages":1,"perPage":20,"hasPrevious":false,"hasNext":false}}}"#
    }

    static let assessment = #"""
    {"schemaVersion":"ADMIN_USERS_NATIVE_V1","assessment":{"user":{"id":"demo-user-1","entityType":"USER","name":"김민준","realName":"김민준","email":"student@example.com","role":"student","school":{"code":"S1","name":"매쓰고등학교","region":"서울"},"university":null,"schoolGrade":11,"educationStatus":"enrolled","isActive":true,"accountStatus":"active","accountStatusReason":"","suspendedUntil":null,"warningCount":1,"totalStudySeconds":18300,"totalConnectedSeconds":32200,"currentStreak":5,"longestStreak":12,"lastStudyDate":"2026-09-02","lastLoginAt":"2026-09-02T07:30:00.000Z","createdAt":"2026-03-03T01:00:00.000Z","teacherAccessExpiresAt":null,"identityVerificationStatus":"verified","identityDuplicateAlertedAt":null,"parentChildCount":0,"arenaActivityLevel":{"level":3,"totalMatches":12,"matchesToNext":4,"isMaxLevel":false}},"attempt":{"id":"assessment-1","title":"공통수학2 중간 평가","scopeType":"unit","status":"submitted","disqualifiedReason":"","scorePercent":82,"earnedPoints":41,"totalPoints":50,"elapsedTimeMs":2520000,"passed":true,"hasFinalScore":true,"answeredCount":20,"startedAt":"2026-08-30T05:00:00.000Z","submittedAt":"2026-08-30T05:42:00.000Z","deadlineAt":"2026-08-30T06:00:00.000Z","questions":[{"id":"question-1","number":1,"prompt":"함수 f(x)=2x+1일 때 f(3)의 값은?","choices":[{"key":"1","text":"5"},{"key":"2","text":"7"},{"key":"3","text":"9"}],"submittedAnswer":"2","answer":"2","isCorrect":true,"points":3,"responseTimeMs":18000,"answerChanges":1,"typeLabel":"객관식","solution":"f(3)=2×3+1=7입니다."},{"id":"question-2","number":2,"prompt":"합성함수 (f∘g)(x)를 전개하세요.","choices":[],"submittedAnswer":"2x+3","answer":"2x+3","isCorrect":true,"points":4,"responseTimeMs":44000,"answerChanges":0,"typeLabel":"주관식","solution":"g(x)를 f의 입력에 대입합니다."}]}}}
    """#

    static let parentDetail = #"""
    {"schemaVersion":"ADMIN_USERS_NATIVE_V1","detail":{"user":{"id":"demo-parent-1","entityType":"PARENT","name":"김학부모","realName":"","email":"parent@example.com","role":"parent","school":null,"university":null,"schoolGrade":null,"educationStatus":"","isActive":true,"accountStatus":"active","accountStatusReason":"","suspendedUntil":null,"warningCount":0,"totalStudySeconds":0,"totalConnectedSeconds":0,"currentStreak":0,"longestStreak":0,"lastStudyDate":null,"lastLoginAt":"2026-09-02T06:00:00.000Z","createdAt":"2026-04-01T01:00:00.000Z","teacherAccessExpiresAt":null,"identityVerificationStatus":"","identityDuplicateAlertedAt":null,"parentChildCount":1,"arenaActivityLevel":null},"streak":null,"learning":{"currentConcept":null,"progressCount":0,"completedCount":0,"totalAttempts":0,"correctAttempts":0,"correctRate":0,"progress":[]},"packageAccess":null,"arenaActivityLevel":null,"identityMatches":[],"assessments":[],"records":[],"parent":{"acceptedTermsAt":"2026-04-01T01:05:00.000Z","children":[{"id":"demo-user-1","name":"김민준","realName":"김민준","email":"student@example.com","schoolName":"매쓰고등학교","schoolGrade":11,"accountStatus":"active","lastLoginAt":"2026-09-02T07:30:00.000Z","todayStudyMinutes":42,"todaySolvedProblems":18,"weeklyStudyMinutes":236,"correctRate":77,"packageLabel":"29일 학습권 패키지","finalRank":18,"arenaRank":"Gold","emailEnabled":true,"lowLearningEnabled":true,"minimumMinutesPerDay":20,"lowLearningConsecutiveDays":3,"inactivityEnabled":true,"inactivityDays":7}]}}}
    """#

    static let mutation = #"{"schemaVersion":"ADMIN_USERS_NATIVE_V1","ok":true}"#
    static let mutationWithDetail = #"{"schemaVersion":"ADMIN_USERS_NATIVE_V1","ok":true,"detail":\#(detailObject)}"#
    static let delivered = #"{"schemaVersion":"ADMIN_USERS_NATIVE_V1","ok":true,"delivered":true}"#
    static let withdrawn = #"{"schemaVersion":"ADMIN_USERS_NATIVE_V1","ok":true,"purged":false,"detail":\#(detailObject)}"#
    static let parentMutation = #"{"schemaVersion":"ADMIN_USERS_NATIVE_V1","ok":true,"detail":\#(parentDetailObject)}"#

    private static let detailObject: String = {
        guard let range = detail.range(of: "\"detail\":"),
              let end = detail.lastIndex(of: "}") else { return "{}" }
        let start = detail.index(range.upperBound, offsetBy: 0)
        return String(detail[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
    }()

    private static let userObject: String = {
        guard let data = detail.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let body = root["detail"] as? [String: Any], let user = body["user"],
              let encoded = try? JSONSerialization.data(withJSONObject: user),
              let text = String(data: encoded, encoding: .utf8) else { return "{}" }
        return text
    }()

    private static let parentDetailObject: String = {
        guard let range = parentDetail.range(of: "\"detail\":"),
              let end = parentDetail.lastIndex(of: "}") else { return "{}" }
        return String(parentDetail[range.upperBound..<end])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }()
}
