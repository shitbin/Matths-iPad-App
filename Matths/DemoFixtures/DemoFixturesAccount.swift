//  DemoFixturesAccount.swift
//  Matths — DEBUG 데모 모드 픽스처: 계정·학습 동기화·홈·오답노트·퀵연습·이용권
//
//  값은 서버 계약서(/tmp/contract-server.json)와 ServerAPI 의 Codable 정의를 따른다.
//  **필수(non-optional) 필드를 하나라도 빼면 그 화면은 데모에서도 뜨지 않는다.**
//  시각은 DemoTemplate 토큰(@T-3d@ 등)으로 적어 언제 실행해도 "지금" 기준이 된다.
//
//  주의: 아래 문자열은 전부 raw string(#"""…"""#)이라 역슬래시가 그대로 남는다.
//  JSON 안의 LaTeX 는 `\\log` 처럼 **두 번** 적어야 디코더가 통과한다.

#if DEBUG
import Foundation

enum DemoAccountFixtures {

    // MARK: - 인증

    static let authResponse = #"""
    {
      "tokenType": "Bearer",
      "accessToken": "demo-access-token-not-a-real-credential",
      "expiresIn": 2592000,
      "user": {
        "name": "지우",
        "realName": "서지우",
        "email": "demo@matths.kr",
        "schoolGrade": 11,
        "school": { "region": "서울", "code": "7010084", "name": "한영고등학교" },
        "currentStreak": 12,
        "longestStreak": 21,
        "rankingDisplayMode": "nickname"
      }
    }
    """#

    /// 튜토리얼 상태는 DemoRouter가 런타임 동작(RESTART/COMPLETE/SKIP)에 맞춰
    /// 아래 토큰을 치환한다. 정적인 완료 응답만 두면 프로필의 "다시 시작" 버튼이
    /// 성공해도 다음 GET /me에서 완료로 되돌아가 실제 오버레이가 열리지 않는다.
    static let meResponse = #"""
    {
      "user": {
        "name": "지우",
        "realName": "서지우",
        "email": "demo@matths.kr",
        "schoolGrade": 11,
        "school": { "region": "서울", "code": "7010084", "name": "한영고등학교" },
        "currentStreak": 12,
        "longestStreak": 21,
        "rankingDisplayMode": "nickname",
        "dashboardTutorial": {
          "status": "@DASHBOARD_TUTORIAL_STATUS@",
          "shouldAutoStart": @DASHBOARD_TUTORIAL_AUTOSTART@,
          "completedAt": null,
          "skippedAt": null
        },
        "arenaTutorial": @ARENA_TUTORIAL@
      }
    }
    """#

    // 운영과 같은 세 가지 소셜 로그인을 모두 내려줘야 데모에서도 버튼 누락을 잡는다.
    static let authProviders = #"""
    {
      "providers": [
        { "key": "apple", "label": "Apple", "configured": true },
        { "key": "google", "label": "Google", "configured": true },
        { "key": "kakao", "label": "카카오", "configured": true }
      ]
    }
    """#

    static let passwordResetRequest = #"""
    { "message": "인증 코드를 이메일로 보냈습니다. 10분 안에 입력해 주세요.", "previewCode": "482913" }
    """#

    static let passwordResetVerify = #"""
    { "resetAuthorization": { "resetId": "demo-reset-01", "userId": "demo-user-01" } }
    """#

    static let withdrawalOptions = #"""
    {
      "passwordAccepted": true,
      "googleReauthentication": { "linked": true, "available": true },
      "kakaoReauthentication": { "linked": true, "available": true },
      "appleReauthentication": { "linked": true, "available": true }
    }
    """#

    static let withdrawalGoogleStart = #"""
    {
      "authorizationUrl": "https://www.matths.kr/auth/google/app?demo=1",
      "expiresAt": "@T+5m@"
    }
    """#

    static let withdrawResult = #"""
    {
      "withdrawn": true,
      "dataRetention": "anonymous",
      "message": "탈퇴가 완료되었습니다. 학습 기록은 익명으로 보존됩니다."
    }
    """#

    /// 가입 화면 학교 선택 — 지역이 여러 개여야 지역 피커가 실제로 시험된다.
    static let schools = #"""
    {
      "regions": {
        "서울": [
          { "code": "7010084", "name": "한영고등학교", "highSchoolType": "일반고" },
          { "code": "7010057", "name": "서울과학고등학교", "highSchoolType": "영재학교" },
          { "code": "7010132", "name": "경기고등학교", "highSchoolType": "일반고" },
          { "code": "7010208", "name": "숙명여자고등학교", "highSchoolType": "일반고" },
          { "code": "7010311", "name": "대원외국어고등학교", "highSchoolType": "외국어고" }
        ],
        "경기": [
          { "code": "7530045", "name": "수원고등학교", "highSchoolType": "일반고" },
          { "code": "7530112", "name": "분당대진고등학교", "highSchoolType": "일반고" },
          { "code": "7530291", "name": "경기과학고등학교", "highSchoolType": "영재학교" }
        ],
        "부산": [
          { "code": "7150019", "name": "부산일과학고등학교", "highSchoolType": "과학고" },
          { "code": "7150077", "name": "해운대고등학교", "highSchoolType": "일반고" }
        ],
        "대구": [
          { "code": "7261003", "name": "경신고등학교", "highSchoolType": "일반고" }
        ]
      }
    }
    """#

    // MARK: - 학습 진도 (서버 → 앱)

    static let learningProgress = #"""
    {"progress":[{"courseId":"common-math-1","unitId":"polynomials","conceptId":"polynomial-arithmetic","completedTopicIndexes":[0,1,2,3,4],"completionPercent":100,"masteryGate":{"requiredDistinctTypes":3,"correctTypeIds":["type-polynomi-1","type-polynomi-2","type-polynomi-3"],"userCompleted":true},"lastStudiedAt":"@T-40d@"},{"courseId":"common-math-1","unitId":"polynomials","conceptId":"identity-remainder-theorem","completedTopicIndexes":[0,1,2,3,4,5,6],"completionPercent":100,"masteryGate":{"requiredDistinctTypes":3,"correctTypeIds":["type-identity-1","type-identity-2","type-identity-3"],"userCompleted":true},"lastStudiedAt":"@T-40d@"},{"courseId":"common-math-1","unitId":"polynomials","conceptId":"polynomial-factorization","completedTopicIndexes":[0,1,2,3,4,5],"completionPercent":100,"masteryGate":{"requiredDistinctTypes":3,"correctTypeIds":["type-polynomi-1","type-polynomi-2","type-polynomi-3"],"userCompleted":true},"lastStudiedAt":"@T-40d@"},{"courseId":"common-math-1","unitId":"equations-and-inequalities","conceptId":"complex-numbers","completedTopicIndexes":[0,1,2,3,4,5,6,7],"completionPercent":100,"masteryGate":{"requiredDistinctTypes":3,"correctTypeIds":["type-complex--1","type-complex--2","type-complex--3"],"userCompleted":true},"lastStudiedAt":"@T-40d@"},{"courseId":"common-math-1","unitId":"equations-and-inequalities","conceptId":"quadratic-discriminant","completedTopicIndexes":[0,1,2,3,4],"completionPercent":100,"masteryGate":{"requiredDistinctTypes":3,"correctTypeIds":["type-quadrati-1","type-quadrati-2","type-quadrati-3"],"userCompleted":true},"lastStudiedAt":"@T-40d@"},{"courseId":"common-math-1","unitId":"equations-and-inequalities","conceptId":"quadratic-roots-and-coefficients","completedTopicIndexes":[0,1,2,3],"completionPercent":100,"masteryGate":{"requiredDistinctTypes":3,"correctTypeIds":["type-quadrati-1","type-quadrati-2","type-quadrati-3"],"userCompleted":true},"lastStudiedAt":"@T-40d@"},{"courseId":"common-math-1","unitId":"equations-and-inequalities","conceptId":"quadratic-equation-and-function","completedTopicIndexes":[0,1,2,3,4],"completionPercent":100,"masteryGate":{"requiredDistinctTypes":3,"correctTypeIds":["type-quadrati-1","type-quadrati-2","type-quadrati-3"],"userCompleted":true},"lastStudiedAt":"@T-40d@"},{"courseId":"common-math-1","unitId":"equations-and-inequalities","conceptId":"parabola-and-line","completedTopicIndexes":[0,1,2,3,4],"completionPercent":100,"masteryGate":{"requiredDistinctTypes":3,"correctTypeIds":["type-parabola-1","type-parabola-2","type-parabola-3"],"userCompleted":true},"lastStudiedAt":"@T-40d@"},{"courseId":"common-math-1","unitId":"equations-and-inequalities","conceptId":"quadratic-max-min-restricted","completedTopicIndexes":[0,1,2,3,4,5],"completionPercent":100,"masteryGate":{"requiredDistinctTypes":3,"correctTypeIds":["type-quadrati-1","type-quadrati-2","type-quadrati-3"],"userCompleted":true},"lastStudiedAt":"@T-40d@"},{"courseId":"common-math-1","unitId":"equations-and-inequalities","conceptId":"cubic-and-quartic-equations","completedTopicIndexes":[0,1,2,3,4],"completionPercent":100,"masteryGate":{"requiredDistinctTypes":3,"correctTypeIds":["type-cubic-an-1","type-cubic-an-2","type-cubic-an-3"],"userCompleted":true},"lastStudiedAt":"@T-40d@"},{"courseId":"common-math-1","unitId":"equations-and-inequalities","conceptId":"simultaneous-quadratic-equations","completedTopicIndexes":[0,1,2,3,4],"completionPercent":100,"masteryGate":{"requiredDistinctTypes":3,"correctTypeIds":["type-simultan-1","type-simultan-2","type-simultan-3"],"userCompleted":true},"lastStudiedAt":"@T-40d@"},{"courseId":"common-math-1","unitId":"equations-and-inequalities","conceptId":"simultaneous-linear-inequalities","completedTopicIndexes":[0,1,2,3,4],"completionPercent":100,"masteryGate":{"requiredDistinctTypes":3,"correctTypeIds":["type-simultan-1","type-simultan-2","type-simultan-3"],"userCompleted":true},"lastStudiedAt":"@T-40d@"},{"courseId":"common-math-1","unitId":"equations-and-inequalities","conceptId":"absolute-linear-inequalities","completedTopicIndexes":[0,1,2,3,4,5],"completionPercent":100,"masteryGate":{"requiredDistinctTypes":3,"correctTypeIds":["type-absolute-1","type-absolute-2","type-absolute-3"],"userCompleted":true},"lastStudiedAt":"@T-40d@"},{"courseId":"common-math-1","unitId":"equations-and-inequalities","conceptId":"quadratic-inequalities","completedTopicIndexes":[0,1,2,3,4,5],"completionPercent":100,"masteryGate":{"requiredDistinctTypes":3,"correctTypeIds":["type-quadrati-1","type-quadrati-2","type-quadrati-3"],"userCompleted":true},"lastStudiedAt":"@T-40d@"},{"courseId":"common-math-1","unitId":"counting","conceptId":"addition-and-multiplication-principles","completedTopicIndexes":[0,1,2,3,4],"completionPercent":100,"masteryGate":{"requiredDistinctTypes":3,"correctTypeIds":["type-addition-1","type-addition-2","type-addition-3"],"userCompleted":true},"lastStudiedAt":"@T-40d@"},{"courseId":"common-math-1","unitId":"counting","conceptId":"permutations","completedTopicIndexes":[0,1,2,3,4],"completionPercent":100,"masteryGate":{"requiredDistinctTypes":3,"correctTypeIds":["type-permutat-1","type-permutat-2","type-permutat-3"],"userCompleted":true},"lastStudiedAt":"@T-40d@"},{"courseId":"common-math-1","unitId":"counting","conceptId":"combinations","completedTopicIndexes":[0,1,2,3,4],"completionPercent":100,"masteryGate":{"requiredDistinctTypes":3,"correctTypeIds":["type-combinat-1","type-combinat-2","type-combinat-3"],"userCompleted":true},"lastStudiedAt":"@T-40d@"},{"courseId":"common-math-1","unitId":"matrices","conceptId":"matrix-concept","completedTopicIndexes":[0,1,2,3,4,5],"completionPercent":100,"masteryGate":{"requiredDistinctTypes":3,"correctTypeIds":["type-matrix-c-1","type-matrix-c-2","type-matrix-c-3"],"userCompleted":true},"lastStudiedAt":"@T-40d@"},{"courseId":"common-math-1","unitId":"matrices","conceptId":"matrix-operations","completedTopicIndexes":[0,1,2,3,4],"completionPercent":100,"masteryGate":{"requiredDistinctTypes":3,"correctTypeIds":["type-matrix-o-1","type-matrix-o-2","type-matrix-o-3"],"userCompleted":true},"lastStudiedAt":"@T-40d@"},{"courseId":"common-math-2","unitId":"coordinate-geometry","conceptId":"distance-and-internal-division","completedTopicIndexes":[0,1,2,3,4,5],"completionPercent":100,"masteryGate":{"requiredDistinctTypes":3,"correctTypeIds":["type-distance-1","type-distance-2","type-distance-3"],"userCompleted":true},"lastStudiedAt":"@T-26d@"},{"courseId":"common-math-2","unitId":"coordinate-geometry","conceptId":"parallel-and-perpendicular-lines","completedTopicIndexes":[0,1,2,3],"completionPercent":100,"masteryGate":{"requiredDistinctTypes":3,"correctTypeIds":["type-parallel-1","type-parallel-2","type-parallel-3"],"userCompleted":true},"lastStudiedAt":"@T-26d@"},{"courseId":"common-math-2","unitId":"coordinate-geometry","conceptId":"point-line-distance","completedTopicIndexes":[0,1,2,3],"completionPercent":100,"masteryGate":{"requiredDistinctTypes":3,"correctTypeIds":["type-point-li-1","type-point-li-2","type-point-li-3"],"userCompleted":true},"lastStudiedAt":"@T-26d@"},{"courseId":"common-math-2","unitId":"coordinate-geometry","conceptId":"circle-equation","completedTopicIndexes":[0,1,2,3,4],"completionPercent":100,"masteryGate":{"requiredDistinctTypes":3,"correctTypeIds":["type-circle-e-1","type-circle-e-2","type-circle-e-3"],"userCompleted":true},"lastStudiedAt":"@T-26d@"},{"courseId":"common-math-2","unitId":"coordinate-geometry","conceptId":"circle-line-position","completedTopicIndexes":[0,1,2,3,4],"completionPercent":100,"masteryGate":{"requiredDistinctTypes":3,"correctTypeIds":["type-circle-l-1","type-circle-l-2","type-circle-l-3"],"userCompleted":true},"lastStudiedAt":"@T-26d@"},{"courseId":"common-math-2","unitId":"coordinate-geometry","conceptId":"geometric-translation","completedTopicIndexes":[0,1,2,3,4],"completionPercent":100,"masteryGate":{"requiredDistinctTypes":3,"correctTypeIds":["type-geometri-1","type-geometri-2","type-geometri-3"],"userCompleted":true},"lastStudiedAt":"@T-26d@"},{"courseId":"common-math-2","unitId":"coordinate-geometry","conceptId":"geometric-reflection","completedTopicIndexes":[0,1,2,3,4],"completionPercent":100,"masteryGate":{"requiredDistinctTypes":3,"correctTypeIds":["type-geometri-1","type-geometri-2","type-geometri-3"],"userCompleted":true},"lastStudiedAt":"@T-26d@"},{"courseId":"common-math-2","unitId":"sets-and-propositions","conceptId":"set-concept-and-representation","completedTopicIndexes":[0,1,2,3],"completionPercent":60,"masteryGate":{"requiredDistinctTypes":3,"correctTypeIds":["type-set-conc-1"],"userCompleted":false},"lastStudiedAt":"@T-14d@"},{"courseId":"common-math-2","unitId":"sets-and-propositions","conceptId":"set-inclusion","completedTopicIndexes":[0],"completionPercent":25,"masteryGate":{"requiredDistinctTypes":3,"correctTypeIds":["type-set-incl-1"],"userCompleted":false},"lastStudiedAt":"@T-14d@"},{"courseId":"common-math-2","unitId":"sets-and-propositions","conceptId":"set-operations","completedTopicIndexes":[0,1,2,3],"completionPercent":60,"masteryGate":{"requiredDistinctTypes":3,"correctTypeIds":["type-set-oper-1"],"userCompleted":false},"lastStudiedAt":"@T-14d@"},{"courseId":"common-math-2","unitId":"sets-and-propositions","conceptId":"proposition-and-condition","completedTopicIndexes":[0,1],"completionPercent":25,"masteryGate":{"requiredDistinctTypes":3,"correctTypeIds":["type-proposit-1"],"userCompleted":false},"lastStudiedAt":"@T-14d@"},{"courseId":"common-math-2","unitId":"sets-and-propositions","conceptId":"converse-and-contrapositive","completedTopicIndexes":[0,1,2],"completionPercent":60,"masteryGate":{"requiredDistinctTypes":3,"correctTypeIds":["type-converse-1"],"userCompleted":false},"lastStudiedAt":"@T-14d@"},{"courseId":"common-math-2","unitId":"sets-and-propositions","conceptId":"sufficient-and-necessary-conditions","completedTopicIndexes":[0],"completionPercent":25,"masteryGate":{"requiredDistinctTypes":3,"correctTypeIds":["type-sufficie-1"],"userCompleted":false},"lastStudiedAt":"@T-14d@"},{"courseId":"common-math-2","unitId":"sets-and-propositions","conceptId":"proof-by-contrapositive-and-contradiction","completedTopicIndexes":[0,1],"completionPercent":60,"masteryGate":{"requiredDistinctTypes":3,"correctTypeIds":["type-proof-by-1"],"userCompleted":false},"lastStudiedAt":"@T-14d@"},{"courseId":"common-math-2","unitId":"sets-and-propositions","conceptId":"absolute-inequality","completedTopicIndexes":[0],"completionPercent":25,"masteryGate":{"requiredDistinctTypes":3,"correctTypeIds":["type-absolute-1"],"userCompleted":false},"lastStudiedAt":"@T-14d@"},{"courseId":"algebra","unitId":"exponential-logarithmic-functions","conceptId":"algebra-01-01","completedTopicIndexes":[0,1,2],"completionPercent":100,"masteryGate":{"requiredDistinctTypes":3,"correctTypeIds":["type-algebra--1","type-algebra--2","type-algebra--3"],"userCompleted":true},"lastStudiedAt":"@T-9d@"},{"courseId":"algebra","unitId":"exponential-logarithmic-functions","conceptId":"algebra-01-02","completedTopicIndexes":[0,1],"completionPercent":100,"masteryGate":{"requiredDistinctTypes":3,"correctTypeIds":["type-algebra--1","type-algebra--2","type-algebra--3"],"userCompleted":true},"lastStudiedAt":"@T-9d@"},{"courseId":"algebra","unitId":"exponential-logarithmic-functions","conceptId":"algebra-01-03","completedTopicIndexes":[0,1],"completionPercent":100,"masteryGate":{"requiredDistinctTypes":3,"correctTypeIds":["type-algebra--1","type-algebra--2","type-algebra--3"],"userCompleted":true},"lastStudiedAt":"@T-9d@"},{"courseId":"algebra","unitId":"exponential-logarithmic-functions","conceptId":"algebra-01-04","completedTopicIndexes":[0,1],"completionPercent":50,"masteryGate":{"requiredDistinctTypes":3,"correctTypeIds":["type-algebra--1"],"userCompleted":false},"lastStudiedAt":"@T-4d@"},{"courseId":"algebra","unitId":"exponential-logarithmic-functions","conceptId":"algebra-01-05","completedTopicIndexes":[0,1],"completionPercent":50,"masteryGate":{"requiredDistinctTypes":3,"correctTypeIds":["type-algebra--1"],"userCompleted":false},"lastStudiedAt":"@T-4d@"},{"courseId":"algebra","unitId":"trigonometric-functions","conceptId":"algebra-02-01","completedTopicIndexes":[0],"completionPercent":34,"masteryGate":{"requiredDistinctTypes":3,"correctTypeIds":["type-algebra--1"],"userCompleted":false},"lastStudiedAt":"@T-2d@"},{"courseId":"algebra","unitId":"trigonometric-functions","conceptId":"algebra-02-02","completedTopicIndexes":[0],"completionPercent":34,"masteryGate":{"requiredDistinctTypes":3,"correctTypeIds":["type-algebra--1"],"userCompleted":false},"lastStudiedAt":"@T-2d@"},{"courseId":"calculus-1","unitId":"limits-and-continuity","conceptId":"calculus-1-01-01","completedTopicIndexes":[],"completionPercent":25,"masteryGate":{"requiredDistinctTypes":3,"correctTypeIds":["type-calculus-1"],"userCompleted":false},"lastStudiedAt":"@T-1d@"}]}
    """#

    // MARK: - 홈 대시보드
    //
    // 막대 7칸이 **다양한 값**이어야 레이아웃이 실제로 시험된다: 0분인 날 두 개,
    // 두 자리·세 자리가 섞이고, 마지막 칸이 "오늘"이다(서버 규약: 마지막 날 = today).

    static let dashboardActivity = #"""
    {
      "dashboard": {
        "generatedAt": "@T+0s@",
        "stats": {
          "weeklyStudyMinutes": 412,
          "weeklyStudyDetail": "지난 기간보다 +68분",
          "todayStudyMinutes": 47,
          "activeStudyDays": 5,
          "averageStudyMinutes": 82,
          "weeklySolvedProblems": 138,
          "weeklySolvedDetail": "지난 기간보다 +12문제",
          "correctRate": 73,
          "correctRateDetail": "지난 기간보다 +6%"
        },
        "weeklyActivity": {
          "days": [
            { "dateKey": "@D-6@", "label": "@W-6@", "minutes": 0,   "isToday": false },
            { "dateKey": "@D-5@", "label": "@W-5@", "minutes": 96,  "isToday": false },
            { "dateKey": "@D-4@", "label": "@W-4@", "minutes": 45,  "isToday": false },
            { "dateKey": "@D-3@", "label": "@W-3@", "minutes": 128, "isToday": false },
            { "dateKey": "@D-2@", "label": "@W-2@", "minutes": 0,   "isToday": false },
            { "dateKey": "@D-1@", "label": "@W-1@", "minutes": 96,  "isToday": false },
            { "dateKey": "@D-0@", "label": "오늘",   "minutes": 47,  "isToday": true }
          ],
          "maxMinutes": 128
        }
      }
    }
    """#

    // MARK: - 학생 학원 교실

    static let academyDashboard = #"""
    {
      "membership": {
        "id": "demo-membership-01",
        "status": "APPROVED",
        "joinSource": "INVITE_CODE",
        "requestedAt": "@T-20d@",
        "approvedAt": "@T-19d@"
      },
      "academy": { "id": "demo-academy-01", "name": "매쓰온 수학학원", "status": "ACTIVE" },
      "academyClass": {
        "id": "demo-class-01",
        "name": "고2 심화 A반",
        "schedule": {
          "weekdays": [2, 4],
          "startTime": "18:30",
          "endTime": "20:30",
          "effectiveFrom": "2026-03-02",
          "timezone": "Asia/Seoul"
        }
      },
      "weeks": [
        {
          "id": "demo-week-34",
          "academicYear": 2026,
          "weekNumber": 34,
          "title": "지수함수와 로그함수의 그래프",
          "lessonSummary": "그래프의 평행이동과 대칭을 이용해 식과 그래프를 연결했습니다.",
          "concepts": [
            {
              "curriculumId": "kr-2022",
              "courseId": "algebra",
              "courseTitle": "대수",
              "unitId": "exponential-logarithmic-functions",
              "unitTitle": "지수함수와 로그함수",
              "conceptId": "exponential-logarithmic-graphs",
              "conceptTitle": "지수함수와 로그함수의 그래프",
              "href": "/learn/algebra/exponential-logarithmic-functions/exponential-logarithmic-graphs"
            },
            {
              "curriculumId": "kr-2022",
              "courseId": "algebra",
              "courseTitle": "대수",
              "unitId": "exponential-logarithmic-functions",
              "unitTitle": "지수함수와 로그함수",
              "conceptId": "exponential-logarithmic-applications",
              "conceptTitle": "지수함수와 로그함수의 활용",
              "href": "/learn/algebra/exponential-logarithmic-functions/exponential-logarithmic-applications"
            }
          ],
          "assignmentTitle": "그래프 변환 필수 12문제",
          "assignmentInstructions": "개념 화면을 한 번 재생한 뒤 1~12번을 풀고 틀린 문항은 오답노트에 저장하세요.",
          "dueAt": "@T+2d@",
          "files": [
            { "id": "demo-file-01", "originalName": "34주차-그래프-과제.pdf", "mimeType": "application/pdf", "sizeBytes": 428032 }
          ]
        },
        {
          "id": "demo-week-33",
          "academicYear": 2026,
          "weekNumber": 33,
          "title": "로그의 성질과 계산",
          "lessonSummary": "밑과 진수 조건을 확인하며 로그 계산을 연습했습니다.",
          "concepts": [
            {
              "curriculumId": "kr-2022",
              "courseId": "algebra",
              "courseTitle": "대수",
              "unitId": "exponential-logarithmic-functions",
              "unitTitle": "지수함수와 로그함수",
              "conceptId": "logarithm-definition-and-properties",
              "conceptTitle": "로그의 정의와 성질",
              "href": "/learn/algebra/exponential-logarithmic-functions/logarithm-definition-and-properties"
            }
          ],
          "assignmentTitle": "로그 계산 복습",
          "assignmentInstructions": "틀린 계산은 풀이 메모에 조건을 함께 적으세요.",
          "dueAt": "@T-4d@",
          "files": []
        }
      ],
      "attendance": {
        "session": {
          "id": "demo-session-01",
          "dateKey": "@D+0@",
          "startsAt": "@T+20m@",
          "endsAt": "@T+140m@",
          "checkInOpensAt": "@T-5m@",
          "lateAfterAt": "@T+25m@",
          "checkInClosesAt": "@T+40m@",
          "attendanceMode": "SELF_CODE",
          "state": "OPEN",
          "isLateWindow": false,
          "codeVersion": 1
        },
        "attendance": null,
        "canCheckIn": true,
        "serverNow": "@T+0s@"
      },
      "academies": [
        { "id": "demo-academy-01", "name": "매쓰온 수학학원", "status": "ACTIVE" },
        { "id": "demo-academy-02", "name": "한빛수학연구소", "status": "ACTIVE" }
      ]
    }
    """#

    static let academyWeek = #"""
    {
      "academy": { "id": "demo-academy-01", "name": "매쓰온 수학학원", "status": "ACTIVE" },
      "academyClass": {
        "id": "demo-class-01",
        "name": "고2 심화 A반",
        "schedule": { "weekdays": [2,4], "startTime": "18:30", "endTime": "20:30", "effectiveFrom": "2026-03-02", "timezone": "Asia/Seoul" }
      },
      "week": {
        "id": "demo-week-34",
        "academicYear": 2026,
        "weekNumber": 34,
        "title": "지수함수와 로그함수의 그래프",
        "lessonSummary": "그래프의 평행이동과 대칭을 이용해 식과 그래프를 연결했습니다.",
        "concepts": [
          { "curriculumId": "kr-2022", "courseId": "algebra", "courseTitle": "대수", "unitId": "exponential-logarithmic-functions", "unitTitle": "지수함수와 로그함수", "conceptId": "exponential-logarithmic-graphs", "conceptTitle": "지수함수와 로그함수의 그래프", "href": "/learn/algebra/exponential-logarithmic-functions/exponential-logarithmic-graphs" },
          { "curriculumId": "kr-2022", "courseId": "algebra", "courseTitle": "대수", "unitId": "exponential-logarithmic-functions", "unitTitle": "지수함수와 로그함수", "conceptId": "exponential-logarithmic-applications", "conceptTitle": "지수함수와 로그함수의 활용", "href": "/learn/algebra/exponential-logarithmic-functions/exponential-logarithmic-applications" }
        ],
        "assignmentTitle": "그래프 변환 필수 12문제",
        "assignmentInstructions": "개념 화면을 한 번 재생한 뒤 1~12번을 풀고 틀린 문항은 오답노트에 저장하세요.",
        "dueAt": "@T+2d@",
        "files": [
          { "id": "demo-file-01", "originalName": "34주차-그래프-과제.pdf", "mimeType": "application/pdf", "sizeBytes": 428032 }
        ]
      }
    }
    """#

    static let academyCheckIn = #"""
    { "attendance": { "status": "PRESENT", "checkedInAt": "@T+0s@", "source": "SELF_CODE" } }
    """#

    static let teacherAcademyDashboard = #"""
    {
      "academy": { "id": "demo-academy-01", "name": "매쓰온 수학학원", "status": "ACTIVE" },
      "staffRole": "OWNER",
      "isOwner": true,
      "pendingCount": 2,
      "studentCount": 18,
      "classes": [
        { "id": "demo-class-01", "name": "고2 심화 A반", "schedule": { "weekdays": [2,4], "startTime": "18:30", "endTime": "20:30", "effectiveFrom": "2026-03-02", "timezone": "Asia/Seoul" }, "attendancePolicy": { "mode": "SELF_CODE", "opensBeforeMinutes": 10, "lateAfterMinutes": 5, "closesAfterMinutes": 30 }, "studentCount": 9, "canManage": true, "homeroomTeacher": { "id": "demo-teacher-owner", "name": "이상윤", "email": "teacher-demo@matths.kr" }, "coTeachers": [{ "id": "demo-teacher-02", "name": "김다은", "email": "daeun.teacher@example.com" }] },
        { "id": "demo-class-02", "name": "고1 기본 B반", "schedule": { "weekdays": [1,3], "startTime": "17:00", "endTime": "19:00", "effectiveFrom": "2026-03-02", "timezone": "Asia/Seoul" }, "studentCount": 7 },
        { "id": "demo-class-03", "name": "미적분 주말반", "schedule": { "weekdays": [6], "startTime": "10:00", "endTime": "13:00", "effectiveFrom": "2026-03-02", "timezone": "Asia/Seoul" }, "studentCount": 2 }
      ],
      "archivedClasses": [
        { "id": "demo-class-archived-01", "name": "2025 고2 겨울특강", "schedule": { "weekdays": [7], "startTime": "10:00", "endTime": "12:00", "effectiveFrom": "2025-12-20", "timezone": "Asia/Seoul" }, "attendancePolicy": { "mode": "MANUAL", "opensBeforeMinutes": 10, "lateAfterMinutes": 5, "closesAfterMinutes": 20 }, "isActive": false, "studentCount": 0, "canManage": true }
      ],
      "requests": [
        { "id": "demo-request-01", "student": { "id": "demo-student-21", "name": "김민준", "nickname": "수학왕", "schoolGrade": 10, "school": { "name": "잠실고등학교", "region": "서울" } }, "academyClass": null, "requestedAt": "@T-2h@", "approvedAt": null },
        { "id": "demo-request-02", "student": { "id": "demo-student-22", "name": "박서연", "nickname": null, "schoolGrade": 11, "school": { "name": "정신여자고등학교", "region": "서울" } }, "academyClass": { "id": "demo-class-01", "name": "고2 심화 A반", "schedule": null, "studentCount": 9 }, "requestedAt": "@T-35m@", "approvedAt": null }
      ],
      "students": [
        { "id": "demo-membership-11", "student": { "id": "demo-student-11", "name": "서지우", "nickname": "지우", "schoolGrade": 11, "school": { "name": "한영고등학교", "region": "서울" } }, "academyClass": { "id": "demo-class-01", "name": "고2 심화 A반", "schedule": null, "studentCount": 9 }, "requestedAt": "@T-20d@", "approvedAt": "@T-19d@" },
        { "id": "demo-membership-12", "student": { "id": "demo-student-12", "name": "이도윤", "nickname": null, "schoolGrade": 10, "school": { "name": "배명고등학교", "region": "서울" } }, "academyClass": { "id": "demo-class-02", "name": "고1 기본 B반", "schedule": null, "studentCount": 7 }, "requestedAt": "@T-18d@", "approvedAt": "@T-18d@" }
      ],
      "invites": [
        { "id": "demo-invite-01", "label": "고2 9월 신규생", "code": "MTH-9K7P2Q", "academyClass": { "id": "demo-class-01", "name": "고2 심화 A반", "schedule": null, "studentCount": 9 }, "displayState": "ACTIVE", "useCount": 3, "maxUses": 30, "expiresAt": "@T+10d@" },
        { "id": "demo-invite-02", "label": "상담 학생", "code": "MTH-4NR8TW", "academyClass": null, "displayState": "ACTIVE", "useCount": 1, "maxUses": 30, "expiresAt": "@T+5d@" }
      ],
      "staffPendingCount": 1,
      "activeStaff": [
        { "id": "demo-staff-owner", "user": { "id": "demo-teacher-owner", "name": "이상윤", "email": "teacher-demo@matths.kr" }, "role": "OWNER", "status": "ACTIVE", "requestedAt": "@T-120d@", "joinedAt": "@T-120d@" },
        { "id": "demo-staff-02", "user": { "id": "demo-teacher-02", "name": "김다은", "email": "daeun.teacher@example.com" }, "role": "TEACHER", "status": "ACTIVE", "requestedAt": "@T-60d@", "joinedAt": "@T-59d@" }
      ],
      "staffRequests": [
        { "id": "demo-staff-request-01", "user": { "id": "demo-teacher-03", "name": "박현우", "email": "hyunwoo.teacher@example.com" }, "role": "TEACHER", "status": "PENDING", "requestedAt": "@T-3h@", "joinedAt": null }
      ]
    }
    """#

    static let teacherAnalytics = #"""
    {
      "academy": { "id": "demo-academy-01", "name": "매쓰온 수학학원", "status": "ACTIVE" },
      "scope": { "type": "ACADEMY", "academyClass": null },
      "period": {
        "key": "2026-09", "label": "2026년 9월 (이번 달)", "isCurrent": true,
        "options": [
          { "key": "2026-09", "label": "2026년 9월 (이번 달)" },
          { "key": "2026-08", "label": "2026년 8월 (지난달)" },
          { "key": "2026-07", "label": "2026년 7월" }
        ]
      },
      "hasActivity": true,
      "cards": [
        { "label": "학습 건강도", "value": "78점", "detail": "안정 · 데이터 반영 89%" },
        { "label": "학습 참여 학생", "value": "16명", "detail": "89% 참여" },
        { "label": "평균 학습일", "value": "9.4일", "detail": "학생 1인당 · 미학습 0일 포함" },
        { "label": "오답 복습률", "value": "73%", "detail": "전체 오답 126개 기준" }
      ],
      "values": {
        "totalStudents": 18, "activeStudents": 16, "participationRate": 89,
        "averageLearningDays": 9.4, "averageCompletedConcepts": 6.8,
        "averageUniqueProblems": 61.2, "firstAttemptAccuracy": 72,
        "wrongAnswerReviewRate": 73, "retrySuccessRate": 68
      },
      "health": {
        "score": 78, "key": "HEALTHY", "label": "안정", "dataCoverage": 89,
        "targetLearningDays": 12,
        "distribution": { "healthy": 11, "watch": 4, "risk": 3 },
        "components": { "engagement": 81, "accuracy": 72, "review": 73, "recovery": 68 }
      },
      "growth": [
        { "week": 1, "label": "1주", "attempts": 188, "uniqueProblems": 122, "activeStudents": 13, "accuracy": 67 },
        { "week": 2, "label": "2주", "attempts": 246, "uniqueProblems": 158, "activeStudents": 15, "accuracy": 71 },
        { "week": 3, "label": "3주", "attempts": 274, "uniqueProblems": 184, "activeStudents": 16, "accuracy": 74 },
        { "week": 4, "label": "4주", "attempts": 231, "uniqueProblems": 149, "activeStudents": 14, "accuracy": 76 }
      ],
      "summary": [
        { "label": "학습 참여", "text": "승인 학생 18명 중 16명이 이번 달 학습에 참여했습니다." },
        { "label": "학습 건강도", "text": "학원 평균은 78점(안정)이며 건강 11명, 관찰 4명, 주의 3명입니다." },
        { "label": "지도 우선순위", "text": "미분계수의 정의를 먼저 복습하고 오답 재도전 흐름을 확인해 주세요." }
      ],
      "attentionStudents": [
        {
          "membership": { "id": "demo-membership-12", "student": { "id": "demo-student-12", "name": "이도윤", "nickname": null, "schoolGrade": 10, "school": { "name": "배명고등학교", "region": "서울" } }, "academyClass": { "id": "demo-class-02", "name": "고1 기본 B반", "schedule": null, "studentCount": 7 }, "requestedAt": "@T-18d@", "approvedAt": "@T-18d@" },
          "reasons": ["학습일 2일", "오답 복습률 31%"], "priority": 40
        },
        {
          "membership": { "id": "demo-membership-13", "student": { "id": "demo-student-13", "name": "김민준", "nickname": "수학왕", "schoolGrade": 11, "school": { "name": "잠실고등학교", "region": "서울" } }, "academyClass": null, "requestedAt": "@T-14d@", "approvedAt": "@T-13d@" },
          "reasons": ["선택 기간 학습 기록 없음"], "priority": 100
        }
      ],
      "mathMap": {
        "graphVersion": "kr-2022-math-graph-v1.0", "modelVersion": "v1.0",
        "overallMastery": 69, "analyzedConceptCount": 8, "totalStudents": 18,
        "heatmap": [
          { "conceptId": "derivative-definition", "conceptTitle": "미분계수의 정의", "courseTitle": "미적분", "unitTitle": "미분", "mastery": 41, "analyzedCount": 12, "totalStudents": 18, "status": "WEAK", "statusLabel": "보완 필요" },
          { "conceptId": "continuity", "conceptTitle": "함수의 연속", "courseTitle": "미적분", "unitTitle": "극한과 연속", "mastery": 58, "analyzedCount": 14, "totalStudents": 18, "status": "WEAK", "statusLabel": "보완 필요" },
          { "conceptId": "exponential-graphs", "conceptTitle": "지수함수의 그래프", "courseTitle": "대수", "unitTitle": "지수함수", "mastery": 66, "analyzedCount": 15, "totalStudents": 18, "status": "DEVELOPING", "statusLabel": "성장 중" },
          { "conceptId": "logarithm", "conceptTitle": "로그의 성질", "courseTitle": "대수", "unitTitle": "로그", "mastery": 74, "analyzedCount": 15, "totalStudents": 18, "status": "DEVELOPING", "statusLabel": "성장 중" },
          { "conceptId": "limit-basics", "conceptTitle": "함수의 극한", "courseTitle": "미적분", "unitTitle": "극한과 연속", "mastery": 84, "analyzedCount": 16, "totalStudents": 18, "status": "MASTERED", "statusLabel": "숙달" },
          { "conceptId": "sequence", "conceptTitle": "수열의 합", "courseTitle": "대수", "unitTitle": "수열", "mastery": 91, "analyzedCount": 13, "totalStudents": 18, "status": "MASTERED", "statusLabel": "숙달" }
        ],
        "bottlenecks": [
          { "conceptId": "derivative-definition", "conceptTitle": "미분계수의 정의", "mastery": 41, "analyzedCount": 12, "weakCount": 8, "affectedConceptCount": 4 }
        ],
        "recommendation": {
          "conceptId": "derivative-definition", "conceptTitle": "미분계수의 정의", "mastery": 41,
          "reason": "분석 학생 중 보완 필요 비율이 높고 4개 후속 개념과 연결되어 있습니다.",
          "problemCount": 12
        }
      }
    }
    """#

    static let teacherAnalyticsEmpty = #"""
    {
      "academy": { "id": "demo-academy-01", "name": "매쓰온 수학학원", "status": "ACTIVE" },
      "scope": { "type": "ACADEMY", "academyClass": null },
      "period": { "key": "2026-09", "label": "2026년 9월 (이번 달)", "isCurrent": true, "options": [{ "key": "2026-09", "label": "2026년 9월 (이번 달)" }] },
      "hasActivity": false,
      "cards": [
        { "label": "학습 건강도", "value": "—", "detail": "승인 학생 없음" },
        { "label": "학습 참여 학생", "value": "0명", "detail": "승인 학생 없음" },
        { "label": "평균 학습일", "value": "—", "detail": "학생 1인당 · 미학습 0일 포함" },
        { "label": "오답 복습률", "value": "—", "detail": "새 오답 없음" }
      ],
      "values": { "totalStudents": 0, "activeStudents": 0, "participationRate": null, "averageLearningDays": null, "averageCompletedConcepts": null, "averageUniqueProblems": null, "firstAttemptAccuracy": null, "wrongAnswerReviewRate": null, "retrySuccessRate": null },
      "health": { "score": null, "key": "RISK", "label": "데이터 없음", "dataCoverage": 0, "targetLearningDays": 12, "distribution": { "healthy": 0, "watch": 0, "risk": 0 }, "components": { "engagement": null, "accuracy": null, "review": null, "recovery": null } },
      "growth": [{ "week": 1, "label": "1주", "attempts": 0, "uniqueProblems": 0, "activeStudents": 0, "accuracy": null }],
      "summary": [{ "label": "학습 참여", "text": "승인된 학생이 없어 월간 평균을 계산하지 않았습니다." }],
      "attentionStudents": [],
      "mathMap": { "graphVersion": "kr-2022-math-graph-v1.0", "modelVersion": "v1.0", "overallMastery": null, "analyzedConceptCount": 0, "totalStudents": 0, "heatmap": [], "bottlenecks": [], "recommendation": null }
    }
    """#

    static let teacherSetupChoice = #"""
    {
      "isReady": false,
      "pendingAcademy": null,
      "pendingRequest": null,
      "rejectedAcademy": null,
      "academies": [
        { "id": "demo-academy-01", "name": "매쓰온 수학학원", "status": "ACTIVE" },
        { "id": "demo-academy-02", "name": "한빛수학연구소", "status": "ACTIVE" },
        { "id": "demo-academy-03", "name": "송파 수학의힘", "status": "ACTIVE" }
      ]
    }
    """#

    static let teacherSetupPendingAcademy = #"""
    {
      "isReady": false,
      "pendingAcademy": { "id": "demo-academy-new", "name": "평촌 하이수학", "status": "PENDING" },
      "pendingRequest": null,
      "rejectedAcademy": null,
      "academies": []
    }
    """#

    static let teacherSetupPendingJoin = #"""
    {
      "isReady": false,
      "pendingAcademy": null,
      "pendingRequest": {
        "id": "demo-staff-pending",
        "academy": { "id": "demo-academy-01", "name": "매쓰온 수학학원", "status": "ACTIVE" },
        "requestedAt": "@T-2h@"
      },
      "rejectedAcademy": null,
      "academies": []
    }
    """#

    static let teacherSetupRejected = #"""
    {
      "isReady": false,
      "pendingAcademy": null,
      "pendingRequest": null,
      "rejectedAcademy": { "id": "demo-academy-rejected", "name": "매쓰온 수학학언", "status": "REJECTED" },
      "academies": [
        { "id": "demo-academy-01", "name": "매쓰온 수학학원", "status": "ACTIVE" },
        { "id": "demo-academy-02", "name": "한빛수학연구소", "status": "ACTIVE" }
      ]
    }
    """#

    static let teacherForensics = #"""
    {
      "academy": { "id": "demo-academy-01", "name": "매쓰온 수학학원", "status": "ACTIVE" },
      "isOwner": true,
      "classes": [
        { "id": "demo-class-a", "name": "고2 미적분 A", "isActive": true },
        { "id": "demo-class-b", "name": "고3 실전반", "isActive": true },
        { "id": "demo-class-old", "name": "2025 겨울특강", "isActive": false }
      ],
      "selectedClass": { "id": "demo-class-a", "name": "고2 미적분 A", "isActive": true },
      "scope": { "approvedStudents": 18, "issuedCopies": 46, "distinctDownloaders": 17, "firstIssuedAt": "@T-30d@" },
      "analysis": null
    }
    """#

    static let teacherForensicsResult = #"""
    {
      "academy": { "id": "demo-academy-01", "name": "매쓰온 수학학원", "status": "ACTIVE" },
      "isOwner": true,
      "classes": [{ "id": "demo-class-a", "name": "고2 미적분 A", "isActive": true }],
      "selectedClass": { "id": "demo-class-a", "name": "고2 미적분 A", "isActive": true },
      "scope": { "approvedStudents": 18, "issuedCopies": 46, "distinctDownloaders": 17, "firstIssuedAt": "@T-30d@" },
      "analysis": {
        "inputType": "TRACE_CODE",
        "traceCodes": ["MTH-0123ABCD4567EF89"],
        "matches": [{
          "displayName": "김민준", "className": "고2 미적분 A", "userRole": "student",
          "downloadedAt": "@T-7d@", "traceCode": "MTH-0123ABCD4567EF89",
          "documentIssueId": "issue-demo-01", "originalName": "미적분_주간과제_08.pdf",
          "signatureVerified": true, "recognitionMethod": "MANUAL_TRACE_CODE",
          "ocrConfidence": null, "matchedCandidate": null
        }]
      }
    }
    """#

    static let teacherForensicsEmpty = #"""
    {
      "academy": { "id": "demo-academy-01", "name": "매쓰온 수학학원", "status": "ACTIVE" },
      "isOwner": false, "classes": [], "selectedClass": null,
      "scope": { "approvedStudents": 0, "issuedCopies": 0, "distinctDownloaders": 0, "firstIssuedAt": null },
      "analysis": null
    }
    """#

    static let teacherStudentPage = #"""
    {
      "academy": { "id": "demo-academy-01", "name": "매쓰온 수학학원", "status": "ACTIVE" },
      "classes": [
        { "id": "demo-class-01", "name": "고2 심화 A반", "schedule": null, "studentCount": 9 },
        { "id": "demo-class-02", "name": "고1 기본 B반", "schedule": null, "studentCount": 7 },
        { "id": "demo-class-03", "name": "미적분 주말반", "schedule": null, "studentCount": 2 }
      ],
      "students": [
        { "id": "demo-membership-11", "student": { "id": "demo-student-11", "name": "서지우", "nickname": "지우", "schoolGrade": 11, "school": { "name": "한영고등학교", "region": "서울" } }, "academyClass": { "id": "demo-class-01", "name": "고2 심화 A반", "schedule": null, "studentCount": 9 }, "requestedAt": "@T-20d@", "approvedAt": "@T-19d@" },
        { "id": "demo-membership-12", "student": { "id": "demo-student-12", "name": "이도윤", "nickname": null, "schoolGrade": 10, "school": { "name": "배명고등학교", "region": "서울" } }, "academyClass": { "id": "demo-class-02", "name": "고1 기본 B반", "schedule": null, "studentCount": 7 }, "requestedAt": "@T-18d@", "approvedAt": "@T-18d@" },
        { "id": "demo-membership-13", "student": { "id": "demo-student-13", "name": "김민준", "nickname": "수학왕", "schoolGrade": 11, "school": { "name": "잠실고등학교", "region": "서울" } }, "academyClass": null, "requestedAt": "@T-14d@", "approvedAt": "@T-13d@" }
      ],
      "page": 1, "pageSize": 20, "total": 18, "totalPages": 1
    }
    """#

    static let teacherStudentEmptyPage = #"""
    {
      "academy": { "id": "demo-academy-01", "name": "매쓰온 수학학원", "status": "ACTIVE" },
      "classes": [{ "id": "demo-class-01", "name": "고2 심화 A반", "schedule": null, "studentCount": 0 }],
      "students": [], "page": 1, "pageSize": 20, "total": 0, "totalPages": 1
    }
    """#

    static let teacherStudentDetail = #"""
    {
      "academy": { "id": "demo-academy-01", "name": "매쓰온 수학학원", "status": "ACTIVE" },
      "membership": { "id": "demo-membership-11", "student": { "id": "demo-student-11", "name": "서지우", "nickname": "지우", "schoolGrade": 11, "school": { "name": "한영고등학교", "region": "서울" } }, "academyClass": { "id": "demo-class-01", "name": "고2 심화 A반", "schedule": null, "studentCount": 9 }, "requestedAt": "@T-20d@", "approvedAt": "@T-19d@" },
      "statistics": {
        "period": { "key": "2026-09", "label": "2026년 9월 (이번 달)", "isCurrent": true, "options": [{ "key": "2026-09", "label": "2026년 9월 (이번 달)" }, { "key": "2026-08", "label": "2026년 8월 (지난달)" }] },
        "hasActivity": true,
        "cards": [
          { "label": "학습일", "value": "12일", "detail": "의미 있는 월간 학습일" },
          { "label": "완료 개념", "value": "8개", "detail": "기간 안에 완료 처리" },
          { "label": "문제 풀이", "value": "84개", "detail": "중복을 제외한 문제 수" },
          { "label": "첫 시도 정답률", "value": "76%", "detail": "첫 제출 68문제 기준" },
          { "label": "오답 복습률", "value": "82%", "detail": "새 오답 17문제 기준" },
          { "label": "재도전 성공률", "value": "71%", "detail": "재도전 14문제 기준" },
          { "label": "학습 건강도", "value": "81점", "detail": "안정 · 데이터 신뢰도 88%" }
        ],
        "summary": { "bullets": [
          { "label": "학습 참여", "text": "이번 달 12일 학습해 꾸준한 흐름을 유지하고 있습니다." },
          { "label": "강점", "text": "함수의 극한에서 첫 시도 정답률과 풀이 안정성이 높습니다." },
          { "label": "다음 지도", "text": "미분계수의 정의를 우선 복습한 뒤 관련 유형을 다시 풀어보는 것이 좋습니다." }
        ] }
      },
      "mathMap": {
        "graphVersion": "kr-2022-math-graph-v1.0", "modelVersion": "v1.0", "overallMastery": 72,
        "analyzedConceptCount": 6, "unknownConceptCount": 2,
        "topStrength": { "id": "limit-basics", "title": "함수의 극한", "courseTitle": "미적분", "unitTitle": "함수의 극한과 연속", "mastery": 91, "status": "MASTERED", "statusLabel": "숙달", "confidenceLabel": "높음", "evidence": { "attemptCount": 12, "correctCount": 11, "retryAttemptedCount": 1, "retryRecoveredCount": 1, "averageResponseTimeMs": 54000, "lastStudiedAt": "@T-1d@" } },
        "topPriority": { "id": "derivative-definition", "title": "미분계수의 정의", "courseTitle": "미적분", "unitTitle": "미분", "mastery": 43, "status": "WEAK", "statusLabel": "보완 필요", "confidenceLabel": "보통", "evidence": { "attemptCount": 9, "correctCount": 4, "retryAttemptedCount": 3, "retryRecoveredCount": 1, "averageResponseTimeMs": 88000, "lastStudiedAt": "@T-2d@" } },
        "bottlenecks": [{ "conceptId": "derivative-definition", "conceptTitle": "미분계수의 정의", "affectedConceptCount": 4 }],
        "concepts": [
          { "id": "derivative-definition", "title": "미분계수의 정의", "courseTitle": "미적분", "unitTitle": "미분", "mastery": 43, "status": "WEAK", "statusLabel": "보완 필요", "confidenceLabel": "보통", "evidence": { "attemptCount": 9, "correctCount": 4, "retryAttemptedCount": 3, "retryRecoveredCount": 1, "averageResponseTimeMs": 88000, "lastStudiedAt": "@T-2d@" } },
          { "id": "continuity", "title": "함수의 연속", "courseTitle": "미적분", "unitTitle": "함수의 극한과 연속", "mastery": 66, "status": "DEVELOPING", "statusLabel": "성장 중", "confidenceLabel": "보통", "evidence": { "attemptCount": 8, "correctCount": 5, "retryAttemptedCount": 2, "retryRecoveredCount": 1, "averageResponseTimeMs": 67000, "lastStudiedAt": "@T-3d@" } },
          { "id": "limit-basics", "title": "함수의 극한", "courseTitle": "미적분", "unitTitle": "함수의 극한과 연속", "mastery": 91, "status": "MASTERED", "statusLabel": "숙달", "confidenceLabel": "높음", "evidence": { "attemptCount": 12, "correctCount": 11, "retryAttemptedCount": 1, "retryRecoveredCount": 1, "averageResponseTimeMs": 54000, "lastStudiedAt": "@T-1d@" } }
        ]
      }
    }
    """#

    static let teacherAttendanceRoster = #"""
    {
      "dateKey": "@D+0@",
      "todayKey": "@D+0@",
      "classes": [
        { "id": "demo-class-01", "name": "고2 심화 A반", "schedule": { "weekdays": [2,4], "startTime": "18:30", "endTime": "20:30", "effectiveFrom": "2026-03-02", "timezone": "Asia/Seoul" }, "studentCount": 9 },
        { "id": "demo-class-02", "name": "고1 기본 B반", "schedule": { "weekdays": [1,3], "startTime": "17:00", "endTime": "19:00", "effectiveFrom": "2026-03-02", "timezone": "Asia/Seoul" }, "studentCount": 7 }
      ],
      "selectedClass": { "id": "demo-class-01", "name": "고2 심화 A반", "schedule": { "weekdays": [2,4], "startTime": "18:30", "endTime": "20:30", "effectiveFrom": "2026-03-02", "timezone": "Asia/Seoul" }, "studentCount": 9 },
      "session": {
        "id": "demo-session-01", "dateKey": "@D+0@",
        "startsAt": "@T-30m@", "endsAt": "@T+90m@",
        "checkInOpensAt": "@T-45m@", "lateAfterAt": "@T+0m@", "checkInClosesAt": "@T+45m@",
        "attendanceMode": "SELF_CODE", "state": "OPEN", "isLateWindow": true,
        "codeVersion": 3, "code": "824159"
      },
      "roster": [
        { "id": "demo-attendance-01", "student": { "id": "demo-student-11", "name": "서지우", "nickname": "지우", "schoolGrade": 11, "school": { "name": "한영고등학교", "region": "서울" } }, "attendance": { "status": "PRESENT", "checkedInAt": "@T-15m@", "source": "SELF_CODE", "note": "" } },
        { "id": "demo-attendance-02", "student": { "id": "demo-student-12", "name": "이도윤", "nickname": null, "schoolGrade": 11, "school": { "name": "배명고등학교", "region": "서울" } }, "attendance": { "status": "LATE", "checkedInAt": "@T+5m@", "source": "MANUAL", "note": "버스 지연" } },
        { "id": "demo-attendance-03", "student": { "id": "demo-student-13", "name": "김민준", "nickname": "수학왕", "schoolGrade": 11, "school": { "name": "잠실고등학교", "region": "서울" } }, "attendance": null },
        { "id": "demo-attendance-04", "student": { "id": "demo-student-14", "name": "박서연", "nickname": null, "schoolGrade": 11, "school": { "name": "정신여자고등학교", "region": "서울" } }, "attendance": { "status": "EXCUSED", "checkedInAt": null, "source": "MANUAL", "note": "학교 행사" } }
      ],
      "counts": { "TOTAL": 4, "PRESENT": 1, "LATE": 1, "ABSENT": 0, "EXCUSED": 1, "UNRECORDED": 1 },
      "truncated": false
    }
    """#

    static let teacherAttendanceSession = #"""
    {
      "session": {
        "id": "demo-session-01", "dateKey": "@D+0@",
        "startsAt": "@T-30m@", "endsAt": "@T+90m@",
        "checkInOpensAt": "@T-45m@", "lateAfterAt": "@T+0m@", "checkInClosesAt": "@T+45m@",
        "attendanceMode": "SELF_CODE", "state": "OPEN", "isLateWindow": true,
        "codeVersion": 4, "code": "519482"
      }
    }
    """#

    static let teacherAttendanceEmpty = #"""
    {
      "dateKey": "@D+0@",
      "todayKey": "@D+0@",
      "classes": [
        { "id": "demo-class-02", "name": "고1 기본 B반", "schedule": { "weekdays": [1,3], "startTime": "17:00", "endTime": "19:00", "effectiveFrom": "2026-03-02", "timezone": "Asia/Seoul" }, "studentCount": 0 }
      ],
      "selectedClass": { "id": "demo-class-02", "name": "고1 기본 B반", "schedule": { "weekdays": [1,3], "startTime": "17:00", "endTime": "19:00", "effectiveFrom": "2026-03-02", "timezone": "Asia/Seoul" }, "studentCount": 0 },
      "session": null,
      "roster": [],
      "counts": { "TOTAL": 0, "PRESENT": 0, "LATE": 0, "ABSENT": 0, "EXCUSED": 0, "UNRECORDED": 0 },
      "truncated": false
    }
    """#

    static let teacherClasswork = #"""
    {
      "academyClass": {
        "id": "demo-class-01",
        "name": "고2 심화 A반",
        "schedule": { "weekdays": [2,4], "startTime": "18:30", "endTime": "20:30", "effectiveFrom": "2026-03-02", "timezone": "Asia/Seoul" },
        "studentCount": 9
      },
      "currentAcademicYear": 2026,
      "weeks": [
        {
          "id": "demo-week-34",
          "academicYear": 2026,
          "weekNumber": 34,
          "title": "지수함수와 로그함수의 그래프",
          "lessonSummary": "그래프의 평행이동과 대칭을 이용해 식과 그래프를 연결했습니다.",
          "concepts": [
            { "curriculumId": "kr-2022", "courseId": "algebra", "courseTitle": "대수", "unitId": "exponential-logarithmic-functions", "unitTitle": "지수함수와 로그함수", "conceptId": "exponential-logarithmic-graphs", "conceptTitle": "지수함수와 로그함수의 그래프", "href": "/learn/algebra/exponential-logarithmic-functions/exponential-logarithmic-graphs" }
          ],
          "assignmentTitle": "그래프 변환 필수 12문제",
          "assignmentInstructions": "1~12번을 풀고 틀린 문항은 오답노트에 저장하세요.",
          "dueAt": "@T+2d@",
          "files": [
            { "id": "demo-file-01", "originalName": "34주차-그래프-과제.pdf", "mimeType": "application/pdf", "sizeBytes": 428032 }
          ]
        },
        {
          "id": "demo-week-33",
          "academicYear": 2026,
          "weekNumber": 33,
          "title": "지수와 로그",
          "lessonSummary": "지수법칙과 로그의 성질을 문제에 적용했습니다.",
          "concepts": [
            { "curriculumId": "kr-2022", "courseId": "algebra", "courseTitle": "대수", "unitId": "exponential-logarithmic-functions", "unitTitle": "지수함수와 로그함수", "conceptId": "logarithms", "conceptTitle": "로그", "href": "/learn/algebra/exponential-logarithmic-functions/logarithms" }
          ],
          "assignmentTitle": "로그 계산 복습",
          "assignmentInstructions": "풀이 과정에 사용한 로그의 성질을 표시하세요.",
          "dueAt": null,
          "files": []
        }
      ],
      "catalog": [
        {
          "id": "algebra",
          "title": "대수",
          "units": [
            {
              "id": "exponential-logarithmic-functions",
              "title": "지수함수와 로그함수",
              "concepts": [
                { "key": "algebra|exponential-logarithmic-functions|exponential-logarithmic-graphs", "curriculumId": "kr-2022", "courseId": "algebra", "courseTitle": "대수", "unitId": "exponential-logarithmic-functions", "unitTitle": "지수함수와 로그함수", "conceptId": "exponential-logarithmic-graphs", "conceptTitle": "지수함수와 로그함수의 그래프" },
                { "key": "algebra|exponential-logarithmic-functions|logarithms", "curriculumId": "kr-2022", "courseId": "algebra", "courseTitle": "대수", "unitId": "exponential-logarithmic-functions", "unitTitle": "지수함수와 로그함수", "conceptId": "logarithms", "conceptTitle": "로그" }
              ]
            }
          ]
        },
        {
          "id": "calculus",
          "title": "미적분",
          "units": [
            {
              "id": "derivatives",
              "title": "미분법",
              "concepts": [
                { "key": "calculus|derivatives|applications", "curriculumId": "kr-2022", "courseId": "calculus", "courseTitle": "미적분", "unitId": "derivatives", "unitTitle": "미분법", "conceptId": "applications", "conceptTitle": "도함수의 활용" }
              ]
            }
          ]
        }
      ]
    }
    """#

    static let adminAcademyDashboard = #"""
    {
      "pendingCount": 2,
      "activeCount": 14,
      "applications": [
        {
          "id": "demo-academy-pending-01",
          "name": "정진 수학학원",
          "status": "PENDING",
          "createdAt": "@T-3h@",
          "contractStartsAt": "@T-5d@",
          "contractEndsAt": "@T+90d@",
          "includesMockExam": true,
          "applicant": {
            "id": "demo-owner-01",
            "name": "김정진",
            "email": "owner-one@matths.kr",
            "accountStatus": "active"
          }
        },
        {
          "id": "demo-academy-pending-02",
          "name": "한결 고등수학",
          "status": "PENDING",
          "createdAt": "@T-45m@",
          "contractStartsAt": "@T-1d@",
          "contractEndsAt": "@T+120d@",
          "includesMockExam": true,
          "applicant": {
            "id": "demo-owner-02",
            "name": "박한결",
            "email": "owner-two@matths.kr",
            "accountStatus": "active"
          }
        }
      ]
    }
    """#

    static let adminAcademyList = #"""
    {
      "academies": [
        {
          "id": "demo-academy-active-01",
          "name": "정진 수학학원",
          "status": "ACTIVE",
          "createdAt": "@T-140d@",
          "contractStartsAt": "@T-120d@",
          "contractEndsAt": "@T+245d@",
          "includesMockExam": true,
          "applicant": {
            "id": "demo-owner-01",
            "name": "김정진",
            "email": "owner-one@matths.kr",
            "accountStatus": "active"
          },
          "profileImageURL": null,
          "planCode": "ACADEMY_PRO",
          "counts": {
            "activeStaff": 4,
            "pendingStaff": 1,
            "approvedStudents": 37,
            "pendingStudents": 2,
            "activeClasses": 5
          }
        },
        {
          "id": "demo-academy-active-02",
          "name": "한결 고등수학",
          "status": "ACTIVE",
          "createdAt": "@T-80d@",
          "contractStartsAt": "@T-75d@",
          "contractEndsAt": "@T+290d@",
          "includesMockExam": true,
          "applicant": {
            "id": "demo-owner-02",
            "name": "박한결",
            "email": "owner-two@matths.kr",
            "accountStatus": "active"
          },
          "profileImageURL": null,
          "planCode": "ACADEMY_STANDARD",
          "counts": {
            "activeStaff": 2,
            "pendingStaff": 0,
            "approvedStudents": 21,
            "pendingStudents": 0,
            "activeClasses": 3
          }
        },
        {
          "id": "demo-academy-paused-01",
          "name": "수림 수학연구소",
          "status": "PAUSED",
          "createdAt": "@T-260d@",
          "contractStartsAt": "@T-250d@",
          "contractEndsAt": "@T-12d@",
          "includesMockExam": false,
          "applicant": null,
          "profileImageURL": null,
          "planCode": null,
          "counts": {
            "activeStaff": 1,
            "pendingStaff": 0,
            "approvedStudents": 8,
            "pendingStudents": 0,
            "activeClasses": 1
          }
        }
      ],
      "filters": { "search": "", "status": "ALL" },
      "pagination": { "page": 1, "pageSize": 20, "total": 3, "totalPages": 1 },
      "statusCounts": { "ACTIVE": 14, "PENDING": 2, "PAUSED": 1, "REJECTED": 1 }
    }
    """#

    static let adminAcademyListEmpty = #"""
    {
      "academies": [],
      "filters": { "search": "없는 학원", "status": "ALL" },
      "pagination": { "page": 1, "pageSize": 20, "total": 0, "totalPages": 1 },
      "statusCounts": { "ACTIVE": 14, "PENDING": 2, "PAUSED": 1, "REJECTED": 1 }
    }
    """#

    static let adminAcademyDetail = #"""
    {
      "academy": {
        "id": "demo-academy-active-01",
        "name": "정진 수학학원",
        "status": "ACTIVE",
        "createdAt": "@T-140d@",
        "contractStartsAt": "@T-120d@",
        "contractEndsAt": "@T+245d@",
        "includesMockExam": true,
        "applicant": {
          "id": "demo-owner-01",
          "name": "김정진",
          "email": "owner-one@matths.kr",
          "accountStatus": "active"
        },
        "profileImageURL": null,
        "planCode": "ACADEMY_PRO"
      },
      "counts": {
        "activeStaff": 4,
        "pendingStaff": 1,
        "approvedStudents": 37,
        "pendingStudents": 2,
        "activeClasses": 5,
        "activeInvites": 2
      },
      "staff": [
        {
          "id": "demo-staff-owner",
          "user": { "id": "demo-owner-01", "name": "김정진", "email": "owner-one@matths.kr" },
          "role": "OWNER",
          "status": "ACTIVE",
          "requestedAt": "@T-140d@",
          "joinedAt": "@T-138d@"
        },
        {
          "id": "demo-staff-teacher",
          "user": { "id": "demo-teacher-02", "name": "이상윤", "email": "teacher-demo@matths.kr" },
          "role": "TEACHER",
          "status": "ACTIVE",
          "requestedAt": "@T-40d@",
          "joinedAt": "@T-39d@"
        },
        {
          "id": "demo-staff-pending",
          "user": { "id": "demo-teacher-03", "name": "최민서", "email": "minseo@matths.kr" },
          "role": "TEACHER",
          "status": "PENDING",
          "requestedAt": "@T-2d@",
          "joinedAt": null
        }
      ],
      "students": [
        {
          "id": "demo-membership-01",
          "student": { "id": "demo-student-01", "name": "서지우", "nickname": "지우", "schoolGrade": 11, "school": { "name": "한영고등학교", "region": "서울" } },
          "academyClass": { "id": "demo-class-a", "name": "고2 심화 A", "isActive": true },
          "status": "APPROVED",
          "requestedAt": "@T-30d@",
          "approvedAt": "@T-29d@"
        },
        {
          "id": "demo-membership-02",
          "student": { "id": "demo-student-02", "name": "한도윤", "nickname": null, "schoolGrade": 10, "school": { "name": "잠실고등학교", "region": "서울" } },
          "academyClass": null,
          "status": "PENDING",
          "requestedAt": "@T-4h@",
          "approvedAt": null
        }
      ],
      "classes": [
        {
          "id": "demo-class-a",
          "name": "고2 심화 A",
          "schedule": { "weekdays": [2, 4], "startTime": "18:30", "endTime": "21:30", "effectiveFrom": "@D-30@", "timezone": "Asia/Seoul" },
          "attendancePolicy": { "mode": "SELF_CODE", "opensBeforeMinutes": 15, "lateAfterMinutes": 10, "closesAfterMinutes": 30 },
          "isActive": true,
          "homeroomTeacher": { "id": "demo-teacher-02", "name": "이상윤", "email": "teacher-demo@matths.kr" },
          "coTeachers": [],
          "teacherHistory": [
            { "id": "demo-history-01", "previousTeacher": { "id": "demo-owner-01", "name": "김정진", "email": "owner-one@matths.kr" }, "nextTeacher": { "id": "demo-teacher-02", "name": "이상윤", "email": "teacher-demo@matths.kr" }, "changedBy": { "id": "demo-admin", "name": "운영자", "email": "admin@matths.kr" }, "changedAt": "@T-35d@" }
          ],
          "lifecycleHistory": []
        },
        {
          "id": "demo-class-b",
          "name": "고3 수능 집중",
          "schedule": null,
          "attendancePolicy": null,
          "isActive": true,
          "homeroomTeacher": { "id": "demo-owner-01", "name": "김정진", "email": "owner-one@matths.kr" },
          "coTeachers": []
        }
      ],
      "classWeeks": [
        {
          "id": "demo-admin-week-01",
          "academicYear": 2026,
          "weekNumber": 35,
          "title": "미분 활용 종합",
          "lessonSummary": "증가·감소와 극대·극소 조건을 그래프 해석과 연결했습니다.",
          "concepts": [
            { "curriculumId": "2022", "courseId": "calculus", "courseTitle": "미적분", "unitId": "derivative", "unitTitle": "미분", "conceptId": "derivative-application", "conceptTitle": "도함수의 활용", "href": null }
          ],
          "assignmentTitle": "도함수 활용 복습",
          "assignmentInstructions": "첨부 문제를 풀고 틀린 문항에 오답 원인을 적으세요.",
          "dueAt": "@T+4d@",
          "files": [
            { "id": "demo-admin-file-01", "originalName": "35주차-도함수-활용.pdf", "mimeType": "application/pdf", "sizeBytes": 245760 }
          ],
          "academyClass": { "id": "demo-class-a", "name": "고2 심화 A", "isActive": true },
          "status": "PUBLISHED",
          "createdBy": { "id": "demo-teacher-02", "name": "이상윤", "email": "teacher-demo@matths.kr" },
          "updatedBy": { "id": "demo-teacher-02", "name": "이상윤", "email": "teacher-demo@matths.kr" },
          "createdAt": "@T-4d@",
          "updatedAt": "@T-2d@"
        }
      ],
      "invites": [
        { "id": "demo-invite-01", "label": "고2 A반 9월 모집", "code": "JJA2026", "token": "demo-invite-token-01", "status": "ACTIVE", "academyClass": { "id": "demo-class-a", "name": "고2 심화 A", "isActive": true }, "displayState": "ACTIVE", "useCount": 7, "maxUses": 30, "expiresAt": "@T+12d@", "createdBy": { "id": "demo-owner-01", "name": "김정진", "email": "owner-one@matths.kr" }, "createdAt": "@T-14d@" },
        { "id": "demo-invite-02", "label": "전체 학생 초대", "code": "MATH37", "academyClass": null, "displayState": "ACTIVE", "useCount": 3, "maxUses": 50, "expiresAt": "@T+28d@" }
      ],
      "attendanceSessions": [
        { "id": "demo-session-01", "academyClass": { "id": "demo-class-a", "name": "고2 심화 A", "isActive": true }, "dateKey": "@D+0@", "startsAt": "@T+2h@", "attendanceMode": "SELF_CODE", "state": "OPEN", "code": "4821" },
        { "id": "demo-session-02", "academyClass": { "id": "demo-class-b", "name": "고3 수능 집중", "isActive": true }, "dateKey": "@D-1@", "startsAt": "@T-22h@", "attendanceMode": "TEACHER_ONLY", "state": "CLOSED", "code": null }
      ],
      "analytics": {
        "academy": { "id": "demo-academy-active-01", "name": "정진 수학학원", "status": "ACTIVE", "profileImageURL": null },
        "scope": { "type": "ACADEMY", "academyClass": null },
        "period": { "key": "2026-09", "label": "2026년 9월", "isCurrent": true, "options": [{ "key": "2026-09", "label": "2026년 9월" }, { "key": "2026-08", "label": "2026년 8월" }] },
        "hasActivity": true,
        "cards": [
          { "label": "학습 건강도", "value": "76점", "detail": "관찰 · 데이터 반영 84%" },
          { "label": "학습 참여 학생", "value": "31명", "detail": "84% 참여" },
          { "label": "평균 학습일", "value": "4.8일", "detail": "학생 1인당 · 미학습 포함" },
          { "label": "오답 복습률", "value": "68%", "detail": "전체 오답 기준" }
        ],
        "values": { "totalStudents": 37, "activeStudents": 31, "participationRate": 84, "averageLearningDays": 4.8, "averageCompletedConcepts": 6.2, "averageUniqueProblems": 42.1, "firstAttemptAccuracy": 71, "wrongAnswerReviewRate": 68, "retrySuccessRate": 63 },
        "health": { "score": 76, "key": "WATCH", "label": "관찰", "dataCoverage": 84, "targetLearningDays": 8, "distribution": { "healthy": 21, "watch": 10, "risk": 6 }, "components": { "engagement": 78, "accuracy": 74, "review": 68, "recovery": 63 } },
        "growth": [],
        "summary": [{ "label": "참여", "text": "승인 학생 37명 중 31명이 학습했습니다." }],
        "attentionStudents": [{ "membership": { "id": "demo-membership-02", "student": { "id": "demo-student-02", "name": "한도윤", "nickname": null, "schoolGrade": 10, "school": { "name": "잠실고등학교", "region": "서울" } }, "academyClass": null, "requestedAt": "@T-4h@", "approvedAt": null }, "reasons": ["선택 기간 학습 기록 없음"], "priority": 100 }],
        "mathMap": { "graphVersion": "2026.08", "modelVersion": "rule-v2", "overallMastery": 72.4, "analyzedConceptCount": 18, "totalStudents": 37, "heatmap": [{ "conceptId": "derivative-application", "conceptTitle": "도함수의 활용", "courseTitle": "미적분", "unitTitle": "미분", "mastery": 61.2, "analyzedCount": 24, "totalStudents": 37, "status": "DEVELOPING", "statusLabel": "성장 중" }], "bottlenecks": [], "recommendation": { "conceptId": "derivative-application", "conceptTitle": "도함수의 활용", "mastery": 61.2, "reason": "보완 필요 학생 비율이 높습니다.", "problemCount": 5 } }
      }
    }
    """#

    static let coachSuggestionBoard = #"""
    {
      "board": {
        "isAdmin": false,
        "approved": [
          { "id": "demo-coach-approved-01", "authorName": "수학왕", "mode": "mild", "situation": "incorrect", "message": "틀린 자리가 오늘 가장 많이 배우는 자리야.", "status": "approved", "rejectionReason": "", "createdAt": "@T-5d@", "moderatedAt": "@T-4d@" },
          { "id": "demo-coach-approved-02", "authorName": "지우", "mode": "silent", "situation": "study_prompt", "message": "딱 한 문제부터 시작하자.", "status": "approved", "rejectionReason": "", "createdAt": "@T-8d@", "moderatedAt": "@T-7d@" }
        ],
        "mine": [
          { "id": "demo-coach-mine-01", "authorName": "지우", "mode": "spicy", "situation": "unanswered", "message": "빈칸은 점수가 아니라 다음 행동을 알려준다.", "status": "pending", "rejectionReason": "", "createdAt": "@T-2h@", "moderatedAt": null },
          { "id": "demo-coach-mine-02", "authorName": "지우", "mode": "mild", "situation": "correct", "message": "이번 정답은 우연이 아니라 네가 쌓아온 결과야.", "status": "approved", "rejectionReason": "", "createdAt": "@T-9d@", "moderatedAt": "@T-8d@" }
        ],
        "pending": []
      }
    }
    """#

    static let coachSuggestionBoardAdmin = #"""
    {
      "board": {
        "isAdmin": true,
        "approved": [
          { "id": "demo-coach-approved-01", "authorName": "수학왕", "mode": "mild", "situation": "incorrect", "message": "틀린 자리가 오늘 가장 많이 배우는 자리야.", "status": "approved", "rejectionReason": "", "createdAt": "@T-5d@", "moderatedAt": "@T-4d@" }
        ],
        "mine": [],
        "pending": [
          { "id": "demo-coach-pending-01", "authorName": "민준", "mode": "spicy", "situation": "unanswered", "message": "모르는 문제를 비워두는 것보다 한 줄이라도 시작해.", "status": "pending", "rejectionReason": "", "createdAt": "@T-3h@", "moderatedAt": null },
          { "id": "demo-coach-pending-02", "authorName": "서연", "mode": "mild", "situation": "correct", "message": "방금 푼 방식, 다음 문제에서도 다시 꺼내 쓸 수 있어.", "status": "pending", "rejectionReason": "", "createdAt": "@T-40m@", "moderatedAt": null }
        ]
      }
    }
    """#

    static let coachSuggestionMutation = #"""
    {
      "suggestion": {
        "id": "demo-coach-mutation-01", "authorName": "지우", "mode": "mild",
        "situation": "study_prompt", "message": "딱 한 문제부터 시작하자.",
        "status": "pending", "rejectionReason": "", "createdAt": "@T+0s@", "moderatedAt": null
      }
    }
    """#

    static let supportDashboard = #"""
    {
      "contact": {
        "nickname": "지우",
        "realName": "김지우",
        "email": "demo@matths.kr"
      },
      "inquiries": [
        {
          "id": "demo-support-01",
          "subject": "가로 화면에서 풀이 메모가 저장되지 않아요",
          "status": "in_review",
          "notificationStatus": "sent",
          "createdAt": "@T-3h@",
          "repliedAt": null
        },
        {
          "id": "demo-support-02",
          "subject": "학원 초대 코드를 다시 확인하고 싶어요",
          "status": "replied",
          "notificationStatus": "sent",
          "createdAt": "@T-4d@",
          "repliedAt": "@T-3d@"
        }
      ],
      "submission": null
    }
    """#

    static let supportSubmission = #"""
    {
      "contact": {
        "nickname": "지우",
        "realName": "김지우",
        "email": "demo@matths.kr"
      },
      "inquiries": [
        {
          "id": "demo-support-new",
          "subject": "새로 접수한 문의",
          "status": "pending",
          "notificationStatus": "sent",
          "createdAt": "@T+0s@",
          "repliedAt": null
        },
        {
          "id": "demo-support-01",
          "subject": "가로 화면에서 풀이 메모가 저장되지 않아요",
          "status": "in_review",
          "notificationStatus": "sent",
          "createdAt": "@T-3h@",
          "repliedAt": null
        }
      ],
      "submission": {
        "emailStatus": "sent",
        "emailDelivered": true
      }
    }
    """#

    static let archiveDashboard = #"""
    {
      "archive": {
        "isAdmin": false,
        "folders": [
          {
            "id": "demo-archive-folder-free",
            "parentFolderId": null,
            "name": "학교 시험 대비",
            "description": "내신 기출과 단원별 정리",
            "isPinned": true,
            "itemCount": 12,
            "isLocked": false,
            "requiredAccessLevel": "AUTHENTICATED"
          },
          {
            "id": "demo-archive-folder-paid",
            "parentFolderId": null,
            "name": "주간 모의고사 해설",
            "description": "이용권 회원 전용 해설 자료",
            "isPinned": false,
            "itemCount": 8,
            "isLocked": true,
            "requiredAccessLevel": "MOCK_EXAM_PACKAGE"
          }
        ],
        "selectedFolder": null,
        "breadcrumbs": [],
        "items": [
          {
            "id": "demo-archive-item-root",
            "folderId": null,
            "title": "9월 학습 계획표",
            "description": "한 달 학습 순서를 한눈에 확인합니다.",
            "category": "개념 자료",
            "originalName": "9월-학습-계획표.pdf",
            "mimeType": "application/pdf",
            "sizeBytes": 842311,
            "downloadCount": 31,
            "createdAt": "@T-2d@"
          }
        ]
      }
    }
    """#

    static let archiveFolderDashboard = #"""
    {
      "archive": {
        "isAdmin": false,
        "folders": [],
        "selectedFolder": {
          "id": "demo-archive-folder-free",
          "parentFolderId": null,
          "name": "학교 시험 대비",
          "description": "내신 기출과 단원별 정리",
          "isPinned": true,
          "itemCount": 12,
          "isLocked": false,
          "requiredAccessLevel": "AUTHENTICATED"
        },
        "breadcrumbs": [
          { "id": "demo-archive-folder-free", "name": "학교 시험 대비" }
        ],
        "items": [
          {
            "id": "demo-archive-item-midterm",
            "folderId": "demo-archive-folder-free",
            "title": "2학기 중간고사 함수 집중 문제",
            "description": "함수의 극한부터 미분까지 20문항",
            "category": "문제지",
            "originalName": "중간고사-함수-20문항.pdf",
            "mimeType": "application/pdf",
            "sizeBytes": 1942310,
            "downloadCount": 86,
            "createdAt": "@T-1d@"
          },
          {
            "id": "demo-archive-item-solution",
            "folderId": "demo-archive-folder-free",
            "title": "함수 집중 문제 해설",
            "description": "핵심 발상과 오답 포인트",
            "category": "해설",
            "originalName": "중간고사-함수-해설.pdf",
            "mimeType": "application/pdf",
            "sizeBytes": 2519012,
            "downloadCount": 54,
            "createdAt": "@T-1d@"
          }
        ]
      }
    }
    """#

    // MARK: - 오답노트 (서버 동기화 내려받기)
    //
    // 선다형/주관식, 복습 전(pending)·예약(scheduled)·완료(completed), 오답 횟수 1~5회를
    // 섞는다. 한 종류만 있으면 목록 셀의 뱃지·상태 색이 검토되지 않는다.

    static let wrongNotes = #"""
    {
      "entries": [
        {
          "attemptId": "demo-wrong-01",
          "clientAttemptId": "demo-client-01",
          "statement": "함수 $f(x)=x^3-3x^2+4$ 의 극댓값과 극솟값의 합을 구하시오.",
          "answer": "4",
          "steps": [
            "$f'(x)=3x^2-6x=3x(x-2)$ 로 인수분해한다.",
            "$f'(x)=0$ 이 되는 $x=0$ 과 $x=2$ 에서 증감이 바뀐다.",
            "$f(0)=4$ 가 극댓값, $f(2)=0$ 이 극솟값이다.",
            "따라서 두 값의 합은 $4+0=4$ 이다."
          ],
          "typeKey": "extremum",
          "seed": "1837",
          "myAnswer": "8",
          "divergenceStep": 3,
          "errorType": "계산 실수",
          "srsStage": 1,
          "wrongCount": 2,
          "nextReviewAt": "@T+1d@",
          "reviewStatus": "scheduled",
          "createdAt": "@T-3d@",
          "updatedAt": "@T-1d@",
          "isTex": true
        },
        {
          "attemptId": "demo-wrong-02",
          "clientAttemptId": "demo-client-02",
          "statement": "$\\log_2 (x-1)+\\log_2 (x+3)=5$ 를 만족시키는 $x$ 의 값은?",
          "answer": "b",
          "steps": [
            "진수 조건에서 $x>1$ 이어야 한다.",
            "$\\log_2 (x-1)(x+3)=5$ 이므로 $(x-1)(x+3)=32$ 이다.",
            "$x^2+2x-35=0$ 에서 $x=5$ 또는 $x=-7$ 이다.",
            "진수 조건을 만족하는 값은 $x=5$ 뿐이다."
          ],
          "typeKey": "logEq",
          "seed": "2044",
          "myAnswer": "d",
          "divergenceStep": 1,
          "errorType": "조건 누락",
          "srsStage": 0,
          "wrongCount": 4,
          "nextReviewAt": null,
          "reviewStatus": "pending",
          "createdAt": "@T-2d@",
          "updatedAt": "@T-2d@",
          "choices": ["3", "5", "7", "-7", "9"],
          "isTex": true
        },
        {
          "attemptId": "demo-wrong-03",
          "clientAttemptId": "demo-client-03",
          "statement": "서로 다른 6개의 공을 3개의 상자에 남김없이 나누어 넣는 경우의 수를 구하시오. (빈 상자를 허용한다)",
          "answer": "729",
          "steps": [
            "각 공이 들어갈 상자를 독립적으로 고른다.",
            "공 하나마다 상자 3가지 선택이 있다.",
            "따라서 $3^6=729$ 가지이다."
          ],
          "typeKey": "counting",
          "seed": "913",
          "myAnswer": "90",
          "divergenceStep": 1,
          "errorType": "개념 혼동",
          "srsStage": 3,
          "wrongCount": 1,
          "nextReviewAt": "@T+4d@",
          "reviewStatus": "scheduled",
          "createdAt": "@T-9d@",
          "updatedAt": "@T-2d@",
          "isTex": false
        },
        {
          "attemptId": "demo-wrong-04",
          "clientAttemptId": "demo-client-04",
          "statement": "정적분 $\\int_{0}^{2}(3x^2-2x)dx$ 의 값을 구하시오.",
          "answer": "4",
          "steps": [
            "부정적분은 $x^3-x^2$ 이다.",
            "$[x^3-x^2]_0^2=(8-4)-0=4$ 이다."
          ],
          "typeKey": "integral",
          "seed": "556",
          "myAnswer": "12",
          "divergenceStep": 2,
          "errorType": "계산 실수",
          "srsStage": 5,
          "wrongCount": 5,
          "nextReviewAt": "@T-1d@",
          "reviewStatus": "pending",
          "createdAt": "@T-21d@",
          "updatedAt": "@T-6d@",
          "isTex": true
        },
        {
          "attemptId": "demo-wrong-05",
          "clientAttemptId": "demo-client-05",
          "statement": "등차수열에서 $a_3=7$, $a_7=19$ 일 때 $a_{15}$ 의 값은?",
          "answer": "c",
          "steps": [
            "공차는 $(19-7)/(7-3)=3$ 이다.",
            "$a_1=a_3-2d=1$ 이다.",
            "$a_{15}=1+14 \\times 3=43$ 이다."
          ],
          "typeKey": "sequence",
          "seed": "3312",
          "myAnswer": "a",
          "divergenceStep": 2,
          "errorType": "공식 오적용",
          "srsStage": 2,
          "wrongCount": 3,
          "nextReviewAt": "@T+2d@",
          "reviewStatus": "scheduled",
          "createdAt": "@T-13d@",
          "updatedAt": "@T-3d@",
          "choices": ["37", "40", "43", "46", "49"],
          "isTex": true
        },
        {
          "attemptId": "demo-wrong-06",
          "clientAttemptId": "demo-client-06",
          "statement": "원 $x^2+y^2=25$ 위의 점 $(3,4)$ 에서의 접선의 방정식을 구하시오.",
          "answer": "3x+4y=25",
          "steps": [
            "원 $x^2+y^2=r^2$ 위의 점에서의 접선은 $x_1 x+y_1 y=r^2$ 이다.",
            "따라서 $3x+4y=25$ 이다."
          ],
          "typeKey": "circleTangent",
          "seed": "77",
          "myAnswer": "4x+3y=25",
          "divergenceStep": 1,
          "errorType": "좌표 혼동",
          "srsStage": 4,
          "wrongCount": 1,
          "nextReviewAt": null,
          "reviewStatus": "completed",
          "createdAt": "@T-30d@",
          "updatedAt": "@T-5d@",
          "isTex": true
        },
        {
          "attemptId": "demo-wrong-07",
          "clientAttemptId": "demo-client-07",
          "statement": "확률변수 $X$ 가 이항분포 $B(100, 0.2)$ 를 따를 때 $V(X)$ 의 값을 구하시오.",
          "answer": "16",
          "steps": [
            "$V(X)=npq$ 이다.",
            "$100 \\times 0.2 \\times 0.8=16$ 이다."
          ],
          "typeKey": "binomial",
          "seed": "128",
          "myAnswer": "20",
          "divergenceStep": 1,
          "errorType": "공식 혼동",
          "srsStage": 0,
          "wrongCount": 2,
          "nextReviewAt": null,
          "reviewStatus": "pending",
          "createdAt": "@T-1d@",
          "updatedAt": "@T-1d@",
          "isTex": true
        },
        {
          "attemptId": "demo-wrong-08",
          "clientAttemptId": "demo-client-08",
          "statement": "$\\sin\\theta+\\cos\\theta=1/2$ 일 때 $\\sin\\theta\\cos\\theta$ 의 값을 구하시오.",
          "answer": "-3/8",
          "steps": [
            "양변을 제곱하면 $1+2\\sin\\theta\\cos\\theta=1/4$ 이다.",
            "$2\\sin\\theta\\cos\\theta=-3/4$ 이므로 답은 $-3/8$ 이다."
          ],
          "typeKey": "trig",
          "seed": "641",
          "myAnswer": "3/8",
          "divergenceStep": 2,
          "errorType": "부호 실수",
          "srsStage": 1,
          "wrongCount": 1,
          "nextReviewAt": "@T+3d@",
          "reviewStatus": "scheduled",
          "createdAt": "@T-6d@",
          "updatedAt": "@T-4d@",
          "isTex": true
        }
      ],
      "hasMore": false,
      "nextCursor": null
    }
    """#

    static let stuckPoints = #"""
    {
      "stuckPoints": [
        { "id": "demo-stuck-01", "text": "삼차함수 그래프에서 극값 개수를 판별식으로 세는 이유가 아직 헷갈립니다.", "createdAt": "@T-2d@" },
        { "id": "demo-stuck-02", "text": "로그 방정식에서 진수 조건을 언제 먼저 확인해야 하는지 모르겠어요.", "createdAt": "@T-5d@" },
        { "id": "demo-stuck-03", "text": "중복조합 H 기호가 나오면 항상 식을 잘못 세웁니다.", "createdAt": "@T-11d@" }
      ]
    }
    """#

    // MARK: - 배치고사

    static let placementStatus = #"""
    {
      "placement": {
        "status": "submitted",
        "attemptId": "demo-placement-01",
        "answeredCount": 20,
        "ctaLabel": "배치 결과 보기",
        "result": {
          "attemptId": "demo-placement-01",
          "status": "CONFIRMED",
          "totalCorrect": 14,
          "placementScore": 71.5,
          "initialMmr": 1240,
          "tierCode": "GOLD",
          "tierLabel": "골드",
          "rankPoint": 62,
          "rankingStatus": "PROVISIONAL",
          "percentile": 38.4,
          "verificationRequired": false,
          "presentationId": "demo-placement-presentation-01"
        },
        "presentation": {
          "id": "demo-placement-presentation-01",
          "kind": "PLACEMENT",
          "tierCode": "GOLD",
          "tierLabel": "골드"
        }
      }
    }
    """#

    static let placementAttempt = #"""
    {
      "attempt": {
        "id": "demo-placement-01",
        "phase": "exam",
        "status": "in-progress",
        "purpose": "PLACEMENT",
        "title": "입단 배치고사",
        "subtitle": "20문항 · 60분",
        "timeLimitMs": 3600000,
        "startedAt": "@T-12m@",
        "deadlineAt": "@T+48m@",
        "submittedAt": null,
        "elapsedTimeMs": 720000,
        "currentQuestionIndex": 2,
        "answeredCount": 2,
        "questionCount": 3,
        "questions": [
          {
            "id": "demo-placement-q1",
            "number": 1,
            "prompt": "다항식 $(x+2)(x^2-2x+4)$ 를 전개했을 때 $x^3$ 의 계수는?",
            "inputMode": "choice",
            "choices": [
              { "key": "a", "text": "1" },
              { "key": "b", "text": "2" },
              { "key": "c", "text": "4" },
              { "key": "d", "text": "6" },
              { "key": "e", "text": "8" }
            ],
            "points": 3.0,
            "submittedAnswer": "a",
            "responseTimeMs": 41000,
            "visitCount": 1
          },
          {
            "id": "demo-placement-q2",
            "number": 2,
            "prompt": "$2^{x}=5$ 일 때 $4^{x}$ 의 값을 구하시오.",
            "inputMode": "short",
            "choices": [],
            "points": 3.0,
            "submittedAnswer": "25",
            "responseTimeMs": 63000,
            "visitCount": 2
          },
          {
            "id": "demo-placement-q3",
            "number": 3,
            "prompt": "함수 $f(x)=x^3-6x^2+9x$ 의 극댓값을 구하시오.",
            "inputMode": "short",
            "choices": [],
            "points": 4.0,
            "submittedAnswer": "",
            "responseTimeMs": 0,
            "visitCount": 0
          }
        ],
        "result": null,
        "presentation": null
      }
    }
    """#

    static let placementDraft = #"""
    {
      "draft": {
        "savedAt": "@T+0s@",
        "elapsedTimeMs": 720000,
        "answeredCount": 2,
        "currentQuestionIndex": 2,
        "status": "in-progress",
        "expired": false
      }
    }
    """#

    static let placementSubmission = #"""
    {
      "attempt": {
        "id": "demo-placement-01",
        "phase": "result",
        "status": "submitted",
        "purpose": "PLACEMENT",
        "title": "입단 배치고사",
        "subtitle": "20문항 · 60분",
        "timeLimitMs": 3600000,
        "startedAt": "@T-58m@",
        "deadlineAt": "@T+2m@",
        "submittedAt": "@T+0s@",
        "elapsedTimeMs": 3480000,
        "currentQuestionIndex": 2,
        "answeredCount": 3,
        "questionCount": 3,
        "questions": [],
        "result": {
          "attemptId": "demo-placement-01",
          "status": "CONFIRMED",
          "totalCorrect": 14,
          "placementScore": 71.5,
          "initialMmr": 1240,
          "tierCode": "GOLD",
          "tierLabel": "골드",
          "rankPoint": 62,
          "rankingStatus": "PROVISIONAL",
          "percentile": 38.4,
          "verificationRequired": false,
          "presentationId": "demo-placement-presentation-01"
        },
        "presentation": {
          "id": "demo-placement-presentation-01",
          "kind": "PLACEMENT",
          "tierCode": "GOLD",
          "tierLabel": "골드"
        }
      },
      "result": {
        "attemptId": "demo-placement-01",
        "status": "CONFIRMED",
        "totalCorrect": 14,
        "placementScore": 71.5,
        "initialMmr": 1240,
        "tierCode": "GOLD",
        "tierLabel": "골드",
        "rankPoint": 62,
        "rankingStatus": "PROVISIONAL",
        "percentile": 38.4,
        "verificationRequired": false,
        "presentationId": "demo-placement-presentation-01"
      },
      "presentation": {
        "id": "demo-placement-presentation-01",
        "kind": "PLACEMENT",
        "tierCode": "GOLD",
        "tierLabel": "골드"
      }
    }
    """#

    // MARK: - 퀵 연습

    static func quickStart(pointValue: Int) -> String {
        let twoPoint = pointValue == 2
        let prompt = twoPoint
            ? "$\\\\lim_{x \\\\to 2} (x^2-4)/(x-2)$ 의 값을 구하시오."
            : "$\\\\log_{3} 18 - \\\\log_{3} 2$ 의 값을 구하시오."
        let topicKey = twoPoint ? "limit-basic" : "log-basic"
        let topicLabel = twoPoint ? "함수의 극한" : "로그의 성질"
        return #"""
        {
          "timeLimitMs": 40000,
          "attempt": {
            "instanceId": "demo-quick-\#(pointValue)-01",
            "pointValue": \#(pointValue),
            "topicKey": "\#(topicKey)",
            "topicLabel": "\#(topicLabel)",
            "variantLabel": "변형 A",
            "sourceScope": "수능 첫 페이지",
            "prompt": "\#(prompt)",
            "deadlineAt": "@T+40s@"
          }
        }
        """#
    }

    static func quickSubmit(answer: String) -> String {
        #"""
        {
          "result": {
            "expired": false,
            "correct": true,
            "solution": "밑이 같은 로그의 뺄셈은 진수의 나눗셈이므로 $\\log_3 (18/2)=\\log_3 9=2$ 입니다.",
            "answer": "2",
            "responseTimeMs": 18400,
            "pending": false
          }
        }
        """#
    }

    static let quickExpire = #"""
    {
      "result": {
        "expired": true,
        "correct": false,
        "solution": "40초 안에 풀지 못했습니다. 밑이 같은 로그의 뺄셈은 진수의 나눗셈으로 정리합니다.",
        "answer": "2",
        "responseTimeMs": 40000,
        "pending": false
      }
    }
    """#

    static let quickStats = #"""
    { "stats": { "total": 86, "correct": 61, "accuracy": 0.709, "averageMs": 21400 } }
    """#

    // MARK: - 이용권 상점 (웹 결제로 넘기기 전 카드 표시)

    static let storefront = #"""
    {
      "storefront": {
        "generatedAt": "@T+0s@",
        "checkoutEnabled": true,
        "currency": "KRW",
        "access": {
          "packageType": "LEARNING_PACKAGE",
          "learningPackageActive": true,
          "mockExamPackageActive": false,
          "arenaAllowed": true,
          "rankedShopAvailable": false,
          "mockExamEndsAt": null
        },
        "products": [
          {
            "code": "MOCK_EXAM_ONLY",
            "name": "Matths 주간 공식 모의고사 이용권",
            "amount": 5500,
            "periodLabel": "30일",
            "description": "주간 공식 모의고사 응시에 집중하는 이용권",
            "features": ["주간 공식 모의고사", "응시 기록과 성적 확인", "학습권과 분리된 30일 이용"],
            "current": false
          },
          {
            "code": "LEARNING_PACKAGE_29",
            "name": "29일 학습권 패키지",
            "amount": 29000,
            "periodLabel": "29일",
            "description": "모의고사·배치고사·GOAT Arena까지 포함한 학습권",
            "features": ["모의고사와 배치고사", "GOAT Arena 공식 경기", "29일 학습 사이클"],
            "current": true
          }
        ]
      }
    }
    """#

    static let commerceHandoff = #"""
    {
      "handoff": {
        "url": "https://www.matths.kr/app/commerce/demo-token-not-a-real-session",
        "expiresAt": "@T+2m@"
      }
    }
    """#

    // MARK: - 알림함
    //
    // 감독이 요청한 네 갈래를 모두 한 벌에 담는다: 게시판 답글 알림 · 전체 공지 ·
    // 관리자 개별 안내 · 경고. 거기에 계정/닉네임/무결성/시스템까지 넣어 서버
    // kind 열거형 7종이 화면에서 어떻게 보이는지 한 화면에서 확인할 수 있게 했다.
    // 읽음/안읽음, 긴급/일반, 오늘/어제/지난주가 섞여 있어야 정렬·배지·구분선이
    // 실제로 도는지 보인다.
    static let notificationInbox = #"""
    {
      "notifications": [
        {
          "id": "demo-noti-01",
          "kind": "warning",
          "title": "경고 1회 — 커뮤니티 이용 규칙 위반",
          "message": "게시판 글 '이거 답 뭐임?' 에서 문제 전문을 그대로 옮겨 적으셨습니다. 저작권 문제가 있어 해당 글은 가려졌습니다. 경고가 3회 쌓이면 커뮤니티 쓰기가 7일 제한됩니다.",
          "href": "/community",
          "sourceType": "communityModeration",
          "createdAt": "@T-40m@",
          "readAt": null
        },
        {
          "id": "demo-noti-02",
          "kind": "admin",
          "title": "배치고사 일정 안내",
          "message": "지우 님의 GOAT Arena 배치고사가 8월 22일(금) 오후 8시로 배정되었습니다. 시작 10분 전까지 입장해 주세요.",
          "href": "/goat-arena",
          "sourceType": "arenaPlacement",
          "createdAt": "@T-3h@",
          "readAt": null
        },
        {
          "id": "demo-noti-03",
          "kind": "announcement",
          "title": "9월 정기 점검 안내",
          "message": "9월 1일(화) 오전 2시부터 4시까지 서버 점검이 있습니다. 점검 중에는 아레나 경기와 주간 모의고사 제출이 잠시 멈춥니다. 오프라인 학습과 오답노트는 그대로 쓰실 수 있습니다.",
          "href": "/main",
          "sourceType": "announcement",
          "createdAt": "@T-9h@",
          "readAt": null
        },
        {
          "id": "demo-noti-04",
          "kind": "system",
          "title": "새 답글이 달렸습니다",
          "message": "내 글 '삼차함수 극값 질문' 에 민준 님이 답글을 남겼습니다: \"미분해서 f'(x)=0 인 x를 먼저 구해보세요.\"",
          "href": "/community",
          "sourceType": "communityReply",
          "createdAt": "@T-26h@",
          "readAt": null
        },
        {
          "id": "demo-noti-05",
          "kind": "integrity",
          "title": "경기 검토 종료 — 이상 없음",
          "message": "2026-W33 시드 경기의 화면 기록 검토가 끝났습니다. 부정 정황이 확인되지 않아 결과가 그대로 확정되었습니다.",
          "href": "/goat-arena",
          "sourceType": "arenaIntegrity",
          "createdAt": "@T-2d@",
          "readAt": "@T-2d@"
        },
        {
          "id": "demo-noti-06",
          "kind": "nickname",
          "title": "닉네임이 변경되었습니다",
          "message": "요청하신 닉네임 변경이 반영되었습니다. 순위표에는 다음 시드부터 새 닉네임으로 표시됩니다.",
          "href": "/main",
          "sourceType": "account",
          "createdAt": "@T-4d@",
          "readAt": "@T-4d@"
        },
        {
          "id": "demo-noti-07",
          "kind": "account",
          "title": "이용권 만료 D-2",
          "message": "29일 학습권이 8월 20일에 끝납니다. 만료되면 아레나 참가와 주간 모의고사 응시가 멈추고, 오답노트와 진도는 그대로 남습니다.",
          "href": "/pricing",
          "sourceType": "commerce",
          "createdAt": "@T-5d@",
          "readAt": "@T-5d@"
        },
        {
          "id": "demo-noti-08",
          "kind": "admin",
          "title": "학교 인증이 완료되었습니다",
          "message": "한영고등학교 재학 인증이 확인되었습니다. 학교 리그 순위표에 반영되었습니다.",
          "href": "/main",
          "sourceType": "account",
          "createdAt": "@T-8d@",
          "readAt": "@T-7d@"
        },
        {
          "id": "demo-noti-09",
          "kind": "system",
          "title": "오늘의 학습 목표를 달성했습니다",
          "message": "공통수학 개념 2개와 빠른 연습 5문항을 완료했습니다.",
          "href": "/main",
          "sourceType": "dailyGoal",
          "createdAt": "@T-9d@",
          "readAt": "@T-9d@"
        },
        {
          "id": "demo-noti-10",
          "kind": "announcement",
          "title": "주간 학습 리포트가 도착했습니다",
          "message": "지난주 정답률과 복습 권장 개념을 홈에서 확인해 보세요.",
          "href": "/main",
          "sourceType": "weeklyReport",
          "createdAt": "@T-10d@",
          "readAt": "@T-10d@"
        },
        {
          "id": "demo-noti-11",
          "kind": "system",
          "title": "오답 복습이 준비됐습니다",
          "message": "최근 틀린 문제 중 다시 풀기 좋은 4문항을 골랐습니다.",
          "href": "/wrong-note",
          "sourceType": "wrongNote",
          "createdAt": "@T-11d@",
          "readAt": "@T-11d@"
        },
        {
          "id": "demo-noti-12",
          "kind": "admin",
          "title": "학습 상담 답변이 등록됐습니다",
          "message": "문의하신 진도 조정 방법에 관리자가 답변했습니다.",
          "href": "/faq",
          "sourceType": "support",
          "createdAt": "@T-12d@",
          "readAt": "@T-12d@"
        },
        {
          "id": "demo-noti-13",
          "kind": "system",
          "title": "연속 학습 7일을 달성했습니다",
          "message": "일주일 동안 매일 학습했습니다. 기록은 홈 상단에서 확인할 수 있습니다.",
          "href": "/main",
          "sourceType": "learningStreak",
          "createdAt": "@T-13d@",
          "readAt": "@T-13d@"
        },
        {
          "id": "demo-noti-14",
          "kind": "announcement",
          "title": "개념 해설 콘텐츠가 추가됐습니다",
          "message": "집합과 명제 단원에 새로운 움직이는 해설이 추가됐습니다.",
          "href": "/curriculum",
          "sourceType": "curriculum",
          "createdAt": "@T-14d@",
          "readAt": "@T-14d@"
        },
        {
          "id": "demo-noti-15",
          "kind": "system",
          "title": "빠른 연습 기록이 저장됐습니다",
          "message": "완료한 5문항의 정답률과 풀이 시간이 학습 기록에 반영됐습니다.",
          "href": "/quick-practice",
          "sourceType": "quickPractice",
          "createdAt": "@T-15d@",
          "readAt": "@T-15d@"
        },
        {
          "id": "demo-noti-16",
          "kind": "integrity",
          "title": "경기 화면 기록 업로드 완료",
          "message": "GOAT Arena 경기의 화면 기록이 안전하게 제출됐습니다.",
          "href": "/goat-arena",
          "sourceType": "arenaIntegrity",
          "createdAt": "@T-16d@",
          "readAt": "@T-16d@"
        },
        {
          "id": "demo-noti-17",
          "kind": "system",
          "title": "평가 결과가 저장됐습니다",
          "message": "단원 평가 결과와 추천 복습 순서가 평가센터에 반영됐습니다.",
          "href": "/assessment",
          "sourceType": "assessment",
          "createdAt": "@T-17d@",
          "readAt": "@T-17d@"
        },
        {
          "id": "demo-noti-18",
          "kind": "announcement",
          "title": "서비스 이용 안내가 업데이트됐습니다",
          "message": "오프라인 학습과 동기화 동작에 관한 도움말이 보강됐습니다.",
          "href": "/faq",
          "sourceType": "announcement",
          "createdAt": "@T-18d@",
          "readAt": "@T-18d@"
        },
        {
          "id": "demo-noti-19",
          "kind": "system",
          "title": "학습 데이터 동기화 완료",
          "message": "다른 기기에서 진행한 학습 기록을 이 기기에 반영했습니다.",
          "href": "/main",
          "sourceType": "sync",
          "createdAt": "@T-19d@",
          "readAt": "@T-19d@"
        },
        {
          "id": "demo-noti-20",
          "kind": "admin",
          "title": "모의고사 응시 안내",
          "message": "이번 주 공식 모의고사는 일요일 자정까지 응시할 수 있습니다.",
          "href": "/private-mock-exams",
          "sourceType": "weeklyMock",
          "createdAt": "@T-20d@",
          "readAt": "@T-20d@"
        }
      ],
      "stats": { "total": 26, "unread": 4, "urgentUnread": 1, "read": 22 },
      "pagination": { "page": 1, "totalPages": 2, "hasPrevious": false, "hasNext": true }
    }
    """#

    /// 페이지네이션 UI를 실제로 누를 수 있게 하는 오래된 알림 두 번째 페이지.
    /// 운영 서버의 고정 페이지 크기(20건)를 그대로 재현한다. 통계는 전체 26건
    /// 기준으로 첫 페이지와 동일하게 돌려준다.
    static let notificationInboxPage2 = #"""
    {
      "notifications": [
        {
          "id": "demo-noti-21",
          "kind": "system",
          "title": "연속 학습 12일을 달성했습니다",
          "message": "이번 주에도 매일 한 개념 이상 학습했습니다. 현재 기록은 홈 상단에서 언제든 확인할 수 있습니다.",
          "href": "/main",
          "sourceType": "learningStreak",
          "createdAt": "@T-21d@",
          "readAt": "@T-21d@"
        },
        {
          "id": "demo-noti-22",
          "kind": "announcement",
          "title": "공통수학 개념 해설이 업데이트됐습니다",
          "message": "함수와 방정식 단원의 움직이는 해설이 더 짧고 명확하게 바뀌었습니다.",
          "href": "/learn/common-math",
          "sourceType": "curriculum",
          "createdAt": "@T-22d@",
          "readAt": "@T-22d@"
        },
        {
          "id": "demo-noti-23",
          "kind": "admin",
          "title": "주간 모의고사 성적표가 열렸습니다",
          "message": "지난 주 응시한 모의고사의 문항별 정답률과 복습 권장 개념을 확인해 보세요.",
          "href": "/private-mock-exams",
          "sourceType": "weeklyMock",
          "createdAt": "@T-23d@",
          "readAt": "@T-23d@"
        },
        {
          "id": "demo-noti-24",
          "kind": "integrity",
          "title": "풀이 증거 보관 기간 안내",
          "message": "경기 검토가 종료된 풀이 증거는 운영 정책에 따라 순차 삭제됩니다.",
          "href": "/goat-arena/mailbox",
          "sourceType": "arenaIntegrity",
          "createdAt": "@T-24d@",
          "readAt": "@T-24d@"
        },
        {
          "id": "demo-noti-25",
          "kind": "system",
          "title": "빠른 연습 추천 문제가 준비됐습니다",
          "message": "최근 오답을 바탕으로 5문항 연습 세트를 만들었습니다.",
          "href": "/quick-practice",
          "sourceType": "quickPractice",
          "createdAt": "@T-25d@",
          "readAt": "@T-25d@"
        },
        {
          "id": "demo-noti-26",
          "kind": "account",
          "title": "고객지원 답변이 등록됐습니다",
          "message": "문의하신 계정 복구 방법에 답변을 남겼습니다. 고객지원에서 확인해 주세요.",
          "href": "/faq",
          "sourceType": "support",
          "createdAt": "@T-26d@",
          "readAt": "@T-26d@"
        }
      ],
      "stats": { "total": 26, "unread": 4, "urgentUnread": 1, "read": 22 },
      "pagination": { "page": 2, "totalPages": 2, "hasPrevious": true, "hasNext": false }
    }
    """#
}
#endif
