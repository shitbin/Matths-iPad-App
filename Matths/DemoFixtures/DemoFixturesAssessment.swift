//  DemoFixturesAssessment.swift
//  Matths — DEBUG 데모 모드 픽스처: 평가센터 · 주간 공식 모의고사
//
//  courseId/unitId/subunitId 는 assessment-catalog.json 의 실제 id 다.
//  하나라도 틀리면 RemoteAssessment.localValue() 가 nil 을 돌려주고 화면이 빈다.

#if DEBUG
import Foundation

enum DemoAssessmentFixtures {

    // MARK: - 평가센터 (/api/v1/assessments)
    //
    // 완료(합격)·완료(불합격)·진행 중이 섞여 있어야 목록 카드의 상태 뱃지가 실제로 시험된다.
    // 잠김 여부는 앱이 로컬 진도로 판정하므로, 진도 픽스처가 덜 나간 과목이 자연히 잠긴다.

    static let assessments = #"""
    {
      "assessments": [
        {
          "id": "demo-assessment-01",
          "scope": "unit",
          "courseId": "common-math-1",
          "unitId": "polynomials",
          "subunitId": null,
          "title": "“다항식” 기말평가",
          "status": "submitted",
          "questions": \#(gradedQuestions),
          "answers": ["b", "c", "12", "a", "7"],
          "startedAt": "@T-8d@",
          "deadlineAt": "@T-8d@",
          "submittedAt": "@T-8d@",
          "scorePercent": 88,
          "passed": true,
          "timeLimitMs": 2400000,
          "disqualified": false,
          "updatedAt": "@T-8d@"
        },
        {
          "id": "demo-assessment-02",
          "scope": "subunit",
          "courseId": "algebra",
          "unitId": "exponential-logarithmic-functions",
          "subunitId": "log",
          "title": "“로그” 중간평가",
          "status": "submitted",
          "questions": \#(gradedQuestions),
          "answers": ["b", "a", "12", "d", "7"],
          "startedAt": "@T-3d@",
          "deadlineAt": "@T-3d@",
          "submittedAt": "@T-3d@",
          "scorePercent": 60,
          "passed": false,
          "timeLimitMs": 1200000,
          "disqualified": false,
          "updatedAt": "@T-3d@"
        },
        {
          "id": "demo-assessment-03",
          "scope": "subunit",
          "courseId": "common-math-2",
          "unitId": "coordinate-geometry",
          "subunitId": "circle",
          "title": "“원의 방정식” 중간평가",
          "status": "in-progress",
          "questions": \#(openQuestions),
          "answers": ["b", "", "", "", ""],
          "startedAt": "@T-9m@",
          "deadlineAt": "@T+11m@",
          "submittedAt": null,
          "scorePercent": null,
          "passed": null,
          "timeLimitMs": 1200000,
          "disqualified": false,
          "updatedAt": "@T-1m@"
        }
      ]
    }
    """#

    static func assessmentDetail(id: String) -> String {
        #"{ "assessment": \#(openAssessment(id: DemoRouter.escaped(id))) }"#
    }

    static let assessmentDraft = #"""
    { "draft": { "savedAt": "@T+0s@", "elapsedTimeMs": 540000, "status": "in-progress", "expired": false } }
    """#

    /// 평가 시작 — 요청한 범위를 그대로 되비춘다. 범위가 어긋나면 화면이 다른 시험을 연다.
    static func startedAssessment(body: [String: Any]?) -> String {
        let scope = (body?["scopeType"] as? String) ?? "subunit"
        let courseId = (body?["courseId"] as? String) ?? "common-math-1"
        let unitId = (body?["unitId"] as? String).map { #""\#(DemoRouter.escaped($0))""# } ?? "null"
        let subunitId = (body?["subunitId"] as? String).map { #""\#(DemoRouter.escaped($0))""# } ?? "null"
        return #"""
        {
          "assessment": {
            "id": "demo-assessment-new",
            "scope": "\#(DemoRouter.escaped(scope))",
            "courseId": "\#(DemoRouter.escaped(courseId))",
            "unitId": \#(unitId),
            "subunitId": \#(subunitId),
            "title": "데모 평가지",
            "status": "in-progress",
            "questions": \#(openQuestions),
            "answers": ["", "", "", "", ""],
            "startedAt": "@T+0s@",
            "deadlineAt": "@T+20m@",
            "submittedAt": null,
            "scorePercent": null,
            "passed": null,
            "timeLimitMs": 1200000,
            "disqualified": false,
            "updatedAt": "@T+0s@"
          }
        }
        """#
    }

    static func submittedAssessment(id: String) -> String {
        let value = DemoRouter.escaped(id)
        return #"""
        {
          "assessment": {
            "id": "\#(value)",
            "scope": "subunit",
            "courseId": "common-math-2",
            "unitId": "coordinate-geometry",
            "subunitId": "circle",
            "title": "“원의 방정식” 중간평가",
            "status": "submitted",
            "questions": \#(gradedQuestions),
            "answers": ["b", "c", "12", "a", "7"],
            "startedAt": "@T-20m@",
            "deadlineAt": "@T+0s@",
            "submittedAt": "@T+0s@",
            "scorePercent": 80,
            "passed": true,
            "timeLimitMs": 1200000,
            "disqualified": false,
            "updatedAt": "@T+0s@"
          }
        }
        """#
    }

    private static func openAssessment(id: String) -> String {
        #"""
        {
          "id": "\#(id)",
          "scope": "subunit",
          "courseId": "common-math-2",
          "unitId": "coordinate-geometry",
          "subunitId": "circle",
          "title": "“원의 방정식” 중간평가",
          "status": "in-progress",
          "questions": \#(openQuestions),
          "answers": ["b", "", "", "", ""],
          "startedAt": "@T-9m@",
          "deadlineAt": "@T+11m@",
          "submittedAt": null,
          "scorePercent": null,
          "passed": null,
          "timeLimitMs": 1200000,
          "disqualified": false,
          "updatedAt": "@T-1m@"
        }
        """#
    }

    /// 채점이 끝난 시험지 — 정답·해설이 열려 있다(서버는 종료된 회차에만 채워 준다).
    private static let gradedQuestions = #"""
    [
      {
        "id": "demo-q1", "number": 1, "typeKey": "circle-equation",
        "prompt": "중심이 $(2,-1)$ 이고 반지름이 3인 원의 방정식은?",
        "choices": [
          "$(x-2)^2+(y+1)^2=3$",
          "$(x-2)^2+(y+1)^2=9$",
          "$(x+2)^2+(y-1)^2=9$",
          "$(x-2)^2+(y-1)^2=9$",
          "$(x+2)^2+(y+1)^2=3$"
        ],
        "answer": "b", "points": 3,
        "solution": "중심 $(a,b)$, 반지름 $r$ 인 원은 $(x-a)^2+(y-b)^2=r^2$ 이므로 $(x-2)^2+(y+1)^2=9$ 입니다.",
        "submittedAnswer": "b", "isCorrect": true
      },
      {
        "id": "demo-q2", "number": 2, "typeKey": "circle-line-position",
        "prompt": "원 $x^2+y^2=10$ 과 직선 $y=x+k$ 가 접할 때, 양수 $k$ 의 값은?",
        "choices": ["$\\sqrt{5}$", "$2\\sqrt{5}$", "$\\sqrt{10}$", "$2\\sqrt{10}$", "5"],
        "answer": "b", "points": 4,
        "solution": "중심과 직선 사이의 거리가 반지름과 같아야 하므로 $|k|/\\sqrt{2}=\\sqrt{10}$ 에서 $k=2\\sqrt{5}$ 입니다.",
        "submittedAnswer": "c", "isCorrect": false
      },
      {
        "id": "demo-q3", "number": 3, "typeKey": "point-line-distance",
        "prompt": "점 $(3,4)$ 와 직선 $3x+4y-1=0$ 사이의 거리를 구하시오.",
        "choices": [],
        "answer": "24/5", "points": 3,
        "solution": "$|3 \\times 3 + 4 \\times 4 - 1| / \\sqrt{3^2+4^2} = 24/5$ 입니다.",
        "submittedAnswer": "12", "isCorrect": false
      },
      {
        "id": "demo-q4", "number": 4, "typeKey": "geometric-translation",
        "prompt": "원 $x^2+y^2=4$ 를 $x$ 축 방향으로 3만큼 평행이동한 도형의 방정식은?",
        "choices": [
          "$(x-3)^2+y^2=4$",
          "$(x+3)^2+y^2=4$",
          "$x^2+(y-3)^2=4$",
          "$x^2+(y+3)^2=4$",
          "$(x-3)^2+(y-3)^2=4$"
        ],
        "answer": "a", "points": 3,
        "solution": "$x$ 축 방향 평행이동은 $x$ 대신 $x-3$ 을 넣습니다.",
        "submittedAnswer": "a", "isCorrect": true
      },
      {
        "id": "demo-q5", "number": 5, "typeKey": "circle-tangent",
        "prompt": "원 $x^2+y^2=25$ 위의 점 $(3,4)$ 에서의 접선이 $x$ 축과 만나는 점의 $x$ 좌표를 구하시오.",
        "choices": [],
        "answer": "25/3", "points": 4,
        "solution": "접선은 $3x+4y=25$ 이고 $y=0$ 을 넣으면 $x=25/3$ 입니다.",
        "submittedAnswer": "7", "isCorrect": false
      }
    ]
    """#

    /// 진행 중 시험지 — 서버는 종료 전에는 정답·해설을 빈 문자열로 내려 준다.
    private static let openQuestions = #"""
    [
      {
        "id": "demo-open-q1", "number": 1, "typeKey": "circle-equation",
        "prompt": "중심이 $(2,-1)$ 이고 반지름이 3인 원의 방정식은?",
        "choices": [
          "$(x-2)^2+(y+1)^2=3$",
          "$(x-2)^2+(y+1)^2=9$",
          "$(x+2)^2+(y-1)^2=9$",
          "$(x-2)^2+(y-1)^2=9$",
          "$(x+2)^2+(y+1)^2=3$"
        ],
        "answer": "", "points": 3, "solution": "", "submittedAnswer": "b", "isCorrect": null
      },
      {
        "id": "demo-open-q2", "number": 2, "typeKey": "circle-line-position",
        "prompt": "원 $x^2+y^2=10$ 과 직선 $y=x+k$ 가 접할 때, 양수 $k$ 의 값은?",
        "choices": ["$\\sqrt{5}$", "$2\\sqrt{5}$", "$\\sqrt{10}$", "$2\\sqrt{10}$", "5"],
        "answer": "", "points": 4, "solution": "", "submittedAnswer": "", "isCorrect": null
      },
      {
        "id": "demo-open-q3", "number": 3, "typeKey": "point-line-distance",
        "prompt": "점 $(3,4)$ 와 직선 $3x+4y-1=0$ 사이의 거리를 구하시오.",
        "choices": [],
        "answer": "", "points": 3, "solution": "", "submittedAnswer": "", "isCorrect": null
      },
      {
        "id": "demo-open-q4", "number": 4, "typeKey": "geometric-translation",
        "prompt": "원 $x^2+y^2=4$ 를 $x$ 축 방향으로 3만큼 평행이동한 도형의 방정식은?",
        "choices": [
          "$(x-3)^2+y^2=4$",
          "$(x+3)^2+y^2=4$",
          "$x^2+(y-3)^2=4$",
          "$x^2+(y+3)^2=4$",
          "$(x-3)^2+(y-3)^2=4$"
        ],
        "answer": "", "points": 3, "solution": "", "submittedAnswer": "", "isCorrect": null
      },
      {
        "id": "demo-open-q5", "number": 5, "typeKey": "circle-tangent",
        "prompt": "원 $x^2+y^2=25$ 위의 점 $(3,4)$ 에서의 접선이 $x$ 축과 만나는 점의 $x$ 좌표를 구하시오.",
        "choices": [],
        "answer": "", "points": 4, "solution": "", "submittedAnswer": "", "isCorrect": null
      }
    ]
    """#

    // MARK: - 주간 공식 모의고사

    static let weeklyMockDashboard = #"""
    {
      "weeklyMock": {
        "eligibility": {
          "allowed": true,
          "status": "accepted",
          "title": "응시 가능",
          "message": "이번 주 공식 모의고사에 응시할 수 있습니다.",
          "ctaLabel": "시험실 입장",
          "packageType": "LEARNING_PACKAGE",
          "availableLearningDays": 17
        },
        "serverNow": "@T+0s@",
        "nextReleaseAt": "@SUN+1T15:00@",
        "latestReleaseAt": "@SUN+0T15:00@",
        "scheduleLabel": "매주 일요일 오후 3시·6시·9시, 최대 3회 응시",
        "durationMinutes": 100,
        "currentExam": {
          "id": "demo-mock-01",
          "title": "2026학년도 주간 공식 모의고사 34주차",
          "formCode": "W34-A",
          "attemptNumber": 1,
          "isTest": false,
          "questionCount": 30,
          "durationMinutes": 100,
          "releaseAt": "@SUN+0T15:00@",
          "closeAt": "@SUN+1T15:00@",
          "lobbyOpensAt": "@SUN+0T15:00@",
          "status": "submitted",
          "canEnterRoom": true,
          "canStart": false,
          "attemptStatus": "submitted",
          "answeredCount": 30,
          "score": 84.0,
          "standardizedPerformance": 128.5,
          "detailPath": "/weekly-mock/demo-mock-01",
          "paperPath": null
        },
        "weeklyExams": [
          {
            "id": "demo-mock-01",
            "title": "2026학년도 주간 공식 모의고사 34주차",
            "formCode": "W34-A",
            "attemptNumber": 1,
            "isTest": false,
            "questionCount": 30,
            "durationMinutes": 100,
            "releaseAt": "@SUN+0T15:00@",
            "closeAt": "@SUN+1T15:00@",
            "lobbyOpensAt": "@SUN+0T15:00@",
            "status": "submitted",
            "canEnterRoom": true,
            "canStart": false,
            "attemptStatus": "submitted",
            "answeredCount": 30,
            "score": 84.0,
            "standardizedPerformance": 128.5,
            "detailPath": "/weekly-mock/demo-mock-01",
            "paperPath": null
          },
          {
            "id": "demo-mock-02",
            "title": "2026학년도 주간 공식 모의고사 34주차 (2회차)",
            "formCode": "W34-B",
            "attemptNumber": 2,
            "isTest": false,
            "questionCount": 30,
            "durationMinutes": 100,
            "releaseAt": "@SUN+0T18:00@",
            "closeAt": "@SUN+1T15:00@",
            "lobbyOpensAt": "@SUN+0T18:00@",
            "status": "open",
            "canEnterRoom": true,
            "canStart": true,
            "attemptStatus": "new",
            "answeredCount": 0,
            "score": null,
            "standardizedPerformance": null,
            "detailPath": "/weekly-mock/demo-mock-02",
            "paperPath": null
          },
          {
            "id": "demo-mock-03",
            "title": "2026학년도 주간 공식 모의고사 35주차",
            "formCode": "W35-A",
            "attemptNumber": 1,
            "isTest": false,
            "questionCount": 30,
            "durationMinutes": 100,
            "releaseAt": "@SUN+1T15:00@",
            "closeAt": "@SUN+2T15:00@",
            "lobbyOpensAt": "@SUN+1T15:00@",
            "status": "locked",
            "canEnterRoom": false,
            "canStart": false,
            "attemptStatus": "new",
            "answeredCount": 0,
            "score": null,
            "standardizedPerformance": null,
            "detailPath": null,
            "paperPath": null
          },
          {
            "id": "demo-mock-00",
            "title": "2026학년도 주간 공식 모의고사 33주차",
            "formCode": "W33-A",
            "attemptNumber": 1,
            "isTest": false,
            "questionCount": 30,
            "durationMinutes": 100,
            "releaseAt": "@SUN-1T15:00@",
            "closeAt": "@SUN+0T15:00@",
            "lobbyOpensAt": "@SUN-1T15:00@",
            "status": "expired",
            "canEnterRoom": false,
            "canStart": false,
            "attemptStatus": "submitted",
            "answeredCount": 28,
            "score": 71.0,
            "standardizedPerformance": 119.2,
            "detailPath": "/weekly-mock/demo-mock-00",
            "paperPath": null
          }
        ],
        "selection": {
          "weekKey": "@WEEK@",
          "attemptCount": 2,
          "canChoose": true,
          "locked": false,
          "selectionState": "AUTO",
          "selectionReason": "아직 대표 성적을 직접 고르지 않아 가장 높은 회차가 자동 선택되어 있습니다.",
          "selectedAttemptId": null,
          "representativeAttemptId": "demo-mock-01",
          "attempts": [
            {
              "id": "demo-mock-01",
              "attemptNumber": 1,
              "formCode": "W34-A",
              "rawScore": 84.0,
              "standardizedPerformance": 128.5,
              "totalPercentile": 92.4,
              "isRepresentative": true
            },
            {
              "id": "demo-mock-00",
              "attemptNumber": 2,
              "formCode": "W33-A",
              "rawScore": 71.0,
              "standardizedPerformance": 119.2,
              "totalPercentile": 78.1,
              "isRepresentative": false
            }
          ]
        },
        "rankingTitle": "34주차 전체 순위",
        "rankingFinalized": true,
        "rankingPending": null,
        "rankingSummary": { "participantCount": 3184, "averageScore": 62.7 },
        "weeklyRanking": [
          { "rank": 1, "displayName": "정민서", "score": 100.0, "standardizedPerformance": 148.0, "attemptCount": 1, "elapsedMs": 4210000, "elapsedLabel": "70분 10초" },
          { "rank": 2, "displayName": "라이트닝볼트수학마스터", "score": 96.0, "standardizedPerformance": 144.5, "attemptCount": 2, "elapsedMs": 4980000, "elapsedLabel": "83분 0초" },
          { "rank": 3, "displayName": "윤", "score": 96.0, "standardizedPerformance": 143.8, "attemptCount": 1, "elapsedMs": 5120000, "elapsedLabel": "85분 20초" },
          { "rank": 4, "displayName": "김도현", "score": 92.0, "standardizedPerformance": 139.1, "attemptCount": 1, "elapsedMs": 5400000, "elapsedLabel": "90분 0초" },
          { "rank": 5, "displayName": "박서연", "score": 88.0, "standardizedPerformance": 133.2, "attemptCount": 1, "elapsedMs": 5760000, "elapsedLabel": "96분 0초" },
          { "rank": 187, "displayName": "지우", "score": 84.0, "standardizedPerformance": 128.5, "attemptCount": 1, "elapsedMs": 5880000, "elapsedLabel": "98분 0초" }
        ],
        "rankingRules": [
          "주차별 대표 성적 1개만 순위에 반영합니다.",
          "표준화 성취도가 같으면 총 풀이시간이 짧은 응시자가 앞섭니다.",
          "무결성 검토 중인 응시는 검토가 끝난 뒤 순위에 반영합니다."
        ]
      }
    }
    """#

    static func weeklyMockAttempt(examId: String) -> String {
        #"{ "attempt": \#(weeklyMockAttemptBody(examId: DemoRouter.escaped(examId))) }"#
    }

    static func weeklyMockStart(examId: String) -> String {
        #"""
        { "replayed": false, "attempt": \#(weeklyMockAttemptBody(examId: DemoRouter.escaped(examId))) }
        """#
    }

    private static func weeklyMockAttemptBody(examId: String) -> String {
        #"""
        {
          "state": "submitted",
          "submitted": true,
          "serverNow": "@T+0s@",
          "deadline": "@T-1d@",
          "releaseAt": "@T-2d@",
          "canStart": false,
          "pendingAggregation": false,
          "resultsAvailableAt": "@T-1d@",
          "reviewAvailable": true,
          "reviewPublishesAt": "@T-1d@",
          "exam": {
            "id": "\#(examId)",
            "title": "2026학년도 주간 공식 모의고사 34주차",
            "weekKey": "@WEEK@",
            "formCode": "W34-A",
            "attemptNumber": 1,
            "isTest": false,
            "questionCount": 30,
            "questionModes": null,
            "durationMinutes": 100,
            "paperPath": null
          },
          "attempt": {
            "id": "demo-mock-attempt-01",
            "answers": [
              "3","5","1","4","2","5","3","1","2","4",
              "5","2","3","4","1","2","5","3","1","4",
              "2","12","7","25","36","18","9","64","5","144"
            ],
            "answeredCount": 30
          },
          "tools": { "formulaPath": null },
          "result": {
            "standardizedPerformance": 128.5,
            "totalPercentile": 92.4,
            "rawScore": 84.0,
            "correctCount": 25,
            "questionCount": 30,
            "elapsedLabel": "98분 0초"
          },
          "selection": null,
          "integrityReview": null,
          "review": [
            { "number": 1, "mode": "multiple-choice", "submittedAnswer": "3", "correctAnswer": "3", "isCorrect": true, "points": 2.0, "explanation": "지수법칙으로 밑을 통일하면 바로 계산됩니다." },
            { "number": 12, "mode": "multiple-choice", "submittedAnswer": "2", "correctAnswer": "4", "isCorrect": false, "points": 4.0, "explanation": "접선의 기울기를 구하기 전에 정의역 제한을 먼저 확인해야 합니다." },
            { "number": 22, "mode": "short-answer", "submittedAnswer": "12", "correctAnswer": "12", "isCorrect": true, "points": 3.0, "explanation": "수열의 합 공식을 그대로 적용하면 됩니다." },
            { "number": 29, "mode": "short-answer", "submittedAnswer": "5", "correctAnswer": "7", "isCorrect": false, "points": 4.0, "explanation": "경우의 수를 셀 때 중복을 제거하지 않았습니다." },
            { "number": 30, "mode": "short-answer", "submittedAnswer": "144", "correctAnswer": "144", "isCorrect": true, "points": 4.0, "explanation": "치환 뒤 범위를 다시 확인한 풀이가 정확합니다." }
          ]
        }
        """#
    }

    static let weeklyMockDraft = #"""
    {
      "draft": {
        "replayed": false,
        "submitted": false,
        "answeredCount": 18,
        "savedAt": "@T+0s@",
        "attempt": null
      }
    }
    """#

    static let weeklyMockSubmit = #"""
    {
      "submitted": true,
      "replayed": false,
      "result": {
        "elapsedMs": 5880000,
        "elapsedLabel": "98분 0초",
        "pendingAggregation": true,
        "resultsAvailableAt": "@T+2h@",
        "attemptNumber": 1,
        "formCode": "W34-A",
        "isTest": false,
        "weekKey": "@WEEK@"
      },
      "attempt": null
    }
    """#

    static let weeklyMockExpire = #"""
    {
      "expired": true,
      "replayed": false,
      "state": "submitted",
      "attemptId": "demo-mock-attempt-01",
      "attempt": null
    }
    """#

    // MARK: 무결성 소명 / 이의신청

    static let weeklyMockIntegrityCases = #"""
    { "integrityCases": [ \#(integrityCaseBody) ] }
    """#

    static let weeklyMockIntegrityDetail = #"""
    { "integrityCase": \#(integrityCaseBody) }
    """#

    private static let integrityCaseBody = #"""
    {
      "id": "demo-integrity-01",
      "exam": {
        "id": "demo-mock-01",
        "title": "2026학년도 주간 공식 모의고사 34주차",
        "formCode": "W34-A",
        "releaseAt": "@T-2d@"
      },
      "attemptId": "demo-mock-attempt-01",
      "weekKey": "@WEEK@",
      "status": "reviewing",
      "requestedQuestionNumbers": [12, 22, 29],
      "evidenceRequest": {
        "requestedAt": "@T-20h@",
        "deadlineAt": "@T+4h@",
        "instructions": "요청한 문항의 실제 풀이과정 사진을 문항 번호가 보이도록 촬영해 제출해 주세요."
      },
      "evidenceSubmissions": [
        {
          "receiptId": "demo-receipt-01",
          "submittedAt": "@T-3h@",
          "note": "12번은 연습장 앞면, 22번은 뒷면에 있습니다.",
          "files": [
            { "originalName": "풀이_12번.jpg", "mimeType": "image/jpeg", "sizeBytes": 1842301, "uploadedAt": "@T-3h@" },
            { "originalName": "풀이_22번.jpg", "mimeType": "image/jpeg", "sizeBytes": 2104882, "uploadedAt": "@T-3h@" }
          ]
        }
      ],
      "reviewStatus": "pending",
      "penaltyDecision": "none",
      "decision": { "result": "pending", "reason": "운영 검토가 진행 중입니다.", "decidedAt": null },
      "canSubmit": true
    }
    """#

    static let weeklyMockObjectionOptions = #"""
    {
      "exams": [
        { "id": "demo-mock-01", "title": "2026학년도 주간 공식 모의고사 34주차", "formCode": "W34-A", "questionCount": 30, "releaseAt": "@T-2d@" },
        { "id": "demo-mock-00", "title": "2026학년도 주간 공식 모의고사 33주차", "formCode": "W33-A", "questionCount": 30, "releaseAt": "@T-9d@" }
      ]
    }
    """#

    static let weeklyMockObjections = #"""
    {
      "objections": [
        {
          "id": "demo-objection-01",
          "examId": "demo-mock-01",
          "examTitle": "2026학년도 주간 공식 모의고사 34주차",
          "questionNumber": 12,
          "issueDetail": "접선의 기울기를 구하는 과정에서 정의역 조건이 문제에 명시되지 않은 것 같습니다.",
          "status": "reviewing",
          "reviewReason": "출제 검토 중입니다.",
          "reviewedAt": null,
          "createdAt": "@T-1d@"
        },
        {
          "id": "demo-objection-02",
          "examId": "demo-mock-00",
          "examTitle": "2026학년도 주간 공식 모의고사 33주차",
          "questionNumber": 26,
          "issueDetail": "보기 ③과 ⑤가 같은 값을 나타내는 것으로 보입니다.",
          "status": "accepted",
          "reviewReason": "중복 보기가 확인되어 전원 정답 처리했습니다.",
          "reviewedAt": "@T-6d@",
          "createdAt": "@T-8d@"
        },
        {
          "id": "demo-objection-03",
          "examId": "demo-mock-00",
          "examTitle": "2026학년도 주간 공식 모의고사 33주차",
          "questionNumber": 4,
          "issueDetail": "정답이 2번이 아니라 3번이라고 생각합니다.",
          "status": "rejected",
          "reviewReason": "제시된 조건에서 2번만 성립하여 원안을 유지합니다.",
          "reviewedAt": "@T-6d@",
          "createdAt": "@T-8d@"
        }
      ]
    }
    """#

    static let weeklyMockObjectionCreated = #"""
    {
      "replayed": false,
      "objection": {
        "id": "demo-objection-new",
        "examId": "demo-mock-01",
        "examTitle": "2026학년도 주간 공식 모의고사 34주차",
        "questionNumber": 12,
        "issueDetail": "데모에서 접수된 이의신청입니다.",
        "status": "reviewing",
        "reviewReason": "접수되었습니다.",
        "reviewedAt": null,
        "createdAt": "@T+0s@"
      }
    }
    """#
}
#endif
