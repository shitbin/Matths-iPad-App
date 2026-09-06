// GENERATED; do not edit. Web e3cc06360415a4c60460895b01f06a3248dae665; tools/generate-web-derived-assets.mjs
(() => {
  var __getOwnPropNames = Object.getOwnPropertyNames;
  var __require = /* @__PURE__ */ ((x) => typeof require !== "undefined" ? require : typeof Proxy !== "undefined" ? new Proxy(x, {
    get: (a, b) => (typeof require !== "undefined" ? require : a)[b]
  }) : x)(function(x) {
    if (typeof require !== "undefined") return require.apply(this, arguments);
    throw Error('Dynamic require of "' + x + '" is not supported');
  });
  var __commonJS = (cb, mod) => function __require2() {
    return mod || (0, cb[__getOwnPropNames(cb)[0]])((mod = { exports: {} }).exports, mod), mod.exports;
  };

  // services/assessmentReferences/mockExamCatalog.js
  var require_mockExamCatalog = __commonJS({
    "services/assessmentReferences/mockExamCatalog.js"(exports, module) {
      var ARCHIVE_URLS = {
        1: "https://www.ebsi.co.kr/ebs/xip/xipc/previousPaperList.ebs?targetCd=D100",
        2: "https://www.ebsi.co.kr/ebs/xip/xipc/previousPaperList.ebs?targetCd=D200",
        3: "https://www.ebsi.co.kr/ebs/xip/xipc/previousPaperList.ebs?targetCd=D300"
      };
      var YEARS = [
        2022,
        2023,
        2024,
        2025,
        2026
      ];
      var GRADE_ONE_TWO_SCHEDULES = {
        2022: [
          [3, "서울"],
          [6, "부산"],
          [9, "인천"],
          [11, "경기"]
        ],
        2023: [
          [3, "서울"],
          [6, "부산"],
          [9, "인천"],
          [11, "경기"]
        ],
        2024: [
          [3, "서울"],
          [6, "부산"],
          [9, "인천"],
          [10, "경기"]
        ],
        2025: [
          [3, "서울"],
          [6, "부산"],
          [9, "인천"],
          [10, "경기"]
        ],
        2026: [
          [3, "서울"],
          [6, "부산"]
        ]
      };
      var GRADE_THREE_SCHEDULES = {
        2022: [
          [3, "서울", "학평"],
          [4, "경기", "학평"],
          [6, "평가원", "모평"],
          [7, "인천", "학평"],
          [9, "평가원", "모평"],
          [10, "서울", "학평"]
        ],
        2023: [
          [3, "서울", "학평"],
          [4, "경기", "학평"],
          [6, "평가원", "모평"],
          [7, "인천", "학평"],
          [9, "평가원", "모평"],
          [10, "서울", "학평"]
        ],
        2024: [
          [3, "서울", "학평"],
          [4, "경기", "학평"],
          [6, "평가원", "모평"],
          [7, "인천", "학평"],
          [9, "평가원", "모평"],
          [10, "서울", "학평"]
        ],
        2025: [
          [3, "서울", "학평"],
          [5, "경기", "학평"],
          [6, "평가원", "모평"],
          [7, "인천", "학평"],
          [9, "평가원", "모평"],
          [10, "서울", "학평"]
        ],
        2026: [
          [3, "서울", "학평"],
          [5, "경기", "학평"],
          [6, "평가원", "모평"],
          [7, "인천", "학평"]
        ]
      };
      function twoDigits(value) {
        return String(value).padStart(2, "0");
      }
      function sessionId({
        year,
        grade,
        month
      }) {
        return [
          year,
          `g${grade}`,
          twoDigits(month)
        ].join("-");
      }
      function makeSession({
        year,
        grade,
        month,
        host,
        kind,
        selections
      }) {
        const id = sessionId({
          year,
          grade,
          month
        });
        return {
          id,
          year,
          grade,
          month,
          host,
          kind,
          archiveUrl: ARCHIVE_URLS[grade],
          selections
        };
      }
      var MOCK_EXAM_SESSIONS = [
        ...[1, 2].flatMap(
          (grade) => YEARS.flatMap(
            (year) => GRADE_ONE_TWO_SCHEDULES[year].map(
              ([month, host]) => makeSession({
                year,
                grade,
                month,
                host,
                kind: "학평",
                selections: ["수학"]
              })
            )
          )
        ),
        ...YEARS.flatMap(
          (year) => GRADE_THREE_SCHEDULES[year].map(
            ([month, host, kind]) => makeSession({
              year,
              grade: 3,
              month,
              host,
              kind,
              selections: [
                "미적분",
                "확률과 통계"
              ]
            })
          )
        )
      ];
      var MOCK_EXAM_PAPERS = MOCK_EXAM_SESSIONS.flatMap(
        (session) => session.selections.map(
          (selection) => ({
            id: `${session.id}-${selection === "수학" ? "math" : selection === "미적분" ? "calculus" : "probability"}`,
            sessionId: session.id,
            year: session.year,
            grade: session.grade,
            month: session.month,
            host: session.host,
            kind: session.kind,
            selection,
            title: `고${session.grade} ${session.month}월 ${session.kind}(${session.host}) ${selection}`,
            archiveUrl: session.archiveUrl,
            archiveFilters: {
              year: session.year,
              month: session.month,
              subject: selection
            },
            analysisStatus: "indexed"
          })
        )
      );
      var UNIT_REFERENCE_RULES = {
        "common-math-1/polynomials": {
          corpusFilter: (paper) => paper.grade === 1,
          signals: [
            "다항식의 구조를 보존하는 사칙연산",
            "항등식의 계수 비교와 나머지정리",
            "곱셈공식·치환을 이용한 인수분해",
            "조건에서 다항식의 값을 역추론"
          ]
        },
        "common-math-1/equations-and-inequalities": {
          corpusFilter: (paper) => paper.grade === 1,
          signals: [
            "복소수의 연산과 켤레복소수",
            "이차방정식의 판별식과 근의 위치",
            "이차함수 그래프와 직선의 교점",
            "고차방정식의 인수정리와 치환",
            "절댓값·이차부등식의 해 구간"
          ]
        },
        "common-math-1/counting": {
          corpusFilter: (paper) => paper.grade === 1,
          signals: [
            "합의 법칙과 곱의 법칙의 구분",
            "조건이 있는 순열의 단계별 분류",
            "순서를 제거한 조합의 모델링",
            "여사건을 이용한 경우의 수 계산"
          ]
        },
        "common-math-1/matrices": {
          corpusFilter: (paper) => paper.grade === 1,
          signals: [
            "행렬의 크기와 성분의 대응",
            "행렬의 덧셈·실수배",
            "행과 열을 연결한 행렬의 곱",
            "행렬 관계식에서 미지 성분 복원"
          ]
        },
        "common-math-2/coordinate-geometry": {
          corpusFilter: (paper) => paper.grade === 1,
          signals: [
            "좌표에서 거리·내분점 복원",
            "직선의 평행·수직과 점선거리",
            "원과 직선의 위치 관계",
            "평행이동·대칭이동의 방정식 변환"
          ]
        },
        "common-math-2/sets-and-propositions": {
          corpusFilter: (paper) => paper.grade === 1,
          signals: [
            "집합의 포함관계와 연산",
            "조건의 진리집합과 명제의 참·거짓",
            "역·이·대우와 필요충분조건",
            "대우·귀류법과 절대부등식 증명"
          ]
        },
        "common-math-2/functions-and-graphs": {
          corpusFilter: (paper) => paper.grade === 1,
          signals: [
            "함수의 정의역·치역과 그래프",
            "합성 순서와 합성함수의 정의역",
            "역함수 존재 조건과 y=x 대칭",
            "유리함수·무리함수의 이동과 정의역"
          ]
        },
        "algebra/exponential-logarithmic-functions": {
          corpusFilter: (paper) => paper.grade < 3 || paper.selection === "미적분",
          signals: [
            "지수·로그 식의 치환과 해의 조건",
            "지수·로그 그래프의 교점과 평행이동",
            "상용로그를 이용한 자릿수·소수부분 해석",
            "지수·로그 방정식과 부등식의 매개변수"
          ]
        },
        "algebra/trigonometric-functions": {
          corpusFilter: (paper) => paper.grade < 3 || paper.selection === "미적분",
          signals: [
            "삼각함수 그래프의 주기·최대최소 역추론",
            "일반각의 사분면과 삼각함수 값",
            "사인법칙·코사인법칙·넓이의 연쇄 적용",
            "도형 조건에서 길이와 각을 단계적으로 복원"
          ]
        },
        "algebra/sequences": {
          corpusFilter: (paper) => paper.grade < 3 || paper.selection === "미적분",
          signals: [
            "부분합으로 일반항 복원",
            "등차·등비 조건의 연립",
            "점화식의 블록·주기 분석",
            "시그마 변형과 망원합",
            "정수·자연수 조건을 이용한 후보 제거"
          ]
        },
        "calculus-1/limits-and-continuity": {
          corpusFilter: (paper) => paper.grade >= 2 && (paper.grade < 3 || paper.selection === "미적분"),
          signals: [
            "인수분해·유리화 후 극한",
            "좌극한·우극한·함숫값의 일치",
            "구간별 함수의 연속 조건으로 매개변수 결정",
            "중간값 정리의 존재 구간 판정"
          ]
        },
        "calculus-1/differentiation": {
          corpusFilter: (paper) => paper.grade >= 2 && (paper.grade < 3 || paper.selection === "미적분"),
          signals: [
            "도함수의 근에서 증가·감소와 극값 복원",
            "접선 조건과 다항함수 계수 결정",
            "방정식 실근 개수를 그래프 교점으로 변환",
            "위치·속도·가속도의 단계적 해석",
            "후속 적분 문항에서 적분 직전 단계까지만 절단"
          ]
        },
        "calculus-1/integration": {
          corpusFilter: (paper) => paper.grade >= 2 && (paper.grade < 3 || paper.selection === "미적분"),
          signals: [
            "도함수 조건에서 원함수를 복원한 뒤 정적분",
            "교점과 함수의 대소를 판정한 뒤 넓이 계산",
            "속도의 부호 변화 시점을 찾아 이동거리 계산",
            "정적분으로 정의된 함수의 조건 해석"
          ]
        },
        "probability-statistics/counting": {
          corpusFilter: (paper) => paper.grade < 3 || paper.selection === "확률과 통계",
          signals: [
            "중복·인접·양끝 조건이 있는 배열",
            "포함배제로 금지 조건 제거",
            "중복조합의 하한·상한 치환",
            "이항계수의 특정 항과 계수합"
          ]
        },
        "probability-statistics/probability": {
          corpusFilter: (paper) => paper.grade < 3 || paper.selection === "확률과 통계",
          signals: [
            "조건부확률에서 표본공간 축소",
            "독립 시행과 여사건",
            "베이즈형 원인 역추론",
            "비복원 추출의 단계별 조건 갱신"
          ]
        },
        "probability-statistics/statistics": {
          corpusFilter: (paper) => paper.grade < 3 || paper.selection === "확률과 통계",
          signals: [
            "확률분포표에서 미지 확률과 기댓값 복원",
            "이항분포의 평균·분산 역추론",
            "정규분포 표준화와 대칭성",
            "표본평균의 분포와 표본 크기",
            "신뢰구간 길이의 역산"
          ]
        }
      };
      function getUnitReferenceAnalysis(courseId, unitId) {
        const key = `${courseId}/${unitId}`;
        const rule = UNIT_REFERENCE_RULES[key];
        if (!rule) return null;
        const papers = MOCK_EXAM_PAPERS.filter(
          rule.corpusFilter
        );
        return {
          key,
          years: YEARS.slice(),
          signals: rule.signals.slice(),
          paperIds: papers.map(
            (paper) => paper.id
          ),
          sessionIds: [
            ...new Set(
              papers.map(
                (paper) => paper.sessionId
              )
            )
          ]
        };
      }
      function referenceIdsForTemplate(courseId, unitId, templateIndex, count = 5) {
        const analysis = getUnitReferenceAnalysis(
          courseId,
          unitId
        );
        if (!analysis) return [];
        const ids = analysis.paperIds;
        const selected = [];
        for (let offset = 0; offset < ids.length && selected.length < count; offset += 1) {
          const index = (templateIndex + offset * Math.max(
            1,
            Math.floor(
              ids.length / count
            )
          )) % ids.length;
          const id = ids[index];
          if (!selected.includes(id)) {
            selected.push(id);
          }
        }
        return selected;
      }
      if (MOCK_EXAM_PAPERS.length !== 92) {
        throw new Error(
          `최근 5개년 모의고사 코퍼스는 92개 문제지여야 합니다: ${MOCK_EXAM_PAPERS.length}`
        );
      }
      module.exports = {
        YEARS,
        ARCHIVE_URLS,
        MOCK_EXAM_SESSIONS,
        MOCK_EXAM_PAPERS,
        UNIT_REFERENCE_RULES,
        getUnitReferenceAnalysis,
        referenceIdsForTemplate
      };
    }
  });

  // verified-curriculum:catalog
  var require_catalog = __commonJS({
    "verified-curriculum:catalog"(exports, module) {
      module.exports = { loadCurriculum: () => ({ "schemaVersion": 1, "curriculum": { "id": "kr-2022", "title": "2022 개정 교육과정", "country": "KR", "source": { "title": "교육부 고시 제2022-33호 [별책 8] 수학과 교육과정", "type": "official-curriculum", "url": "https://www.moe.go.kr/boardCnts/viewRenew.do?boardID=141&boardSeq=93458&lev=0" } }, "grade": { "id": "high-school", "title": "고등학교 수학 전 과정", "levels": [{ "schoolGrade": 10, "title": "고등학교 1학년", "type": "common" }, { "schoolGrade": 11, "title": "고등학교 2학년", "type": "school-defined" }, { "schoolGrade": 12, "title": "고등학교 3학년", "type": "school-defined" }, { "schoolGrade": 13, "title": "N수생", "type": "school-defined" }] }, "coursePlacementPolicy": { "type": "school-defined", "description": "공통수학1·2 이후 선택 과목의 실제 개설 학년과 학기는 학교 교육과정과 학생의 진로 선택에 따라 달라질 수 있습니다." }, "categories": [{ "id": "common", "title": "공통 과목", "englishTitle": "COMMON", "description": "고등학교 수학 학습의 공통 기반이 되는 필수 과목입니다.", "order": 1, "courses": [{ "id": "common-math-1", "officialTitle": "공통수학1", "defaultSemester": 1, "conceptCount": 19, "units": [{ "id": "polynomials", "title": "다항식", "order": 1, "concepts": [{ "id": "polynomial-arithmetic", "order": 1, "title": "다항식의 사칙연산", "standardCode": "10공수1-01-01", "achievementStandard": "다항식의 사칙연산의 원리를 설명하고, 그 계산을 할 수 있다.", "topics": ["다항식의 덧셈과 뺄셈", "다항식의 곱셈", "다항식의 나눗셈", "몫과 나머지의 관계", "조립제법"], "scopeNotes": ["조립제법은 구체적인 예를 통해 간단히 다룬다.", "중학교의 다항식을 단항식으로 나누는 연산과 연결한다."], "visualizationIdeas": ["대수 타일로 다항식의 덧셈과 곱셈 표현", "넓이 모델로 다항식의 곱셈 표현", "나눗셈 블록이 몫과 나머지로 분해되는 애니메이션"] }, { "id": "identity-remainder-theorem", "order": 2, "title": "항등식과 나머지정리", "standardCode": "10공수1-01-02", "achievementStandard": "항등식의 성질과 나머지정리를 이해하고, 이를 활용하여 문제를 해결할 수 있다.", "topics": ["항등식의 뜻", "방정식과 항등식의 차이", "미정계수법", "계수 비교법", "수치 대입법", "나머지정리", "인수정리"], "scopeNotes": ["항등식의 성질과 나머지정리를 활용하는 복잡한 문제는 다루지 않는다.", "인수정리를 활용하는 복잡한 문제는 다루지 않는다."], "visualizationIdeas": ["여러 x값에서도 양변이 항상 같게 유지되는 그래프", "P(x)를 x-a로 나눈 몫과 나머지의 블록 분해", "x=a에서 P(a)가 나머지가 되는 과정"] }, { "id": "polynomial-factorization", "order": 3, "title": "다항식의 인수분해", "standardCode": "10공수1-01-03", "achievementStandard": "다항식의 인수분해를 할 수 있다.", "topics": ["공통인수 묶기", "곱셈공식을 역으로 이용하기", "항을 묶어 인수분해하기", "치환을 이용한 인수분해", "인수정리를 이용한 인수분해", "조립제법을 이용한 인수분해"], "scopeNotes": ["중학교에서 학습한 인수분해에서 확장한다.", "복잡한 인수분해 문제는 다루지 않는다."], "visualizationIdeas": ["하나의 넓이를 두 변의 곱으로 재구성", "다항식 블록을 공통인수별로 묶기", "근과 인수가 연결되는 그래프"] }], "conceptCount": 3 }, { "id": "equations-and-inequalities", "title": "방정식과 부등식", "order": 2, "concepts": [{ "id": "complex-numbers", "order": 1, "title": "복소수의 뜻과 연산", "standardCode": "10공수1-02-01", "achievementStandard": "복소수의 뜻과 성질을 설명하고, 사칙연산을 수행할 수 있다.", "topics": ["허수단위 i", "복소수 a+bi", "실수부분과 허수부분", "허수와 켤레복소수", "복소수의 덧셈과 뺄셈", "복소수의 곱셈", "복소수의 나눗셈", "i의 거듭제곱"], "scopeNotes": ["실수의 성질 및 사칙연산과 연결하여 이해한다.", "나눗셈은 켤레복소수를 이용하여 계산한다."], "visualizationIdeas": ["실수선이 복소평면으로 확장되는 애니메이션", "i를 곱할 때 90도 회전하는 표현", "켤레복소수가 실수축에 대칭되는 표현"] }, { "id": "quadratic-discriminant", "order": 2, "title": "이차방정식의 실근·허근과 판별식", "standardCode": "10공수1-02-02", "achievementStandard": "이차방정식의 실근과 허근을 이해하고, 판별식을 이용하여 이차방정식의 근을 판별할 수 있다.", "topics": ["이차방정식의 근", "실근과 허근", "중근", "판별식 D=b²-4ac", "판별식과 근의 종류"], "scopeNotes": ["이차방정식의 계수가 실수인 경우만 다룬다.", "복소수 범위에서 이차방정식은 항상 근을 갖는다는 것을 이해한다."], "visualizationIdeas": ["판별식 변화에 따른 포물선과 x축의 교점 변화", "두 실근이 중근을 거쳐 허근이 되는 연속 애니메이션"] }, { "id": "quadratic-roots-and-coefficients", "order": 3, "title": "이차방정식의 근과 계수의 관계", "standardCode": "10공수1-02-03", "achievementStandard": "이차방정식의 근과 계수의 관계를 설명할 수 있다.", "topics": ["두 근의 합", "두 근의 곱", "근과 계수의 관계 유도", "두 근으로 이차방정식 만들기"], "scopeNotes": ["근과 계수의 관계를 활용하는 지나치게 복잡한 문제는 다루지 않는다."], "visualizationIdeas": ["두 근이 이동할 때 계수가 변화하는 그래프", "(x-α)(x-β)가 전개되며 계수와 연결되는 애니메이션"] }, { "id": "quadratic-equation-and-function", "order": 4, "title": "이차방정식과 이차함수의 관계", "standardCode": "10공수1-02-04", "achievementStandard": "이차방정식과 이차함수를 연결하여 그 관계를 설명할 수 있다.", "topics": ["f(x)=0의 의미", "이차방정식의 근과 x절편", "실근의 개수와 교점 개수", "중근과 접점", "판별식의 그래프적 의미"], "visualizationIdeas": ["식의 근이 그래프의 x절편으로 이동하는 변환", "대수적 풀이와 그래프 풀이의 동시 표시"] }, { "id": "parabola-and-line", "order": 5, "title": "이차함수 그래프와 직선의 위치 관계", "standardCode": "10공수1-02-05", "achievementStandard": "이차함수의 그래프와 직선의 위치 관계를 판단할 수 있다.", "topics": ["포물선과 직선의 교점", "두 점에서 만나는 경우", "접하는 경우", "만나지 않는 경우", "판별식을 이용한 위치 관계 판단"], "visualizationIdeas": ["직선이 이동하며 교점이 2개·1개·0개로 변하는 애니메이션", "교점 개수와 판별식 부호를 동시에 표시"] }, { "id": "quadratic-max-min-restricted", "order": 6, "title": "제한된 범위에서 이차함수의 최대·최소", "standardCode": "10공수1-02-06", "achievementStandard": "이차함수의 최대, 최소를 탐구하고, 이를 실생활과 연결하여 유용성을 인식할 수 있다.", "topics": ["이차함수의 꼭짓점", "제한된 구간", "구간 안에 꼭짓점이 있는 경우", "구간 밖에 꼭짓점이 있는 경우", "양 끝점과 꼭짓점의 함숫값 비교", "실생활 최적화 문제"], "scopeNotes": ["이차함수의 최대와 최소는 제한된 범위에서만 다룬다."], "visualizationIdeas": ["그래프 위 제한 구간을 움직이며 최대·최소 후보 비교", "꼭짓점과 구간 양 끝점에 값 표시"] }, { "id": "cubic-and-quartic-equations", "order": 7, "title": "삼차방정식과 사차방정식", "standardCode": "10공수1-02-07", "achievementStandard": "간단한 삼차방정식과 사차방정식을 풀 수 있다.", "topics": ["삼차방정식", "사차방정식", "인수분해를 이용한 풀이", "인수정리와 조립제법", "간단한 치환"], "scopeNotes": ["계수가 실수인 경우만 다룬다.", "인수분해 공식, 인수정리, 조립제법으로 풀 수 있는 경우만 다룬다."], "visualizationIdeas": ["고차다항식이 일차·이차 인수로 분해되는 애니메이션", "각 인수의 근이 그래프의 절편과 연결되는 표현"] }, { "id": "simultaneous-quadratic-equations", "order": 8, "title": "연립이차방정식", "standardCode": "10공수1-02-08", "achievementStandard": "미지수가 2개인 연립이차방정식을 풀 수 있다.", "topics": ["일차식과 이차식의 연립", "대입을 통한 일원화", "두 이차식의 연립", "인수분해를 이용한 풀이", "그래프의 교점과 해"], "scopeNotes": ["일차식과 이차식이 각각 한 개씩 주어진 경우를 다룬다.", "두 이차식 중 한 이차식이 간단히 인수분해되는 경우를 다룬다."], "visualizationIdeas": ["두 그래프의 교점이 연립방정식의 해가 되는 표현", "대입으로 두 변수 중 하나가 제거되는 과정"] }, { "id": "simultaneous-linear-inequalities", "order": 9, "title": "연립일차부등식", "standardCode": "10공수1-02-09", "achievementStandard": "미지수가 1개인 연립일차부등식을 풀 수 있다.", "topics": ["일차부등식의 해", "두 부등식의 공통 해", "수직선 표현", "해가 없는 경우", "모든 실수가 해인 경우"], "visualizationIdeas": ["두 수직선 범위가 겹치는 부분을 강조", "부등식별 범위를 합성하여 공통 해 생성"] }, { "id": "absolute-linear-inequalities", "order": 10, "title": "절댓값을 포함한 일차부등식", "standardCode": "10공수1-02-10", "achievementStandard": "절댓값을 포함한 일차부등식을 풀 수 있다.", "topics": ["절댓값의 거리 의미", "|x|<a", "|x|>a", "|x-a|<b", "경우를 나누는 풀이", "수직선에서 해석하기"], "visualizationIdeas": ["기준점에서의 거리로 절댓값 범위 표현", "수직선 위 두 경계가 벌어지고 좁아지는 애니메이션"] }, { "id": "quadratic-inequalities", "order": 11, "title": "이차부등식과 연립이차부등식", "standardCode": "10공수1-02-11", "achievementStandard": "이차부등식과 이차함수를 연결하여 그 관계를 설명하고, 이차부등식과 연립이차부등식을 풀 수 있다.", "topics": ["이차식의 부호", "이차함수 그래프와 이차부등식", "두 실근을 갖는 경우", "중근을 갖는 경우", "실근이 없는 경우", "연립이차부등식의 공통 해"], "visualizationIdeas": ["그래프가 x축 위·아래인 구간을 색으로 구분", "그래프의 부호 구간을 수직선 해로 변환"] }], "conceptCount": 11 }, { "id": "counting", "title": "경우의 수", "order": 3, "concepts": [{ "id": "addition-and-multiplication-principles", "order": 1, "title": "합의 법칙과 곱의 법칙", "standardCode": "10공수1-03-01", "achievementStandard": "합의 법칙과 곱의 법칙을 이해하고, 적절한 전략을 사용하여 경우의 수와 관련된 문제를 해결할 수 있다.", "topics": ["직접 나열하기", "표와 수형도", "합의 법칙", "곱의 법칙", "두 법칙이 적용되는 상황의 차이"], "scopeNotes": ["구체적인 예를 중심으로 간단히 다룬다.", "지나치게 복잡한 경우의 수 문제는 다루지 않는다."], "visualizationIdeas": ["선택 경로를 나무 모양으로 확장", "서로 배타적인 경로는 더하고 연속 선택은 곱하는 표현"] }, { "id": "permutations", "order": 2, "title": "순열", "standardCode": "10공수1-03-02", "achievementStandard": "순열의 개념을 이해하고, 순열의 수를 구하는 방법을 설명할 수 있다.", "topics": ["순서가 있는 배열", "계승 n!", "순열 nPr", "직접 나열과 수형도", "순열 공식의 원리"], "scopeNotes": ["원순열과 중복순열은 핵심 범위에 포함하지 않는다.", "지나치게 복잡한 문제는 다루지 않는다."], "visualizationIdeas": ["빈 자리에 대상을 하나씩 배치하며 선택지 수 감소", "수형도의 끝점 수와 순열 공식 연결"] }, { "id": "combinations", "order": 3, "title": "조합", "standardCode": "10공수1-03-03", "achievementStandard": "조합의 개념을 이해하고, 조합의 수를 구하는 방법을 설명할 수 있다.", "topics": ["순서를 고려하지 않는 선택", "조합 nCr", "순열과 조합의 차이", "조합 공식의 원리", "직접 나열과 수형도"], "scopeNotes": ["중복조합은 핵심 범위에 포함하지 않는다.", "지나치게 복잡한 문제는 다루지 않는다."], "visualizationIdeas": ["같은 구성의 서로 다른 순서를 하나의 묶음으로 합치기", "순열 결과를 r!개씩 묶어 조합으로 변환"] }], "conceptCount": 3 }, { "id": "matrices", "title": "행렬", "order": 4, "concepts": [{ "id": "matrix-concept", "order": 1, "title": "행렬의 뜻과 표현", "standardCode": "10공수1-04-01", "achievementStandard": "행렬의 뜻을 알고, 실생활 상황을 행렬로 표현할 수 있다.", "topics": ["행렬의 뜻", "행과 열", "성분", "행렬의 크기", "두 행렬이 같은 조건", "실생활 자료의 행렬 표현"], "visualizationIdeas": ["표 형태의 자료가 행렬 기호로 변환되는 애니메이션", "행·열·성분을 색으로 구분"] }, { "id": "matrix-operations", "order": 2, "title": "행렬의 연산", "standardCode": "10공수1-04-02", "achievementStandard": "행렬의 연산을 수행하고, 관련된 문제를 해결할 수 있다.", "topics": ["행렬의 덧셈과 뺄셈", "행렬의 실수배", "행렬의 곱셈", "행렬 곱셈이 가능한 조건", "행렬을 이용한 문제 해결"], "scopeNotes": ["곱셈은 행과 열의 수가 각각 2를 넘지 않는 범위에서 다룬다.", "행렬 연산의 대수적 구조를 일반화한 법칙은 다루지 않는다.", "역행렬은 공식 핵심 범위에 포함하지 않는다."], "visualizationIdeas": ["대응하는 성분끼리 더해지는 표현", "행과 열이 만나 하나의 성분을 만드는 곱셈 애니메이션"] }], "conceptCount": 2 }], "category": "common", "categoryTitle": "공통 과목", "categoryEnglishTitle": "COMMON", "categoryDescription": "고등학교 수학 학습의 공통 기반이 되는 필수 과목입니다.", "categoryOrder": 1, "recommendedGrades": [10], "placementLabel": "1학기 기본 순서", "sourceFile": "kr-2022-g10-math-curri.yaml", "developmentLocked": false }, { "id": "common-math-2", "officialTitle": "공통수학2", "defaultSemester": 2, "conceptCount": 20, "units": [{ "id": "coordinate-geometry", "title": "도형의 방정식", "order": 1, "concepts": [{ "id": "distance-and-internal-division", "order": 1, "title": "두 점 사이의 거리와 선분의 내분", "standardCode": "10공수2-01-01", "achievementStandard": "선분의 내분을 이해하고, 내분점의 좌표를 계산할 수 있다.", "topics": ["수직선 위 두 점 사이의 거리", "좌표평면 위 두 점 사이의 거리", "수직선 위 내분점", "좌표평면 위 내분점", "중점", "내분 공식의 원리"], "scopeNotes": ["두 점 사이의 거리를 먼저 다룬 뒤 내분으로 확장한다.", "외분점은 다루지 않는다."], "visualizationIdeas": ["선분을 주어진 비율로 나누는 점 이동", "수직선의 내분이 좌표평면으로 확장되는 애니메이션"] }, { "id": "parallel-and-perpendicular-lines", "order": 2, "title": "두 직선의 평행·수직 조건", "standardCode": "10공수2-01-02", "achievementStandard": "두 직선의 평행 조건과 수직 조건을 탐구하고 이해한다.", "topics": ["직선의 기울기", "직선의 방정식", "두 직선의 평행 조건", "두 직선의 수직 조건"], "visualizationIdeas": ["한 직선의 기울기가 변하며 평행·수직 상태 표시", "직각 표시와 기울기 곱을 동시에 연결"] }, { "id": "point-line-distance", "order": 3, "title": "점과 직선 사이의 거리", "standardCode": "10공수2-01-03", "achievementStandard": "점과 직선 사이의 거리를 구하고, 관련된 문제를 해결할 수 있다.", "topics": ["수선의 발", "점과 직선 사이 거리의 의미", "점과 직선 사이의 거리 공식", "두 평행선 사이의 거리"], "visualizationIdeas": ["점에서 직선으로 향하는 여러 선분 중 수선이 가장 짧음을 비교", "직선 이동에 따른 거리 변화"] }, { "id": "circle-equation", "order": 4, "title": "원의 방정식", "standardCode": "10공수2-01-04", "achievementStandard": "원의 방정식을 구하고, 그래프를 그릴 수 있다.", "topics": ["중심이 원점인 원", "중심이 (a,b)인 원", "반지름과 원의 방정식", "원의 중심과 반지름 찾기", "완전제곱식을 이용한 표준형 변환"], "visualizationIdeas": ["중심에서 원 위 점까지의 거리가 일정한 자취", "중심과 반지름 변화에 따른 방정식 갱신"] }, { "id": "circle-line-position", "order": 5, "title": "원과 직선의 위치 관계", "standardCode": "10공수2-01-05", "achievementStandard": "좌표평면에서 원과 직선의 위치 관계를 판단하고, 이를 활용하여 문제를 해결할 수 있다.", "topics": ["두 점에서 만나는 경우", "접하는 경우", "만나지 않는 경우", "중심과 직선 사이의 거리", "반지름과 거리 비교"], "visualizationIdeas": ["직선이 이동하며 할선·접선·외부 직선으로 변화", "중심과 직선 사이 거리와 반지름을 막대로 비교"] }, { "id": "geometric-translation", "order": 6, "title": "평행이동", "standardCode": "10공수2-01-06", "achievementStandard": "평행이동을 탐구하고, 실생활과 연결하여 문제를 해결할 수 있다.", "topics": ["점의 평행이동", "도형의 평행이동", "이동 전후 좌표", "방정식으로 표현된 도형의 이동", "실생활에서의 평행이동"], "scopeNotes": ["좌표축 자체의 평행이동은 다루지 않는다."], "visualizationIdeas": ["도형의 모든 점이 같은 벡터만큼 이동", "이동 전후 방정식과 좌표 변화 동시 표시"] }, { "id": "geometric-reflection", "order": 7, "title": "대칭이동", "standardCode": "10공수2-01-07", "achievementStandard": "원점, x축, y축, 직선 y=x에 대한 대칭이동을 탐구하고, 실생활과 연결하여 문제를 해결할 수 있다.", "topics": ["원점 대칭", "x축 대칭", "y축 대칭", "직선 y=x 대칭", "점과 도형의 대칭이동"], "visualizationIdeas": ["대칭축을 기준으로 도형을 접어 포개기", "좌표의 부호 및 순서가 바뀌는 과정"] }], "conceptCount": 7 }, { "id": "sets-and-propositions", "title": "집합과 명제", "order": 2, "concepts": [{ "id": "set-concept-and-representation", "order": 1, "title": "집합의 개념과 표현", "standardCode": "10공수2-02-01", "achievementStandard": "집합의 개념을 이해하고, 집합을 표현할 수 있다.", "topics": ["집합과 집합이 아닌 모임", "원소와 공집합", "유한집합과 무한집합", "원소나열법", "조건제시법", "벤 다이어그램"], "scopeNotes": ["집합의 개념은 이해하는 수준에서 간단히 평가한다."], "visualizationIdeas": ["여러 대상을 조건에 따라 집합 안팎으로 분류", "원소나열법이 벤 다이어그램으로 변환되는 표현"] }, { "id": "set-inclusion", "order": 2, "title": "집합의 포함관계", "standardCode": "10공수2-02-02", "achievementStandard": "두 집합 사이의 포함관계를 판단할 수 있다.", "topics": ["부분집합", "진부분집합", "두 집합이 같은 조건", "집합의 포함관계"], "scopeNotes": ["집합의 포함관계는 이해하는 수준에서 간단히 평가한다."], "visualizationIdeas": ["작은 집합이 큰 집합 안에 들어가는 애니메이션", "원소 이동에 따른 포함관계 변화"] }, { "id": "set-operations", "order": 3, "title": "집합의 연산과 벤 다이어그램", "standardCode": "10공수2-02-03", "achievementStandard": "집합의 연산을 수행하고, 벤 다이어그램을 이용하여 나타낼 수 있다.", "topics": ["합집합과 교집합", "전체집합과 여집합", "차집합과 서로소", "교환법칙과 결합법칙", "분배법칙", "드모르간의 법칙"], "scopeNotes": ["집합의 법칙은 벤 다이어그램으로 확인하는 정도로 간단히 다룬다."], "visualizationIdeas": ["연산 기호에 따라 벤 다이어그램 색칠 영역 변화", "드모르간의 법칙 양변을 색칠 영역으로 비교"] }, { "id": "proposition-and-condition", "order": 4, "title": "명제와 조건", "standardCode": "10공수2-02-04", "achievementStandard": "명제와 조건의 뜻을 알고, ‘모든’, ‘어떤’을 포함한 명제를 이해하고 설명할 수 있다.", "topics": ["명제와 조건", "참과 거짓", "진리집합", "명제의 부정", "모든을 포함한 명제", "어떤을 포함한 명제", "반례"], "scopeNotes": ["수학적인 문장을 이해하는 수준에서 간단히 다룬다.", "모든과 어떤을 포함한 명제는 구체적인 상황으로 도입한다."], "visualizationIdeas": ["모든 원소를 검사하는 과정과 하나의 반례 비교", "조건과 진리집합의 대응"] }, { "id": "converse-and-contrapositive", "order": 5, "title": "명제의 역과 대우", "standardCode": "10공수2-02-05", "achievementStandard": "명제의 역과 대우를 이해하고 설명할 수 있다.", "topics": ["가정과 결론", "명제 p→q", "명제의 역", "명제의 대우", "명제와 대우의 참·거짓 관계"], "scopeNotes": ["명제의 이는 별도 성취기준이 아니므로 보조 개념으로만 사용할 수 있다."], "visualizationIdeas": ["p와 q 카드의 순서 및 부정 상태 변환", "원래 명제와 대우의 진리표 비교"] }, { "id": "sufficient-and-necessary-conditions", "order": 6, "title": "충분조건과 필요조건", "standardCode": "10공수2-02-06", "achievementStandard": "충분조건과 필요조건을 이해하고 판단할 수 있다.", "topics": ["충분조건", "필요조건", "필요충분조건", "진리집합의 포함관계"], "scopeNotes": ["구체적인 예를 통해 이해한다."], "visualizationIdeas": ["두 진리집합의 포함관계로 충분·필요조건 표현", "조건 변화에 따라 포함관계가 바뀌는 애니메이션"] }, { "id": "proof-by-contrapositive-and-contradiction", "order": 7, "title": "대우를 이용한 증명과 귀류법", "standardCode": "10공수2-02-07", "achievementStandard": "대우를 이용한 증명법과 귀류법을 이해하고 관련된 명제를 증명할 수 있다.", "topics": ["증명의 의미", "대우를 이용한 증명", "귀류법", "두 증명 방법의 차이"], "scopeNotes": ["대우 증명과 귀류법은 간단한 명제만 다룬다.", "직관적인 이해에서 시작하여 점진적으로 형식화한다."], "visualizationIdeas": ["논리의 진행 경로를 흐름도로 표현", "가정의 부정이 모순에 도달하는 과정"] }, { "id": "absolute-inequality", "order": 8, "title": "절대부등식", "standardCode": "10공수2-02-08", "achievementStandard": "절대부등식의 뜻을 알고, 간단한 절대부등식을 증명할 수 있다.", "topics": ["절대부등식의 뜻", "실수의 제곱을 이용한 증명", "등호 성립 조건", "간단한 절대부등식"], "scopeNotes": ["간단한 절대부등식의 증명만 다룬다."], "visualizationIdeas": ["넓이 비교로 부등식 표현", "두 양의 차의 제곱이 0 이상인 과정"] }], "conceptCount": 8 }, { "id": "functions-and-graphs", "title": "함수와 그래프", "order": 3, "concepts": [{ "id": "function-concept-and-graph", "order": 1, "title": "함수의 개념과 그래프", "standardCode": "10공수2-03-01", "achievementStandard": "함수의 개념을 설명하고, 그 그래프를 이해한다.", "topics": ["두 집합 사이의 대응", "함수의 뜻", "정의역·공역·치역", "함수값과 그래프", "일대일함수와 일대일대응", "항등함수와 상수함수"], "scopeNotes": ["중학교에서 학습한 함수 개념을 두 집합 사이의 대응 관계로 확장한다."], "visualizationIdeas": ["정의역 원소에서 공역 원소로 향하는 대응 화살표", "대응 관계가 좌표평면의 점으로 변환되는 애니메이션"] }, { "id": "composite-function", "order": 2, "title": "합성함수", "standardCode": "10공수2-03-02", "achievementStandard": "함수의 합성을 설명하고, 합성함수를 구할 수 있다.", "topics": ["함수 합성의 뜻", "합성함수 f∘g", "합성 순서", "합성함수의 함수값", "간단한 합성함수 구하기"], "visualizationIdeas": ["입력값이 두 개의 함수 기계를 연속 통과", "합성 순서를 바꿀 때 결과 비교"] }, { "id": "inverse-function", "order": 3, "title": "역함수", "standardCode": "10공수2-03-03", "achievementStandard": "역함수의 개념을 설명하고, 역함수를 구할 수 있다.", "topics": ["역함수의 뜻", "역함수가 존재할 조건", "일대일대응과 역함수", "정의역과 치역의 교환", "역함수 구하기", "y=x에 대한 그래프 대칭"], "visualizationIdeas": ["대응 화살표의 방향 반전", "함수 그래프가 y=x를 기준으로 뒤집히는 애니메이션"] }, { "id": "rational-function", "order": 4, "title": "유리함수의 그래프", "standardCode": "10공수2-03-04", "achievementStandard": "유리함수의 그래프를 그릴 수 있고, 그 그래프의 성질을 탐구할 수 있다.", "topics": ["유리식과 유리함수의 기본 의미", "기본 유리함수", "정의역과 치역", "점근선", "그래프의 평행이동", "계수 변화와 그래프의 성질"], "scopeNotes": ["유리식은 유리함수를 이해하는 데 필요한 정도만 간단히 다룬다.", "유리함수는 기본적인 형태를 중심으로 간단한 문제만 다룬다."], "visualizationIdeas": ["x값이 특정 값에 가까워질 때 그래프가 점근선에 접근", "그래프 이동과 점근선 이동 동시 표시"] }, { "id": "irrational-function", "order": 5, "title": "무리함수의 그래프", "standardCode": "10공수2-03-05", "achievementStandard": "무리함수의 그래프를 그릴 수 있고, 그 그래프의 성질을 탐구할 수 있다.", "topics": ["무리식과 무리함수의 기본 의미", "기본 무리함수", "정의역과 치역", "그래프의 시작점", "그래프의 평행이동", "계수 변화와 그래프의 성질"], "scopeNotes": ["무리식은 무리함수를 이해하는 데 필요한 정도만 간단히 다룬다.", "무리함수는 기본적인 형태를 중심으로 간단한 문제만 다룬다."], "visualizationIdeas": ["정의역 경계에서 그래프가 시작되는 과정", "식의 이동과 그래프 시작점의 이동 동시 표시"] }], "conceptCount": 5 }], "category": "common", "categoryTitle": "공통 과목", "categoryEnglishTitle": "COMMON", "categoryDescription": "고등학교 수학 학습의 공통 기반이 되는 필수 과목입니다.", "categoryOrder": 1, "recommendedGrades": [10], "placementLabel": "2학기 기본 순서", "sourceFile": "kr-2022-g10-math-curri.yaml", "developmentLocked": false }] }, { "id": "general-elective", "title": "일반 선택", "englishTitle": "GENERAL ELECTIVE", "description": "대학 학습과 진로의 기초가 되는 주요 선택 과목입니다.", "order": 2, "courses": [{ "id": "algebra", "officialTitle": "대수", "category": "general-elective", "categoryTitle": "일반 선택", "recommendedGrades": [11, 12], "prerequisites": ["common-math-1", "common-math-2"], "defaultSemester": "school-defined", "conceptCount": 18, "units": [{ "id": "exponential-logarithmic-functions", "title": "지수함수와 로그함수", "order": 1, "concepts": [{ "id": "algebra-01-01", "order": 1, "title": "거듭제곱과 거듭제곱근", "standardCode": "12대수01-01", "achievementStandard": "거듭제곱과 거듭제곱근의 뜻을 알고, 그 성질을 이용하여 계산할 수 있다.", "topics": ["거듭제곱과 거듭제곱근", "핵심 의미와 원리", "계산 방법과 절차"], "scopeNotes": ["실수 지수는 밑이 양수인 경우에 한하여 직관적으로 다룬다.", "지수함수와 로그함수는 역함수 관계를 그래프로 확인한다.", "지나치게 복잡한 계산을 포함하는 문제는 다루지 않는다."], "visualizationIdeas": ["지수가 정수에서 유리수와 실수로 촘촘하게 확장되는 수직선 애니메이션", "지수함수와 로그함수가 y=x에 대해 대칭이 되는 역함수 변환", "복리·성장·감쇠 자료를 로그 눈금과 일반 눈금으로 비교하는 인터랙션"] }, { "id": "algebra-01-02", "order": 2, "title": "유리수·실수 지수로의 확장", "standardCode": "12대수01-02", "achievementStandard": "지수가 유리수, 실수까지 확장될 수 있음을 이해하고, 이를 설명할 수 있다.", "topics": ["유리수·실수 지수로의 확장", "핵심 의미와 원리"], "scopeNotes": ["실수 지수는 밑이 양수인 경우에 한하여 직관적으로 다룬다.", "지수함수와 로그함수는 역함수 관계를 그래프로 확인한다.", "지나치게 복잡한 계산을 포함하는 문제는 다루지 않는다."], "visualizationIdeas": ["지수가 정수에서 유리수와 실수로 촘촘하게 확장되는 수직선 애니메이션", "지수함수와 로그함수가 y=x에 대해 대칭이 되는 역함수 변환", "복리·성장·감쇠 자료를 로그 눈금과 일반 눈금으로 비교하는 인터랙션"] }, { "id": "algebra-01-03", "order": 3, "title": "지수법칙", "standardCode": "12대수01-03", "achievementStandard": "지수법칙을 이해하고, 이를 이용하여 식을 간단히 나타낼 수 있다.", "topics": ["지수법칙", "핵심 의미와 원리"], "scopeNotes": ["실수 지수는 밑이 양수인 경우에 한하여 직관적으로 다룬다.", "지수함수와 로그함수는 역함수 관계를 그래프로 확인한다.", "지나치게 복잡한 계산을 포함하는 문제는 다루지 않는다."], "visualizationIdeas": ["지수가 정수에서 유리수와 실수로 촘촘하게 확장되는 수직선 애니메이션", "지수함수와 로그함수가 y=x에 대해 대칭이 되는 역함수 변환", "복리·성장·감쇠 자료를 로그 눈금과 일반 눈금으로 비교하는 인터랙션"] }, { "id": "algebra-01-04", "order": 4, "title": "로그의 뜻과 성질", "standardCode": "12대수01-04", "achievementStandard": "로그의 뜻을 알고, 그 성질을 이용하여 계산할 수 있다.", "topics": ["로그의 뜻과 성질", "핵심 의미와 원리", "계산 방법과 절차"], "scopeNotes": ["실수 지수는 밑이 양수인 경우에 한하여 직관적으로 다룬다.", "지수함수와 로그함수는 역함수 관계를 그래프로 확인한다.", "지나치게 복잡한 계산을 포함하는 문제는 다루지 않는다."], "visualizationIdeas": ["지수가 정수에서 유리수와 실수로 촘촘하게 확장되는 수직선 애니메이션", "지수함수와 로그함수가 y=x에 대해 대칭이 되는 역함수 변환", "복리·성장·감쇠 자료를 로그 눈금과 일반 눈금으로 비교하는 인터랙션"] }, { "id": "algebra-01-05", "order": 5, "title": "상용로그의 활용", "standardCode": "12대수01-05", "achievementStandard": "상용로그를 이해하고, 이를 실생활과 연결하여 문제를 해결할 수 있다.", "topics": ["상용로그의 활용", "핵심 의미와 원리", "적용과 문제 해결"], "scopeNotes": ["실수 지수는 밑이 양수인 경우에 한하여 직관적으로 다룬다.", "지수함수와 로그함수는 역함수 관계를 그래프로 확인한다.", "지나치게 복잡한 계산을 포함하는 문제는 다루지 않는다."], "visualizationIdeas": ["지수가 정수에서 유리수와 실수로 촘촘하게 확장되는 수직선 애니메이션", "지수함수와 로그함수가 y=x에 대해 대칭이 되는 역함수 변환", "복리·성장·감쇠 자료를 로그 눈금과 일반 눈금으로 비교하는 인터랙션"] }, { "id": "algebra-01-06", "order": 6, "title": "지수함수와 로그함수의 뜻", "standardCode": "12대수01-06", "achievementStandard": "지수함수와 로그함수의 뜻을 알고, 이를 설명할 수 있다.", "topics": ["지수함수와 로그함수의 뜻", "핵심 의미와 원리"], "scopeNotes": ["실수 지수는 밑이 양수인 경우에 한하여 직관적으로 다룬다.", "지수함수와 로그함수는 역함수 관계를 그래프로 확인한다.", "지나치게 복잡한 계산을 포함하는 문제는 다루지 않는다."], "visualizationIdeas": ["지수가 정수에서 유리수와 실수로 촘촘하게 확장되는 수직선 애니메이션", "지수함수와 로그함수가 y=x에 대해 대칭이 되는 역함수 변환", "복리·성장·감쇠 자료를 로그 눈금과 일반 눈금으로 비교하는 인터랙션"] }, { "id": "algebra-01-07", "order": 7, "title": "지수함수와 로그함수의 그래프", "standardCode": "12대수01-07", "achievementStandard": "지수함수와 로그함수의 그래프를 그릴 수 있고, 그 성질을 설명할 수 있다.", "topics": ["지수함수와 로그함수의 그래프", "핵심 의미와 원리", "수학적 표현과 해석"], "scopeNotes": ["실수 지수는 밑이 양수인 경우에 한하여 직관적으로 다룬다.", "지수함수와 로그함수는 역함수 관계를 그래프로 확인한다.", "지나치게 복잡한 계산을 포함하는 문제는 다루지 않는다."], "visualizationIdeas": ["지수가 정수에서 유리수와 실수로 촘촘하게 확장되는 수직선 애니메이션", "지수함수와 로그함수가 y=x에 대해 대칭이 되는 역함수 변환", "복리·성장·감쇠 자료를 로그 눈금과 일반 눈금으로 비교하는 인터랙션"] }, { "id": "algebra-01-08", "order": 8, "title": "지수함수와 로그함수의 활용", "standardCode": "12대수01-08", "achievementStandard": "지수함수, 로그함수를 활용하여 문제를 해결할 수 있다.", "topics": ["지수함수와 로그함수의 활용", "적용과 문제 해결"], "scopeNotes": ["실수 지수는 밑이 양수인 경우에 한하여 직관적으로 다룬다.", "지수함수와 로그함수는 역함수 관계를 그래프로 확인한다.", "지나치게 복잡한 계산을 포함하는 문제는 다루지 않는다."], "visualizationIdeas": ["지수가 정수에서 유리수와 실수로 촘촘하게 확장되는 수직선 애니메이션", "지수함수와 로그함수가 y=x에 대해 대칭이 되는 역함수 변환", "복리·성장·감쇠 자료를 로그 눈금과 일반 눈금으로 비교하는 인터랙션"] }], "conceptCount": 8 }, { "id": "trigonometric-functions", "title": "삼각함수", "order": 2, "concepts": [{ "id": "algebra-02-01", "order": 1, "title": "일반각과 호도법", "standardCode": "12대수02-01", "achievementStandard": "일반각과 호도법의 뜻을 알고, 그 관계를 설명할 수 있다.", "topics": ["일반각과 호도법", "핵심 의미와 원리"], "scopeNotes": ["삼각함수는 중학교의 삼각비와 연결하여 이해한다.", "삼각방정식과 부등식은 그래프 해석에 필요한 간단한 경우만 다룬다.", "그래프의 기본 성질 이해에 중점을 두고 지나치게 복잡한 문제는 다루지 않는다."], "visualizationIdeas": ["단위원 위 점의 회전과 사인·코사인·탄젠트 그래프를 동기화", "각도를 도와 라디안으로 동시에 표시하며 호의 길이를 비교", "삼각형의 변과 각을 움직이며 사인법칙·코사인법칙의 불변 관계 표시"] }, { "id": "algebra-02-02", "order": 2, "title": "삼각함수와 그래프", "standardCode": "12대수02-02", "achievementStandard": "삼각함수의 개념을 이해하여 사인함수, 코사인함수, 탄젠트함수의 그래프를 그리고, 그 성질을 설명할 수 있다.", "topics": ["삼각함수와 그래프", "핵심 의미와 원리", "수학적 표현과 해석"], "scopeNotes": ["삼각함수는 중학교의 삼각비와 연결하여 이해한다.", "삼각방정식과 부등식은 그래프 해석에 필요한 간단한 경우만 다룬다.", "그래프의 기본 성질 이해에 중점을 두고 지나치게 복잡한 문제는 다루지 않는다."], "visualizationIdeas": ["단위원 위 점의 회전과 사인·코사인·탄젠트 그래프를 동기화", "각도를 도와 라디안으로 동시에 표시하며 호의 길이를 비교", "삼각형의 변과 각을 움직이며 사인법칙·코사인법칙의 불변 관계 표시"] }, { "id": "algebra-02-03", "order": 3, "title": "사인법칙과 코사인법칙", "standardCode": "12대수02-03", "achievementStandard": "사인법칙과 코사인법칙을 이해하고, 실생활 문제를 해결할 수 있다.", "topics": ["사인법칙과 코사인법칙", "핵심 의미와 원리", "적용과 문제 해결"], "scopeNotes": ["삼각함수는 중학교의 삼각비와 연결하여 이해한다.", "삼각방정식과 부등식은 그래프 해석에 필요한 간단한 경우만 다룬다.", "그래프의 기본 성질 이해에 중점을 두고 지나치게 복잡한 문제는 다루지 않는다."], "visualizationIdeas": ["단위원 위 점의 회전과 사인·코사인·탄젠트 그래프를 동기화", "각도를 도와 라디안으로 동시에 표시하며 호의 길이를 비교", "삼각형의 변과 각을 움직이며 사인법칙·코사인법칙의 불변 관계 표시"] }], "conceptCount": 3 }, { "id": "sequences", "title": "수열", "order": 3, "concepts": [{ "id": "algebra-03-01", "order": 1, "title": "수열의 뜻", "standardCode": "12대수03-01", "achievementStandard": "수열의 뜻을 설명할 수 있다.", "topics": ["수열의 뜻", "핵심 의미와 원리"], "scopeNotes": ["자연수 거듭제곱의 합과 여러 가지 수열의 합은 간단한 경우만 다룬다.", "귀납적으로 정의된 수열의 일반항을 구하는 문제는 다루지 않는다.", "수학적 귀납법은 원리를 이해할 수 있는 간단한 증명을 중심으로 다룬다."], "visualizationIdeas": ["항이 점과 막대로 차례로 생성되며 일반항과 부분합을 동시에 표시", "등차수열은 일정한 높이 증가, 등비수열은 일정한 배율 확대 형태로 비교", "도미노 구조로 수학적 귀납법의 시작 단계와 전이 단계를 표현"] }, { "id": "algebra-03-02", "order": 2, "title": "등차수열", "standardCode": "12대수03-02", "achievementStandard": "등차수열의 뜻을 알고, 일반항과 첫째항부터 제n항까지의 합을 구할 수 있다.", "topics": ["등차수열", "핵심 의미와 원리", "계산 방법과 절차"], "scopeNotes": ["자연수 거듭제곱의 합과 여러 가지 수열의 합은 간단한 경우만 다룬다.", "귀납적으로 정의된 수열의 일반항을 구하는 문제는 다루지 않는다.", "수학적 귀납법은 원리를 이해할 수 있는 간단한 증명을 중심으로 다룬다."], "visualizationIdeas": ["항이 점과 막대로 차례로 생성되며 일반항과 부분합을 동시에 표시", "등차수열은 일정한 높이 증가, 등비수열은 일정한 배율 확대 형태로 비교", "도미노 구조로 수학적 귀납법의 시작 단계와 전이 단계를 표현"] }, { "id": "algebra-03-03", "order": 3, "title": "등비수열", "standardCode": "12대수03-03", "achievementStandard": "등비수열의 뜻을 알고, 일반항과 첫째항부터 제n항까지의 합을 구할 수 있다.", "topics": ["등비수열", "핵심 의미와 원리", "계산 방법과 절차"], "scopeNotes": ["자연수 거듭제곱의 합과 여러 가지 수열의 합은 간단한 경우만 다룬다.", "귀납적으로 정의된 수열의 일반항을 구하는 문제는 다루지 않는다.", "수학적 귀납법은 원리를 이해할 수 있는 간단한 증명을 중심으로 다룬다."], "visualizationIdeas": ["항이 점과 막대로 차례로 생성되며 일반항과 부분합을 동시에 표시", "등차수열은 일정한 높이 증가, 등비수열은 일정한 배율 확대 형태로 비교", "도미노 구조로 수학적 귀납법의 시작 단계와 전이 단계를 표현"] }, { "id": "algebra-03-04", "order": 4, "title": "시그마(Σ)의 뜻과 성질", "standardCode": "12대수03-04", "achievementStandard": "시그마(Σ)의 뜻과 성질을 이해하고, 이를 활용하여 문제를 해결할 수 있다.", "topics": ["시그마(Σ)의 뜻과 성질", "핵심 의미와 원리", "적용과 문제 해결"], "scopeNotes": ["자연수 거듭제곱의 합과 여러 가지 수열의 합은 간단한 경우만 다룬다.", "귀납적으로 정의된 수열의 일반항을 구하는 문제는 다루지 않는다.", "수학적 귀납법은 원리를 이해할 수 있는 간단한 증명을 중심으로 다룬다."], "visualizationIdeas": ["항이 점과 막대로 차례로 생성되며 일반항과 부분합을 동시에 표시", "등차수열은 일정한 높이 증가, 등비수열은 일정한 배율 확대 형태로 비교", "도미노 구조로 수학적 귀납법의 시작 단계와 전이 단계를 표현"] }, { "id": "algebra-03-05", "order": 5, "title": "여러 가지 수열의 합", "standardCode": "12대수03-05", "achievementStandard": "여러 가지 수열의 첫째항부터 제n항까지의 합을 구하는 방법을 설명할 수 있다.", "topics": ["여러 가지 수열의 합", "핵심 의미와 원리"], "scopeNotes": ["자연수 거듭제곱의 합과 여러 가지 수열의 합은 간단한 경우만 다룬다.", "귀납적으로 정의된 수열의 일반항을 구하는 문제는 다루지 않는다.", "수학적 귀납법은 원리를 이해할 수 있는 간단한 증명을 중심으로 다룬다."], "visualizationIdeas": ["항이 점과 막대로 차례로 생성되며 일반항과 부분합을 동시에 표시", "등차수열은 일정한 높이 증가, 등비수열은 일정한 배율 확대 형태로 비교", "도미노 구조로 수학적 귀납법의 시작 단계와 전이 단계를 표현"] }, { "id": "algebra-03-06", "order": 6, "title": "수열의 귀납적 정의", "standardCode": "12대수03-06", "achievementStandard": "수열의 귀납적 정의를 설명할 수 있다.", "topics": ["수열의 귀납적 정의", "핵심 의미와 원리"], "scopeNotes": ["자연수 거듭제곱의 합과 여러 가지 수열의 합은 간단한 경우만 다룬다.", "귀납적으로 정의된 수열의 일반항을 구하는 문제는 다루지 않는다.", "수학적 귀납법은 원리를 이해할 수 있는 간단한 증명을 중심으로 다룬다."], "visualizationIdeas": ["항이 점과 막대로 차례로 생성되며 일반항과 부분합을 동시에 표시", "등차수열은 일정한 높이 증가, 등비수열은 일정한 배율 확대 형태로 비교", "도미노 구조로 수학적 귀납법의 시작 단계와 전이 단계를 표현"] }, { "id": "algebra-03-07", "order": 7, "title": "수학적 귀납법", "standardCode": "12대수03-07", "achievementStandard": "수학적 귀납법의 원리를 이해하고, 이를 이용하여 명제를 증명할 수 있다.", "topics": ["수학적 귀납법", "핵심 의미와 원리"], "scopeNotes": ["자연수 거듭제곱의 합과 여러 가지 수열의 합은 간단한 경우만 다룬다.", "귀납적으로 정의된 수열의 일반항을 구하는 문제는 다루지 않는다.", "수학적 귀납법은 원리를 이해할 수 있는 간단한 증명을 중심으로 다룬다."], "visualizationIdeas": ["항이 점과 막대로 차례로 생성되며 일반항과 부분합을 동시에 표시", "등차수열은 일정한 높이 증가, 등비수열은 일정한 배율 확대 형태로 비교", "도미노 구조로 수학적 귀납법의 시작 단계와 전이 단계를 표현"] }], "conceptCount": 7 }], "categoryEnglishTitle": "GENERAL ELECTIVE", "categoryDescription": "대학 학습과 진로의 기초가 되는 주요 선택 과목입니다.", "categoryOrder": 2, "placementLabel": "학교별 개설·편성", "sourceFile": "kr-2022-algebra.yaml", "developmentLocked": false }, { "id": "calculus-1", "officialTitle": "미적분Ⅰ", "category": "general-elective", "categoryTitle": "일반 선택", "recommendedGrades": [11, 12], "prerequisites": ["common-math-1", "common-math-2"], "defaultSemester": "school-defined", "conceptCount": 20, "units": [{ "id": "limits-and-continuity", "title": "함수의 극한과 연속", "order": 1, "concepts": [{ "id": "calculus-1-01-01", "order": 1, "title": "함수의 극한", "standardCode": "12미적Ⅰ-01-01", "achievementStandard": "함수의 극한의 뜻을 알고, 이를 설명할 수 있다.", "topics": ["함수의 극한", "핵심 의미와 원리"], "scopeNotes": ["극한과 연속의 뜻과 성질은 그래프를 통해 직관적으로 이해한다.", "복잡한 합성함수나 절댓값이 여러 개 포함된 함수는 다루지 않는다."], "visualizationIdeas": ["점이 좌우에서 한 점에 접근할 때 함수값과 극한값을 동시 표시", "그래프의 끊김·점프·구멍을 움직이며 연속 조건을 비교", "사잇값 정리를 움직이는 수평선과 교점으로 표현"] }, { "id": "calculus-1-01-02", "order": 2, "title": "극한의 성질과 계산", "standardCode": "12미적Ⅰ-01-02", "achievementStandard": "함수의 극한에 대한 성질을 이해하고, 함수의 극한값을 구할 수 있다.", "topics": ["극한의 성질과 계산", "핵심 의미와 원리", "계산 방법과 절차"], "scopeNotes": ["극한과 연속의 뜻과 성질은 그래프를 통해 직관적으로 이해한다.", "복잡한 합성함수나 절댓값이 여러 개 포함된 함수는 다루지 않는다."], "visualizationIdeas": ["점이 좌우에서 한 점에 접근할 때 함수값과 극한값을 동시 표시", "그래프의 끊김·점프·구멍을 움직이며 연속 조건을 비교", "사잇값 정리를 움직이는 수평선과 교점으로 표현"] }, { "id": "calculus-1-01-03", "order": 3, "title": "함수의 연속", "standardCode": "12미적Ⅰ-01-03", "achievementStandard": "함수의 연속을 극한으로 탐구하고 이해한다.", "topics": ["함수의 연속", "핵심 의미와 원리", "탐구 설계와 수행"], "scopeNotes": ["극한과 연속의 뜻과 성질은 그래프를 통해 직관적으로 이해한다.", "복잡한 합성함수나 절댓값이 여러 개 포함된 함수는 다루지 않는다."], "visualizationIdeas": ["점이 좌우에서 한 점에 접근할 때 함수값과 극한값을 동시 표시", "그래프의 끊김·점프·구멍을 움직이며 연속 조건을 비교", "사잇값 정리를 움직이는 수평선과 교점으로 표현"] }, { "id": "calculus-1-01-04", "order": 4, "title": "연속함수의 성질", "standardCode": "12미적Ⅰ-01-04", "achievementStandard": "연속함수의 성질을 이해하고, 이를 활용하여 문제를 해결할 수 있다.", "topics": ["연속함수의 성질", "핵심 의미와 원리", "적용과 문제 해결"], "scopeNotes": ["극한과 연속의 뜻과 성질은 그래프를 통해 직관적으로 이해한다.", "복잡한 합성함수나 절댓값이 여러 개 포함된 함수는 다루지 않는다."], "visualizationIdeas": ["점이 좌우에서 한 점에 접근할 때 함수값과 극한값을 동시 표시", "그래프의 끊김·점프·구멍을 움직이며 연속 조건을 비교", "사잇값 정리를 움직이는 수평선과 교점으로 표현"] }], "conceptCount": 4 }, { "id": "differentiation", "title": "미분", "order": 2, "concepts": [{ "id": "calculus-1-02-01", "order": 1, "title": "미분계수", "standardCode": "12미적Ⅰ-02-01", "achievementStandard": "미분계수를 이해하고, 이를 구할 수 있다.", "topics": ["미분계수", "핵심 의미와 원리", "계산 방법과 절차"], "scopeNotes": ["미분계수는 평균변화율의 극한과 접선의 기울기를 연결하여 다룬다.", "속도와 가속도 문제는 직선 운동에 한하여 다룬다.", "지나치게 복잡한 도함수 계산은 다루지 않는다."], "visualizationIdeas": ["두 점을 잇는 할선이 한 점의 접선으로 수렴하는 애니메이션", "도함수 부호와 원함수의 증가·감소 구간을 색으로 연결", "위치·속도·가속도 그래프를 같은 시간축에 동기화"] }, { "id": "calculus-1-02-02", "order": 2, "title": "미분가능성과 연속성", "standardCode": "12미적Ⅰ-02-02", "achievementStandard": "함수의 미분가능성과 연속성의 관계를 설명하고, 이를 활용할 수 있다.", "topics": ["미분가능성과 연속성", "핵심 의미와 원리", "계산 방법과 절차", "적용과 문제 해결"], "scopeNotes": ["미분계수는 평균변화율의 극한과 접선의 기울기를 연결하여 다룬다.", "속도와 가속도 문제는 직선 운동에 한하여 다룬다.", "지나치게 복잡한 도함수 계산은 다루지 않는다."], "visualizationIdeas": ["두 점을 잇는 할선이 한 점의 접선으로 수렴하는 애니메이션", "도함수 부호와 원함수의 증가·감소 구간을 색으로 연결", "위치·속도·가속도 그래프를 같은 시간축에 동기화"] }, { "id": "calculus-1-02-03", "order": 3, "title": "거듭제곱함수의 도함수", "standardCode": "12미적Ⅰ-02-03", "achievementStandard": "함수 xⁿ(n은 양의 정수)의 도함수를 구할 수 있다.", "topics": ["거듭제곱함수의 도함수", "계산 방법과 절차"], "scopeNotes": ["미분계수는 평균변화율의 극한과 접선의 기울기를 연결하여 다룬다.", "속도와 가속도 문제는 직선 운동에 한하여 다룬다.", "지나치게 복잡한 도함수 계산은 다루지 않는다."], "visualizationIdeas": ["두 점을 잇는 할선이 한 점의 접선으로 수렴하는 애니메이션", "도함수 부호와 원함수의 증가·감소 구간을 색으로 연결", "위치·속도·가속도 그래프를 같은 시간축에 동기화"] }, { "id": "calculus-1-02-04", "order": 4, "title": "다항함수의 미분법", "standardCode": "12미적Ⅰ-02-04", "achievementStandard": "함수의 실수배, 합, 차, 곱의 미분법을 알고, 다항함수의 도함수를 구할 수 있다.", "topics": ["다항함수의 미분법", "계산 방법과 절차"], "scopeNotes": ["미분계수는 평균변화율의 극한과 접선의 기울기를 연결하여 다룬다.", "속도와 가속도 문제는 직선 운동에 한하여 다룬다.", "지나치게 복잡한 도함수 계산은 다루지 않는다."], "visualizationIdeas": ["두 점을 잇는 할선이 한 점의 접선으로 수렴하는 애니메이션", "도함수 부호와 원함수의 증가·감소 구간을 색으로 연결", "위치·속도·가속도 그래프를 같은 시간축에 동기화"] }, { "id": "calculus-1-02-05", "order": 5, "title": "접선의 방정식", "standardCode": "12미적Ⅰ-02-05", "achievementStandard": "미분계수와 접선의 기울기의 관계를 이해하고, 접선의 방정식을 구할 수 있다.", "topics": ["접선의 방정식", "핵심 의미와 원리", "계산 방법과 절차", "수학적 표현과 해석"], "scopeNotes": ["미분계수는 평균변화율의 극한과 접선의 기울기를 연결하여 다룬다.", "속도와 가속도 문제는 직선 운동에 한하여 다룬다.", "지나치게 복잡한 도함수 계산은 다루지 않는다."], "visualizationIdeas": ["두 점을 잇는 할선이 한 점의 접선으로 수렴하는 애니메이션", "도함수 부호와 원함수의 증가·감소 구간을 색으로 연결", "위치·속도·가속도 그래프를 같은 시간축에 동기화"] }, { "id": "calculus-1-02-06", "order": 6, "title": "평균값 정리", "standardCode": "12미적Ⅰ-02-06", "achievementStandard": "함수에 대한 평균값 정리를 설명하고, 이를 활용할 수 있다.", "topics": ["평균값 정리", "핵심 의미와 원리", "적용과 문제 해결"], "scopeNotes": ["미분계수는 평균변화율의 극한과 접선의 기울기를 연결하여 다룬다.", "속도와 가속도 문제는 직선 운동에 한하여 다룬다.", "지나치게 복잡한 도함수 계산은 다루지 않는다."], "visualizationIdeas": ["두 점을 잇는 할선이 한 점의 접선으로 수렴하는 애니메이션", "도함수 부호와 원함수의 증가·감소 구간을 색으로 연결", "위치·속도·가속도 그래프를 같은 시간축에 동기화"] }, { "id": "calculus-1-02-07", "order": 7, "title": "함수의 증가·감소와 극값", "standardCode": "12미적Ⅰ-02-07", "achievementStandard": "함수의 증가와 감소, 극대와 극소를 판정하고 설명할 수 있다.", "topics": ["함수의 증가·감소와 극값", "핵심 의미와 원리"], "scopeNotes": ["미분계수는 평균변화율의 극한과 접선의 기울기를 연결하여 다룬다.", "속도와 가속도 문제는 직선 운동에 한하여 다룬다.", "지나치게 복잡한 도함수 계산은 다루지 않는다."], "visualizationIdeas": ["두 점을 잇는 할선이 한 점의 접선으로 수렴하는 애니메이션", "도함수 부호와 원함수의 증가·감소 구간을 색으로 연결", "위치·속도·가속도 그래프를 같은 시간축에 동기화"] }, { "id": "calculus-1-02-08", "order": 8, "title": "함수 그래프의 개형", "standardCode": "12미적Ⅰ-02-08", "achievementStandard": "함수의 그래프의 개형을 그릴 수 있다.", "topics": ["함수 그래프의 개형", "수학적 표현과 해석"], "scopeNotes": ["미분계수는 평균변화율의 극한과 접선의 기울기를 연결하여 다룬다.", "속도와 가속도 문제는 직선 운동에 한하여 다룬다.", "지나치게 복잡한 도함수 계산은 다루지 않는다."], "visualizationIdeas": ["두 점을 잇는 할선이 한 점의 접선으로 수렴하는 애니메이션", "도함수 부호와 원함수의 증가·감소 구간을 색으로 연결", "위치·속도·가속도 그래프를 같은 시간축에 동기화"] }, { "id": "calculus-1-02-09", "order": 9, "title": "미분과 방정식·부등식", "standardCode": "12미적Ⅰ-02-09", "achievementStandard": "방정식과 부등식에 대한 문제를 해결할 수 있다.", "topics": ["미분과 방정식·부등식", "수학적 표현과 해석", "적용과 문제 해결"], "scopeNotes": ["미분계수는 평균변화율의 극한과 접선의 기울기를 연결하여 다룬다.", "속도와 가속도 문제는 직선 운동에 한하여 다룬다.", "지나치게 복잡한 도함수 계산은 다루지 않는다."], "visualizationIdeas": ["두 점을 잇는 할선이 한 점의 접선으로 수렴하는 애니메이션", "도함수 부호와 원함수의 증가·감소 구간을 색으로 연결", "위치·속도·가속도 그래프를 같은 시간축에 동기화"] }, { "id": "calculus-1-02-10", "order": 10, "title": "속도와 가속도", "standardCode": "12미적Ⅰ-02-10", "achievementStandard": "미분을 속도와 가속도에 대한 문제에 활용하고, 그 유용성을 인식할 수 있다.", "topics": ["속도와 가속도", "계산 방법과 절차", "적용과 문제 해결"], "scopeNotes": ["미분계수는 평균변화율의 극한과 접선의 기울기를 연결하여 다룬다.", "속도와 가속도 문제는 직선 운동에 한하여 다룬다.", "지나치게 복잡한 도함수 계산은 다루지 않는다."], "visualizationIdeas": ["두 점을 잇는 할선이 한 점의 접선으로 수렴하는 애니메이션", "도함수 부호와 원함수의 증가·감소 구간을 색으로 연결", "위치·속도·가속도 그래프를 같은 시간축에 동기화"] }], "conceptCount": 10 }, { "id": "integration", "title": "적분", "order": 3, "concepts": [{ "id": "calculus-1-03-01", "order": 1, "title": "부정적분", "standardCode": "12미적Ⅰ-03-01", "achievementStandard": "부정적분의 뜻을 알고, 이를 설명할 수 있다.", "topics": ["부정적분", "핵심 의미와 원리", "계산 방법과 절차"], "scopeNotes": ["정적분은 넓이에서 출발하여 일반적인 연속함수의 경우로 확장한다.", "위치·속도·거리 문제는 직선 운동에 한하여 다룬다.", "정적분 활용에서 지나치게 복잡한 문제는 다루지 않는다."], "visualizationIdeas": ["곡선 아래 직사각형 분할이 촘촘해지며 넓이가 정적분으로 수렴", "미분과 적분을 변화율과 누적량의 반대 과정으로 왕복 표현", "속도 그래프 아래 부호 있는 넓이가 변위로 누적되는 애니메이션"] }, { "id": "calculus-1-03-02", "order": 2, "title": "다항함수의 부정적분", "standardCode": "12미적Ⅰ-03-02", "achievementStandard": "함수의 실수배, 합, 차의 부정적분을 알고, 다항함수의 부정적분을 구할 수 있다.", "topics": ["다항함수의 부정적분", "계산 방법과 절차"], "scopeNotes": ["정적분은 넓이에서 출발하여 일반적인 연속함수의 경우로 확장한다.", "위치·속도·거리 문제는 직선 운동에 한하여 다룬다.", "정적분 활용에서 지나치게 복잡한 문제는 다루지 않는다."], "visualizationIdeas": ["곡선 아래 직사각형 분할이 촘촘해지며 넓이가 정적분으로 수렴", "미분과 적분을 변화율과 누적량의 반대 과정으로 왕복 표현", "속도 그래프 아래 부호 있는 넓이가 변위로 누적되는 애니메이션"] }, { "id": "calculus-1-03-03", "order": 3, "title": "정적분의 개념과 성질", "standardCode": "12미적Ⅰ-03-03", "achievementStandard": "정적분의 개념을 탐구하고, 그 성질을 이해한다.", "topics": ["정적분의 개념과 성질", "핵심 의미와 원리", "계산 방법과 절차", "탐구 설계와 수행"], "scopeNotes": ["정적분은 넓이에서 출발하여 일반적인 연속함수의 경우로 확장한다.", "위치·속도·거리 문제는 직선 운동에 한하여 다룬다.", "정적분 활용에서 지나치게 복잡한 문제는 다루지 않는다."], "visualizationIdeas": ["곡선 아래 직사각형 분할이 촘촘해지며 넓이가 정적분으로 수렴", "미분과 적분을 변화율과 누적량의 반대 과정으로 왕복 표현", "속도 그래프 아래 부호 있는 넓이가 변위로 누적되는 애니메이션"] }, { "id": "calculus-1-03-04", "order": 4, "title": "부정적분과 정적분의 관계", "standardCode": "12미적Ⅰ-03-04", "achievementStandard": "부정적분과 정적분의 관계를 이해하고, 다항함수의 정적분을 구할 수 있다.", "topics": ["부정적분과 정적분의 관계", "핵심 의미와 원리", "계산 방법과 절차"], "scopeNotes": ["정적분은 넓이에서 출발하여 일반적인 연속함수의 경우로 확장한다.", "위치·속도·거리 문제는 직선 운동에 한하여 다룬다.", "정적분 활용에서 지나치게 복잡한 문제는 다루지 않는다."], "visualizationIdeas": ["곡선 아래 직사각형 분할이 촘촘해지며 넓이가 정적분으로 수렴", "미분과 적분을 변화율과 누적량의 반대 과정으로 왕복 표현", "속도 그래프 아래 부호 있는 넓이가 변위로 누적되는 애니메이션"] }, { "id": "calculus-1-03-05", "order": 5, "title": "정적분과 넓이", "standardCode": "12미적Ⅰ-03-05", "achievementStandard": "곡선으로 둘러싸인 도형의 넓이에 대한 문제를 해결할 수 있다.", "topics": ["정적분과 넓이", "적용과 문제 해결"], "scopeNotes": ["정적분은 넓이에서 출발하여 일반적인 연속함수의 경우로 확장한다.", "위치·속도·거리 문제는 직선 운동에 한하여 다룬다.", "정적분 활용에서 지나치게 복잡한 문제는 다루지 않는다."], "visualizationIdeas": ["곡선 아래 직사각형 분할이 촘촘해지며 넓이가 정적분으로 수렴", "미분과 적분을 변화율과 누적량의 반대 과정으로 왕복 표현", "속도 그래프 아래 부호 있는 넓이가 변위로 누적되는 애니메이션"] }, { "id": "calculus-1-03-06", "order": 6, "title": "적분과 속도·거리", "standardCode": "12미적Ⅰ-03-06", "achievementStandard": "적분을 속도와 거리에 대한 문제에 활용하고, 그 유용성을 인식할 수 있다.", "topics": ["적분과 속도·거리", "계산 방법과 절차", "적용과 문제 해결"], "scopeNotes": ["정적분은 넓이에서 출발하여 일반적인 연속함수의 경우로 확장한다.", "위치·속도·거리 문제는 직선 운동에 한하여 다룬다.", "정적분 활용에서 지나치게 복잡한 문제는 다루지 않는다."], "visualizationIdeas": ["곡선 아래 직사각형 분할이 촘촘해지며 넓이가 정적분으로 수렴", "미분과 적분을 변화율과 누적량의 반대 과정으로 왕복 표현", "속도 그래프 아래 부호 있는 넓이가 변위로 누적되는 애니메이션"] }], "conceptCount": 6 }], "categoryEnglishTitle": "GENERAL ELECTIVE", "categoryDescription": "대학 학습과 진로의 기초가 되는 주요 선택 과목입니다.", "categoryOrder": 2, "placementLabel": "학교별 개설·편성", "sourceFile": "kr-2022-calculus-1.yaml", "developmentLocked": false }, { "id": "probability-statistics", "officialTitle": "확률과 통계", "category": "general-elective", "categoryTitle": "일반 선택", "recommendedGrades": [11, 12], "prerequisites": ["common-math-1", "common-math-2"], "defaultSemester": "school-defined", "conceptCount": 16, "units": [{ "id": "counting", "title": "경우의 수", "order": 1, "concepts": [{ "id": "probability-statistics-01-01", "order": 1, "title": "중복순열과 같은 것이 있는 순열", "standardCode": "12확통01-01", "achievementStandard": "중복순열, 같은 것이 있는 순열을 이해하고, 그 순열의 수를 구하는 방법을 설명할 수 있다.", "topics": ["중복순열과 같은 것이 있는 순열", "핵심 의미와 원리"], "scopeNotes": ["공통수학1의 경우의 수와 연결되는 내용은 필요한 경우 간단히 다룬다.", "항이 세 개 이상인 다항정리와 허수단위가 포함된 이항정리는 다루지 않는다."], "visualizationIdeas": ["선택 과정을 가지로 펼쳐 중복 허용 여부에 따른 경우의 수 비교", "같은 대상의 자리 교환을 접어 중복 제거 과정을 표현", "파스칼의 삼각형과 이항계수가 동시에 생성되는 애니메이션"] }, { "id": "probability-statistics-01-02", "order": 2, "title": "중복조합", "standardCode": "12확통01-02", "achievementStandard": "중복조합을 이해하고, 중복조합의 수를 구하는 방법을 설명할 수 있다.", "topics": ["중복조합", "핵심 의미와 원리"], "scopeNotes": ["공통수학1의 경우의 수와 연결되는 내용은 필요한 경우 간단히 다룬다.", "항이 세 개 이상인 다항정리와 허수단위가 포함된 이항정리는 다루지 않는다."], "visualizationIdeas": ["선택 과정을 가지로 펼쳐 중복 허용 여부에 따른 경우의 수 비교", "같은 대상의 자리 교환을 접어 중복 제거 과정을 표현", "파스칼의 삼각형과 이항계수가 동시에 생성되는 애니메이션"] }, { "id": "probability-statistics-01-03", "order": 3, "title": "이항정리", "standardCode": "12확통01-03", "achievementStandard": "이항정리를 이해하고, 이를 활용하여 문제를 해결할 수 있다.", "topics": ["이항정리", "핵심 의미와 원리", "적용과 문제 해결"], "scopeNotes": ["공통수학1의 경우의 수와 연결되는 내용은 필요한 경우 간단히 다룬다.", "항이 세 개 이상인 다항정리와 허수단위가 포함된 이항정리는 다루지 않는다."], "visualizationIdeas": ["선택 과정을 가지로 펼쳐 중복 허용 여부에 따른 경우의 수 비교", "같은 대상의 자리 교환을 접어 중복 제거 과정을 표현", "파스칼의 삼각형과 이항계수가 동시에 생성되는 애니메이션"] }], "conceptCount": 3 }, { "id": "probability", "title": "확률", "order": 2, "concepts": [{ "id": "probability-statistics-02-01", "order": 1, "title": "확률의 개념과 기본 성질", "standardCode": "12확통02-01", "achievementStandard": "확률의 개념을 이해하고 기본 성질을 설명할 수 있다.", "topics": ["확률의 개념과 기본 성질", "핵심 의미와 원리"], "scopeNotes": ["통계적 확률과 수학적 확률을 함께 사용하여 확률 개념을 도입한다.", "조건부확률을 시간적 순서나 인과관계로 오해하지 않도록 한다.", "세 사건 이상의 복잡한 배반·독립 문제는 다루지 않는다."], "visualizationIdeas": ["반복 시행의 상대도수가 이론적 확률에 가까워지는 시뮬레이션", "벤다이어그램의 겹침과 넓이로 덧셈정리·여사건 표현", "표본공간이 조건에 따라 축소되는 장면으로 조건부확률 설명"] }, { "id": "probability-statistics-02-02", "order": 2, "title": "확률의 덧셈정리", "standardCode": "12확통02-02", "achievementStandard": "확률의 덧셈정리를 이해하고, 이를 활용하여 문제를 해결할 수 있다.", "topics": ["확률의 덧셈정리", "핵심 의미와 원리", "적용과 문제 해결"], "scopeNotes": ["통계적 확률과 수학적 확률을 함께 사용하여 확률 개념을 도입한다.", "조건부확률을 시간적 순서나 인과관계로 오해하지 않도록 한다.", "세 사건 이상의 복잡한 배반·독립 문제는 다루지 않는다."], "visualizationIdeas": ["반복 시행의 상대도수가 이론적 확률에 가까워지는 시뮬레이션", "벤다이어그램의 겹침과 넓이로 덧셈정리·여사건 표현", "표본공간이 조건에 따라 축소되는 장면으로 조건부확률 설명"] }, { "id": "probability-statistics-02-03", "order": 3, "title": "여사건의 확률", "standardCode": "12확통02-03", "achievementStandard": "여사건의 확률을 이해하고, 이를 활용하여 문제를 해결할 수 있다.", "topics": ["여사건의 확률", "핵심 의미와 원리", "적용과 문제 해결"], "scopeNotes": ["통계적 확률과 수학적 확률을 함께 사용하여 확률 개념을 도입한다.", "조건부확률을 시간적 순서나 인과관계로 오해하지 않도록 한다.", "세 사건 이상의 복잡한 배반·독립 문제는 다루지 않는다."], "visualizationIdeas": ["반복 시행의 상대도수가 이론적 확률에 가까워지는 시뮬레이션", "벤다이어그램의 겹침과 넓이로 덧셈정리·여사건 표현", "표본공간이 조건에 따라 축소되는 장면으로 조건부확률 설명"] }, { "id": "probability-statistics-02-04", "order": 4, "title": "조건부확률", "standardCode": "12확통02-04", "achievementStandard": "조건부확률을 이해하고, 이를 실생활과 연결하여 문제를 해결할 수 있다.", "topics": ["조건부확률", "핵심 의미와 원리", "적용과 문제 해결"], "scopeNotes": ["통계적 확률과 수학적 확률을 함께 사용하여 확률 개념을 도입한다.", "조건부확률을 시간적 순서나 인과관계로 오해하지 않도록 한다.", "세 사건 이상의 복잡한 배반·독립 문제는 다루지 않는다."], "visualizationIdeas": ["반복 시행의 상대도수가 이론적 확률에 가까워지는 시뮬레이션", "벤다이어그램의 겹침과 넓이로 덧셈정리·여사건 표현", "표본공간이 조건에 따라 축소되는 장면으로 조건부확률 설명"] }, { "id": "probability-statistics-02-05", "order": 5, "title": "사건의 독립과 종속", "standardCode": "12확통02-05", "achievementStandard": "사건의 독립과 종속을 이해하고, 이를 판단할 수 있다.", "topics": ["사건의 독립과 종속", "핵심 의미와 원리"], "scopeNotes": ["통계적 확률과 수학적 확률을 함께 사용하여 확률 개념을 도입한다.", "조건부확률을 시간적 순서나 인과관계로 오해하지 않도록 한다.", "세 사건 이상의 복잡한 배반·독립 문제는 다루지 않는다."], "visualizationIdeas": ["반복 시행의 상대도수가 이론적 확률에 가까워지는 시뮬레이션", "벤다이어그램의 겹침과 넓이로 덧셈정리·여사건 표현", "표본공간이 조건에 따라 축소되는 장면으로 조건부확률 설명"] }, { "id": "probability-statistics-02-06", "order": 6, "title": "확률의 곱셈정리", "standardCode": "12확통02-06", "achievementStandard": "확률의 곱셈정리를 이해하고, 이를 활용하여 문제를 해결할 수 있다.", "topics": ["확률의 곱셈정리", "핵심 의미와 원리", "적용과 문제 해결"], "scopeNotes": ["통계적 확률과 수학적 확률을 함께 사용하여 확률 개념을 도입한다.", "조건부확률을 시간적 순서나 인과관계로 오해하지 않도록 한다.", "세 사건 이상의 복잡한 배반·독립 문제는 다루지 않는다."], "visualizationIdeas": ["반복 시행의 상대도수가 이론적 확률에 가까워지는 시뮬레이션", "벤다이어그램의 겹침과 넓이로 덧셈정리·여사건 표현", "표본공간이 조건에 따라 축소되는 장면으로 조건부확률 설명"] }], "conceptCount": 6 }, { "id": "statistics", "title": "통계", "order": 3, "concepts": [{ "id": "probability-statistics-03-01", "order": 1, "title": "확률변수와 확률분포", "standardCode": "12확통03-01", "achievementStandard": "확률변수와 확률분포의 뜻을 설명할 수 있다.", "topics": ["확률변수와 확률분포", "핵심 의미와 원리"], "scopeNotes": ["이항분포 평균과 분산 공식을 증명하는 문제는 다루지 않는다.", "모평균 추정은 모집단이 정규분포인 경우, 모비율 추정은 표본 크기가 큰 경우를 다룬다.", "복잡한 신뢰구간 계산보다 결과의 의미와 해석에 중점을 둔다."], "visualizationIdeas": ["확률질량이 막대 높이로 배치되고 기댓값이 무게중심으로 이동", "이항분포의 시행 횟수가 커질수록 정규곡선에 가까워지는 애니메이션", "여러 표본의 평균과 비율이 표집분포를 형성하는 시뮬레이션"] }, { "id": "probability-statistics-03-02", "order": 2, "title": "이산확률변수의 기댓값과 표준편차", "standardCode": "12확통03-02", "achievementStandard": "이산확률변수의 기댓값(평균)과 표준편차를 구할 수 있다.", "topics": ["이산확률변수의 기댓값과 표준편차", "계산 방법과 절차", "수학적 표현과 해석"], "scopeNotes": ["이항분포 평균과 분산 공식을 증명하는 문제는 다루지 않는다.", "모평균 추정은 모집단이 정규분포인 경우, 모비율 추정은 표본 크기가 큰 경우를 다룬다.", "복잡한 신뢰구간 계산보다 결과의 의미와 해석에 중점을 둔다."], "visualizationIdeas": ["확률질량이 막대 높이로 배치되고 기댓값이 무게중심으로 이동", "이항분포의 시행 횟수가 커질수록 정규곡선에 가까워지는 애니메이션", "여러 표본의 평균과 비율이 표집분포를 형성하는 시뮬레이션"] }, { "id": "probability-statistics-03-03", "order": 3, "title": "이항분포", "standardCode": "12확통03-03", "achievementStandard": "이항분포의 뜻과 성질을 이해하고, 평균과 표준편차를 구할 수 있다.", "topics": ["이항분포", "핵심 의미와 원리", "계산 방법과 절차", "수학적 표현과 해석"], "scopeNotes": ["이항분포 평균과 분산 공식을 증명하는 문제는 다루지 않는다.", "모평균 추정은 모집단이 정규분포인 경우, 모비율 추정은 표본 크기가 큰 경우를 다룬다.", "복잡한 신뢰구간 계산보다 결과의 의미와 해석에 중점을 둔다."], "visualizationIdeas": ["확률질량이 막대 높이로 배치되고 기댓값이 무게중심으로 이동", "이항분포의 시행 횟수가 커질수록 정규곡선에 가까워지는 애니메이션", "여러 표본의 평균과 비율이 표집분포를 형성하는 시뮬레이션"] }, { "id": "probability-statistics-03-04", "order": 4, "title": "정규분포와 이항분포의 관계", "standardCode": "12확통03-04", "achievementStandard": "정규분포의 뜻과 성질을 이해하고, 이항분포와의 관계를 설명할 수 있다.", "topics": ["정규분포와 이항분포의 관계", "핵심 의미와 원리"], "scopeNotes": ["이항분포 평균과 분산 공식을 증명하는 문제는 다루지 않는다.", "모평균 추정은 모집단이 정규분포인 경우, 모비율 추정은 표본 크기가 큰 경우를 다룬다.", "복잡한 신뢰구간 계산보다 결과의 의미와 해석에 중점을 둔다."], "visualizationIdeas": ["확률질량이 막대 높이로 배치되고 기댓값이 무게중심으로 이동", "이항분포의 시행 횟수가 커질수록 정규곡선에 가까워지는 애니메이션", "여러 표본의 평균과 비율이 표집분포를 형성하는 시뮬레이션"] }, { "id": "probability-statistics-03-05", "order": 5, "title": "모집단과 표본추출", "standardCode": "12확통03-05", "achievementStandard": "모집단과 표본의 뜻을 알고, 표본추출의 방법을 설명할 수 있다.", "topics": ["모집단과 표본추출", "핵심 의미와 원리", "수학적 표현과 해석"], "scopeNotes": ["이항분포 평균과 분산 공식을 증명하는 문제는 다루지 않는다.", "모평균 추정은 모집단이 정규분포인 경우, 모비율 추정은 표본 크기가 큰 경우를 다룬다.", "복잡한 신뢰구간 계산보다 결과의 의미와 해석에 중점을 둔다."], "visualizationIdeas": ["확률질량이 막대 높이로 배치되고 기댓값이 무게중심으로 이동", "이항분포의 시행 횟수가 커질수록 정규곡선에 가까워지는 애니메이션", "여러 표본의 평균과 비율이 표집분포를 형성하는 시뮬레이션"] }, { "id": "probability-statistics-03-06", "order": 6, "title": "표본통계량과 모수의 관계", "standardCode": "12확통03-06", "achievementStandard": "표본평균과 모평균, 표본비율과 모비율의 관계를 이해하고 설명할 수 있다.", "topics": ["표본통계량과 모수의 관계", "핵심 의미와 원리", "수학적 표현과 해석"], "scopeNotes": ["이항분포 평균과 분산 공식을 증명하는 문제는 다루지 않는다.", "모평균 추정은 모집단이 정규분포인 경우, 모비율 추정은 표본 크기가 큰 경우를 다룬다.", "복잡한 신뢰구간 계산보다 결과의 의미와 해석에 중점을 둔다."], "visualizationIdeas": ["확률질량이 막대 높이로 배치되고 기댓값이 무게중심으로 이동", "이항분포의 시행 횟수가 커질수록 정규곡선에 가까워지는 애니메이션", "여러 표본의 평균과 비율이 표집분포를 형성하는 시뮬레이션"] }, { "id": "probability-statistics-03-07", "order": 7, "title": "모평균과 모비율의 추정", "standardCode": "12확통03-07", "achievementStandard": "공학 도구를 이용하여 모평균 및 모비율을 추정하고 그 결과를 해석할 수 있다.", "topics": ["모평균과 모비율의 추정", "핵심 관계"], "scopeNotes": ["이항분포 평균과 분산 공식을 증명하는 문제는 다루지 않는다.", "모평균 추정은 모집단이 정규분포인 경우, 모비율 추정은 표본 크기가 큰 경우를 다룬다.", "복잡한 신뢰구간 계산보다 결과의 의미와 해석에 중점을 둔다."], "visualizationIdeas": ["확률질량이 막대 높이로 배치되고 기댓값이 무게중심으로 이동", "이항분포의 시행 횟수가 커질수록 정규곡선에 가까워지는 애니메이션", "여러 표본의 평균과 비율이 표집분포를 형성하는 시뮬레이션"] }], "conceptCount": 7 }], "categoryEnglishTitle": "GENERAL ELECTIVE", "categoryDescription": "대학 학습과 진로의 기초가 되는 주요 선택 과목입니다.", "categoryOrder": 2, "placementLabel": "학교별 개설·편성", "sourceFile": "kr-2022-probability-statistics.yaml", "developmentLocked": false }] }, { "id": "career-elective", "title": "진로 선택", "englishTitle": "CAREER ELECTIVE", "description": "관심 분야와 진로에 따라 깊이 있게 학습하는 과목입니다.", "order": 3, "courses": [{ "id": "calculus-2", "officialTitle": "미적분Ⅱ", "category": "career-elective", "categoryTitle": "진로 선택", "recommendedGrades": [11, 12], "prerequisites": ["algebra", "calculus-1"], "defaultSemester": "school-defined", "conceptCount": 23, "units": [{ "id": "limits-of-sequences", "title": "수열의 극한", "order": 1, "concepts": [{ "id": "calculus-2-01-01", "order": 1, "title": "수열의 수렴과 발산", "standardCode": "12미적Ⅱ-01-01", "achievementStandard": "수열의 수렴, 발산의 뜻을 알고, 이를 판정할 수 있다.", "topics": ["수열의 수렴과 발산", "핵심 의미와 원리"], "scopeNotes": ["수열과 급수의 수렴·발산을 공학 도구로 탐구할 수 있다.", "지나치게 복잡한 급수 계산은 다루지 않는다."], "visualizationIdeas": ["수열의 항을 수직선과 좌표평면에 동시에 찍어 수렴·발산 비교", "부분합 막대가 일정한 값에 가까워지거나 벗어나는 과정 표현", "무한등비급수를 반복적으로 축소되는 넓이 조각으로 재구성"] }, { "id": "calculus-2-01-02", "order": 2, "title": "수열의 극한 성질", "standardCode": "12미적Ⅱ-01-02", "achievementStandard": "수열의 극한에 대한 성질을 이해하고, 이를 활용하여 극한값을 구하는 방법을 설명할 수 있다.", "topics": ["수열의 극한 성질", "핵심 의미와 원리", "적용과 문제 해결"], "scopeNotes": ["수열과 급수의 수렴·발산을 공학 도구로 탐구할 수 있다.", "지나치게 복잡한 급수 계산은 다루지 않는다."], "visualizationIdeas": ["수열의 항을 수직선과 좌표평면에 동시에 찍어 수렴·발산 비교", "부분합 막대가 일정한 값에 가까워지거나 벗어나는 과정 표현", "무한등비급수를 반복적으로 축소되는 넓이 조각으로 재구성"] }, { "id": "calculus-2-01-03", "order": 3, "title": "등비수열의 극한", "standardCode": "12미적Ⅱ-01-03", "achievementStandard": "등비수열의 수렴, 발산을 판정하고, 수렴하는 경우 그 극한값을 구할 수 있다.", "topics": ["등비수열의 극한", "계산 방법과 절차"], "scopeNotes": ["수열과 급수의 수렴·발산을 공학 도구로 탐구할 수 있다.", "지나치게 복잡한 급수 계산은 다루지 않는다."], "visualizationIdeas": ["수열의 항을 수직선과 좌표평면에 동시에 찍어 수렴·발산 비교", "부분합 막대가 일정한 값에 가까워지거나 벗어나는 과정 표현", "무한등비급수를 반복적으로 축소되는 넓이 조각으로 재구성"] }, { "id": "calculus-2-01-04", "order": 4, "title": "급수의 수렴과 발산", "standardCode": "12미적Ⅱ-01-04", "achievementStandard": "급수의 수렴, 발산의 뜻을 알고, 이를 판정할 수 있다.", "topics": ["급수의 수렴과 발산", "핵심 의미와 원리"], "scopeNotes": ["수열과 급수의 수렴·발산을 공학 도구로 탐구할 수 있다.", "지나치게 복잡한 급수 계산은 다루지 않는다."], "visualizationIdeas": ["수열의 항을 수직선과 좌표평면에 동시에 찍어 수렴·발산 비교", "부분합 막대가 일정한 값에 가까워지거나 벗어나는 과정 표현", "무한등비급수를 반복적으로 축소되는 넓이 조각으로 재구성"] }, { "id": "calculus-2-01-05", "order": 5, "title": "등비급수", "standardCode": "12미적Ⅱ-01-05", "achievementStandard": "등비급수의 합을 구하고, 이를 활용할 수 있다.", "topics": ["등비급수", "적용과 문제 해결"], "scopeNotes": ["수열과 급수의 수렴·발산을 공학 도구로 탐구할 수 있다.", "지나치게 복잡한 급수 계산은 다루지 않는다."], "visualizationIdeas": ["수열의 항을 수직선과 좌표평면에 동시에 찍어 수렴·발산 비교", "부분합 막대가 일정한 값에 가까워지거나 벗어나는 과정 표현", "무한등비급수를 반복적으로 축소되는 넓이 조각으로 재구성"] }], "conceptCount": 5 }, { "id": "advanced-differentiation", "title": "미분법", "order": 2, "concepts": [{ "id": "calculus-2-02-01", "order": 1, "title": "지수함수와 로그함수의 극한·미분", "standardCode": "12미적Ⅱ-02-01", "achievementStandard": "지수함수와 로그함수의 극한을 구하고 미분할 수 있다.", "topics": ["지수함수와 로그함수의 극한·미분", "계산 방법과 절차"], "scopeNotes": ["지수·로그·삼각함수의 극한은 도함수를 구하는 데 필요한 정도로 다룬다.", "매개변수 함수와 음함수는 간단한 경우만 다룬다.", "이계도함수는 볼록성과 변곡점의 기하적 의미와 연결한다."], "visualizationIdeas": ["합성함수를 바깥 함수와 안쪽 함수의 연속 변환으로 분해", "매개변수 변화에 따라 점이 곡선을 그리고 접선 벡터가 움직이는 애니메이션", "일계·이계도함수의 부호와 원함수의 증가·볼록성을 3단 그래프로 연결"] }, { "id": "calculus-2-02-02", "order": 2, "title": "삼각함수의 덧셈정리", "standardCode": "12미적Ⅱ-02-02", "achievementStandard": "삼각함수의 덧셈정리를 설명하고, 이를 활용할 수 있다.", "topics": ["삼각함수의 덧셈정리", "핵심 의미와 원리", "적용과 문제 해결"], "scopeNotes": ["지수·로그·삼각함수의 극한은 도함수를 구하는 데 필요한 정도로 다룬다.", "매개변수 함수와 음함수는 간단한 경우만 다룬다.", "이계도함수는 볼록성과 변곡점의 기하적 의미와 연결한다."], "visualizationIdeas": ["합성함수를 바깥 함수와 안쪽 함수의 연속 변환으로 분해", "매개변수 변화에 따라 점이 곡선을 그리고 접선 벡터가 움직이는 애니메이션", "일계·이계도함수의 부호와 원함수의 증가·볼록성을 3단 그래프로 연결"] }, { "id": "calculus-2-02-03", "order": 3, "title": "삼각함수의 극한·미분", "standardCode": "12미적Ⅱ-02-03", "achievementStandard": "삼각함수의 극한을 구하고, 사인함수와 코사인함수를 미분할 수 있다.", "topics": ["삼각함수의 극한·미분", "계산 방법과 절차"], "scopeNotes": ["지수·로그·삼각함수의 극한은 도함수를 구하는 데 필요한 정도로 다룬다.", "매개변수 함수와 음함수는 간단한 경우만 다룬다.", "이계도함수는 볼록성과 변곡점의 기하적 의미와 연결한다."], "visualizationIdeas": ["합성함수를 바깥 함수와 안쪽 함수의 연속 변환으로 분해", "매개변수 변화에 따라 점이 곡선을 그리고 접선 벡터가 움직이는 애니메이션", "일계·이계도함수의 부호와 원함수의 증가·볼록성을 3단 그래프로 연결"] }, { "id": "calculus-2-02-04", "order": 4, "title": "몫의 미분법", "standardCode": "12미적Ⅱ-02-04", "achievementStandard": "함수의 몫을 미분할 수 있다.", "topics": ["몫의 미분법", "계산 방법과 절차"], "scopeNotes": ["지수·로그·삼각함수의 극한은 도함수를 구하는 데 필요한 정도로 다룬다.", "매개변수 함수와 음함수는 간단한 경우만 다룬다.", "이계도함수는 볼록성과 변곡점의 기하적 의미와 연결한다."], "visualizationIdeas": ["합성함수를 바깥 함수와 안쪽 함수의 연속 변환으로 분해", "매개변수 변화에 따라 점이 곡선을 그리고 접선 벡터가 움직이는 애니메이션", "일계·이계도함수의 부호와 원함수의 증가·볼록성을 3단 그래프로 연결"] }, { "id": "calculus-2-02-05", "order": 5, "title": "합성함수의 미분법", "standardCode": "12미적Ⅱ-02-05", "achievementStandard": "합성함수를 미분할 수 있다.", "topics": ["합성함수의 미분법", "계산 방법과 절차"], "scopeNotes": ["지수·로그·삼각함수의 극한은 도함수를 구하는 데 필요한 정도로 다룬다.", "매개변수 함수와 음함수는 간단한 경우만 다룬다.", "이계도함수는 볼록성과 변곡점의 기하적 의미와 연결한다."], "visualizationIdeas": ["합성함수를 바깥 함수와 안쪽 함수의 연속 변환으로 분해", "매개변수 변화에 따라 점이 곡선을 그리고 접선 벡터가 움직이는 애니메이션", "일계·이계도함수의 부호와 원함수의 증가·볼록성을 3단 그래프로 연결"] }, { "id": "calculus-2-02-06", "order": 6, "title": "매개변수 함수의 미분", "standardCode": "12미적Ⅱ-02-06", "achievementStandard": "매개변수로 나타낸 함수를 미분할 수 있다.", "topics": ["매개변수 함수의 미분", "계산 방법과 절차"], "scopeNotes": ["지수·로그·삼각함수의 극한은 도함수를 구하는 데 필요한 정도로 다룬다.", "매개변수 함수와 음함수는 간단한 경우만 다룬다.", "이계도함수는 볼록성과 변곡점의 기하적 의미와 연결한다."], "visualizationIdeas": ["합성함수를 바깥 함수와 안쪽 함수의 연속 변환으로 분해", "매개변수 변화에 따라 점이 곡선을 그리고 접선 벡터가 움직이는 애니메이션", "일계·이계도함수의 부호와 원함수의 증가·볼록성을 3단 그래프로 연결"] }, { "id": "calculus-2-02-07", "order": 7, "title": "음함수와 역함수의 미분", "standardCode": "12미적Ⅱ-02-07", "achievementStandard": "음함수와 역함수를 미분할 수 있다.", "topics": ["음함수와 역함수의 미분", "계산 방법과 절차"], "scopeNotes": ["지수·로그·삼각함수의 극한은 도함수를 구하는 데 필요한 정도로 다룬다.", "매개변수 함수와 음함수는 간단한 경우만 다룬다.", "이계도함수는 볼록성과 변곡점의 기하적 의미와 연결한다."], "visualizationIdeas": ["합성함수를 바깥 함수와 안쪽 함수의 연속 변환으로 분해", "매개변수 변화에 따라 점이 곡선을 그리고 접선 벡터가 움직이는 애니메이션", "일계·이계도함수의 부호와 원함수의 증가·볼록성을 3단 그래프로 연결"] }, { "id": "calculus-2-02-08", "order": 8, "title": "여러 곡선의 접선", "standardCode": "12미적Ⅱ-02-08", "achievementStandard": "다양한 곡선의 접선의 방정식을 구할 수 있다.", "topics": ["여러 곡선의 접선", "계산 방법과 절차", "수학적 표현과 해석"], "scopeNotes": ["지수·로그·삼각함수의 극한은 도함수를 구하는 데 필요한 정도로 다룬다.", "매개변수 함수와 음함수는 간단한 경우만 다룬다.", "이계도함수는 볼록성과 변곡점의 기하적 의미와 연결한다."], "visualizationIdeas": ["합성함수를 바깥 함수와 안쪽 함수의 연속 변환으로 분해", "매개변수 변화에 따라 점이 곡선을 그리고 접선 벡터가 움직이는 애니메이션", "일계·이계도함수의 부호와 원함수의 증가·볼록성을 3단 그래프로 연결"] }, { "id": "calculus-2-02-09", "order": 9, "title": "이계도함수와 그래프의 개형", "standardCode": "12미적Ⅱ-02-09", "achievementStandard": "함수의 그래프의 개형을 그릴 수 있다.", "topics": ["이계도함수와 그래프의 개형", "수학적 표현과 해석"], "scopeNotes": ["지수·로그·삼각함수의 극한은 도함수를 구하는 데 필요한 정도로 다룬다.", "매개변수 함수와 음함수는 간단한 경우만 다룬다.", "이계도함수는 볼록성과 변곡점의 기하적 의미와 연결한다."], "visualizationIdeas": ["합성함수를 바깥 함수와 안쪽 함수의 연속 변환으로 분해", "매개변수 변화에 따라 점이 곡선을 그리고 접선 벡터가 움직이는 애니메이션", "일계·이계도함수의 부호와 원함수의 증가·볼록성을 3단 그래프로 연결"] }, { "id": "calculus-2-02-10", "order": 10, "title": "미분과 방정식·부등식", "standardCode": "12미적Ⅱ-02-10", "achievementStandard": "방정식과 부등식에 대한 문제를 해결할 수 있다.", "topics": ["미분과 방정식·부등식", "수학적 표현과 해석", "적용과 문제 해결"], "scopeNotes": ["지수·로그·삼각함수의 극한은 도함수를 구하는 데 필요한 정도로 다룬다.", "매개변수 함수와 음함수는 간단한 경우만 다룬다.", "이계도함수는 볼록성과 변곡점의 기하적 의미와 연결한다."], "visualizationIdeas": ["합성함수를 바깥 함수와 안쪽 함수의 연속 변환으로 분해", "매개변수 변화에 따라 점이 곡선을 그리고 접선 벡터가 움직이는 애니메이션", "일계·이계도함수의 부호와 원함수의 증가·볼록성을 3단 그래프로 연결"] }, { "id": "calculus-2-02-11", "order": 11, "title": "미분과 속도·가속도", "standardCode": "12미적Ⅱ-02-11", "achievementStandard": "미분을 속도와 가속도에 대한 문제에 활용하고, 그 유용성을 인식할 수 있다.", "topics": ["미분과 속도·가속도", "계산 방법과 절차", "적용과 문제 해결"], "scopeNotes": ["지수·로그·삼각함수의 극한은 도함수를 구하는 데 필요한 정도로 다룬다.", "매개변수 함수와 음함수는 간단한 경우만 다룬다.", "이계도함수는 볼록성과 변곡점의 기하적 의미와 연결한다."], "visualizationIdeas": ["합성함수를 바깥 함수와 안쪽 함수의 연속 변환으로 분해", "매개변수 변화에 따라 점이 곡선을 그리고 접선 벡터가 움직이는 애니메이션", "일계·이계도함수의 부호와 원함수의 증가·볼록성을 3단 그래프로 연결"] }], "conceptCount": 11 }, { "id": "advanced-integration", "title": "적분법", "order": 3, "concepts": [{ "id": "calculus-2-03-01", "order": 1, "title": "여러 함수의 적분", "standardCode": "12미적Ⅱ-03-01", "achievementStandard": "함수 xᵃ(a는 실수), 지수함수, 삼각함수의 부정적분과 정적분을 구할 수 있다.", "topics": ["여러 함수의 적분", "계산 방법과 절차"], "scopeNotes": ["치환적분법과 부분적분법은 기본 원리와 간단한 활용에 중점을 둔다.", "정적분의 다양한 문제 해결을 통해 적분의 유용성을 인식한다."], "visualizationIdeas": ["좌표축 또는 변수 변환에 따라 같은 넓이가 다른 적분식으로 바뀌는 장면", "곱의 미분법을 역으로 되감아 부분적분 공식을 구성", "회전체를 얇은 원판으로 분할해 부피가 누적되는 애니메이션"] }, { "id": "calculus-2-03-02", "order": 2, "title": "치환적분법", "standardCode": "12미적Ⅱ-03-02", "achievementStandard": "치환적분법을 이해하고, 이를 활용할 수 있다.", "topics": ["치환적분법", "핵심 의미와 원리", "계산 방법과 절차", "적용과 문제 해결"], "scopeNotes": ["치환적분법과 부분적분법은 기본 원리와 간단한 활용에 중점을 둔다.", "정적분의 다양한 문제 해결을 통해 적분의 유용성을 인식한다."], "visualizationIdeas": ["좌표축 또는 변수 변환에 따라 같은 넓이가 다른 적분식으로 바뀌는 장면", "곱의 미분법을 역으로 되감아 부분적분 공식을 구성", "회전체를 얇은 원판으로 분할해 부피가 누적되는 애니메이션"] }, { "id": "calculus-2-03-03", "order": 3, "title": "부분적분법", "standardCode": "12미적Ⅱ-03-03", "achievementStandard": "부분적분법을 이해하고, 이를 활용할 수 있다.", "topics": ["부분적분법", "핵심 의미와 원리", "계산 방법과 절차", "적용과 문제 해결"], "scopeNotes": ["치환적분법과 부분적분법은 기본 원리와 간단한 활용에 중점을 둔다.", "정적분의 다양한 문제 해결을 통해 적분의 유용성을 인식한다."], "visualizationIdeas": ["좌표축 또는 변수 변환에 따라 같은 넓이가 다른 적분식으로 바뀌는 장면", "곱의 미분법을 역으로 되감아 부분적분 공식을 구성", "회전체를 얇은 원판으로 분할해 부피가 누적되는 애니메이션"] }, { "id": "calculus-2-03-04", "order": 4, "title": "정적분과 급수의 관계", "standardCode": "12미적Ⅱ-03-04", "achievementStandard": "정적분과 급수의 합 사이의 관계를 탐구하고 이해한다.", "topics": ["정적분과 급수의 관계", "핵심 의미와 원리", "계산 방법과 절차", "탐구 설계와 수행"], "scopeNotes": ["치환적분법과 부분적분법은 기본 원리와 간단한 활용에 중점을 둔다.", "정적분의 다양한 문제 해결을 통해 적분의 유용성을 인식한다."], "visualizationIdeas": ["좌표축 또는 변수 변환에 따라 같은 넓이가 다른 적분식으로 바뀌는 장면", "곱의 미분법을 역으로 되감아 부분적분 공식을 구성", "회전체를 얇은 원판으로 분할해 부피가 누적되는 애니메이션"] }, { "id": "calculus-2-03-05", "order": 5, "title": "정적분과 넓이", "standardCode": "12미적Ⅱ-03-05", "achievementStandard": "곡선으로 둘러싸인 도형의 넓이에 대한 문제를 해결할 수 있다.", "topics": ["정적분과 넓이", "적용과 문제 해결"], "scopeNotes": ["치환적분법과 부분적분법은 기본 원리와 간단한 활용에 중점을 둔다.", "정적분의 다양한 문제 해결을 통해 적분의 유용성을 인식한다."], "visualizationIdeas": ["좌표축 또는 변수 변환에 따라 같은 넓이가 다른 적분식으로 바뀌는 장면", "곱의 미분법을 역으로 되감아 부분적분 공식을 구성", "회전체를 얇은 원판으로 분할해 부피가 누적되는 애니메이션"] }, { "id": "calculus-2-03-06", "order": 6, "title": "정적분과 부피", "standardCode": "12미적Ⅱ-03-06", "achievementStandard": "입체도형의 부피에 대한 문제를 해결할 수 있다.", "topics": ["정적분과 부피", "적용과 문제 해결"], "scopeNotes": ["치환적분법과 부분적분법은 기본 원리와 간단한 활용에 중점을 둔다.", "정적분의 다양한 문제 해결을 통해 적분의 유용성을 인식한다."], "visualizationIdeas": ["좌표축 또는 변수 변환에 따라 같은 넓이가 다른 적분식으로 바뀌는 장면", "곱의 미분법을 역으로 되감아 부분적분 공식을 구성", "회전체를 얇은 원판으로 분할해 부피가 누적되는 애니메이션"] }, { "id": "calculus-2-03-07", "order": 7, "title": "적분과 속도·거리", "standardCode": "12미적Ⅱ-03-07", "achievementStandard": "적분을 속도와 거리에 대한 문제에 활용하고, 그 유용성을 인식할 수 있다.", "topics": ["적분과 속도·거리", "계산 방법과 절차", "적용과 문제 해결"], "scopeNotes": ["치환적분법과 부분적분법은 기본 원리와 간단한 활용에 중점을 둔다.", "정적분의 다양한 문제 해결을 통해 적분의 유용성을 인식한다."], "visualizationIdeas": ["좌표축 또는 변수 변환에 따라 같은 넓이가 다른 적분식으로 바뀌는 장면", "곱의 미분법을 역으로 되감아 부분적분 공식을 구성", "회전체를 얇은 원판으로 분할해 부피가 누적되는 애니메이션"] }], "conceptCount": 7 }], "categoryEnglishTitle": "CAREER ELECTIVE", "categoryDescription": "관심 분야와 진로에 따라 깊이 있게 학습하는 과목입니다.", "categoryOrder": 3, "placementLabel": "학교별 개설·편성", "sourceFile": "kr-2022-calculus-2.yaml", "developmentLocked": true }, { "id": "geometry", "officialTitle": "기하", "category": "career-elective", "categoryTitle": "진로 선택", "recommendedGrades": [11, 12], "prerequisites": ["common-math-1", "common-math-2"], "defaultSemester": "school-defined", "conceptCount": 14, "units": [{ "id": "conic-sections", "title": "이차곡선", "order": 1, "concepts": [{ "id": "geometry-01-01", "order": 1, "title": "포물선", "standardCode": "12기하01-01", "achievementStandard": "포물선의 뜻을 알고, 포물선을 방정식으로 표현할 수 있다.", "topics": ["포물선", "핵심 의미와 원리", "수학적 표현과 해석"], "scopeNotes": ["이차곡선은 정의와 방정식을 초점·준선·거리 관계와 연결한다.", "이차곡선의 접선은 이차방정식의 판별식을 이용하여 구한다."], "visualizationIdeas": ["원뿔 절단 각도에 따라 원·타원·포물선·쌍곡선이 나타나는 3차원 애니메이션", "점이 움직여도 초점과 준선 또는 두 초점까지 거리 관계가 유지되는 추적", "접선이 곡선과 한 점에서 만나는 조건을 판별식 D=0과 연결"] }, { "id": "geometry-01-02", "order": 2, "title": "타원", "standardCode": "12기하01-02", "achievementStandard": "타원의 뜻을 알고, 타원을 방정식으로 표현할 수 있다.", "topics": ["타원", "핵심 의미와 원리", "수학적 표현과 해석"], "scopeNotes": ["이차곡선은 정의와 방정식을 초점·준선·거리 관계와 연결한다.", "이차곡선의 접선은 이차방정식의 판별식을 이용하여 구한다."], "visualizationIdeas": ["원뿔 절단 각도에 따라 원·타원·포물선·쌍곡선이 나타나는 3차원 애니메이션", "점이 움직여도 초점과 준선 또는 두 초점까지 거리 관계가 유지되는 추적", "접선이 곡선과 한 점에서 만나는 조건을 판별식 D=0과 연결"] }, { "id": "geometry-01-03", "order": 3, "title": "쌍곡선", "standardCode": "12기하01-03", "achievementStandard": "쌍곡선의 뜻을 알고, 쌍곡선을 방정식으로 표현할 수 있다.", "topics": ["쌍곡선", "핵심 의미와 원리", "수학적 표현과 해석"], "scopeNotes": ["이차곡선은 정의와 방정식을 초점·준선·거리 관계와 연결한다.", "이차곡선의 접선은 이차방정식의 판별식을 이용하여 구한다."], "visualizationIdeas": ["원뿔 절단 각도에 따라 원·타원·포물선·쌍곡선이 나타나는 3차원 애니메이션", "점이 움직여도 초점과 준선 또는 두 초점까지 거리 관계가 유지되는 추적", "접선이 곡선과 한 점에서 만나는 조건을 판별식 D=0과 연결"] }, { "id": "geometry-01-04", "order": 4, "title": "이차곡선의 접선", "standardCode": "12기하01-04", "achievementStandard": "이차곡선의 접선의 방정식을 구할 수 있다.", "topics": ["이차곡선의 접선", "계산 방법과 절차", "수학적 표현과 해석"], "scopeNotes": ["이차곡선은 정의와 방정식을 초점·준선·거리 관계와 연결한다.", "이차곡선의 접선은 이차방정식의 판별식을 이용하여 구한다."], "visualizationIdeas": ["원뿔 절단 각도에 따라 원·타원·포물선·쌍곡선이 나타나는 3차원 애니메이션", "점이 움직여도 초점과 준선 또는 두 초점까지 거리 관계가 유지되는 추적", "접선이 곡선과 한 점에서 만나는 조건을 판별식 D=0과 연결"] }], "conceptCount": 4 }, { "id": "solid-geometry-and-coordinates", "title": "공간도형과 공간좌표", "order": 2, "concepts": [{ "id": "geometry-02-01", "order": 1, "title": "공간의 직선과 평면의 위치 관계", "standardCode": "12기하02-01", "achievementStandard": "직선과 직선, 직선과 평면, 평면과 평면의 위치 관계에 대한 간단한 증명을 할 수 있다.", "topics": ["공간의 직선과 평면의 위치 관계", "핵심 관계"], "scopeNotes": ["평면에서 공간으로 차원을 확장하는 원리를 이해하는 데 중점을 둔다.", "위치 관계의 증명은 간단한 경우를 다룬다."], "visualizationIdeas": ["3차원 공간에서 직선과 평면을 회전시켜 평행·교차·수직 관계 관찰", "빛의 방향을 움직이며 정사영의 길이와 넓이 변화 표시", "공간좌표의 두 점과 내분점이 평면 좌표의 원리를 확장하는 장면"] }, { "id": "geometry-02-02", "order": 2, "title": "삼수선 정리", "standardCode": "12기하02-02", "achievementStandard": "삼수선 정리를 이해하고, 이를 활용하여 문제를 해결할 수 있다.", "topics": ["삼수선 정리", "핵심 의미와 원리", "적용과 문제 해결"], "scopeNotes": ["평면에서 공간으로 차원을 확장하는 원리를 이해하는 데 중점을 둔다.", "위치 관계의 증명은 간단한 경우를 다룬다."], "visualizationIdeas": ["3차원 공간에서 직선과 평면을 회전시켜 평행·교차·수직 관계 관찰", "빛의 방향을 움직이며 정사영의 길이와 넓이 변화 표시", "공간좌표의 두 점과 내분점이 평면 좌표의 원리를 확장하는 장면"] }, { "id": "geometry-02-03", "order": 3, "title": "정사영", "standardCode": "12기하02-03", "achievementStandard": "도형의 정사영의 뜻을 알고, 도형과 정사영의 관계를 탐구할 수 있다.", "topics": ["정사영", "핵심 의미와 원리", "계산 방법과 절차", "탐구 설계와 수행"], "scopeNotes": ["평면에서 공간으로 차원을 확장하는 원리를 이해하는 데 중점을 둔다.", "위치 관계의 증명은 간단한 경우를 다룬다."], "visualizationIdeas": ["3차원 공간에서 직선과 평면을 회전시켜 평행·교차·수직 관계 관찰", "빛의 방향을 움직이며 정사영의 길이와 넓이 변화 표시", "공간좌표의 두 점과 내분점이 평면 좌표의 원리를 확장하는 장면"] }, { "id": "geometry-02-04", "order": 4, "title": "공간좌표의 거리와 내분점", "standardCode": "12기하02-04", "achievementStandard": "좌표공간에서 두 점 사이의 거리와 선분의 내분점의 좌표를 구할 수 있다.", "topics": ["공간좌표의 거리와 내분점", "계산 방법과 절차", "수학적 표현과 해석"], "scopeNotes": ["평면에서 공간으로 차원을 확장하는 원리를 이해하는 데 중점을 둔다.", "위치 관계의 증명은 간단한 경우를 다룬다."], "visualizationIdeas": ["3차원 공간에서 직선과 평면을 회전시켜 평행·교차·수직 관계 관찰", "빛의 방향을 움직이며 정사영의 길이와 넓이 변화 표시", "공간좌표의 두 점과 내분점이 평면 좌표의 원리를 확장하는 장면"] }, { "id": "geometry-02-05", "order": 5, "title": "구의 방정식", "standardCode": "12기하02-05", "achievementStandard": "구를 방정식으로 표현할 수 있다.", "topics": ["구의 방정식", "수학적 표현과 해석"], "scopeNotes": ["평면에서 공간으로 차원을 확장하는 원리를 이해하는 데 중점을 둔다.", "위치 관계의 증명은 간단한 경우를 다룬다."], "visualizationIdeas": ["3차원 공간에서 직선과 평면을 회전시켜 평행·교차·수직 관계 관찰", "빛의 방향을 움직이며 정사영의 길이와 넓이 변화 표시", "공간좌표의 두 점과 내분점이 평면 좌표의 원리를 확장하는 장면"] }], "conceptCount": 5 }, { "id": "vectors", "title": "벡터", "order": 3, "concepts": [{ "id": "geometry-03-01", "order": 1, "title": "벡터의 뜻과 연산", "standardCode": "12기하03-01", "achievementStandard": "벡터의 뜻을 알고, 벡터의 덧셈, 뺄셈, 실수배를 할 수 있다.", "topics": ["벡터의 뜻과 연산", "핵심 의미와 원리", "수학적 표현과 해석"], "scopeNotes": ["벡터의 기하적 표현과 좌표를 이용한 대수적 표현을 함께 다룬다.", "직선·평면·구를 벡터로 간결하게 표현하는 의미에 중점을 둔다."], "visualizationIdeas": ["벡터를 평행이동해도 크기와 방향이 유지되는 장면", "벡터의 덧셈을 삼각형법과 평행사변형법으로 동시 표현", "내적이 정사영 길이와 각도에 따라 변하는 인터랙션"] }, { "id": "geometry-03-02", "order": 2, "title": "위치벡터와 좌표", "standardCode": "12기하03-02", "achievementStandard": "위치벡터의 뜻을 알고, 벡터와 좌표를 대응시켜 표현할 수 있다.", "topics": ["위치벡터와 좌표", "핵심 의미와 원리", "수학적 표현과 해석"], "scopeNotes": ["벡터의 기하적 표현과 좌표를 이용한 대수적 표현을 함께 다룬다.", "직선·평면·구를 벡터로 간결하게 표현하는 의미에 중점을 둔다."], "visualizationIdeas": ["벡터를 평행이동해도 크기와 방향이 유지되는 장면", "벡터의 덧셈을 삼각형법과 평행사변형법으로 동시 표현", "내적이 정사영 길이와 각도에 따라 변하는 인터랙션"] }, { "id": "geometry-03-03", "order": 3, "title": "벡터의 내적", "standardCode": "12기하03-03", "achievementStandard": "내적의 뜻을 알고, 두 벡터의 내적을 구할 수 있다.", "topics": ["벡터의 내적", "핵심 의미와 원리", "계산 방법과 절차", "수학적 표현과 해석"], "scopeNotes": ["벡터의 기하적 표현과 좌표를 이용한 대수적 표현을 함께 다룬다.", "직선·평면·구를 벡터로 간결하게 표현하는 의미에 중점을 둔다."], "visualizationIdeas": ["벡터를 평행이동해도 크기와 방향이 유지되는 장면", "벡터의 덧셈을 삼각형법과 평행사변형법으로 동시 표현", "내적이 정사영 길이와 각도에 따라 변하는 인터랙션"] }, { "id": "geometry-03-04", "order": 4, "title": "벡터와 직선의 방정식", "standardCode": "12기하03-04", "achievementStandard": "벡터를 이용하여 직선의 방정식을 구할 수 있다.", "topics": ["벡터와 직선의 방정식", "계산 방법과 절차", "수학적 표현과 해석"], "scopeNotes": ["벡터의 기하적 표현과 좌표를 이용한 대수적 표현을 함께 다룬다.", "직선·평면·구를 벡터로 간결하게 표현하는 의미에 중점을 둔다."], "visualizationIdeas": ["벡터를 평행이동해도 크기와 방향이 유지되는 장면", "벡터의 덧셈을 삼각형법과 평행사변형법으로 동시 표현", "내적이 정사영 길이와 각도에 따라 변하는 인터랙션"] }, { "id": "geometry-03-05", "order": 5, "title": "벡터와 평면·구의 방정식", "standardCode": "12기하03-05", "achievementStandard": "좌표공간에서 벡터를 이용하여 평면의 방정식과 구의 방정식을 구할 수 있다.", "topics": ["벡터와 평면·구의 방정식", "계산 방법과 절차", "수학적 표현과 해석"], "scopeNotes": ["벡터의 기하적 표현과 좌표를 이용한 대수적 표현을 함께 다룬다.", "직선·평면·구를 벡터로 간결하게 표현하는 의미에 중점을 둔다."], "visualizationIdeas": ["벡터를 평행이동해도 크기와 방향이 유지되는 장면", "벡터의 덧셈을 삼각형법과 평행사변형법으로 동시 표현", "내적이 정사영 길이와 각도에 따라 변하는 인터랙션"] }], "conceptCount": 5 }], "categoryEnglishTitle": "CAREER ELECTIVE", "categoryDescription": "관심 분야와 진로에 따라 깊이 있게 학습하는 과목입니다.", "categoryOrder": 3, "placementLabel": "학교별 개설·편성", "sourceFile": "kr-2022-geometry.yaml", "developmentLocked": true }, { "id": "economics-math", "officialTitle": "경제 수학", "category": "career-elective", "categoryTitle": "진로 선택", "recommendedGrades": [11, 12], "prerequisites": ["common-math-1", "common-math-2"], "defaultSemester": "school-defined", "conceptCount": 18, "units": [{ "id": "numbers-and-economics", "title": "수와 경제", "order": 1, "concepts": [{ "id": "economics-math-01-01", "order": 1, "title": "경제지표", "standardCode": "12경수01-01", "achievementStandard": "통계 자료를 활용하여 경제지표의 의미를 이해하고, 경제지표의 변화를 설명할 수 있다.", "topics": ["경제지표", "핵심 의미와 원리", "수학적 표현과 해석", "적용과 문제 해결"], "scopeNotes": ["공식 암기보다 경제 상황에 맞는 수학적 개념과 표현의 선택에 중점을 둔다.", "경제지표·환율·세금·금융상품은 학생 삶과 연결된 구체적 사례로 다룬다.", "미적분Ⅱ 이수자에게는 연속복리를 선택적으로 다룰 수 있다."], "visualizationIdeas": ["물가·환율 지표의 기준 시점과 변화율을 시간축에서 비교", "단리·복리·연속복리의 원리합계 곡선을 같은 축에 중첩", "미래 현금 흐름을 현재 시점으로 할인해 이동시키는 애니메이션"] }, { "id": "economics-math-01-02", "order": 2, "title": "환율", "standardCode": "12경수01-02", "achievementStandard": "환율과 관련된 실생활 문제를 해결할 수 있다.", "topics": ["환율", "적용과 문제 해결"], "scopeNotes": ["공식 암기보다 경제 상황에 맞는 수학적 개념과 표현의 선택에 중점을 둔다.", "경제지표·환율·세금·금융상품은 학생 삶과 연결된 구체적 사례로 다룬다.", "미적분Ⅱ 이수자에게는 연속복리를 선택적으로 다룰 수 있다."], "visualizationIdeas": ["물가·환율 지표의 기준 시점과 변화율을 시간축에서 비교", "단리·복리·연속복리의 원리합계 곡선을 같은 축에 중첩", "미래 현금 흐름을 현재 시점으로 할인해 이동시키는 애니메이션"] }, { "id": "economics-math-01-03", "order": 3, "title": "세금", "standardCode": "12경수01-03", "achievementStandard": "세금과 관련된 실생활 문제를 해결할 수 있다.", "topics": ["세금", "적용과 문제 해결"], "scopeNotes": ["공식 암기보다 경제 상황에 맞는 수학적 개념과 표현의 선택에 중점을 둔다.", "경제지표·환율·세금·금융상품은 학생 삶과 연결된 구체적 사례로 다룬다.", "미적분Ⅱ 이수자에게는 연속복리를 선택적으로 다룰 수 있다."], "visualizationIdeas": ["물가·환율 지표의 기준 시점과 변화율을 시간축에서 비교", "단리·복리·연속복리의 원리합계 곡선을 같은 축에 중첩", "미래 현금 흐름을 현재 시점으로 할인해 이동시키는 애니메이션"] }, { "id": "economics-math-01-04", "order": 4, "title": "이자와 현재가치", "standardCode": "12경수01-04", "achievementStandard": "단리와 복리를 이용하여 이자와 원리합계를 구하고, 미래에 받을 금액의 현재가치를 구할 수 있다.", "topics": ["이자와 현재가치", "계산 방법과 절차"], "scopeNotes": ["공식 암기보다 경제 상황에 맞는 수학적 개념과 표현의 선택에 중점을 둔다.", "경제지표·환율·세금·금융상품은 학생 삶과 연결된 구체적 사례로 다룬다.", "미적분Ⅱ 이수자에게는 연속복리를 선택적으로 다룰 수 있다."], "visualizationIdeas": ["물가·환율 지표의 기준 시점과 변화율을 시간축에서 비교", "단리·복리·연속복리의 원리합계 곡선을 같은 축에 중첩", "미래 현금 흐름을 현재 시점으로 할인해 이동시키는 애니메이션"] }, { "id": "economics-math-01-05", "order": 5, "title": "연금의 현재가치", "standardCode": "12경수01-05", "achievementStandard": "연금의 뜻을 알고, 연금의 현재가치를 구할 수 있다.", "topics": ["연금의 현재가치", "핵심 의미와 원리", "계산 방법과 절차"], "scopeNotes": ["공식 암기보다 경제 상황에 맞는 수학적 개념과 표현의 선택에 중점을 둔다.", "경제지표·환율·세금·금융상품은 학생 삶과 연결된 구체적 사례로 다룬다.", "미적분Ⅱ 이수자에게는 연속복리를 선택적으로 다룰 수 있다."], "visualizationIdeas": ["물가·환율 지표의 기준 시점과 변화율을 시간축에서 비교", "단리·복리·연속복리의 원리합계 곡선을 같은 축에 중첩", "미래 현금 흐름을 현재 시점으로 할인해 이동시키는 애니메이션"] }], "conceptCount": 5 }, { "id": "functions-and-economics", "title": "함수와 경제", "order": 2, "concepts": [{ "id": "economics-math-02-01", "order": 1, "title": "경제 현상과 함수", "standardCode": "12경수02-01", "achievementStandard": "여러 가지 경제 현상을 함수로 나타낼 수 있다.", "topics": ["경제 현상과 함수", "적용과 문제 해결"], "scopeNotes": ["여러 독립변수 중 일부를 고정해 일변수함수로 해석할 수 있음을 이해한다.", "부등식 영역의 최대·최소에서는 경제 관련 함수를 일차식으로 제한한다."], "visualizationIdeas": ["수요·공급곡선이 이동하며 균형가격과 거래량이 바뀌는 애니메이션", "예산 제약선과 효용 수준을 움직이며 선택 가능한 영역 비교", "부등식의 영역을 생산 가능 조합의 색칠된 영역으로 표현"] }, { "id": "economics-math-02-02", "order": 2, "title": "수요곡선과 공급곡선", "standardCode": "12경수02-02", "achievementStandard": "함수와 그래프를 활용하여 수요곡선과 공급곡선의 의미를 탐구하고 이해한다.", "topics": ["수요곡선과 공급곡선", "핵심 의미와 원리", "수학적 표현과 해석", "적용과 문제 해결", "탐구 설계와 수행"], "scopeNotes": ["여러 독립변수 중 일부를 고정해 일변수함수로 해석할 수 있음을 이해한다.", "부등식 영역의 최대·최소에서는 경제 관련 함수를 일차식으로 제한한다."], "visualizationIdeas": ["수요·공급곡선이 이동하며 균형가격과 거래량이 바뀌는 애니메이션", "예산 제약선과 효용 수준을 움직이며 선택 가능한 영역 비교", "부등식의 영역을 생산 가능 조합의 색칠된 영역으로 표현"] }, { "id": "economics-math-02-03", "order": 3, "title": "효용함수", "standardCode": "12경수02-03", "achievementStandard": "효용의 의미를 이해하고, 효용을 함수와 그래프로 나타낼 수 있다.", "topics": ["효용함수", "핵심 의미와 원리", "수학적 표현과 해석"], "scopeNotes": ["여러 독립변수 중 일부를 고정해 일변수함수로 해석할 수 있음을 이해한다.", "부등식 영역의 최대·최소에서는 경제 관련 함수를 일차식으로 제한한다."], "visualizationIdeas": ["수요·공급곡선이 이동하며 균형가격과 거래량이 바뀌는 애니메이션", "예산 제약선과 효용 수준을 움직이며 선택 가능한 영역 비교", "부등식의 영역을 생산 가능 조합의 색칠된 영역으로 표현"] }, { "id": "economics-math-02-04", "order": 4, "title": "균형가격과 균형수급량", "standardCode": "12경수02-04", "achievementStandard": "수요와 공급의 상호 작용에 의해 균형가격이 결정되는 경제 현상을 설명할 수 있다.", "topics": ["균형가격과 균형수급량", "핵심 의미와 원리", "적용과 문제 해결"], "scopeNotes": ["여러 독립변수 중 일부를 고정해 일변수함수로 해석할 수 있음을 이해한다.", "부등식 영역의 최대·최소에서는 경제 관련 함수를 일차식으로 제한한다."], "visualizationIdeas": ["수요·공급곡선이 이동하며 균형가격과 거래량이 바뀌는 애니메이션", "예산 제약선과 효용 수준을 움직이며 선택 가능한 영역 비교", "부등식의 영역을 생산 가능 조합의 색칠된 영역으로 표현"] }, { "id": "economics-math-02-05", "order": 5, "title": "세금·소득과 균형가격", "standardCode": "12경수02-05", "achievementStandard": "세금과 소득의 변화가 균형가격에 미치는 영향을 탐구하고 이해한다.", "topics": ["세금·소득과 균형가격", "핵심 의미와 원리", "탐구 설계와 수행"], "scopeNotes": ["여러 독립변수 중 일부를 고정해 일변수함수로 해석할 수 있음을 이해한다.", "부등식 영역의 최대·최소에서는 경제 관련 함수를 일차식으로 제한한다."], "visualizationIdeas": ["수요·공급곡선이 이동하며 균형가격과 거래량이 바뀌는 애니메이션", "예산 제약선과 효용 수준을 움직이며 선택 가능한 영역 비교", "부등식의 영역을 생산 가능 조합의 색칠된 영역으로 표현"] }, { "id": "economics-math-02-06", "order": 6, "title": "부등식의 영역과 경제 문제", "standardCode": "12경수02-06", "achievementStandard": "부등식의 영역의 개념을 이해하고, 이를 활용하여 경제 현상의 문제를 해결할 수 있다.", "topics": ["부등식의 영역과 경제 문제", "핵심 의미와 원리", "적용과 문제 해결"], "scopeNotes": ["여러 독립변수 중 일부를 고정해 일변수함수로 해석할 수 있음을 이해한다.", "부등식 영역의 최대·최소에서는 경제 관련 함수를 일차식으로 제한한다."], "visualizationIdeas": ["수요·공급곡선이 이동하며 균형가격과 거래량이 바뀌는 애니메이션", "예산 제약선과 효용 수준을 움직이며 선택 가능한 영역 비교", "부등식의 영역을 생산 가능 조합의 색칠된 영역으로 표현"] }], "conceptCount": 6 }, { "id": "matrices-and-economics", "title": "행렬과 경제", "order": 3, "concepts": [{ "id": "economics-math-03-01", "order": 1, "title": "경제 자료와 행렬", "standardCode": "12경수03-01", "achievementStandard": "여러 가지 경제 현상을 행렬로 나타내고, 연산할 수 있다.", "topics": ["경제 자료와 행렬", "계산 방법과 절차", "수학적 표현과 해석", "적용과 문제 해결"], "scopeNotes": ["복잡한 형식 논리 규칙이나 엄밀한 대수적 증명은 다루지 않는다.", "행렬 연산이 경제 현상에서 의미하는 바를 해석하는 데 중점을 둔다."], "visualizationIdeas": ["산업 간 거래 표가 행렬로 변환되고 행·열 연산이 경제 흐름과 연결", "선형변환을 되돌리는 과정으로 역행렬의 의미 표현"] }, { "id": "economics-math-03-02", "order": 2, "title": "역행렬", "standardCode": "12경수03-02", "achievementStandard": "역행렬의 뜻을 알고, 행렬의 역행렬을 구할 수 있다.", "topics": ["역행렬", "핵심 의미와 원리", "계산 방법과 절차", "수학적 표현과 해석"], "scopeNotes": ["복잡한 형식 논리 규칙이나 엄밀한 대수적 증명은 다루지 않는다.", "행렬 연산이 경제 현상에서 의미하는 바를 해석하는 데 중점을 둔다."], "visualizationIdeas": ["산업 간 거래 표가 행렬로 변환되고 행·열 연산이 경제 흐름과 연결", "선형변환을 되돌리는 과정으로 역행렬의 의미 표현"] }, { "id": "economics-math-03-03", "order": 3, "title": "행렬을 활용한 경제 문제", "standardCode": "12경수03-03", "achievementStandard": "행렬의 연산과 역행렬을 활용하여 경제 현상의 문제를 해결할 수 있다.", "topics": ["행렬을 활용한 경제 문제", "계산 방법과 절차", "수학적 표현과 해석", "적용과 문제 해결"], "scopeNotes": ["복잡한 형식 논리 규칙이나 엄밀한 대수적 증명은 다루지 않는다.", "행렬 연산이 경제 현상에서 의미하는 바를 해석하는 데 중점을 둔다."], "visualizationIdeas": ["산업 간 거래 표가 행렬로 변환되고 행·열 연산이 경제 흐름과 연결", "선형변환을 되돌리는 과정으로 역행렬의 의미 표현"] }], "conceptCount": 3 }, { "id": "differentiation-and-economics", "title": "미분과 경제", "order": 4, "concepts": [{ "id": "economics-math-04-01", "order": 1, "title": "경제 함수의 미분", "standardCode": "12경수04-01", "achievementStandard": "미분의 개념을 이해하고 경제 현상을 나타내는 함수를 미분할 수 있다.", "topics": ["경제 함수의 미분", "핵심 의미와 원리", "계산 방법과 절차", "적용과 문제 해결"], "scopeNotes": ["함수의 극한은 직관적으로, 미분계수는 접선의 기울기로 도입한다.", "다항함수의 미분을 중심으로 다룬다.", "효용·생산함수의 특정 변수를 고정하여 일변수함수로 최적화한다."], "visualizationIdeas": ["총비용·총수입 곡선의 접선 기울기를 한계비용·한계수입과 연결", "가격 변화에 따른 수요량 변화와 탄력성을 그래프 위 비율로 표시", "이윤함수의 최고점과 최적 생산량을 움직이는 점으로 탐색"] }, { "id": "economics-math-04-02", "order": 2, "title": "경제 함수 그래프", "standardCode": "12경수04-02", "achievementStandard": "미분을 이용하여 그래프의 개형을 탐구하고 해석할 수 있다.", "topics": ["경제 함수 그래프", "계산 방법과 절차", "수학적 표현과 해석", "탐구 설계와 수행"], "scopeNotes": ["함수의 극한은 직관적으로, 미분계수는 접선의 기울기로 도입한다.", "다항함수의 미분을 중심으로 다룬다.", "효용·생산함수의 특정 변수를 고정하여 일변수함수로 최적화한다."], "visualizationIdeas": ["총비용·총수입 곡선의 접선 기울기를 한계비용·한계수입과 연결", "가격 변화에 따른 수요량 변화와 탄력성을 그래프 위 비율로 표시", "이윤함수의 최고점과 최적 생산량을 움직이는 점으로 탐색"] }, { "id": "economics-math-04-03", "order": 3, "title": "탄력성", "standardCode": "12경수04-03", "achievementStandard": "미분을 활용하여 탄력성의 의미를 탐구하고 이해한다.", "topics": ["탄력성", "핵심 의미와 원리", "계산 방법과 절차", "적용과 문제 해결", "탐구 설계와 수행"], "scopeNotes": ["함수의 극한은 직관적으로, 미분계수는 접선의 기울기로 도입한다.", "다항함수의 미분을 중심으로 다룬다.", "효용·생산함수의 특정 변수를 고정하여 일변수함수로 최적화한다."], "visualizationIdeas": ["총비용·총수입 곡선의 접선 기울기를 한계비용·한계수입과 연결", "가격 변화에 따른 수요량 변화와 탄력성을 그래프 위 비율로 표시", "이윤함수의 최고점과 최적 생산량을 움직이는 점으로 탐색"] }, { "id": "economics-math-04-04", "order": 4, "title": "경제 최적화", "standardCode": "12경수04-04", "achievementStandard": "미분을 활용하여 경제 현상의 최적화 문제를 해결할 수 있다.", "topics": ["경제 최적화", "계산 방법과 절차", "적용과 문제 해결"], "scopeNotes": ["함수의 극한은 직관적으로, 미분계수는 접선의 기울기로 도입한다.", "다항함수의 미분을 중심으로 다룬다.", "효용·생산함수의 특정 변수를 고정하여 일변수함수로 최적화한다."], "visualizationIdeas": ["총비용·총수입 곡선의 접선 기울기를 한계비용·한계수입과 연결", "가격 변화에 따른 수요량 변화와 탄력성을 그래프 위 비율로 표시", "이윤함수의 최고점과 최적 생산량을 움직이는 점으로 탐색"] }], "conceptCount": 4 }], "categoryEnglishTitle": "CAREER ELECTIVE", "categoryDescription": "관심 분야와 진로에 따라 깊이 있게 학습하는 과목입니다.", "categoryOrder": 3, "placementLabel": "학교별 개설·편성", "sourceFile": "kr-2022-economics-math.yaml", "developmentLocked": true }, { "id": "ai-math", "officialTitle": "인공지능 수학", "category": "career-elective", "categoryTitle": "진로 선택", "recommendedGrades": [11, 12], "prerequisites": ["common-math-1", "common-math-2"], "defaultSemester": "school-defined", "conceptCount": 15, "units": [{ "id": "ai-and-big-data", "title": "인공지능과 빅데이터", "order": 1, "concepts": [{ "id": "ai-math-01-01", "order": 1, "title": "인공지능의 학습 방식", "standardCode": "12인수01-01", "achievementStandard": "인공지능의 개념을 이해하고 학습 방식을 수학적으로 해석할 수 있다.", "topics": ["인공지능의 학습 방식", "핵심 의미와 원리"], "scopeNotes": ["지도학습·비지도학습·강화학습과 퍼셉트론은 개념 중심으로 다룬다.", "빅데이터 활용에서 편향과 공정성을 함께 고려한다."], "visualizationIdeas": ["퍼셉트론의 입력·가중치·활성화 결과가 흐르는 네트워크 애니메이션", "OR·AND·XOR의 결정 영역과 단층·다층 구조 비교", "데이터 표본의 편향이 예측 결과의 편향으로 이어지는 시뮬레이션"] }, { "id": "ai-math-01-02", "order": 2, "title": "인공지능과 수학의 역사", "standardCode": "12인수01-02", "achievementStandard": "인공지능에서 수학을 활용한 역사적 사례를 탐구하고 설명할 수 있다.", "topics": ["인공지능과 수학의 역사", "핵심 의미와 원리", "적용과 문제 해결", "탐구 설계와 수행"], "scopeNotes": ["지도학습·비지도학습·강화학습과 퍼셉트론은 개념 중심으로 다룬다.", "빅데이터 활용에서 편향과 공정성을 함께 고려한다."], "visualizationIdeas": ["퍼셉트론의 입력·가중치·활성화 결과가 흐르는 네트워크 애니메이션", "OR·AND·XOR의 결정 영역과 단층·다층 구조 비교", "데이터 표본의 편향이 예측 결과의 편향으로 이어지는 시뮬레이션"] }, { "id": "ai-math-01-03", "order": 3, "title": "빅데이터와 인공지능", "standardCode": "12인수01-03", "achievementStandard": "빅데이터의 개념과 특성을 알고 인공지능에서 빅데이터를 활용한 사례를 찾을 수 있다.", "topics": ["빅데이터와 인공지능", "핵심 의미와 원리", "적용과 문제 해결"], "scopeNotes": ["지도학습·비지도학습·강화학습과 퍼셉트론은 개념 중심으로 다룬다.", "빅데이터 활용에서 편향과 공정성을 함께 고려한다."], "visualizationIdeas": ["퍼셉트론의 입력·가중치·활성화 결과가 흐르는 네트워크 애니메이션", "OR·AND·XOR의 결정 영역과 단층·다층 구조 비교", "데이터 표본의 편향이 예측 결과의 편향으로 이어지는 시뮬레이션"] }], "conceptCount": 3 }, { "id": "text-data-processing", "title": "텍스트 데이터 처리", "order": 2, "concepts": [{ "id": "ai-math-02-01", "order": 1, "title": "텍스트의 집합·벡터 표현", "standardCode": "12인수02-01", "achievementStandard": "집합과 벡터를 이용하여 텍스트 데이터를 목적에 맞게 표현할 수 있다.", "topics": ["텍스트의 집합·벡터 표현", "수학적 표현과 해석"], "scopeNotes": ["수학 이론 자체보다 인공지능에서의 활용을 중심으로 다룬다.", "코사인 유사도에서 내적 관련 용어와 기호는 사용하지 않는다.", "대수 이수자는 로그를 이용한 역문서빈도 표현을 선택적으로 다룰 수 있다."], "visualizationIdeas": ["문장이 단어 집합과 빈도 벡터로 변환되는 토큰 애니메이션", "문서빈도에 따라 단어의 TF-IDF 가중치가 변하는 막대그래프", "텍스트 벡터 사이 거리와 유사도를 2차원 공간에서 비교"] }, { "id": "ai-math-02-02", "order": 2, "title": "단어가방과 TF-IDF", "standardCode": "12인수02-02", "achievementStandard": "빈도수 벡터를 이용하여 텍스트 데이터를 요약하고 유용한 정보를 추출할 수 있다.", "topics": ["단어가방과 TF-IDF", "수학적 표현과 해석"], "scopeNotes": ["수학 이론 자체보다 인공지능에서의 활용을 중심으로 다룬다.", "코사인 유사도에서 내적 관련 용어와 기호는 사용하지 않는다.", "대수 이수자는 로그를 이용한 역문서빈도 표현을 선택적으로 다룰 수 있다."], "visualizationIdeas": ["문장이 단어 집합과 빈도 벡터로 변환되는 토큰 애니메이션", "문서빈도에 따라 단어의 TF-IDF 가중치가 변하는 막대그래프", "텍스트 벡터 사이 거리와 유사도를 2차원 공간에서 비교"] }, { "id": "ai-math-02-03", "order": 3, "title": "텍스트 유사도와 감성 분석", "standardCode": "12인수02-03", "achievementStandard": "인공지능이 텍스트를 특성에 따라 분석하는 수학적 방법을 설명할 수 있다.", "topics": ["텍스트 유사도와 감성 분석", "핵심 의미와 원리", "탐구 설계와 수행"], "scopeNotes": ["수학 이론 자체보다 인공지능에서의 활용을 중심으로 다룬다.", "코사인 유사도에서 내적 관련 용어와 기호는 사용하지 않는다.", "대수 이수자는 로그를 이용한 역문서빈도 표현을 선택적으로 다룰 수 있다."], "visualizationIdeas": ["문장이 단어 집합과 빈도 벡터로 변환되는 토큰 애니메이션", "문서빈도에 따라 단어의 TF-IDF 가중치가 변하는 막대그래프", "텍스트 벡터 사이 거리와 유사도를 2차원 공간에서 비교"] }], "conceptCount": 3 }, { "id": "image-data-processing", "title": "이미지 데이터 처리", "order": 3, "concepts": [{ "id": "ai-math-03-01", "order": 1, "title": "이미지의 행렬 표현", "standardCode": "12인수03-01", "achievementStandard": "행렬을 이용하여 이미지 데이터를 목적에 맞게 표현할 수 있다.", "topics": ["이미지의 행렬 표현", "수학적 표현과 해석"], "scopeNotes": ["픽셀 위치와 RGB 정보를 행렬로 표현한다.", "행렬 연산을 이용한 이미지 변환에서 회전변환은 다루지 않는다."], "visualizationIdeas": ["이미지를 확대해 픽셀 RGB 행렬로 변환", "행렬값 변화가 밝기·대비·선명도에 미치는 효과를 실시간 비교", "두 이미지의 픽셀 차이가 해밍 거리로 누적되는 장면"] }, { "id": "ai-math-03-02", "order": 2, "title": "행렬을 이용한 이미지 변환", "standardCode": "12인수03-02", "achievementStandard": "행렬의 연산을 이용하여 이미지 데이터를 다양하게 변환할 수 있다.", "topics": ["행렬을 이용한 이미지 변환", "계산 방법과 절차", "수학적 표현과 해석"], "scopeNotes": ["픽셀 위치와 RGB 정보를 행렬로 표현한다.", "행렬 연산을 이용한 이미지 변환에서 회전변환은 다루지 않는다."], "visualizationIdeas": ["이미지를 확대해 픽셀 RGB 행렬로 변환", "행렬값 변화가 밝기·대비·선명도에 미치는 효과를 실시간 비교", "두 이미지의 픽셀 차이가 해밍 거리로 누적되는 장면"] }, { "id": "ai-math-03-03", "order": 3, "title": "이미지 분류와 유사도", "standardCode": "12인수03-03", "achievementStandard": "인공지능이 이미지를 자동으로 분류하는 수학적 방법을 설명할 수 있다.", "topics": ["이미지 분류와 유사도", "핵심 의미와 원리"], "scopeNotes": ["픽셀 위치와 RGB 정보를 행렬로 표현한다.", "행렬 연산을 이용한 이미지 변환에서 회전변환은 다루지 않는다."], "visualizationIdeas": ["이미지를 확대해 픽셀 RGB 행렬로 변환", "행렬값 변화가 밝기·대비·선명도에 미치는 효과를 실시간 비교", "두 이미지의 픽셀 차이가 해밍 거리로 누적되는 장면"] }], "conceptCount": 3 }, { "id": "prediction-and-optimization", "title": "예측과 최적화", "order": 4, "concepts": [{ "id": "ai-math-04-01", "order": 1, "title": "데이터와 확률 예측", "standardCode": "12인수04-01", "achievementStandard": "데이터를 분석하여 사건이 일어날 확률을 구하고 이를 예측에 이용할 수 있다.", "topics": ["데이터와 확률 예측", "적용과 문제 해결", "탐구 설계와 수행"], "scopeNotes": ["확률 계산은 상대도수를 활용하고 조건부확률 용어와 기호는 다루지 않는다.", "손실함수는 일변수함수로 정의된 간단한 경우를 다룬다.", "극한과 미분계수는 경사하강법 이해에 필요한 직관적 수준으로 다룬다."], "visualizationIdeas": ["여러 추세선의 잔차를 선분으로 표시하고 손실값 비교", "손실함수 곡면 위 점이 기울기 반대 방향으로 최솟값에 이동", "학습률에 따라 수렴·진동·발산하는 경사하강 경로 비교"] }, { "id": "ai-math-04-02", "order": 2, "title": "추세선과 예측", "standardCode": "12인수04-02", "achievementStandard": "공학 도구를 사용하여 데이터의 경향성을 추세선으로 나타내고 이를 예측에 이용할 수 있다.", "topics": ["추세선과 예측", "적용과 문제 해결"], "scopeNotes": ["확률 계산은 상대도수를 활용하고 조건부확률 용어와 기호는 다루지 않는다.", "손실함수는 일변수함수로 정의된 간단한 경우를 다룬다.", "극한과 미분계수는 경사하강법 이해에 필요한 직관적 수준으로 다룬다."], "visualizationIdeas": ["여러 추세선의 잔차를 선분으로 표시하고 손실값 비교", "손실함수 곡면 위 점이 기울기 반대 방향으로 최솟값에 이동", "학습률에 따라 수렴·진동·발산하는 경사하강 경로 비교"] }, { "id": "ai-math-04-03", "order": 3, "title": "손실함수", "standardCode": "12인수04-03", "achievementStandard": "손실함수를 이해하고 최적화된 추세선을 찾을 수 있다.", "topics": ["손실함수", "핵심 의미와 원리"], "scopeNotes": ["확률 계산은 상대도수를 활용하고 조건부확률 용어와 기호는 다루지 않는다.", "손실함수는 일변수함수로 정의된 간단한 경우를 다룬다.", "극한과 미분계수는 경사하강법 이해에 필요한 직관적 수준으로 다룬다."], "visualizationIdeas": ["여러 추세선의 잔차를 선분으로 표시하고 손실값 비교", "손실함수 곡면 위 점이 기울기 반대 방향으로 최솟값에 이동", "학습률에 따라 수렴·진동·발산하는 경사하강 경로 비교"] }, { "id": "ai-math-04-04", "order": 4, "title": "경사하강법", "standardCode": "12인수04-04", "achievementStandard": "경사하강법을 이해하고 최적화된 예측을 위한 인공지능의 학습 방법을 설명할 수 있다.", "topics": ["경사하강법", "핵심 의미와 원리", "적용과 문제 해결"], "scopeNotes": ["확률 계산은 상대도수를 활용하고 조건부확률 용어와 기호는 다루지 않는다.", "손실함수는 일변수함수로 정의된 간단한 경우를 다룬다.", "극한과 미분계수는 경사하강법 이해에 필요한 직관적 수준으로 다룬다."], "visualizationIdeas": ["여러 추세선의 잔차를 선분으로 표시하고 손실값 비교", "손실함수 곡면 위 점이 기울기 반대 방향으로 최솟값에 이동", "학습률에 따라 수렴·진동·발산하는 경사하강 경로 비교"] }], "conceptCount": 4 }, { "id": "ai-math-inquiry", "title": "인공지능과 수학 탐구", "order": 5, "concepts": [{ "id": "ai-math-05-01", "order": 1, "title": "인공지능의 합리적 의사 결정", "standardCode": "12인수05-01", "achievementStandard": "수학적 원리를 이용하여 인공지능이 실생활 문제를 합리적으로 해결하는 사례를 찾을 수 있다.", "topics": ["인공지능의 합리적 의사 결정", "적용과 문제 해결"], "scopeNotes": ["인공지능 의사 결정의 효율성과 함께 윤리성과 공정성을 판단한다.", "환경·생태·지속가능발전과 관련된 탐구를 수행할 수 있다."], "visualizationIdeas": ["같은 데이터에서 목표함수에 따라 다른 의사 결정이 나오는 비교", "탐구 질문→데이터→수학적 모델→결론의 프로젝트 흐름도"] }, { "id": "ai-math-05-02", "order": 2, "title": "인공지능 수학 주제 탐구", "standardCode": "12인수05-02", "achievementStandard": "인공지능과 관련된 수학 주제를 선정하여 탐구할 수 있다.", "topics": ["인공지능 수학 주제 탐구", "계산 방법과 절차", "탐구 설계와 수행"], "scopeNotes": ["인공지능 의사 결정의 효율성과 함께 윤리성과 공정성을 판단한다.", "환경·생태·지속가능발전과 관련된 탐구를 수행할 수 있다."], "visualizationIdeas": ["같은 데이터에서 목표함수에 따라 다른 의사 결정이 나오는 비교", "탐구 질문→데이터→수학적 모델→결론의 프로젝트 흐름도"] }], "conceptCount": 2 }], "categoryEnglishTitle": "CAREER ELECTIVE", "categoryDescription": "관심 분야와 진로에 따라 깊이 있게 학습하는 과목입니다.", "categoryOrder": 3, "placementLabel": "학교별 개설·편성", "sourceFile": "kr-2022-ai-math.yaml", "developmentLocked": true }, { "id": "vocational-math", "officialTitle": "직무 수학", "category": "career-elective", "categoryTitle": "진로 선택", "recommendedGrades": [11, 12], "prerequisites": [], "defaultSemester": "school-defined", "conceptCount": 18, "units": [{ "id": "numbers-and-operations", "title": "수와 연산", "order": 1, "concepts": [{ "id": "vocational-math-01-01", "order": 1, "title": "직무와 사칙연산", "standardCode": "12직수01-01", "achievementStandard": "직무 상황에서 수 개념과 사칙연산의 문제를 해결하고 그 유용성을 인식할 수 있다.", "topics": ["직무와 사칙연산", "핵심 의미와 원리", "계산 방법과 절차", "적용과 문제 해결"], "scopeNotes": ["직무 상황의 실제 문제 해결에 중점을 두고 필요한 경우 공학 도구를 사용한다.", "국제단위계 외 단위와 국가 간 시차를 실제 자료와 연결할 수 있다."], "visualizationIdeas": ["예산·비용 항목이 사칙연산으로 합쳐지는 직무 영수증 시뮬레이션", "올림·버림·반올림에 따른 견적 차이 비교", "단위 블록의 크기가 환산 비율에 따라 바뀌는 애니메이션"] }, { "id": "vocational-math-01-02", "order": 2, "title": "큰 수와 어림", "standardCode": "12직수01-02", "achievementStandard": "큰 수를 어림하여 문제를 해결하고, 어림값을 이용하여 수의 크기를 비교할 수 있다.", "topics": ["큰 수와 어림", "적용과 문제 해결"], "scopeNotes": ["직무 상황의 실제 문제 해결에 중점을 두고 필요한 경우 공학 도구를 사용한다.", "국제단위계 외 단위와 국가 간 시차를 실제 자료와 연결할 수 있다."], "visualizationIdeas": ["예산·비용 항목이 사칙연산으로 합쳐지는 직무 영수증 시뮬레이션", "올림·버림·반올림에 따른 견적 차이 비교", "단위 블록의 크기가 환산 비율에 따라 바뀌는 애니메이션"] }, { "id": "vocational-math-01-03", "order": 3, "title": "표준 단위와 단위 환산", "standardCode": "12직수01-03", "achievementStandard": "시간, 길이, 무게, 들이의 표준 단위를 알고, 단위를 환산할 수 있다.", "topics": ["표준 단위와 단위 환산", "수학적 표현과 해석"], "scopeNotes": ["직무 상황의 실제 문제 해결에 중점을 두고 필요한 경우 공학 도구를 사용한다.", "국제단위계 외 단위와 국가 간 시차를 실제 자료와 연결할 수 있다."], "visualizationIdeas": ["예산·비용 항목이 사칙연산으로 합쳐지는 직무 영수증 시뮬레이션", "올림·버림·반올림에 따른 견적 차이 비교", "단위 블록의 크기가 환산 비율에 따라 바뀌는 애니메이션"] }], "conceptCount": 3 }, { "id": "change-and-relationships", "title": "변화와 관계", "order": 2, "concepts": [{ "id": "vocational-math-02-01", "order": 1, "title": "비와 비례식", "standardCode": "12직수02-01", "achievementStandard": "비의 개념을 직무 상황에 연결하여 적용할 수 있다.", "topics": ["비와 비례식", "핵심 의미와 원리", "적용과 문제 해결"], "scopeNotes": ["개념과 절차 자체보다 직무 상황에 적용하는 데 중점을 둔다.", "요율·매출·판매량 자료를 근거로 합리적 의사 결정을 하게 한다."], "visualizationIdeas": ["단가·환율·할인율이 실제 금액에 적용되는 계산 흐름", "요율표의 구간을 그래프와 연결해 대응 관계 표시", "비용 조건을 일차부등식 영역으로 바꾸어 가능한 선택 비교"] }, { "id": "vocational-math-02-02", "order": 2, "title": "비율과 백분율", "standardCode": "12직수02-02", "achievementStandard": "비율을 백분율로 표현할 수 있고 직무 상황에 연결하여 적용할 수 있다.", "topics": ["비율과 백분율", "수학적 표현과 해석", "적용과 문제 해결"], "scopeNotes": ["개념과 절차 자체보다 직무 상황에 적용하는 데 중점을 둔다.", "요율·매출·판매량 자료를 근거로 합리적 의사 결정을 하게 한다."], "visualizationIdeas": ["단가·환율·할인율이 실제 금액에 적용되는 계산 흐름", "요율표의 구간을 그래프와 연결해 대응 관계 표시", "비용 조건을 일차부등식 영역으로 바꾸어 가능한 선택 비교"] }, { "id": "vocational-math-02-03", "order": 3, "title": "대응 관계와 요율표", "standardCode": "12직수02-03", "achievementStandard": "두 양 사이의 대응 관계를 나타낸 표에서 규칙을 찾아 설명할 수 있다.", "topics": ["대응 관계와 요율표", "핵심 의미와 원리", "수학적 표현과 해석"], "scopeNotes": ["개념과 절차 자체보다 직무 상황에 적용하는 데 중점을 둔다.", "요율·매출·판매량 자료를 근거로 합리적 의사 결정을 하게 한다."], "visualizationIdeas": ["단가·환율·할인율이 실제 금액에 적용되는 계산 흐름", "요율표의 구간을 그래프와 연결해 대응 관계 표시", "비용 조건을 일차부등식 영역으로 바꾸어 가능한 선택 비교"] }, { "id": "vocational-math-02-04", "order": 4, "title": "변화 그래프", "standardCode": "12직수02-04", "achievementStandard": "증가와 감소, 주기적 변화 등의 관계를 나타내는 그래프를 설명할 수 있다.", "topics": ["변화 그래프", "핵심 의미와 원리", "수학적 표현과 해석"], "scopeNotes": ["개념과 절차 자체보다 직무 상황에 적용하는 데 중점을 둔다.", "요율·매출·판매량 자료를 근거로 합리적 의사 결정을 하게 한다."], "visualizationIdeas": ["단가·환율·할인율이 실제 금액에 적용되는 계산 흐름", "요율표의 구간을 그래프와 연결해 대응 관계 표시", "비용 조건을 일차부등식 영역으로 바꾸어 가능한 선택 비교"] }, { "id": "vocational-math-02-05", "order": 5, "title": "직무와 일차방정식·부등식", "standardCode": "12직수02-05", "achievementStandard": "일차방정식 또는 일차부등식을 활용하여 직무 상황의 문제를 해결할 수 있다.", "topics": ["직무와 일차방정식·부등식", "수학적 표현과 해석", "적용과 문제 해결"], "scopeNotes": ["개념과 절차 자체보다 직무 상황에 적용하는 데 중점을 둔다.", "요율·매출·판매량 자료를 근거로 합리적 의사 결정을 하게 한다."], "visualizationIdeas": ["단가·환율·할인율이 실제 금액에 적용되는 계산 흐름", "요율표의 구간을 그래프와 연결해 대응 관계 표시", "비용 조건을 일차부등식 영역으로 바꾸어 가능한 선택 비교"] }], "conceptCount": 5 }, { "id": "geometry-and-measurement", "title": "도형과 측정", "order": 3, "concepts": [{ "id": "vocational-math-03-01", "order": 1, "title": "겨냥도와 전개도", "standardCode": "12직수03-01", "achievementStandard": "입체도형의 겨냥도와 전개도를 그릴 수 있고, 이를 이용하여 입체도형의 모양을 만들 수 있다.", "topics": ["겨냥도와 전개도", "핵심 관계"], "scopeNotes": ["도형의 이동·합동·닮음은 제품 설계와 배치 등 직무 상황에 적용한다.", "겉넓이와 부피는 포장·보관·운송 상황과 연결한다."], "visualizationIdeas": ["상자를 펼쳐 전개도로 만들고 다시 접는 3차원 애니메이션", "물체를 회전하며 위·앞·옆 모습과 동기화", "포장재 크기와 용량을 바꾸며 겉넓이·부피의 변화 비교"] }, { "id": "vocational-math-03-02", "order": 2, "title": "여러 방향에서 본 모양", "standardCode": "12직수03-02", "achievementStandard": "입체도형을 위, 앞, 옆에서 본 모양으로 표현하고, 이러한 표현을 보고 입체도형의 모양을 판별할 수 있다.", "topics": ["여러 방향에서 본 모양", "수학적 표현과 해석"], "scopeNotes": ["도형의 이동·합동·닮음은 제품 설계와 배치 등 직무 상황에 적용한다.", "겉넓이와 부피는 포장·보관·운송 상황과 연결한다."], "visualizationIdeas": ["상자를 펼쳐 전개도로 만들고 다시 접는 3차원 애니메이션", "물체를 회전하며 위·앞·옆 모습과 동기화", "포장재 크기와 용량을 바꾸며 겉넓이·부피의 변화 비교"] }, { "id": "vocational-math-03-03", "order": 3, "title": "도형의 이동·합동·닮음", "standardCode": "12직수03-03", "achievementStandard": "도형의 이동, 합동과 닮음을 직무 상황에 연결하여 문제를 해결할 수 있다.", "topics": ["도형의 이동·합동·닮음", "적용과 문제 해결"], "scopeNotes": ["도형의 이동·합동·닮음은 제품 설계와 배치 등 직무 상황에 적용한다.", "겉넓이와 부피는 포장·보관·운송 상황과 연결한다."], "visualizationIdeas": ["상자를 펼쳐 전개도로 만들고 다시 접는 3차원 애니메이션", "물체를 회전하며 위·앞·옆 모습과 동기화", "포장재 크기와 용량을 바꾸며 겉넓이·부피의 변화 비교"] }, { "id": "vocational-math-03-04", "order": 4, "title": "평면도형의 둘레와 넓이", "standardCode": "12직수03-04", "achievementStandard": "직무 상황에서 나타나는 평면도형의 둘레와 넓이를 구할 수 있다.", "topics": ["평면도형의 둘레와 넓이", "계산 방법과 절차", "적용과 문제 해결"], "scopeNotes": ["도형의 이동·합동·닮음은 제품 설계와 배치 등 직무 상황에 적용한다.", "겉넓이와 부피는 포장·보관·운송 상황과 연결한다."], "visualizationIdeas": ["상자를 펼쳐 전개도로 만들고 다시 접는 3차원 애니메이션", "물체를 회전하며 위·앞·옆 모습과 동기화", "포장재 크기와 용량을 바꾸며 겉넓이·부피의 변화 비교"] }, { "id": "vocational-math-03-05", "order": 5, "title": "입체도형의 겉넓이와 부피", "standardCode": "12직수03-05", "achievementStandard": "직무 상황에서 나타나는 입체도형의 겉넓이와 부피를 구할 수 있다.", "topics": ["입체도형의 겉넓이와 부피", "계산 방법과 절차", "적용과 문제 해결"], "scopeNotes": ["도형의 이동·합동·닮음은 제품 설계와 배치 등 직무 상황에 적용한다.", "겉넓이와 부피는 포장·보관·운송 상황과 연결한다."], "visualizationIdeas": ["상자를 펼쳐 전개도로 만들고 다시 접는 3차원 애니메이션", "물체를 회전하며 위·앞·옆 모습과 동기화", "포장재 크기와 용량을 바꾸며 겉넓이·부피의 변화 비교"] }], "conceptCount": 5 }, { "id": "data-and-chance", "title": "자료와 가능성", "order": 4, "concepts": [{ "id": "vocational-math-04-01", "order": 1, "title": "직무 상황의 경우의 수", "standardCode": "12직수04-01", "achievementStandard": "직무 상황에서 경우의 수를 구할 수 있다.", "topics": ["직무 상황의 경우의 수", "계산 방법과 절차", "적용과 문제 해결"], "scopeNotes": ["가능성은 실제 자료를 근거로 파악하고 해석하는 데 중점을 둔다.", "그림그래프·선그래프·비율그래프·방사형그래프·산점도 등을 다양하게 활용한다."], "visualizationIdeas": ["상품 구성과 좌석 배치를 드래그하며 가능한 조합 수 계산", "여러 표를 하나의 표와 그래프로 통합하는 변환", "같은 데이터를 서로 다른 그래프로 표현해 해석 차이 비교"] }, { "id": "vocational-math-04-02", "order": 2, "title": "가능성의 수치화", "standardCode": "12직수04-02", "achievementStandard": "어떤 현상이 나타날 가능성을 수치화하여 설명할 수 있다.", "topics": ["가능성의 수치화", "핵심 의미와 원리"], "scopeNotes": ["가능성은 실제 자료를 근거로 파악하고 해석하는 데 중점을 둔다.", "그림그래프·선그래프·비율그래프·방사형그래프·산점도 등을 다양하게 활용한다."], "visualizationIdeas": ["상품 구성과 좌석 배치를 드래그하며 가능한 조합 수 계산", "여러 표를 하나의 표와 그래프로 통합하는 변환", "같은 데이터를 서로 다른 그래프로 표현해 해석 차이 비교"] }, { "id": "vocational-math-04-03", "order": 3, "title": "표와 그래프의 정리", "standardCode": "12직수04-03", "achievementStandard": "직무 상황의 자료를 목적에 맞게 표와 그래프로 정리할 수 있다.", "topics": ["표와 그래프의 정리", "수학적 표현과 해석", "적용과 문제 해결"], "scopeNotes": ["가능성은 실제 자료를 근거로 파악하고 해석하는 데 중점을 둔다.", "그림그래프·선그래프·비율그래프·방사형그래프·산점도 등을 다양하게 활용한다."], "visualizationIdeas": ["상품 구성과 좌석 배치를 드래그하며 가능한 조합 수 계산", "여러 표를 하나의 표와 그래프로 통합하는 변환", "같은 데이터를 서로 다른 그래프로 표현해 해석 차이 비교"] }, { "id": "vocational-math-04-04", "order": 4, "title": "표와 그래프의 해석", "standardCode": "12직수04-04", "achievementStandard": "직무 상황의 다양한 표와 그래프를 해석할 수 있다.", "topics": ["표와 그래프의 해석", "수학적 표현과 해석", "적용과 문제 해결"], "scopeNotes": ["가능성은 실제 자료를 근거로 파악하고 해석하는 데 중점을 둔다.", "그림그래프·선그래프·비율그래프·방사형그래프·산점도 등을 다양하게 활용한다."], "visualizationIdeas": ["상품 구성과 좌석 배치를 드래그하며 가능한 조합 수 계산", "여러 표를 하나의 표와 그래프로 통합하는 변환", "같은 데이터를 서로 다른 그래프로 표현해 해석 차이 비교"] }, { "id": "vocational-math-04-05", "order": 5, "title": "자료 기반 의사 결정", "standardCode": "12직수04-05", "achievementStandard": "다양한 자료의 특성을 파악하여, 직무 목적에 적합한 표나 그래프로 나타내고 합리적인 의사 결정을 할 수 있다.", "topics": ["자료 기반 의사 결정", "수학적 표현과 해석", "적용과 문제 해결"], "scopeNotes": ["가능성은 실제 자료를 근거로 파악하고 해석하는 데 중점을 둔다.", "그림그래프·선그래프·비율그래프·방사형그래프·산점도 등을 다양하게 활용한다."], "visualizationIdeas": ["상품 구성과 좌석 배치를 드래그하며 가능한 조합 수 계산", "여러 표를 하나의 표와 그래프로 통합하는 변환", "같은 데이터를 서로 다른 그래프로 표현해 해석 차이 비교"] }], "conceptCount": 5 }], "categoryEnglishTitle": "CAREER ELECTIVE", "categoryDescription": "관심 분야와 진로에 따라 깊이 있게 학습하는 과목입니다.", "categoryOrder": 3, "placementLabel": "학교별 개설·편성", "sourceFile": "kr-2022-vocational-math.yaml", "developmentLocked": true }] }, { "id": "convergence-elective", "title": "융합 선택", "englishTitle": "CONVERGENCE ELECTIVE", "description": "수학을 문화, 통계, 탐구 활동과 연결하는 과목입니다.", "order": 4, "courses": [{ "id": "math-and-culture", "officialTitle": "수학과 문화", "category": "convergence-elective", "categoryTitle": "융합 선택", "recommendedGrades": [11, 12], "prerequisites": [], "defaultSemester": "school-defined", "conceptCount": 16, "units": [{ "id": "art-and-mathematics", "title": "예술과 수학", "order": 1, "concepts": [{ "id": "math-and-culture-01-01", "order": 1, "title": "음악과 수학", "standardCode": "12수문01-01", "achievementStandard": "음악과 관련된 수학적 내용을 조사하고, 관련 활동을 수행할 수 있다.", "topics": ["음악과 수학", "탐구 설계와 수행"], "scopeNotes": ["예술 속 수학의 아름다움과 유용성을 탐구하고 창작 활동으로 연결한다.", "자료와 작품을 활용할 때 출처를 명확히 밝힌다."], "visualizationIdeas": ["현의 길이 비와 음정이 파형·주파수로 연결되는 애니메이션", "원근법·황금비·쪽매맞춤을 작품 위 가이드로 중첩", "문학·영상의 수학적 구조를 장면 지도와 패턴으로 표현"] }, { "id": "math-and-culture-01-02", "order": 2, "title": "미술·사진과 수학", "standardCode": "12수문01-02", "achievementStandard": "미술과 관련된 수학적 내용을 조사하고, 관련 활동을 수행할 수 있다.", "topics": ["미술·사진과 수학", "탐구 설계와 수행"], "scopeNotes": ["예술 속 수학의 아름다움과 유용성을 탐구하고 창작 활동으로 연결한다.", "자료와 작품을 활용할 때 출처를 명확히 밝힌다."], "visualizationIdeas": ["현의 길이 비와 음정이 파형·주파수로 연결되는 애니메이션", "원근법·황금비·쪽매맞춤을 작품 위 가이드로 중첩", "문학·영상의 수학적 구조를 장면 지도와 패턴으로 표현"] }, { "id": "math-and-culture-01-03", "order": 3, "title": "문학과 수학", "standardCode": "12수문01-03", "achievementStandard": "문학과 관련된 수학적 내용을 조사하고, 관련 활동을 수행할 수 있다.", "topics": ["문학과 수학", "탐구 설계와 수행"], "scopeNotes": ["예술 속 수학의 아름다움과 유용성을 탐구하고 창작 활동으로 연결한다.", "자료와 작품을 활용할 때 출처를 명확히 밝힌다."], "visualizationIdeas": ["현의 길이 비와 음정이 파형·주파수로 연결되는 애니메이션", "원근법·황금비·쪽매맞춤을 작품 위 가이드로 중첩", "문학·영상의 수학적 구조를 장면 지도와 패턴으로 표현"] }, { "id": "math-and-culture-01-04", "order": 4, "title": "영화와 수학", "standardCode": "12수문01-04", "achievementStandard": "영화와 관련된 수학적 내용을 조사하고, 관련 활동을 수행할 수 있다.", "topics": ["영화와 수학", "탐구 설계와 수행"], "scopeNotes": ["예술 속 수학의 아름다움과 유용성을 탐구하고 창작 활동으로 연결한다.", "자료와 작품을 활용할 때 출처를 명확히 밝힌다."], "visualizationIdeas": ["현의 길이 비와 음정이 파형·주파수로 연결되는 애니메이션", "원근법·황금비·쪽매맞춤을 작품 위 가이드로 중첩", "문학·영상의 수학적 구조를 장면 지도와 패턴으로 표현"] }], "conceptCount": 4 }, { "id": "leisure-and-mathematics", "title": "여가와 수학", "order": 2, "concepts": [{ "id": "math-and-culture-02-01", "order": 1, "title": "스포츠와 수학", "standardCode": "12수문02-01", "achievementStandard": "스포츠와 관련된 수학적 내용을 조사하여 그 유용성을 인식할 수 있다.", "topics": ["스포츠와 수학", "탐구 설계와 수행"], "scopeNotes": ["여가와 기술 속 수학적 원리를 조사하고 합리적 의사 결정과 공정성을 함께 탐구한다."], "visualizationIdeas": ["스포츠 궤적·각도·점수 산출을 실제 장면 위에 시각화", "게임 전략을 확률나무와 상태 전이로 표현", "서로 다른 투표 방식에서 결과가 달라지는 시뮬레이션"] }, { "id": "math-and-culture-02-02", "order": 2, "title": "게임과 수학", "standardCode": "12수문02-02", "achievementStandard": "게임과 관련된 수학적 내용을 조사하고 관련 활동을 수행할 수 있다.", "topics": ["게임과 수학", "탐구 설계와 수행"], "scopeNotes": ["여가와 기술 속 수학적 원리를 조사하고 합리적 의사 결정과 공정성을 함께 탐구한다."], "visualizationIdeas": ["스포츠 궤적·각도·점수 산출을 실제 장면 위에 시각화", "게임 전략을 확률나무와 상태 전이로 표현", "서로 다른 투표 방식에서 결과가 달라지는 시뮬레이션"] }, { "id": "math-and-culture-02-03", "order": 3, "title": "디지털 기술과 수학", "standardCode": "12수문02-03", "achievementStandard": "디지털 기술에 활용된 수학적 내용을 조사하여 설명할 수 있다.", "topics": ["디지털 기술과 수학", "핵심 의미와 원리", "적용과 문제 해결", "탐구 설계와 수행"], "scopeNotes": ["여가와 기술 속 수학적 원리를 조사하고 합리적 의사 결정과 공정성을 함께 탐구한다."], "visualizationIdeas": ["스포츠 궤적·각도·점수 산출을 실제 장면 위에 시각화", "게임 전략을 확률나무와 상태 전이로 표현", "서로 다른 투표 방식에서 결과가 달라지는 시뮬레이션"] }, { "id": "math-and-culture-02-04", "order": 4, "title": "투표와 수학", "standardCode": "12수문02-04", "achievementStandard": "투표와 관련된 수학적 내용을 조사하고 이를 활용하여 합리적 의사 결정을 위한 방법을 제안할 수 있다.", "topics": ["투표와 수학", "수학적 표현과 해석", "적용과 문제 해결", "탐구 설계와 수행"], "scopeNotes": ["여가와 기술 속 수학적 원리를 조사하고 합리적 의사 결정과 공정성을 함께 탐구한다."], "visualizationIdeas": ["스포츠 궤적·각도·점수 산출을 실제 장면 위에 시각화", "게임 전략을 확률나무와 상태 전이로 표현", "서로 다른 투표 방식에서 결과가 달라지는 시뮬레이션"] }], "conceptCount": 4 }, { "id": "society-and-mathematics", "title": "사회와 수학", "order": 3, "concepts": [{ "id": "math-and-culture-03-01", "order": 1, "title": "민속·건축과 수학", "standardCode": "12수문03-01", "achievementStandard": "민속 수학과 건축 양식 속에 나타난 수학적 원리에 대해 탐구하고 문화 다양성을 이해한다.", "topics": ["민속·건축과 수학", "핵심 의미와 원리", "탐구 설계와 수행"], "scopeNotes": ["문화 다양성과 사회적 소수자를 배려하는 공동체 관점을 포함한다.", "데이터 해석과 소비 의사 결정에서 다양한 가치와 관점을 비교한다."], "visualizationIdeas": ["문화권별 달력·건축 패턴의 수 체계와 대칭 비교", "점자 배열을 이진 패턴과 진법으로 변환", "대중매체 데이터가 워드클라우드와 빈도 그래프로 변하는 과정"] }, { "id": "math-and-culture-03-02", "order": 2, "title": "점자와 진법", "standardCode": "12수문03-02", "achievementStandard": "점자표에 사용된 수학적 원리에 대해 탐구하고 이를 활용하여 산출물을 설계할 수 있다.", "topics": ["점자와 진법", "수학적 표현과 해석", "적용과 문제 해결", "탐구 설계와 수행"], "scopeNotes": ["문화 다양성과 사회적 소수자를 배려하는 공동체 관점을 포함한다.", "데이터 해석과 소비 의사 결정에서 다양한 가치와 관점을 비교한다."], "visualizationIdeas": ["문화권별 달력·건축 패턴의 수 체계와 대칭 비교", "점자 배열을 이진 패턴과 진법으로 변환", "대중매체 데이터가 워드클라우드와 빈도 그래프로 변하는 과정"] }, { "id": "math-and-culture-03-03", "order": 3, "title": "대중매체 데이터", "standardCode": "12수문03-03", "achievementStandard": "대중매체로부터 얻은 데이터를 정리, 분석하여 그 의미와 가치를 해석할 수 있다.", "topics": ["대중매체 데이터", "핵심 의미와 원리", "탐구 설계와 수행"], "scopeNotes": ["문화 다양성과 사회적 소수자를 배려하는 공동체 관점을 포함한다.", "데이터 해석과 소비 의사 결정에서 다양한 가치와 관점을 비교한다."], "visualizationIdeas": ["문화권별 달력·건축 패턴의 수 체계와 대칭 비교", "점자 배열을 이진 패턴과 진법으로 변환", "대중매체 데이터가 워드클라우드와 빈도 그래프로 변하는 과정"] }, { "id": "math-and-culture-03-04", "order": 4, "title": "가치소비와 의사 결정", "standardCode": "12수문03-04", "achievementStandard": "가치소비를 위한 의사 결정 방법을 탐구하고 실천 방법을 제시할 수 있다.", "topics": ["가치소비와 의사 결정", "적용과 문제 해결", "탐구 설계와 수행"], "scopeNotes": ["문화 다양성과 사회적 소수자를 배려하는 공동체 관점을 포함한다.", "데이터 해석과 소비 의사 결정에서 다양한 가치와 관점을 비교한다."], "visualizationIdeas": ["문화권별 달력·건축 패턴의 수 체계와 대칭 비교", "점자 배열을 이진 패턴과 진법으로 변환", "대중매체 데이터가 워드클라우드와 빈도 그래프로 변하는 과정"] }], "conceptCount": 4 }, { "id": "environment-and-mathematics", "title": "환경과 수학", "order": 4, "concepts": [{ "id": "math-and-culture-04-01", "order": 1, "title": "식생활 문제의 수학적 분석", "standardCode": "12수문04-01", "achievementStandard": "식생활과 관련된 문제를 수학적으로 분석하고 이를 개선하기 위한 방법을 제안할 수 있다.", "topics": ["식생활 문제의 수학적 분석", "적용과 문제 해결", "탐구 설계와 수행"], "scopeNotes": ["환경 자료의 출처를 밝히고 공학 도구를 이용해 분석할 수 있다.", "분석 결과를 토대로 개선 방안과 실천을 함께 제안한다."], "visualizationIdeas": ["식단 영양·식량 자료를 비율과 그래프로 재구성", "탄소 배출과 기온 자료를 시간축·산점도·추세선으로 비교", "서식지 감소와 생물 다양성 변화를 지도와 그래프로 연결"] }, { "id": "math-and-culture-04-02", "order": 2, "title": "대기 오염의 수학적 분석", "standardCode": "12수문04-02", "achievementStandard": "대기 오염과 관련된 문제를 수학적으로 분석하고 이를 개선하기 위한 방법을 제안할 수 있다.", "topics": ["대기 오염의 수학적 분석", "적용과 문제 해결", "탐구 설계와 수행"], "scopeNotes": ["환경 자료의 출처를 밝히고 공학 도구를 이용해 분석할 수 있다.", "분석 결과를 토대로 개선 방안과 실천을 함께 제안한다."], "visualizationIdeas": ["식단 영양·식량 자료를 비율과 그래프로 재구성", "탄소 배출과 기온 자료를 시간축·산점도·추세선으로 비교", "서식지 감소와 생물 다양성 변화를 지도와 그래프로 연결"] }, { "id": "math-and-culture-04-03", "order": 3, "title": "사막화의 수학적 분석", "standardCode": "12수문04-03", "achievementStandard": "사막화 현상과 관련된 문제를 수학적으로 분석하고 이를 개선하기 위한 방법을 제안 할 수 있다.", "topics": ["사막화의 수학적 분석", "적용과 문제 해결", "탐구 설계와 수행"], "scopeNotes": ["환경 자료의 출처를 밝히고 공학 도구를 이용해 분석할 수 있다.", "분석 결과를 토대로 개선 방안과 실천을 함께 제안한다."], "visualizationIdeas": ["식단 영양·식량 자료를 비율과 그래프로 재구성", "탄소 배출과 기온 자료를 시간축·산점도·추세선으로 비교", "서식지 감소와 생물 다양성 변화를 지도와 그래프로 연결"] }, { "id": "math-and-culture-04-04", "order": 4, "title": "생물 다양성과 생명권", "standardCode": "12수문04-04", "achievementStandard": "생물 다양성과 생명권 관련 자료를 수학적으로 분석하고 이를 통해 생태 감수성을 함양할 수 있다.", "topics": ["생물 다양성과 생명권", "탐구 설계와 수행"], "scopeNotes": ["환경 자료의 출처를 밝히고 공학 도구를 이용해 분석할 수 있다.", "분석 결과를 토대로 개선 방안과 실천을 함께 제안한다."], "visualizationIdeas": ["식단 영양·식량 자료를 비율과 그래프로 재구성", "탄소 배출과 기온 자료를 시간축·산점도·추세선으로 비교", "서식지 감소와 생물 다양성 변화를 지도와 그래프로 연결"] }], "conceptCount": 4 }], "categoryEnglishTitle": "CONVERGENCE ELECTIVE", "categoryDescription": "수학을 문화, 통계, 탐구 활동과 연결하는 과목입니다.", "categoryOrder": 4, "placementLabel": "학교별 개설·편성", "sourceFile": "kr-2022-math-and-culture.yaml", "developmentLocked": true }, { "id": "practical-statistics", "officialTitle": "실용 통계", "category": "convergence-elective", "categoryTitle": "융합 선택", "recommendedGrades": [11, 12], "prerequisites": ["common-math-1", "common-math-2"], "defaultSemester": "school-defined", "conceptCount": 13, "units": [{ "id": "statistics-and-statistical-problems", "title": "통계와 통계적 문제", "order": 1, "concepts": [{ "id": "practical-statistics-01-01", "order": 1, "title": "통계의 유용성과 필요성", "standardCode": "12실통01-01", "achievementStandard": "통계와 통계적 방법의 유용성과 필요성을 인식할 수 있다.", "topics": ["통계의 유용성과 필요성", "핵심 관계"], "scopeNotes": ["불확실성과 변이성을 고려해 통계적으로 해결 가능한 문제를 구분한다.", "전수조사와 표본조사, 대표적인 확률표출 방법을 사례 중심으로 다룬다."], "visualizationIdeas": ["같은 현상에서 반복 측정값이 흩어지는 변이성 시뮬레이션", "모집단에서 서로 다른 방법으로 표본을 뽑아 편향 비교", "문제 설정부터 결론까지 통계적 문제 해결 순환 과정 표현"] }, { "id": "practical-statistics-01-02", "order": 2, "title": "통계적 문제 해결 과정", "standardCode": "12실통01-02", "achievementStandard": "통계적 문제해결 과정을 이해하고 각 단계의 역할을 설명할 수 있다.", "topics": ["통계적 문제 해결 과정", "핵심 의미와 원리", "적용과 문제 해결"], "scopeNotes": ["불확실성과 변이성을 고려해 통계적으로 해결 가능한 문제를 구분한다.", "전수조사와 표본조사, 대표적인 확률표출 방법을 사례 중심으로 다룬다."], "visualizationIdeas": ["같은 현상에서 반복 측정값이 흩어지는 변이성 시뮬레이션", "모집단에서 서로 다른 방법으로 표본을 뽑아 편향 비교", "문제 설정부터 결론까지 통계적 문제 해결 순환 과정 표현"] }, { "id": "practical-statistics-01-03", "order": 3, "title": "모집단·표본과 표본추출", "standardCode": "12실통01-03", "achievementStandard": "모집단과 표본의 뜻을 알고, 표본추출의 방법을 이해하여 문제 상황에 맞는 방법을 선택할 수 있다.", "topics": ["모집단·표본과 표본추출", "핵심 의미와 원리", "수학적 표현과 해석", "적용과 문제 해결"], "scopeNotes": ["불확실성과 변이성을 고려해 통계적으로 해결 가능한 문제를 구분한다.", "전수조사와 표본조사, 대표적인 확률표출 방법을 사례 중심으로 다룬다."], "visualizationIdeas": ["같은 현상에서 반복 측정값이 흩어지는 변이성 시뮬레이션", "모집단에서 서로 다른 방법으로 표본을 뽑아 편향 비교", "문제 설정부터 결론까지 통계적 문제 해결 순환 과정 표현"] }], "conceptCount": 3 }, { "id": "data-collection-and-organization", "title": "자료의 수집과 정리", "order": 2, "concepts": [{ "id": "practical-statistics-02-01", "order": 1, "title": "자료의 종류와 척도", "standardCode": "12실통02-01", "achievementStandard": "자료의 종류를 알고 설명할 수 있다.", "topics": ["자료의 종류와 척도", "핵심 의미와 원리"], "scopeNotes": ["계산이나 그래프 작성 자체보다 결과 해석에 중점을 둔다.", "자료 수집과 시각화 과정에서 오류와 편향을 비판적으로 검토한다."], "visualizationIdeas": ["범주형·수치형 자료와 네 가지 척도를 카드 분류 방식으로 비교", "동일 자료를 여러 그래프로 바꾸며 적합성과 왜곡 가능성 비교", "자료점 이동에 따라 평균·중앙값·표준편차가 변하는 인터랙션"] }, { "id": "practical-statistics-02-02", "order": 2, "title": "자료 수집 방법", "standardCode": "12실통02-02", "achievementStandard": "자료의 수집 방법을 이해하고 문제 상황에 맞는 자료 수집 방법을 선택할 수 있다.", "topics": ["자료 수집 방법", "핵심 의미와 원리", "적용과 문제 해결"], "scopeNotes": ["계산이나 그래프 작성 자체보다 결과 해석에 중점을 둔다.", "자료 수집과 시각화 과정에서 오류와 편향을 비판적으로 검토한다."], "visualizationIdeas": ["범주형·수치형 자료와 네 가지 척도를 카드 분류 방식으로 비교", "동일 자료를 여러 그래프로 바꾸며 적합성과 왜곡 가능성 비교", "자료점 이동에 따라 평균·중앙값·표준편차가 변하는 인터랙션"] }, { "id": "practical-statistics-02-03", "order": 3, "title": "자료와 그래프", "standardCode": "12실통02-03", "achievementStandard": "그래프의 종류를 알고 자료의 특성을 나타내는 적절한 그래프를 그릴 수 있다.", "topics": ["자료와 그래프", "수학적 표현과 해석"], "scopeNotes": ["계산이나 그래프 작성 자체보다 결과 해석에 중점을 둔다.", "자료 수집과 시각화 과정에서 오류와 편향을 비판적으로 검토한다."], "visualizationIdeas": ["범주형·수치형 자료와 네 가지 척도를 카드 분류 방식으로 비교", "동일 자료를 여러 그래프로 바꾸며 적합성과 왜곡 가능성 비교", "자료점 이동에 따라 평균·중앙값·표준편차가 변하는 인터랙션"] }, { "id": "practical-statistics-02-04", "order": 4, "title": "대푯값과 산포도", "standardCode": "12실통02-04", "achievementStandard": "대푯값과 산포도의 종류를 알고 자료의 특성을 나타내는 값으로 요약할 수 있다.", "topics": ["대푯값과 산포도", "핵심 관계"], "scopeNotes": ["계산이나 그래프 작성 자체보다 결과 해석에 중점을 둔다.", "자료 수집과 시각화 과정에서 오류와 편향을 비판적으로 검토한다."], "visualizationIdeas": ["범주형·수치형 자료와 네 가지 척도를 카드 분류 방식으로 비교", "동일 자료를 여러 그래프로 바꾸며 적합성과 왜곡 가능성 비교", "자료점 이동에 따라 평균·중앙값·표준편차가 변하는 인터랙션"] }], "conceptCount": 4 }, { "id": "data-analysis", "title": "자료의 분석", "order": 3, "concepts": [{ "id": "practical-statistics-03-01", "order": 1, "title": "정규분포와 t분포", "standardCode": "12실통03-01", "achievementStandard": "정규분포와 t 분포를 공학 도구를 이용하여 탐구할 수 있다.", "topics": ["정규분포와 t분포", "계산 방법과 절차", "탐구 설계와 수행"], "scopeNotes": ["이론 전개보다 공학 도구를 이용한 통계적 추론과 결과 해석에 중점을 둔다.", "가설과 유의수준, p값의 의미를 실제 사례와 연결한다."], "visualizationIdeas": ["표본 크기에 따라 정규분포와 t분포 곡선이 가까워지는 애니메이션", "표본을 반복 추출하며 신뢰구간이 모수를 포함하는 빈도 시뮬레이션", "귀무가설 분포에서 관측값과 p값 영역을 색으로 표시"] }, { "id": "practical-statistics-03-02", "order": 2, "title": "모평균 추정", "standardCode": "12실통03-02", "achievementStandard": "실생활에서 공학 도구를 이용하여 모평균을 추정할 수 있다.", "topics": ["모평균 추정", "적용과 문제 해결"], "scopeNotes": ["이론 전개보다 공학 도구를 이용한 통계적 추론과 결과 해석에 중점을 둔다.", "가설과 유의수준, p값의 의미를 실제 사례와 연결한다."], "visualizationIdeas": ["표본 크기에 따라 정규분포와 t분포 곡선이 가까워지는 애니메이션", "표본을 반복 추출하며 신뢰구간이 모수를 포함하는 빈도 시뮬레이션", "귀무가설 분포에서 관측값과 p값 영역을 색으로 표시"] }, { "id": "practical-statistics-03-03", "order": 3, "title": "모비율 추정", "standardCode": "12실통03-03", "achievementStandard": "실생활에서 공학 도구를 이용하여 모비율을 추정할 수 있다.", "topics": ["모비율 추정", "적용과 문제 해결"], "scopeNotes": ["이론 전개보다 공학 도구를 이용한 통계적 추론과 결과 해석에 중점을 둔다.", "가설과 유의수준, p값의 의미를 실제 사례와 연결한다."], "visualizationIdeas": ["표본 크기에 따라 정규분포와 t분포 곡선이 가까워지는 애니메이션", "표본을 반복 추출하며 신뢰구간이 모수를 포함하는 빈도 시뮬레이션", "귀무가설 분포에서 관측값과 p값 영역을 색으로 표시"] }, { "id": "practical-statistics-03-04", "order": 4, "title": "가설검정", "standardCode": "12실통03-04", "achievementStandard": "가설검정을 이해하고, 실생활에서 공학 도구를 이용하여 가설을 검정할 수 있다.", "topics": ["가설검정", "핵심 의미와 원리", "적용과 문제 해결"], "scopeNotes": ["이론 전개보다 공학 도구를 이용한 통계적 추론과 결과 해석에 중점을 둔다.", "가설과 유의수준, p값의 의미를 실제 사례와 연결한다."], "visualizationIdeas": ["표본 크기에 따라 정규분포와 t분포 곡선이 가까워지는 애니메이션", "표본을 반복 추출하며 신뢰구간이 모수를 포함하는 빈도 시뮬레이션", "귀무가설 분포에서 관측값과 p값 영역을 색으로 표시"] }], "conceptCount": 4 }, { "id": "statistical-inquiry", "title": "통계적 탐구", "order": 4, "concepts": [{ "id": "practical-statistics-04-01", "order": 1, "title": "통계적 탐구와 의사 결정", "standardCode": "12실통04-01", "achievementStandard": "실생활에서 통계적 탐구 과정에 따라 문제를 해결하고 합리적인 의사 결정을 할 수 있다.", "topics": ["통계적 탐구와 의사 결정", "적용과 문제 해결", "탐구 설계와 수행"], "scopeNotes": ["표본 조사 설계, 자료 수집, 분석, 결론 도출의 전 과정에서 연구 윤리를 준수한다.", "탐구 목적과 통계 방법의 적합성을 비판적으로 성찰한다."], "visualizationIdeas": ["탐구 질문→조사 설계→자료→분석→결론을 하나의 대시보드 흐름으로 표현", "표본·그래프·분석 방법 선택이 결론에 미치는 영향을 비교"] }, { "id": "practical-statistics-04-02", "order": 2, "title": "통계적 탐구의 성찰", "standardCode": "12실통04-02", "achievementStandard": "통계적 탐구 과정과 그 결과를 비판적으로 성찰할 수 있다.", "topics": ["통계적 탐구의 성찰", "탐구 설계와 수행"], "scopeNotes": ["표본 조사 설계, 자료 수집, 분석, 결론 도출의 전 과정에서 연구 윤리를 준수한다.", "탐구 목적과 통계 방법의 적합성을 비판적으로 성찰한다."], "visualizationIdeas": ["탐구 질문→조사 설계→자료→분석→결론을 하나의 대시보드 흐름으로 표현", "표본·그래프·분석 방법 선택이 결론에 미치는 영향을 비교"] }], "conceptCount": 2 }], "categoryEnglishTitle": "CONVERGENCE ELECTIVE", "categoryDescription": "수학을 문화, 통계, 탐구 활동과 연결하는 과목입니다.", "categoryOrder": 4, "placementLabel": "학교별 개설·편성", "sourceFile": "kr-2022-practical-statistics.yaml", "developmentLocked": true }, { "id": "math-research-project", "officialTitle": "수학과제 탐구", "category": "convergence-elective", "categoryTitle": "융합 선택", "recommendedGrades": [11, 12], "prerequisites": [], "defaultSemester": "school-defined", "conceptCount": 10, "units": [{ "id": "understanding-math-inquiry", "title": "과제 탐구의 이해", "order": 1, "concepts": [{ "id": "math-research-project-01-01", "order": 1, "title": "수학과제 탐구의 의미와 필요성", "standardCode": "12수과01-01", "achievementStandard": "수학과제 탐구의 의미와 필요성을 설명할 수 있다.", "topics": ["수학과제 탐구의 의미와 필요성", "핵심 의미와 원리", "탐구 설계와 수행"], "scopeNotes": ["학생 수준에 맞는 현실적 탐구를 안내하고 과도한 심화는 지양한다.", "표절·조작 방지, 출처 표기, 생명윤리와 안전을 탐구 전 과정에서 준수한다."], "visualizationIdeas": ["일상 질문이 수학적 탐구 문제로 구체화되는 단계별 흐름", "올바른 인용·표절·자료 조작 사례를 비교하는 의사 결정 시나리오"] }, { "id": "math-research-project-01-02", "order": 2, "title": "연구 윤리", "standardCode": "12수과01-02", "achievementStandard": "올바른 연구 윤리를 이해하고, 탐구의 전 과정에서 이를 준수한다.", "topics": ["연구 윤리", "핵심 의미와 원리", "탐구 설계와 수행"], "scopeNotes": ["학생 수준에 맞는 현실적 탐구를 안내하고 과도한 심화는 지양한다.", "표절·조작 방지, 출처 표기, 생명윤리와 안전을 탐구 전 과정에서 준수한다."], "visualizationIdeas": ["일상 질문이 수학적 탐구 문제로 구체화되는 단계별 흐름", "올바른 인용·표절·자료 조작 사례를 비교하는 의사 결정 시나리오"] }], "conceptCount": 2 }, { "id": "inquiry-methods-and-procedures", "title": "과제 탐구의 방법과 절차", "order": 2, "concepts": [{ "id": "math-research-project-02-01", "order": 1, "title": "문헌 조사", "standardCode": "12수과02-01", "achievementStandard": "문헌 조사를 통해 탐구하는 방법과 절차를 이해하고 설명할 수 있다.", "topics": ["문헌 조사", "핵심 의미와 원리", "탐구 설계와 수행"], "scopeNotes": ["탐구 주제에 따라 문헌 조사·사례 조사·수학 실험·개발 연구 중 적절한 방법을 선택한다.", "자료를 허위로 만들거나 임의로 조작하지 않는다."], "visualizationIdeas": ["네 가지 탐구 방법의 입력 자료·절차·산출물을 비교하는 흐름도", "수학적 모델링의 현실 문제→수학 문제→해결→현실 해석 순환 애니메이션", "퍼즐·게임·공학 도구 산출물의 설계와 반복 개선 과정"] }, { "id": "math-research-project-02-02", "order": 2, "title": "사례 조사", "standardCode": "12수과02-02", "achievementStandard": "사례 조사를 통해 탐구하는 방법과 절차를 이해하고 설명할 수 있다.", "topics": ["사례 조사", "핵심 의미와 원리", "탐구 설계와 수행"], "scopeNotes": ["탐구 주제에 따라 문헌 조사·사례 조사·수학 실험·개발 연구 중 적절한 방법을 선택한다.", "자료를 허위로 만들거나 임의로 조작하지 않는다."], "visualizationIdeas": ["네 가지 탐구 방법의 입력 자료·절차·산출물을 비교하는 흐름도", "수학적 모델링의 현실 문제→수학 문제→해결→현실 해석 순환 애니메이션", "퍼즐·게임·공학 도구 산출물의 설계와 반복 개선 과정"] }, { "id": "math-research-project-02-03", "order": 3, "title": "수학 실험", "standardCode": "12수과02-03", "achievementStandard": "수학 실험을 통해 탐구하는 방법과 절차를 이해하고 설명할 수 있다.", "topics": ["수학 실험", "핵심 의미와 원리", "탐구 설계와 수행"], "scopeNotes": ["탐구 주제에 따라 문헌 조사·사례 조사·수학 실험·개발 연구 중 적절한 방법을 선택한다.", "자료를 허위로 만들거나 임의로 조작하지 않는다."], "visualizationIdeas": ["네 가지 탐구 방법의 입력 자료·절차·산출물을 비교하는 흐름도", "수학적 모델링의 현실 문제→수학 문제→해결→현실 해석 순환 애니메이션", "퍼즐·게임·공학 도구 산출물의 설계와 반복 개선 과정"] }, { "id": "math-research-project-02-04", "order": 4, "title": "개발 연구", "standardCode": "12수과02-04", "achievementStandard": "개발 연구를 통해 탐구하는 방법과 절차를 이해하고 설명할 수 있다.", "topics": ["개발 연구", "핵심 의미와 원리", "탐구 설계와 수행"], "scopeNotes": ["탐구 주제에 따라 문헌 조사·사례 조사·수학 실험·개발 연구 중 적절한 방법을 선택한다.", "자료를 허위로 만들거나 임의로 조작하지 않는다."], "visualizationIdeas": ["네 가지 탐구 방법의 입력 자료·절차·산출물을 비교하는 흐름도", "수학적 모델링의 현실 문제→수학 문제→해결→현실 해석 순환 애니메이션", "퍼즐·게임·공학 도구 산출물의 설계와 반복 개선 과정"] }], "conceptCount": 4 }, { "id": "inquiry-execution-and-evaluation", "title": "과제 탐구의 실행 및 평가", "order": 3, "concepts": [{ "id": "math-research-project-03-01", "order": 1, "title": "탐구 주제와 계획", "standardCode": "12수과03-01", "achievementStandard": "여러 가지 현상에서 수학 탐구 주제를 선정하고 탐구 계획을 수립할 수 있다.", "topics": ["탐구 주제와 계획", "탐구 설계와 수행"], "scopeNotes": ["탐구 문제의 명확성·가치·실행 가능성을 고려해 계획을 수립한다.", "과정 중간 점검과 수정, 역할 분담, 자료 기반 의사 결정을 포함한다.", "탐구 목적과 방법의 적합성을 자기·동료 평가로 성찰한다."], "visualizationIdeas": ["주제 후보를 가치·실행 가능성·시간 기준으로 평가하는 매트릭스", "계획→수행→중간 점검→수정→결론의 프로젝트 타임라인", "탐구 산출물의 근거·표현·한계점을 루브릭으로 시각화"] }, { "id": "math-research-project-03-02", "order": 2, "title": "탐구 수행", "standardCode": "12수과03-02", "achievementStandard": "적절한 탐구 방법과 절차에 따라 탐구를 수행할 수 있다.", "topics": ["탐구 수행", "탐구 설계와 수행"], "scopeNotes": ["탐구 문제의 명확성·가치·실행 가능성을 고려해 계획을 수립한다.", "과정 중간 점검과 수정, 역할 분담, 자료 기반 의사 결정을 포함한다.", "탐구 목적과 방법의 적합성을 자기·동료 평가로 성찰한다."], "visualizationIdeas": ["주제 후보를 가치·실행 가능성·시간 기준으로 평가하는 매트릭스", "계획→수행→중간 점검→수정→결론의 프로젝트 타임라인", "탐구 산출물의 근거·표현·한계점을 루브릭으로 시각화"] }, { "id": "math-research-project-03-03", "order": 3, "title": "산출물과 발표", "standardCode": "12수과03-03", "achievementStandard": "탐구 결과를 정리하여 산출물을 만들고 발표할 수 있다.", "topics": ["산출물과 발표", "수학적 표현과 해석", "탐구 설계와 수행"], "scopeNotes": ["탐구 문제의 명확성·가치·실행 가능성을 고려해 계획을 수립한다.", "과정 중간 점검과 수정, 역할 분담, 자료 기반 의사 결정을 포함한다.", "탐구 목적과 방법의 적합성을 자기·동료 평가로 성찰한다."], "visualizationIdeas": ["주제 후보를 가치·실행 가능성·시간 기준으로 평가하는 매트릭스", "계획→수행→중간 점검→수정→결론의 프로젝트 타임라인", "탐구 산출물의 근거·표현·한계점을 루브릭으로 시각화"] }, { "id": "math-research-project-03-04", "order": 4, "title": "탐구 성찰과 평가", "standardCode": "12수과03-04", "achievementStandard": "탐구 과정과 결과를 반성하고 평가할 수 있다.", "topics": ["탐구 성찰과 평가", "탐구 설계와 수행"], "scopeNotes": ["탐구 문제의 명확성·가치·실행 가능성을 고려해 계획을 수립한다.", "과정 중간 점검과 수정, 역할 분담, 자료 기반 의사 결정을 포함한다.", "탐구 목적과 방법의 적합성을 자기·동료 평가로 성찰한다."], "visualizationIdeas": ["주제 후보를 가치·실행 가능성·시간 기준으로 평가하는 매트릭스", "계획→수행→중간 점검→수정→결론의 프로젝트 타임라인", "탐구 산출물의 근거·표현·한계점을 루브릭으로 시각화"] }], "conceptCount": 4 }], "categoryEnglishTitle": "CONVERGENCE ELECTIVE", "categoryDescription": "수학을 문화, 통계, 탐구 활동과 연결하는 과목입니다.", "categoryOrder": 4, "placementLabel": "학교별 개설·편성", "sourceFile": "kr-2022-math-research-project.yaml", "developmentLocked": true }] }], "courses": [{ "id": "common-math-1", "officialTitle": "공통수학1", "defaultSemester": 1, "conceptCount": 19, "units": [{ "id": "polynomials", "title": "다항식", "order": 1, "concepts": [{ "id": "polynomial-arithmetic", "order": 1, "title": "다항식의 사칙연산", "standardCode": "10공수1-01-01", "achievementStandard": "다항식의 사칙연산의 원리를 설명하고, 그 계산을 할 수 있다.", "topics": ["다항식의 덧셈과 뺄셈", "다항식의 곱셈", "다항식의 나눗셈", "몫과 나머지의 관계", "조립제법"], "scopeNotes": ["조립제법은 구체적인 예를 통해 간단히 다룬다.", "중학교의 다항식을 단항식으로 나누는 연산과 연결한다."], "visualizationIdeas": ["대수 타일로 다항식의 덧셈과 곱셈 표현", "넓이 모델로 다항식의 곱셈 표현", "나눗셈 블록이 몫과 나머지로 분해되는 애니메이션"] }, { "id": "identity-remainder-theorem", "order": 2, "title": "항등식과 나머지정리", "standardCode": "10공수1-01-02", "achievementStandard": "항등식의 성질과 나머지정리를 이해하고, 이를 활용하여 문제를 해결할 수 있다.", "topics": ["항등식의 뜻", "방정식과 항등식의 차이", "미정계수법", "계수 비교법", "수치 대입법", "나머지정리", "인수정리"], "scopeNotes": ["항등식의 성질과 나머지정리를 활용하는 복잡한 문제는 다루지 않는다.", "인수정리를 활용하는 복잡한 문제는 다루지 않는다."], "visualizationIdeas": ["여러 x값에서도 양변이 항상 같게 유지되는 그래프", "P(x)를 x-a로 나눈 몫과 나머지의 블록 분해", "x=a에서 P(a)가 나머지가 되는 과정"] }, { "id": "polynomial-factorization", "order": 3, "title": "다항식의 인수분해", "standardCode": "10공수1-01-03", "achievementStandard": "다항식의 인수분해를 할 수 있다.", "topics": ["공통인수 묶기", "곱셈공식을 역으로 이용하기", "항을 묶어 인수분해하기", "치환을 이용한 인수분해", "인수정리를 이용한 인수분해", "조립제법을 이용한 인수분해"], "scopeNotes": ["중학교에서 학습한 인수분해에서 확장한다.", "복잡한 인수분해 문제는 다루지 않는다."], "visualizationIdeas": ["하나의 넓이를 두 변의 곱으로 재구성", "다항식 블록을 공통인수별로 묶기", "근과 인수가 연결되는 그래프"] }], "conceptCount": 3 }, { "id": "equations-and-inequalities", "title": "방정식과 부등식", "order": 2, "concepts": [{ "id": "complex-numbers", "order": 1, "title": "복소수의 뜻과 연산", "standardCode": "10공수1-02-01", "achievementStandard": "복소수의 뜻과 성질을 설명하고, 사칙연산을 수행할 수 있다.", "topics": ["허수단위 i", "복소수 a+bi", "실수부분과 허수부분", "허수와 켤레복소수", "복소수의 덧셈과 뺄셈", "복소수의 곱셈", "복소수의 나눗셈", "i의 거듭제곱"], "scopeNotes": ["실수의 성질 및 사칙연산과 연결하여 이해한다.", "나눗셈은 켤레복소수를 이용하여 계산한다."], "visualizationIdeas": ["실수선이 복소평면으로 확장되는 애니메이션", "i를 곱할 때 90도 회전하는 표현", "켤레복소수가 실수축에 대칭되는 표현"] }, { "id": "quadratic-discriminant", "order": 2, "title": "이차방정식의 실근·허근과 판별식", "standardCode": "10공수1-02-02", "achievementStandard": "이차방정식의 실근과 허근을 이해하고, 판별식을 이용하여 이차방정식의 근을 판별할 수 있다.", "topics": ["이차방정식의 근", "실근과 허근", "중근", "판별식 D=b²-4ac", "판별식과 근의 종류"], "scopeNotes": ["이차방정식의 계수가 실수인 경우만 다룬다.", "복소수 범위에서 이차방정식은 항상 근을 갖는다는 것을 이해한다."], "visualizationIdeas": ["판별식 변화에 따른 포물선과 x축의 교점 변화", "두 실근이 중근을 거쳐 허근이 되는 연속 애니메이션"] }, { "id": "quadratic-roots-and-coefficients", "order": 3, "title": "이차방정식의 근과 계수의 관계", "standardCode": "10공수1-02-03", "achievementStandard": "이차방정식의 근과 계수의 관계를 설명할 수 있다.", "topics": ["두 근의 합", "두 근의 곱", "근과 계수의 관계 유도", "두 근으로 이차방정식 만들기"], "scopeNotes": ["근과 계수의 관계를 활용하는 지나치게 복잡한 문제는 다루지 않는다."], "visualizationIdeas": ["두 근이 이동할 때 계수가 변화하는 그래프", "(x-α)(x-β)가 전개되며 계수와 연결되는 애니메이션"] }, { "id": "quadratic-equation-and-function", "order": 4, "title": "이차방정식과 이차함수의 관계", "standardCode": "10공수1-02-04", "achievementStandard": "이차방정식과 이차함수를 연결하여 그 관계를 설명할 수 있다.", "topics": ["f(x)=0의 의미", "이차방정식의 근과 x절편", "실근의 개수와 교점 개수", "중근과 접점", "판별식의 그래프적 의미"], "visualizationIdeas": ["식의 근이 그래프의 x절편으로 이동하는 변환", "대수적 풀이와 그래프 풀이의 동시 표시"] }, { "id": "parabola-and-line", "order": 5, "title": "이차함수 그래프와 직선의 위치 관계", "standardCode": "10공수1-02-05", "achievementStandard": "이차함수의 그래프와 직선의 위치 관계를 판단할 수 있다.", "topics": ["포물선과 직선의 교점", "두 점에서 만나는 경우", "접하는 경우", "만나지 않는 경우", "판별식을 이용한 위치 관계 판단"], "visualizationIdeas": ["직선이 이동하며 교점이 2개·1개·0개로 변하는 애니메이션", "교점 개수와 판별식 부호를 동시에 표시"] }, { "id": "quadratic-max-min-restricted", "order": 6, "title": "제한된 범위에서 이차함수의 최대·최소", "standardCode": "10공수1-02-06", "achievementStandard": "이차함수의 최대, 최소를 탐구하고, 이를 실생활과 연결하여 유용성을 인식할 수 있다.", "topics": ["이차함수의 꼭짓점", "제한된 구간", "구간 안에 꼭짓점이 있는 경우", "구간 밖에 꼭짓점이 있는 경우", "양 끝점과 꼭짓점의 함숫값 비교", "실생활 최적화 문제"], "scopeNotes": ["이차함수의 최대와 최소는 제한된 범위에서만 다룬다."], "visualizationIdeas": ["그래프 위 제한 구간을 움직이며 최대·최소 후보 비교", "꼭짓점과 구간 양 끝점에 값 표시"] }, { "id": "cubic-and-quartic-equations", "order": 7, "title": "삼차방정식과 사차방정식", "standardCode": "10공수1-02-07", "achievementStandard": "간단한 삼차방정식과 사차방정식을 풀 수 있다.", "topics": ["삼차방정식", "사차방정식", "인수분해를 이용한 풀이", "인수정리와 조립제법", "간단한 치환"], "scopeNotes": ["계수가 실수인 경우만 다룬다.", "인수분해 공식, 인수정리, 조립제법으로 풀 수 있는 경우만 다룬다."], "visualizationIdeas": ["고차다항식이 일차·이차 인수로 분해되는 애니메이션", "각 인수의 근이 그래프의 절편과 연결되는 표현"] }, { "id": "simultaneous-quadratic-equations", "order": 8, "title": "연립이차방정식", "standardCode": "10공수1-02-08", "achievementStandard": "미지수가 2개인 연립이차방정식을 풀 수 있다.", "topics": ["일차식과 이차식의 연립", "대입을 통한 일원화", "두 이차식의 연립", "인수분해를 이용한 풀이", "그래프의 교점과 해"], "scopeNotes": ["일차식과 이차식이 각각 한 개씩 주어진 경우를 다룬다.", "두 이차식 중 한 이차식이 간단히 인수분해되는 경우를 다룬다."], "visualizationIdeas": ["두 그래프의 교점이 연립방정식의 해가 되는 표현", "대입으로 두 변수 중 하나가 제거되는 과정"] }, { "id": "simultaneous-linear-inequalities", "order": 9, "title": "연립일차부등식", "standardCode": "10공수1-02-09", "achievementStandard": "미지수가 1개인 연립일차부등식을 풀 수 있다.", "topics": ["일차부등식의 해", "두 부등식의 공통 해", "수직선 표현", "해가 없는 경우", "모든 실수가 해인 경우"], "visualizationIdeas": ["두 수직선 범위가 겹치는 부분을 강조", "부등식별 범위를 합성하여 공통 해 생성"] }, { "id": "absolute-linear-inequalities", "order": 10, "title": "절댓값을 포함한 일차부등식", "standardCode": "10공수1-02-10", "achievementStandard": "절댓값을 포함한 일차부등식을 풀 수 있다.", "topics": ["절댓값의 거리 의미", "|x|<a", "|x|>a", "|x-a|<b", "경우를 나누는 풀이", "수직선에서 해석하기"], "visualizationIdeas": ["기준점에서의 거리로 절댓값 범위 표현", "수직선 위 두 경계가 벌어지고 좁아지는 애니메이션"] }, { "id": "quadratic-inequalities", "order": 11, "title": "이차부등식과 연립이차부등식", "standardCode": "10공수1-02-11", "achievementStandard": "이차부등식과 이차함수를 연결하여 그 관계를 설명하고, 이차부등식과 연립이차부등식을 풀 수 있다.", "topics": ["이차식의 부호", "이차함수 그래프와 이차부등식", "두 실근을 갖는 경우", "중근을 갖는 경우", "실근이 없는 경우", "연립이차부등식의 공통 해"], "visualizationIdeas": ["그래프가 x축 위·아래인 구간을 색으로 구분", "그래프의 부호 구간을 수직선 해로 변환"] }], "conceptCount": 11 }, { "id": "counting", "title": "경우의 수", "order": 3, "concepts": [{ "id": "addition-and-multiplication-principles", "order": 1, "title": "합의 법칙과 곱의 법칙", "standardCode": "10공수1-03-01", "achievementStandard": "합의 법칙과 곱의 법칙을 이해하고, 적절한 전략을 사용하여 경우의 수와 관련된 문제를 해결할 수 있다.", "topics": ["직접 나열하기", "표와 수형도", "합의 법칙", "곱의 법칙", "두 법칙이 적용되는 상황의 차이"], "scopeNotes": ["구체적인 예를 중심으로 간단히 다룬다.", "지나치게 복잡한 경우의 수 문제는 다루지 않는다."], "visualizationIdeas": ["선택 경로를 나무 모양으로 확장", "서로 배타적인 경로는 더하고 연속 선택은 곱하는 표현"] }, { "id": "permutations", "order": 2, "title": "순열", "standardCode": "10공수1-03-02", "achievementStandard": "순열의 개념을 이해하고, 순열의 수를 구하는 방법을 설명할 수 있다.", "topics": ["순서가 있는 배열", "계승 n!", "순열 nPr", "직접 나열과 수형도", "순열 공식의 원리"], "scopeNotes": ["원순열과 중복순열은 핵심 범위에 포함하지 않는다.", "지나치게 복잡한 문제는 다루지 않는다."], "visualizationIdeas": ["빈 자리에 대상을 하나씩 배치하며 선택지 수 감소", "수형도의 끝점 수와 순열 공식 연결"] }, { "id": "combinations", "order": 3, "title": "조합", "standardCode": "10공수1-03-03", "achievementStandard": "조합의 개념을 이해하고, 조합의 수를 구하는 방법을 설명할 수 있다.", "topics": ["순서를 고려하지 않는 선택", "조합 nCr", "순열과 조합의 차이", "조합 공식의 원리", "직접 나열과 수형도"], "scopeNotes": ["중복조합은 핵심 범위에 포함하지 않는다.", "지나치게 복잡한 문제는 다루지 않는다."], "visualizationIdeas": ["같은 구성의 서로 다른 순서를 하나의 묶음으로 합치기", "순열 결과를 r!개씩 묶어 조합으로 변환"] }], "conceptCount": 3 }, { "id": "matrices", "title": "행렬", "order": 4, "concepts": [{ "id": "matrix-concept", "order": 1, "title": "행렬의 뜻과 표현", "standardCode": "10공수1-04-01", "achievementStandard": "행렬의 뜻을 알고, 실생활 상황을 행렬로 표현할 수 있다.", "topics": ["행렬의 뜻", "행과 열", "성분", "행렬의 크기", "두 행렬이 같은 조건", "실생활 자료의 행렬 표현"], "visualizationIdeas": ["표 형태의 자료가 행렬 기호로 변환되는 애니메이션", "행·열·성분을 색으로 구분"] }, { "id": "matrix-operations", "order": 2, "title": "행렬의 연산", "standardCode": "10공수1-04-02", "achievementStandard": "행렬의 연산을 수행하고, 관련된 문제를 해결할 수 있다.", "topics": ["행렬의 덧셈과 뺄셈", "행렬의 실수배", "행렬의 곱셈", "행렬 곱셈이 가능한 조건", "행렬을 이용한 문제 해결"], "scopeNotes": ["곱셈은 행과 열의 수가 각각 2를 넘지 않는 범위에서 다룬다.", "행렬 연산의 대수적 구조를 일반화한 법칙은 다루지 않는다.", "역행렬은 공식 핵심 범위에 포함하지 않는다."], "visualizationIdeas": ["대응하는 성분끼리 더해지는 표현", "행과 열이 만나 하나의 성분을 만드는 곱셈 애니메이션"] }], "conceptCount": 2 }], "category": "common", "categoryTitle": "공통 과목", "categoryEnglishTitle": "COMMON", "categoryDescription": "고등학교 수학 학습의 공통 기반이 되는 필수 과목입니다.", "categoryOrder": 1, "recommendedGrades": [10], "placementLabel": "1학기 기본 순서", "sourceFile": "kr-2022-g10-math-curri.yaml", "developmentLocked": false }, { "id": "common-math-2", "officialTitle": "공통수학2", "defaultSemester": 2, "conceptCount": 20, "units": [{ "id": "coordinate-geometry", "title": "도형의 방정식", "order": 1, "concepts": [{ "id": "distance-and-internal-division", "order": 1, "title": "두 점 사이의 거리와 선분의 내분", "standardCode": "10공수2-01-01", "achievementStandard": "선분의 내분을 이해하고, 내분점의 좌표를 계산할 수 있다.", "topics": ["수직선 위 두 점 사이의 거리", "좌표평면 위 두 점 사이의 거리", "수직선 위 내분점", "좌표평면 위 내분점", "중점", "내분 공식의 원리"], "scopeNotes": ["두 점 사이의 거리를 먼저 다룬 뒤 내분으로 확장한다.", "외분점은 다루지 않는다."], "visualizationIdeas": ["선분을 주어진 비율로 나누는 점 이동", "수직선의 내분이 좌표평면으로 확장되는 애니메이션"] }, { "id": "parallel-and-perpendicular-lines", "order": 2, "title": "두 직선의 평행·수직 조건", "standardCode": "10공수2-01-02", "achievementStandard": "두 직선의 평행 조건과 수직 조건을 탐구하고 이해한다.", "topics": ["직선의 기울기", "직선의 방정식", "두 직선의 평행 조건", "두 직선의 수직 조건"], "visualizationIdeas": ["한 직선의 기울기가 변하며 평행·수직 상태 표시", "직각 표시와 기울기 곱을 동시에 연결"] }, { "id": "point-line-distance", "order": 3, "title": "점과 직선 사이의 거리", "standardCode": "10공수2-01-03", "achievementStandard": "점과 직선 사이의 거리를 구하고, 관련된 문제를 해결할 수 있다.", "topics": ["수선의 발", "점과 직선 사이 거리의 의미", "점과 직선 사이의 거리 공식", "두 평행선 사이의 거리"], "visualizationIdeas": ["점에서 직선으로 향하는 여러 선분 중 수선이 가장 짧음을 비교", "직선 이동에 따른 거리 변화"] }, { "id": "circle-equation", "order": 4, "title": "원의 방정식", "standardCode": "10공수2-01-04", "achievementStandard": "원의 방정식을 구하고, 그래프를 그릴 수 있다.", "topics": ["중심이 원점인 원", "중심이 (a,b)인 원", "반지름과 원의 방정식", "원의 중심과 반지름 찾기", "완전제곱식을 이용한 표준형 변환"], "visualizationIdeas": ["중심에서 원 위 점까지의 거리가 일정한 자취", "중심과 반지름 변화에 따른 방정식 갱신"] }, { "id": "circle-line-position", "order": 5, "title": "원과 직선의 위치 관계", "standardCode": "10공수2-01-05", "achievementStandard": "좌표평면에서 원과 직선의 위치 관계를 판단하고, 이를 활용하여 문제를 해결할 수 있다.", "topics": ["두 점에서 만나는 경우", "접하는 경우", "만나지 않는 경우", "중심과 직선 사이의 거리", "반지름과 거리 비교"], "visualizationIdeas": ["직선이 이동하며 할선·접선·외부 직선으로 변화", "중심과 직선 사이 거리와 반지름을 막대로 비교"] }, { "id": "geometric-translation", "order": 6, "title": "평행이동", "standardCode": "10공수2-01-06", "achievementStandard": "평행이동을 탐구하고, 실생활과 연결하여 문제를 해결할 수 있다.", "topics": ["점의 평행이동", "도형의 평행이동", "이동 전후 좌표", "방정식으로 표현된 도형의 이동", "실생활에서의 평행이동"], "scopeNotes": ["좌표축 자체의 평행이동은 다루지 않는다."], "visualizationIdeas": ["도형의 모든 점이 같은 벡터만큼 이동", "이동 전후 방정식과 좌표 변화 동시 표시"] }, { "id": "geometric-reflection", "order": 7, "title": "대칭이동", "standardCode": "10공수2-01-07", "achievementStandard": "원점, x축, y축, 직선 y=x에 대한 대칭이동을 탐구하고, 실생활과 연결하여 문제를 해결할 수 있다.", "topics": ["원점 대칭", "x축 대칭", "y축 대칭", "직선 y=x 대칭", "점과 도형의 대칭이동"], "visualizationIdeas": ["대칭축을 기준으로 도형을 접어 포개기", "좌표의 부호 및 순서가 바뀌는 과정"] }], "conceptCount": 7 }, { "id": "sets-and-propositions", "title": "집합과 명제", "order": 2, "concepts": [{ "id": "set-concept-and-representation", "order": 1, "title": "집합의 개념과 표현", "standardCode": "10공수2-02-01", "achievementStandard": "집합의 개념을 이해하고, 집합을 표현할 수 있다.", "topics": ["집합과 집합이 아닌 모임", "원소와 공집합", "유한집합과 무한집합", "원소나열법", "조건제시법", "벤 다이어그램"], "scopeNotes": ["집합의 개념은 이해하는 수준에서 간단히 평가한다."], "visualizationIdeas": ["여러 대상을 조건에 따라 집합 안팎으로 분류", "원소나열법이 벤 다이어그램으로 변환되는 표현"] }, { "id": "set-inclusion", "order": 2, "title": "집합의 포함관계", "standardCode": "10공수2-02-02", "achievementStandard": "두 집합 사이의 포함관계를 판단할 수 있다.", "topics": ["부분집합", "진부분집합", "두 집합이 같은 조건", "집합의 포함관계"], "scopeNotes": ["집합의 포함관계는 이해하는 수준에서 간단히 평가한다."], "visualizationIdeas": ["작은 집합이 큰 집합 안에 들어가는 애니메이션", "원소 이동에 따른 포함관계 변화"] }, { "id": "set-operations", "order": 3, "title": "집합의 연산과 벤 다이어그램", "standardCode": "10공수2-02-03", "achievementStandard": "집합의 연산을 수행하고, 벤 다이어그램을 이용하여 나타낼 수 있다.", "topics": ["합집합과 교집합", "전체집합과 여집합", "차집합과 서로소", "교환법칙과 결합법칙", "분배법칙", "드모르간의 법칙"], "scopeNotes": ["집합의 법칙은 벤 다이어그램으로 확인하는 정도로 간단히 다룬다."], "visualizationIdeas": ["연산 기호에 따라 벤 다이어그램 색칠 영역 변화", "드모르간의 법칙 양변을 색칠 영역으로 비교"] }, { "id": "proposition-and-condition", "order": 4, "title": "명제와 조건", "standardCode": "10공수2-02-04", "achievementStandard": "명제와 조건의 뜻을 알고, ‘모든’, ‘어떤’을 포함한 명제를 이해하고 설명할 수 있다.", "topics": ["명제와 조건", "참과 거짓", "진리집합", "명제의 부정", "모든을 포함한 명제", "어떤을 포함한 명제", "반례"], "scopeNotes": ["수학적인 문장을 이해하는 수준에서 간단히 다룬다.", "모든과 어떤을 포함한 명제는 구체적인 상황으로 도입한다."], "visualizationIdeas": ["모든 원소를 검사하는 과정과 하나의 반례 비교", "조건과 진리집합의 대응"] }, { "id": "converse-and-contrapositive", "order": 5, "title": "명제의 역과 대우", "standardCode": "10공수2-02-05", "achievementStandard": "명제의 역과 대우를 이해하고 설명할 수 있다.", "topics": ["가정과 결론", "명제 p→q", "명제의 역", "명제의 대우", "명제와 대우의 참·거짓 관계"], "scopeNotes": ["명제의 이는 별도 성취기준이 아니므로 보조 개념으로만 사용할 수 있다."], "visualizationIdeas": ["p와 q 카드의 순서 및 부정 상태 변환", "원래 명제와 대우의 진리표 비교"] }, { "id": "sufficient-and-necessary-conditions", "order": 6, "title": "충분조건과 필요조건", "standardCode": "10공수2-02-06", "achievementStandard": "충분조건과 필요조건을 이해하고 판단할 수 있다.", "topics": ["충분조건", "필요조건", "필요충분조건", "진리집합의 포함관계"], "scopeNotes": ["구체적인 예를 통해 이해한다."], "visualizationIdeas": ["두 진리집합의 포함관계로 충분·필요조건 표현", "조건 변화에 따라 포함관계가 바뀌는 애니메이션"] }, { "id": "proof-by-contrapositive-and-contradiction", "order": 7, "title": "대우를 이용한 증명과 귀류법", "standardCode": "10공수2-02-07", "achievementStandard": "대우를 이용한 증명법과 귀류법을 이해하고 관련된 명제를 증명할 수 있다.", "topics": ["증명의 의미", "대우를 이용한 증명", "귀류법", "두 증명 방법의 차이"], "scopeNotes": ["대우 증명과 귀류법은 간단한 명제만 다룬다.", "직관적인 이해에서 시작하여 점진적으로 형식화한다."], "visualizationIdeas": ["논리의 진행 경로를 흐름도로 표현", "가정의 부정이 모순에 도달하는 과정"] }, { "id": "absolute-inequality", "order": 8, "title": "절대부등식", "standardCode": "10공수2-02-08", "achievementStandard": "절대부등식의 뜻을 알고, 간단한 절대부등식을 증명할 수 있다.", "topics": ["절대부등식의 뜻", "실수의 제곱을 이용한 증명", "등호 성립 조건", "간단한 절대부등식"], "scopeNotes": ["간단한 절대부등식의 증명만 다룬다."], "visualizationIdeas": ["넓이 비교로 부등식 표현", "두 양의 차의 제곱이 0 이상인 과정"] }], "conceptCount": 8 }, { "id": "functions-and-graphs", "title": "함수와 그래프", "order": 3, "concepts": [{ "id": "function-concept-and-graph", "order": 1, "title": "함수의 개념과 그래프", "standardCode": "10공수2-03-01", "achievementStandard": "함수의 개념을 설명하고, 그 그래프를 이해한다.", "topics": ["두 집합 사이의 대응", "함수의 뜻", "정의역·공역·치역", "함수값과 그래프", "일대일함수와 일대일대응", "항등함수와 상수함수"], "scopeNotes": ["중학교에서 학습한 함수 개념을 두 집합 사이의 대응 관계로 확장한다."], "visualizationIdeas": ["정의역 원소에서 공역 원소로 향하는 대응 화살표", "대응 관계가 좌표평면의 점으로 변환되는 애니메이션"] }, { "id": "composite-function", "order": 2, "title": "합성함수", "standardCode": "10공수2-03-02", "achievementStandard": "함수의 합성을 설명하고, 합성함수를 구할 수 있다.", "topics": ["함수 합성의 뜻", "합성함수 f∘g", "합성 순서", "합성함수의 함수값", "간단한 합성함수 구하기"], "visualizationIdeas": ["입력값이 두 개의 함수 기계를 연속 통과", "합성 순서를 바꿀 때 결과 비교"] }, { "id": "inverse-function", "order": 3, "title": "역함수", "standardCode": "10공수2-03-03", "achievementStandard": "역함수의 개념을 설명하고, 역함수를 구할 수 있다.", "topics": ["역함수의 뜻", "역함수가 존재할 조건", "일대일대응과 역함수", "정의역과 치역의 교환", "역함수 구하기", "y=x에 대한 그래프 대칭"], "visualizationIdeas": ["대응 화살표의 방향 반전", "함수 그래프가 y=x를 기준으로 뒤집히는 애니메이션"] }, { "id": "rational-function", "order": 4, "title": "유리함수의 그래프", "standardCode": "10공수2-03-04", "achievementStandard": "유리함수의 그래프를 그릴 수 있고, 그 그래프의 성질을 탐구할 수 있다.", "topics": ["유리식과 유리함수의 기본 의미", "기본 유리함수", "정의역과 치역", "점근선", "그래프의 평행이동", "계수 변화와 그래프의 성질"], "scopeNotes": ["유리식은 유리함수를 이해하는 데 필요한 정도만 간단히 다룬다.", "유리함수는 기본적인 형태를 중심으로 간단한 문제만 다룬다."], "visualizationIdeas": ["x값이 특정 값에 가까워질 때 그래프가 점근선에 접근", "그래프 이동과 점근선 이동 동시 표시"] }, { "id": "irrational-function", "order": 5, "title": "무리함수의 그래프", "standardCode": "10공수2-03-05", "achievementStandard": "무리함수의 그래프를 그릴 수 있고, 그 그래프의 성질을 탐구할 수 있다.", "topics": ["무리식과 무리함수의 기본 의미", "기본 무리함수", "정의역과 치역", "그래프의 시작점", "그래프의 평행이동", "계수 변화와 그래프의 성질"], "scopeNotes": ["무리식은 무리함수를 이해하는 데 필요한 정도만 간단히 다룬다.", "무리함수는 기본적인 형태를 중심으로 간단한 문제만 다룬다."], "visualizationIdeas": ["정의역 경계에서 그래프가 시작되는 과정", "식의 이동과 그래프 시작점의 이동 동시 표시"] }], "conceptCount": 5 }], "category": "common", "categoryTitle": "공통 과목", "categoryEnglishTitle": "COMMON", "categoryDescription": "고등학교 수학 학습의 공통 기반이 되는 필수 과목입니다.", "categoryOrder": 1, "recommendedGrades": [10], "placementLabel": "2학기 기본 순서", "sourceFile": "kr-2022-g10-math-curri.yaml", "developmentLocked": false }, { "id": "algebra", "officialTitle": "대수", "category": "general-elective", "categoryTitle": "일반 선택", "recommendedGrades": [11, 12], "prerequisites": ["common-math-1", "common-math-2"], "defaultSemester": "school-defined", "conceptCount": 18, "units": [{ "id": "exponential-logarithmic-functions", "title": "지수함수와 로그함수", "order": 1, "concepts": [{ "id": "algebra-01-01", "order": 1, "title": "거듭제곱과 거듭제곱근", "standardCode": "12대수01-01", "achievementStandard": "거듭제곱과 거듭제곱근의 뜻을 알고, 그 성질을 이용하여 계산할 수 있다.", "topics": ["거듭제곱과 거듭제곱근", "핵심 의미와 원리", "계산 방법과 절차"], "scopeNotes": ["실수 지수는 밑이 양수인 경우에 한하여 직관적으로 다룬다.", "지수함수와 로그함수는 역함수 관계를 그래프로 확인한다.", "지나치게 복잡한 계산을 포함하는 문제는 다루지 않는다."], "visualizationIdeas": ["지수가 정수에서 유리수와 실수로 촘촘하게 확장되는 수직선 애니메이션", "지수함수와 로그함수가 y=x에 대해 대칭이 되는 역함수 변환", "복리·성장·감쇠 자료를 로그 눈금과 일반 눈금으로 비교하는 인터랙션"] }, { "id": "algebra-01-02", "order": 2, "title": "유리수·실수 지수로의 확장", "standardCode": "12대수01-02", "achievementStandard": "지수가 유리수, 실수까지 확장될 수 있음을 이해하고, 이를 설명할 수 있다.", "topics": ["유리수·실수 지수로의 확장", "핵심 의미와 원리"], "scopeNotes": ["실수 지수는 밑이 양수인 경우에 한하여 직관적으로 다룬다.", "지수함수와 로그함수는 역함수 관계를 그래프로 확인한다.", "지나치게 복잡한 계산을 포함하는 문제는 다루지 않는다."], "visualizationIdeas": ["지수가 정수에서 유리수와 실수로 촘촘하게 확장되는 수직선 애니메이션", "지수함수와 로그함수가 y=x에 대해 대칭이 되는 역함수 변환", "복리·성장·감쇠 자료를 로그 눈금과 일반 눈금으로 비교하는 인터랙션"] }, { "id": "algebra-01-03", "order": 3, "title": "지수법칙", "standardCode": "12대수01-03", "achievementStandard": "지수법칙을 이해하고, 이를 이용하여 식을 간단히 나타낼 수 있다.", "topics": ["지수법칙", "핵심 의미와 원리"], "scopeNotes": ["실수 지수는 밑이 양수인 경우에 한하여 직관적으로 다룬다.", "지수함수와 로그함수는 역함수 관계를 그래프로 확인한다.", "지나치게 복잡한 계산을 포함하는 문제는 다루지 않는다."], "visualizationIdeas": ["지수가 정수에서 유리수와 실수로 촘촘하게 확장되는 수직선 애니메이션", "지수함수와 로그함수가 y=x에 대해 대칭이 되는 역함수 변환", "복리·성장·감쇠 자료를 로그 눈금과 일반 눈금으로 비교하는 인터랙션"] }, { "id": "algebra-01-04", "order": 4, "title": "로그의 뜻과 성질", "standardCode": "12대수01-04", "achievementStandard": "로그의 뜻을 알고, 그 성질을 이용하여 계산할 수 있다.", "topics": ["로그의 뜻과 성질", "핵심 의미와 원리", "계산 방법과 절차"], "scopeNotes": ["실수 지수는 밑이 양수인 경우에 한하여 직관적으로 다룬다.", "지수함수와 로그함수는 역함수 관계를 그래프로 확인한다.", "지나치게 복잡한 계산을 포함하는 문제는 다루지 않는다."], "visualizationIdeas": ["지수가 정수에서 유리수와 실수로 촘촘하게 확장되는 수직선 애니메이션", "지수함수와 로그함수가 y=x에 대해 대칭이 되는 역함수 변환", "복리·성장·감쇠 자료를 로그 눈금과 일반 눈금으로 비교하는 인터랙션"] }, { "id": "algebra-01-05", "order": 5, "title": "상용로그의 활용", "standardCode": "12대수01-05", "achievementStandard": "상용로그를 이해하고, 이를 실생활과 연결하여 문제를 해결할 수 있다.", "topics": ["상용로그의 활용", "핵심 의미와 원리", "적용과 문제 해결"], "scopeNotes": ["실수 지수는 밑이 양수인 경우에 한하여 직관적으로 다룬다.", "지수함수와 로그함수는 역함수 관계를 그래프로 확인한다.", "지나치게 복잡한 계산을 포함하는 문제는 다루지 않는다."], "visualizationIdeas": ["지수가 정수에서 유리수와 실수로 촘촘하게 확장되는 수직선 애니메이션", "지수함수와 로그함수가 y=x에 대해 대칭이 되는 역함수 변환", "복리·성장·감쇠 자료를 로그 눈금과 일반 눈금으로 비교하는 인터랙션"] }, { "id": "algebra-01-06", "order": 6, "title": "지수함수와 로그함수의 뜻", "standardCode": "12대수01-06", "achievementStandard": "지수함수와 로그함수의 뜻을 알고, 이를 설명할 수 있다.", "topics": ["지수함수와 로그함수의 뜻", "핵심 의미와 원리"], "scopeNotes": ["실수 지수는 밑이 양수인 경우에 한하여 직관적으로 다룬다.", "지수함수와 로그함수는 역함수 관계를 그래프로 확인한다.", "지나치게 복잡한 계산을 포함하는 문제는 다루지 않는다."], "visualizationIdeas": ["지수가 정수에서 유리수와 실수로 촘촘하게 확장되는 수직선 애니메이션", "지수함수와 로그함수가 y=x에 대해 대칭이 되는 역함수 변환", "복리·성장·감쇠 자료를 로그 눈금과 일반 눈금으로 비교하는 인터랙션"] }, { "id": "algebra-01-07", "order": 7, "title": "지수함수와 로그함수의 그래프", "standardCode": "12대수01-07", "achievementStandard": "지수함수와 로그함수의 그래프를 그릴 수 있고, 그 성질을 설명할 수 있다.", "topics": ["지수함수와 로그함수의 그래프", "핵심 의미와 원리", "수학적 표현과 해석"], "scopeNotes": ["실수 지수는 밑이 양수인 경우에 한하여 직관적으로 다룬다.", "지수함수와 로그함수는 역함수 관계를 그래프로 확인한다.", "지나치게 복잡한 계산을 포함하는 문제는 다루지 않는다."], "visualizationIdeas": ["지수가 정수에서 유리수와 실수로 촘촘하게 확장되는 수직선 애니메이션", "지수함수와 로그함수가 y=x에 대해 대칭이 되는 역함수 변환", "복리·성장·감쇠 자료를 로그 눈금과 일반 눈금으로 비교하는 인터랙션"] }, { "id": "algebra-01-08", "order": 8, "title": "지수함수와 로그함수의 활용", "standardCode": "12대수01-08", "achievementStandard": "지수함수, 로그함수를 활용하여 문제를 해결할 수 있다.", "topics": ["지수함수와 로그함수의 활용", "적용과 문제 해결"], "scopeNotes": ["실수 지수는 밑이 양수인 경우에 한하여 직관적으로 다룬다.", "지수함수와 로그함수는 역함수 관계를 그래프로 확인한다.", "지나치게 복잡한 계산을 포함하는 문제는 다루지 않는다."], "visualizationIdeas": ["지수가 정수에서 유리수와 실수로 촘촘하게 확장되는 수직선 애니메이션", "지수함수와 로그함수가 y=x에 대해 대칭이 되는 역함수 변환", "복리·성장·감쇠 자료를 로그 눈금과 일반 눈금으로 비교하는 인터랙션"] }], "conceptCount": 8 }, { "id": "trigonometric-functions", "title": "삼각함수", "order": 2, "concepts": [{ "id": "algebra-02-01", "order": 1, "title": "일반각과 호도법", "standardCode": "12대수02-01", "achievementStandard": "일반각과 호도법의 뜻을 알고, 그 관계를 설명할 수 있다.", "topics": ["일반각과 호도법", "핵심 의미와 원리"], "scopeNotes": ["삼각함수는 중학교의 삼각비와 연결하여 이해한다.", "삼각방정식과 부등식은 그래프 해석에 필요한 간단한 경우만 다룬다.", "그래프의 기본 성질 이해에 중점을 두고 지나치게 복잡한 문제는 다루지 않는다."], "visualizationIdeas": ["단위원 위 점의 회전과 사인·코사인·탄젠트 그래프를 동기화", "각도를 도와 라디안으로 동시에 표시하며 호의 길이를 비교", "삼각형의 변과 각을 움직이며 사인법칙·코사인법칙의 불변 관계 표시"] }, { "id": "algebra-02-02", "order": 2, "title": "삼각함수와 그래프", "standardCode": "12대수02-02", "achievementStandard": "삼각함수의 개념을 이해하여 사인함수, 코사인함수, 탄젠트함수의 그래프를 그리고, 그 성질을 설명할 수 있다.", "topics": ["삼각함수와 그래프", "핵심 의미와 원리", "수학적 표현과 해석"], "scopeNotes": ["삼각함수는 중학교의 삼각비와 연결하여 이해한다.", "삼각방정식과 부등식은 그래프 해석에 필요한 간단한 경우만 다룬다.", "그래프의 기본 성질 이해에 중점을 두고 지나치게 복잡한 문제는 다루지 않는다."], "visualizationIdeas": ["단위원 위 점의 회전과 사인·코사인·탄젠트 그래프를 동기화", "각도를 도와 라디안으로 동시에 표시하며 호의 길이를 비교", "삼각형의 변과 각을 움직이며 사인법칙·코사인법칙의 불변 관계 표시"] }, { "id": "algebra-02-03", "order": 3, "title": "사인법칙과 코사인법칙", "standardCode": "12대수02-03", "achievementStandard": "사인법칙과 코사인법칙을 이해하고, 실생활 문제를 해결할 수 있다.", "topics": ["사인법칙과 코사인법칙", "핵심 의미와 원리", "적용과 문제 해결"], "scopeNotes": ["삼각함수는 중학교의 삼각비와 연결하여 이해한다.", "삼각방정식과 부등식은 그래프 해석에 필요한 간단한 경우만 다룬다.", "그래프의 기본 성질 이해에 중점을 두고 지나치게 복잡한 문제는 다루지 않는다."], "visualizationIdeas": ["단위원 위 점의 회전과 사인·코사인·탄젠트 그래프를 동기화", "각도를 도와 라디안으로 동시에 표시하며 호의 길이를 비교", "삼각형의 변과 각을 움직이며 사인법칙·코사인법칙의 불변 관계 표시"] }], "conceptCount": 3 }, { "id": "sequences", "title": "수열", "order": 3, "concepts": [{ "id": "algebra-03-01", "order": 1, "title": "수열의 뜻", "standardCode": "12대수03-01", "achievementStandard": "수열의 뜻을 설명할 수 있다.", "topics": ["수열의 뜻", "핵심 의미와 원리"], "scopeNotes": ["자연수 거듭제곱의 합과 여러 가지 수열의 합은 간단한 경우만 다룬다.", "귀납적으로 정의된 수열의 일반항을 구하는 문제는 다루지 않는다.", "수학적 귀납법은 원리를 이해할 수 있는 간단한 증명을 중심으로 다룬다."], "visualizationIdeas": ["항이 점과 막대로 차례로 생성되며 일반항과 부분합을 동시에 표시", "등차수열은 일정한 높이 증가, 등비수열은 일정한 배율 확대 형태로 비교", "도미노 구조로 수학적 귀납법의 시작 단계와 전이 단계를 표현"] }, { "id": "algebra-03-02", "order": 2, "title": "등차수열", "standardCode": "12대수03-02", "achievementStandard": "등차수열의 뜻을 알고, 일반항과 첫째항부터 제n항까지의 합을 구할 수 있다.", "topics": ["등차수열", "핵심 의미와 원리", "계산 방법과 절차"], "scopeNotes": ["자연수 거듭제곱의 합과 여러 가지 수열의 합은 간단한 경우만 다룬다.", "귀납적으로 정의된 수열의 일반항을 구하는 문제는 다루지 않는다.", "수학적 귀납법은 원리를 이해할 수 있는 간단한 증명을 중심으로 다룬다."], "visualizationIdeas": ["항이 점과 막대로 차례로 생성되며 일반항과 부분합을 동시에 표시", "등차수열은 일정한 높이 증가, 등비수열은 일정한 배율 확대 형태로 비교", "도미노 구조로 수학적 귀납법의 시작 단계와 전이 단계를 표현"] }, { "id": "algebra-03-03", "order": 3, "title": "등비수열", "standardCode": "12대수03-03", "achievementStandard": "등비수열의 뜻을 알고, 일반항과 첫째항부터 제n항까지의 합을 구할 수 있다.", "topics": ["등비수열", "핵심 의미와 원리", "계산 방법과 절차"], "scopeNotes": ["자연수 거듭제곱의 합과 여러 가지 수열의 합은 간단한 경우만 다룬다.", "귀납적으로 정의된 수열의 일반항을 구하는 문제는 다루지 않는다.", "수학적 귀납법은 원리를 이해할 수 있는 간단한 증명을 중심으로 다룬다."], "visualizationIdeas": ["항이 점과 막대로 차례로 생성되며 일반항과 부분합을 동시에 표시", "등차수열은 일정한 높이 증가, 등비수열은 일정한 배율 확대 형태로 비교", "도미노 구조로 수학적 귀납법의 시작 단계와 전이 단계를 표현"] }, { "id": "algebra-03-04", "order": 4, "title": "시그마(Σ)의 뜻과 성질", "standardCode": "12대수03-04", "achievementStandard": "시그마(Σ)의 뜻과 성질을 이해하고, 이를 활용하여 문제를 해결할 수 있다.", "topics": ["시그마(Σ)의 뜻과 성질", "핵심 의미와 원리", "적용과 문제 해결"], "scopeNotes": ["자연수 거듭제곱의 합과 여러 가지 수열의 합은 간단한 경우만 다룬다.", "귀납적으로 정의된 수열의 일반항을 구하는 문제는 다루지 않는다.", "수학적 귀납법은 원리를 이해할 수 있는 간단한 증명을 중심으로 다룬다."], "visualizationIdeas": ["항이 점과 막대로 차례로 생성되며 일반항과 부분합을 동시에 표시", "등차수열은 일정한 높이 증가, 등비수열은 일정한 배율 확대 형태로 비교", "도미노 구조로 수학적 귀납법의 시작 단계와 전이 단계를 표현"] }, { "id": "algebra-03-05", "order": 5, "title": "여러 가지 수열의 합", "standardCode": "12대수03-05", "achievementStandard": "여러 가지 수열의 첫째항부터 제n항까지의 합을 구하는 방법을 설명할 수 있다.", "topics": ["여러 가지 수열의 합", "핵심 의미와 원리"], "scopeNotes": ["자연수 거듭제곱의 합과 여러 가지 수열의 합은 간단한 경우만 다룬다.", "귀납적으로 정의된 수열의 일반항을 구하는 문제는 다루지 않는다.", "수학적 귀납법은 원리를 이해할 수 있는 간단한 증명을 중심으로 다룬다."], "visualizationIdeas": ["항이 점과 막대로 차례로 생성되며 일반항과 부분합을 동시에 표시", "등차수열은 일정한 높이 증가, 등비수열은 일정한 배율 확대 형태로 비교", "도미노 구조로 수학적 귀납법의 시작 단계와 전이 단계를 표현"] }, { "id": "algebra-03-06", "order": 6, "title": "수열의 귀납적 정의", "standardCode": "12대수03-06", "achievementStandard": "수열의 귀납적 정의를 설명할 수 있다.", "topics": ["수열의 귀납적 정의", "핵심 의미와 원리"], "scopeNotes": ["자연수 거듭제곱의 합과 여러 가지 수열의 합은 간단한 경우만 다룬다.", "귀납적으로 정의된 수열의 일반항을 구하는 문제는 다루지 않는다.", "수학적 귀납법은 원리를 이해할 수 있는 간단한 증명을 중심으로 다룬다."], "visualizationIdeas": ["항이 점과 막대로 차례로 생성되며 일반항과 부분합을 동시에 표시", "등차수열은 일정한 높이 증가, 등비수열은 일정한 배율 확대 형태로 비교", "도미노 구조로 수학적 귀납법의 시작 단계와 전이 단계를 표현"] }, { "id": "algebra-03-07", "order": 7, "title": "수학적 귀납법", "standardCode": "12대수03-07", "achievementStandard": "수학적 귀납법의 원리를 이해하고, 이를 이용하여 명제를 증명할 수 있다.", "topics": ["수학적 귀납법", "핵심 의미와 원리"], "scopeNotes": ["자연수 거듭제곱의 합과 여러 가지 수열의 합은 간단한 경우만 다룬다.", "귀납적으로 정의된 수열의 일반항을 구하는 문제는 다루지 않는다.", "수학적 귀납법은 원리를 이해할 수 있는 간단한 증명을 중심으로 다룬다."], "visualizationIdeas": ["항이 점과 막대로 차례로 생성되며 일반항과 부분합을 동시에 표시", "등차수열은 일정한 높이 증가, 등비수열은 일정한 배율 확대 형태로 비교", "도미노 구조로 수학적 귀납법의 시작 단계와 전이 단계를 표현"] }], "conceptCount": 7 }], "categoryEnglishTitle": "GENERAL ELECTIVE", "categoryDescription": "대학 학습과 진로의 기초가 되는 주요 선택 과목입니다.", "categoryOrder": 2, "placementLabel": "학교별 개설·편성", "sourceFile": "kr-2022-algebra.yaml", "developmentLocked": false }, { "id": "calculus-1", "officialTitle": "미적분Ⅰ", "category": "general-elective", "categoryTitle": "일반 선택", "recommendedGrades": [11, 12], "prerequisites": ["common-math-1", "common-math-2"], "defaultSemester": "school-defined", "conceptCount": 20, "units": [{ "id": "limits-and-continuity", "title": "함수의 극한과 연속", "order": 1, "concepts": [{ "id": "calculus-1-01-01", "order": 1, "title": "함수의 극한", "standardCode": "12미적Ⅰ-01-01", "achievementStandard": "함수의 극한의 뜻을 알고, 이를 설명할 수 있다.", "topics": ["함수의 극한", "핵심 의미와 원리"], "scopeNotes": ["극한과 연속의 뜻과 성질은 그래프를 통해 직관적으로 이해한다.", "복잡한 합성함수나 절댓값이 여러 개 포함된 함수는 다루지 않는다."], "visualizationIdeas": ["점이 좌우에서 한 점에 접근할 때 함수값과 극한값을 동시 표시", "그래프의 끊김·점프·구멍을 움직이며 연속 조건을 비교", "사잇값 정리를 움직이는 수평선과 교점으로 표현"] }, { "id": "calculus-1-01-02", "order": 2, "title": "극한의 성질과 계산", "standardCode": "12미적Ⅰ-01-02", "achievementStandard": "함수의 극한에 대한 성질을 이해하고, 함수의 극한값을 구할 수 있다.", "topics": ["극한의 성질과 계산", "핵심 의미와 원리", "계산 방법과 절차"], "scopeNotes": ["극한과 연속의 뜻과 성질은 그래프를 통해 직관적으로 이해한다.", "복잡한 합성함수나 절댓값이 여러 개 포함된 함수는 다루지 않는다."], "visualizationIdeas": ["점이 좌우에서 한 점에 접근할 때 함수값과 극한값을 동시 표시", "그래프의 끊김·점프·구멍을 움직이며 연속 조건을 비교", "사잇값 정리를 움직이는 수평선과 교점으로 표현"] }, { "id": "calculus-1-01-03", "order": 3, "title": "함수의 연속", "standardCode": "12미적Ⅰ-01-03", "achievementStandard": "함수의 연속을 극한으로 탐구하고 이해한다.", "topics": ["함수의 연속", "핵심 의미와 원리", "탐구 설계와 수행"], "scopeNotes": ["극한과 연속의 뜻과 성질은 그래프를 통해 직관적으로 이해한다.", "복잡한 합성함수나 절댓값이 여러 개 포함된 함수는 다루지 않는다."], "visualizationIdeas": ["점이 좌우에서 한 점에 접근할 때 함수값과 극한값을 동시 표시", "그래프의 끊김·점프·구멍을 움직이며 연속 조건을 비교", "사잇값 정리를 움직이는 수평선과 교점으로 표현"] }, { "id": "calculus-1-01-04", "order": 4, "title": "연속함수의 성질", "standardCode": "12미적Ⅰ-01-04", "achievementStandard": "연속함수의 성질을 이해하고, 이를 활용하여 문제를 해결할 수 있다.", "topics": ["연속함수의 성질", "핵심 의미와 원리", "적용과 문제 해결"], "scopeNotes": ["극한과 연속의 뜻과 성질은 그래프를 통해 직관적으로 이해한다.", "복잡한 합성함수나 절댓값이 여러 개 포함된 함수는 다루지 않는다."], "visualizationIdeas": ["점이 좌우에서 한 점에 접근할 때 함수값과 극한값을 동시 표시", "그래프의 끊김·점프·구멍을 움직이며 연속 조건을 비교", "사잇값 정리를 움직이는 수평선과 교점으로 표현"] }], "conceptCount": 4 }, { "id": "differentiation", "title": "미분", "order": 2, "concepts": [{ "id": "calculus-1-02-01", "order": 1, "title": "미분계수", "standardCode": "12미적Ⅰ-02-01", "achievementStandard": "미분계수를 이해하고, 이를 구할 수 있다.", "topics": ["미분계수", "핵심 의미와 원리", "계산 방법과 절차"], "scopeNotes": ["미분계수는 평균변화율의 극한과 접선의 기울기를 연결하여 다룬다.", "속도와 가속도 문제는 직선 운동에 한하여 다룬다.", "지나치게 복잡한 도함수 계산은 다루지 않는다."], "visualizationIdeas": ["두 점을 잇는 할선이 한 점의 접선으로 수렴하는 애니메이션", "도함수 부호와 원함수의 증가·감소 구간을 색으로 연결", "위치·속도·가속도 그래프를 같은 시간축에 동기화"] }, { "id": "calculus-1-02-02", "order": 2, "title": "미분가능성과 연속성", "standardCode": "12미적Ⅰ-02-02", "achievementStandard": "함수의 미분가능성과 연속성의 관계를 설명하고, 이를 활용할 수 있다.", "topics": ["미분가능성과 연속성", "핵심 의미와 원리", "계산 방법과 절차", "적용과 문제 해결"], "scopeNotes": ["미분계수는 평균변화율의 극한과 접선의 기울기를 연결하여 다룬다.", "속도와 가속도 문제는 직선 운동에 한하여 다룬다.", "지나치게 복잡한 도함수 계산은 다루지 않는다."], "visualizationIdeas": ["두 점을 잇는 할선이 한 점의 접선으로 수렴하는 애니메이션", "도함수 부호와 원함수의 증가·감소 구간을 색으로 연결", "위치·속도·가속도 그래프를 같은 시간축에 동기화"] }, { "id": "calculus-1-02-03", "order": 3, "title": "거듭제곱함수의 도함수", "standardCode": "12미적Ⅰ-02-03", "achievementStandard": "함수 xⁿ(n은 양의 정수)의 도함수를 구할 수 있다.", "topics": ["거듭제곱함수의 도함수", "계산 방법과 절차"], "scopeNotes": ["미분계수는 평균변화율의 극한과 접선의 기울기를 연결하여 다룬다.", "속도와 가속도 문제는 직선 운동에 한하여 다룬다.", "지나치게 복잡한 도함수 계산은 다루지 않는다."], "visualizationIdeas": ["두 점을 잇는 할선이 한 점의 접선으로 수렴하는 애니메이션", "도함수 부호와 원함수의 증가·감소 구간을 색으로 연결", "위치·속도·가속도 그래프를 같은 시간축에 동기화"] }, { "id": "calculus-1-02-04", "order": 4, "title": "다항함수의 미분법", "standardCode": "12미적Ⅰ-02-04", "achievementStandard": "함수의 실수배, 합, 차, 곱의 미분법을 알고, 다항함수의 도함수를 구할 수 있다.", "topics": ["다항함수의 미분법", "계산 방법과 절차"], "scopeNotes": ["미분계수는 평균변화율의 극한과 접선의 기울기를 연결하여 다룬다.", "속도와 가속도 문제는 직선 운동에 한하여 다룬다.", "지나치게 복잡한 도함수 계산은 다루지 않는다."], "visualizationIdeas": ["두 점을 잇는 할선이 한 점의 접선으로 수렴하는 애니메이션", "도함수 부호와 원함수의 증가·감소 구간을 색으로 연결", "위치·속도·가속도 그래프를 같은 시간축에 동기화"] }, { "id": "calculus-1-02-05", "order": 5, "title": "접선의 방정식", "standardCode": "12미적Ⅰ-02-05", "achievementStandard": "미분계수와 접선의 기울기의 관계를 이해하고, 접선의 방정식을 구할 수 있다.", "topics": ["접선의 방정식", "핵심 의미와 원리", "계산 방법과 절차", "수학적 표현과 해석"], "scopeNotes": ["미분계수는 평균변화율의 극한과 접선의 기울기를 연결하여 다룬다.", "속도와 가속도 문제는 직선 운동에 한하여 다룬다.", "지나치게 복잡한 도함수 계산은 다루지 않는다."], "visualizationIdeas": ["두 점을 잇는 할선이 한 점의 접선으로 수렴하는 애니메이션", "도함수 부호와 원함수의 증가·감소 구간을 색으로 연결", "위치·속도·가속도 그래프를 같은 시간축에 동기화"] }, { "id": "calculus-1-02-06", "order": 6, "title": "평균값 정리", "standardCode": "12미적Ⅰ-02-06", "achievementStandard": "함수에 대한 평균값 정리를 설명하고, 이를 활용할 수 있다.", "topics": ["평균값 정리", "핵심 의미와 원리", "적용과 문제 해결"], "scopeNotes": ["미분계수는 평균변화율의 극한과 접선의 기울기를 연결하여 다룬다.", "속도와 가속도 문제는 직선 운동에 한하여 다룬다.", "지나치게 복잡한 도함수 계산은 다루지 않는다."], "visualizationIdeas": ["두 점을 잇는 할선이 한 점의 접선으로 수렴하는 애니메이션", "도함수 부호와 원함수의 증가·감소 구간을 색으로 연결", "위치·속도·가속도 그래프를 같은 시간축에 동기화"] }, { "id": "calculus-1-02-07", "order": 7, "title": "함수의 증가·감소와 극값", "standardCode": "12미적Ⅰ-02-07", "achievementStandard": "함수의 증가와 감소, 극대와 극소를 판정하고 설명할 수 있다.", "topics": ["함수의 증가·감소와 극값", "핵심 의미와 원리"], "scopeNotes": ["미분계수는 평균변화율의 극한과 접선의 기울기를 연결하여 다룬다.", "속도와 가속도 문제는 직선 운동에 한하여 다룬다.", "지나치게 복잡한 도함수 계산은 다루지 않는다."], "visualizationIdeas": ["두 점을 잇는 할선이 한 점의 접선으로 수렴하는 애니메이션", "도함수 부호와 원함수의 증가·감소 구간을 색으로 연결", "위치·속도·가속도 그래프를 같은 시간축에 동기화"] }, { "id": "calculus-1-02-08", "order": 8, "title": "함수 그래프의 개형", "standardCode": "12미적Ⅰ-02-08", "achievementStandard": "함수의 그래프의 개형을 그릴 수 있다.", "topics": ["함수 그래프의 개형", "수학적 표현과 해석"], "scopeNotes": ["미분계수는 평균변화율의 극한과 접선의 기울기를 연결하여 다룬다.", "속도와 가속도 문제는 직선 운동에 한하여 다룬다.", "지나치게 복잡한 도함수 계산은 다루지 않는다."], "visualizationIdeas": ["두 점을 잇는 할선이 한 점의 접선으로 수렴하는 애니메이션", "도함수 부호와 원함수의 증가·감소 구간을 색으로 연결", "위치·속도·가속도 그래프를 같은 시간축에 동기화"] }, { "id": "calculus-1-02-09", "order": 9, "title": "미분과 방정식·부등식", "standardCode": "12미적Ⅰ-02-09", "achievementStandard": "방정식과 부등식에 대한 문제를 해결할 수 있다.", "topics": ["미분과 방정식·부등식", "수학적 표현과 해석", "적용과 문제 해결"], "scopeNotes": ["미분계수는 평균변화율의 극한과 접선의 기울기를 연결하여 다룬다.", "속도와 가속도 문제는 직선 운동에 한하여 다룬다.", "지나치게 복잡한 도함수 계산은 다루지 않는다."], "visualizationIdeas": ["두 점을 잇는 할선이 한 점의 접선으로 수렴하는 애니메이션", "도함수 부호와 원함수의 증가·감소 구간을 색으로 연결", "위치·속도·가속도 그래프를 같은 시간축에 동기화"] }, { "id": "calculus-1-02-10", "order": 10, "title": "속도와 가속도", "standardCode": "12미적Ⅰ-02-10", "achievementStandard": "미분을 속도와 가속도에 대한 문제에 활용하고, 그 유용성을 인식할 수 있다.", "topics": ["속도와 가속도", "계산 방법과 절차", "적용과 문제 해결"], "scopeNotes": ["미분계수는 평균변화율의 극한과 접선의 기울기를 연결하여 다룬다.", "속도와 가속도 문제는 직선 운동에 한하여 다룬다.", "지나치게 복잡한 도함수 계산은 다루지 않는다."], "visualizationIdeas": ["두 점을 잇는 할선이 한 점의 접선으로 수렴하는 애니메이션", "도함수 부호와 원함수의 증가·감소 구간을 색으로 연결", "위치·속도·가속도 그래프를 같은 시간축에 동기화"] }], "conceptCount": 10 }, { "id": "integration", "title": "적분", "order": 3, "concepts": [{ "id": "calculus-1-03-01", "order": 1, "title": "부정적분", "standardCode": "12미적Ⅰ-03-01", "achievementStandard": "부정적분의 뜻을 알고, 이를 설명할 수 있다.", "topics": ["부정적분", "핵심 의미와 원리", "계산 방법과 절차"], "scopeNotes": ["정적분은 넓이에서 출발하여 일반적인 연속함수의 경우로 확장한다.", "위치·속도·거리 문제는 직선 운동에 한하여 다룬다.", "정적분 활용에서 지나치게 복잡한 문제는 다루지 않는다."], "visualizationIdeas": ["곡선 아래 직사각형 분할이 촘촘해지며 넓이가 정적분으로 수렴", "미분과 적분을 변화율과 누적량의 반대 과정으로 왕복 표현", "속도 그래프 아래 부호 있는 넓이가 변위로 누적되는 애니메이션"] }, { "id": "calculus-1-03-02", "order": 2, "title": "다항함수의 부정적분", "standardCode": "12미적Ⅰ-03-02", "achievementStandard": "함수의 실수배, 합, 차의 부정적분을 알고, 다항함수의 부정적분을 구할 수 있다.", "topics": ["다항함수의 부정적분", "계산 방법과 절차"], "scopeNotes": ["정적분은 넓이에서 출발하여 일반적인 연속함수의 경우로 확장한다.", "위치·속도·거리 문제는 직선 운동에 한하여 다룬다.", "정적분 활용에서 지나치게 복잡한 문제는 다루지 않는다."], "visualizationIdeas": ["곡선 아래 직사각형 분할이 촘촘해지며 넓이가 정적분으로 수렴", "미분과 적분을 변화율과 누적량의 반대 과정으로 왕복 표현", "속도 그래프 아래 부호 있는 넓이가 변위로 누적되는 애니메이션"] }, { "id": "calculus-1-03-03", "order": 3, "title": "정적분의 개념과 성질", "standardCode": "12미적Ⅰ-03-03", "achievementStandard": "정적분의 개념을 탐구하고, 그 성질을 이해한다.", "topics": ["정적분의 개념과 성질", "핵심 의미와 원리", "계산 방법과 절차", "탐구 설계와 수행"], "scopeNotes": ["정적분은 넓이에서 출발하여 일반적인 연속함수의 경우로 확장한다.", "위치·속도·거리 문제는 직선 운동에 한하여 다룬다.", "정적분 활용에서 지나치게 복잡한 문제는 다루지 않는다."], "visualizationIdeas": ["곡선 아래 직사각형 분할이 촘촘해지며 넓이가 정적분으로 수렴", "미분과 적분을 변화율과 누적량의 반대 과정으로 왕복 표현", "속도 그래프 아래 부호 있는 넓이가 변위로 누적되는 애니메이션"] }, { "id": "calculus-1-03-04", "order": 4, "title": "부정적분과 정적분의 관계", "standardCode": "12미적Ⅰ-03-04", "achievementStandard": "부정적분과 정적분의 관계를 이해하고, 다항함수의 정적분을 구할 수 있다.", "topics": ["부정적분과 정적분의 관계", "핵심 의미와 원리", "계산 방법과 절차"], "scopeNotes": ["정적분은 넓이에서 출발하여 일반적인 연속함수의 경우로 확장한다.", "위치·속도·거리 문제는 직선 운동에 한하여 다룬다.", "정적분 활용에서 지나치게 복잡한 문제는 다루지 않는다."], "visualizationIdeas": ["곡선 아래 직사각형 분할이 촘촘해지며 넓이가 정적분으로 수렴", "미분과 적분을 변화율과 누적량의 반대 과정으로 왕복 표현", "속도 그래프 아래 부호 있는 넓이가 변위로 누적되는 애니메이션"] }, { "id": "calculus-1-03-05", "order": 5, "title": "정적분과 넓이", "standardCode": "12미적Ⅰ-03-05", "achievementStandard": "곡선으로 둘러싸인 도형의 넓이에 대한 문제를 해결할 수 있다.", "topics": ["정적분과 넓이", "적용과 문제 해결"], "scopeNotes": ["정적분은 넓이에서 출발하여 일반적인 연속함수의 경우로 확장한다.", "위치·속도·거리 문제는 직선 운동에 한하여 다룬다.", "정적분 활용에서 지나치게 복잡한 문제는 다루지 않는다."], "visualizationIdeas": ["곡선 아래 직사각형 분할이 촘촘해지며 넓이가 정적분으로 수렴", "미분과 적분을 변화율과 누적량의 반대 과정으로 왕복 표현", "속도 그래프 아래 부호 있는 넓이가 변위로 누적되는 애니메이션"] }, { "id": "calculus-1-03-06", "order": 6, "title": "적분과 속도·거리", "standardCode": "12미적Ⅰ-03-06", "achievementStandard": "적분을 속도와 거리에 대한 문제에 활용하고, 그 유용성을 인식할 수 있다.", "topics": ["적분과 속도·거리", "계산 방법과 절차", "적용과 문제 해결"], "scopeNotes": ["정적분은 넓이에서 출발하여 일반적인 연속함수의 경우로 확장한다.", "위치·속도·거리 문제는 직선 운동에 한하여 다룬다.", "정적분 활용에서 지나치게 복잡한 문제는 다루지 않는다."], "visualizationIdeas": ["곡선 아래 직사각형 분할이 촘촘해지며 넓이가 정적분으로 수렴", "미분과 적분을 변화율과 누적량의 반대 과정으로 왕복 표현", "속도 그래프 아래 부호 있는 넓이가 변위로 누적되는 애니메이션"] }], "conceptCount": 6 }], "categoryEnglishTitle": "GENERAL ELECTIVE", "categoryDescription": "대학 학습과 진로의 기초가 되는 주요 선택 과목입니다.", "categoryOrder": 2, "placementLabel": "학교별 개설·편성", "sourceFile": "kr-2022-calculus-1.yaml", "developmentLocked": false }, { "id": "probability-statistics", "officialTitle": "확률과 통계", "category": "general-elective", "categoryTitle": "일반 선택", "recommendedGrades": [11, 12], "prerequisites": ["common-math-1", "common-math-2"], "defaultSemester": "school-defined", "conceptCount": 16, "units": [{ "id": "counting", "title": "경우의 수", "order": 1, "concepts": [{ "id": "probability-statistics-01-01", "order": 1, "title": "중복순열과 같은 것이 있는 순열", "standardCode": "12확통01-01", "achievementStandard": "중복순열, 같은 것이 있는 순열을 이해하고, 그 순열의 수를 구하는 방법을 설명할 수 있다.", "topics": ["중복순열과 같은 것이 있는 순열", "핵심 의미와 원리"], "scopeNotes": ["공통수학1의 경우의 수와 연결되는 내용은 필요한 경우 간단히 다룬다.", "항이 세 개 이상인 다항정리와 허수단위가 포함된 이항정리는 다루지 않는다."], "visualizationIdeas": ["선택 과정을 가지로 펼쳐 중복 허용 여부에 따른 경우의 수 비교", "같은 대상의 자리 교환을 접어 중복 제거 과정을 표현", "파스칼의 삼각형과 이항계수가 동시에 생성되는 애니메이션"] }, { "id": "probability-statistics-01-02", "order": 2, "title": "중복조합", "standardCode": "12확통01-02", "achievementStandard": "중복조합을 이해하고, 중복조합의 수를 구하는 방법을 설명할 수 있다.", "topics": ["중복조합", "핵심 의미와 원리"], "scopeNotes": ["공통수학1의 경우의 수와 연결되는 내용은 필요한 경우 간단히 다룬다.", "항이 세 개 이상인 다항정리와 허수단위가 포함된 이항정리는 다루지 않는다."], "visualizationIdeas": ["선택 과정을 가지로 펼쳐 중복 허용 여부에 따른 경우의 수 비교", "같은 대상의 자리 교환을 접어 중복 제거 과정을 표현", "파스칼의 삼각형과 이항계수가 동시에 생성되는 애니메이션"] }, { "id": "probability-statistics-01-03", "order": 3, "title": "이항정리", "standardCode": "12확통01-03", "achievementStandard": "이항정리를 이해하고, 이를 활용하여 문제를 해결할 수 있다.", "topics": ["이항정리", "핵심 의미와 원리", "적용과 문제 해결"], "scopeNotes": ["공통수학1의 경우의 수와 연결되는 내용은 필요한 경우 간단히 다룬다.", "항이 세 개 이상인 다항정리와 허수단위가 포함된 이항정리는 다루지 않는다."], "visualizationIdeas": ["선택 과정을 가지로 펼쳐 중복 허용 여부에 따른 경우의 수 비교", "같은 대상의 자리 교환을 접어 중복 제거 과정을 표현", "파스칼의 삼각형과 이항계수가 동시에 생성되는 애니메이션"] }], "conceptCount": 3 }, { "id": "probability", "title": "확률", "order": 2, "concepts": [{ "id": "probability-statistics-02-01", "order": 1, "title": "확률의 개념과 기본 성질", "standardCode": "12확통02-01", "achievementStandard": "확률의 개념을 이해하고 기본 성질을 설명할 수 있다.", "topics": ["확률의 개념과 기본 성질", "핵심 의미와 원리"], "scopeNotes": ["통계적 확률과 수학적 확률을 함께 사용하여 확률 개념을 도입한다.", "조건부확률을 시간적 순서나 인과관계로 오해하지 않도록 한다.", "세 사건 이상의 복잡한 배반·독립 문제는 다루지 않는다."], "visualizationIdeas": ["반복 시행의 상대도수가 이론적 확률에 가까워지는 시뮬레이션", "벤다이어그램의 겹침과 넓이로 덧셈정리·여사건 표현", "표본공간이 조건에 따라 축소되는 장면으로 조건부확률 설명"] }, { "id": "probability-statistics-02-02", "order": 2, "title": "확률의 덧셈정리", "standardCode": "12확통02-02", "achievementStandard": "확률의 덧셈정리를 이해하고, 이를 활용하여 문제를 해결할 수 있다.", "topics": ["확률의 덧셈정리", "핵심 의미와 원리", "적용과 문제 해결"], "scopeNotes": ["통계적 확률과 수학적 확률을 함께 사용하여 확률 개념을 도입한다.", "조건부확률을 시간적 순서나 인과관계로 오해하지 않도록 한다.", "세 사건 이상의 복잡한 배반·독립 문제는 다루지 않는다."], "visualizationIdeas": ["반복 시행의 상대도수가 이론적 확률에 가까워지는 시뮬레이션", "벤다이어그램의 겹침과 넓이로 덧셈정리·여사건 표현", "표본공간이 조건에 따라 축소되는 장면으로 조건부확률 설명"] }, { "id": "probability-statistics-02-03", "order": 3, "title": "여사건의 확률", "standardCode": "12확통02-03", "achievementStandard": "여사건의 확률을 이해하고, 이를 활용하여 문제를 해결할 수 있다.", "topics": ["여사건의 확률", "핵심 의미와 원리", "적용과 문제 해결"], "scopeNotes": ["통계적 확률과 수학적 확률을 함께 사용하여 확률 개념을 도입한다.", "조건부확률을 시간적 순서나 인과관계로 오해하지 않도록 한다.", "세 사건 이상의 복잡한 배반·독립 문제는 다루지 않는다."], "visualizationIdeas": ["반복 시행의 상대도수가 이론적 확률에 가까워지는 시뮬레이션", "벤다이어그램의 겹침과 넓이로 덧셈정리·여사건 표현", "표본공간이 조건에 따라 축소되는 장면으로 조건부확률 설명"] }, { "id": "probability-statistics-02-04", "order": 4, "title": "조건부확률", "standardCode": "12확통02-04", "achievementStandard": "조건부확률을 이해하고, 이를 실생활과 연결하여 문제를 해결할 수 있다.", "topics": ["조건부확률", "핵심 의미와 원리", "적용과 문제 해결"], "scopeNotes": ["통계적 확률과 수학적 확률을 함께 사용하여 확률 개념을 도입한다.", "조건부확률을 시간적 순서나 인과관계로 오해하지 않도록 한다.", "세 사건 이상의 복잡한 배반·독립 문제는 다루지 않는다."], "visualizationIdeas": ["반복 시행의 상대도수가 이론적 확률에 가까워지는 시뮬레이션", "벤다이어그램의 겹침과 넓이로 덧셈정리·여사건 표현", "표본공간이 조건에 따라 축소되는 장면으로 조건부확률 설명"] }, { "id": "probability-statistics-02-05", "order": 5, "title": "사건의 독립과 종속", "standardCode": "12확통02-05", "achievementStandard": "사건의 독립과 종속을 이해하고, 이를 판단할 수 있다.", "topics": ["사건의 독립과 종속", "핵심 의미와 원리"], "scopeNotes": ["통계적 확률과 수학적 확률을 함께 사용하여 확률 개념을 도입한다.", "조건부확률을 시간적 순서나 인과관계로 오해하지 않도록 한다.", "세 사건 이상의 복잡한 배반·독립 문제는 다루지 않는다."], "visualizationIdeas": ["반복 시행의 상대도수가 이론적 확률에 가까워지는 시뮬레이션", "벤다이어그램의 겹침과 넓이로 덧셈정리·여사건 표현", "표본공간이 조건에 따라 축소되는 장면으로 조건부확률 설명"] }, { "id": "probability-statistics-02-06", "order": 6, "title": "확률의 곱셈정리", "standardCode": "12확통02-06", "achievementStandard": "확률의 곱셈정리를 이해하고, 이를 활용하여 문제를 해결할 수 있다.", "topics": ["확률의 곱셈정리", "핵심 의미와 원리", "적용과 문제 해결"], "scopeNotes": ["통계적 확률과 수학적 확률을 함께 사용하여 확률 개념을 도입한다.", "조건부확률을 시간적 순서나 인과관계로 오해하지 않도록 한다.", "세 사건 이상의 복잡한 배반·독립 문제는 다루지 않는다."], "visualizationIdeas": ["반복 시행의 상대도수가 이론적 확률에 가까워지는 시뮬레이션", "벤다이어그램의 겹침과 넓이로 덧셈정리·여사건 표현", "표본공간이 조건에 따라 축소되는 장면으로 조건부확률 설명"] }], "conceptCount": 6 }, { "id": "statistics", "title": "통계", "order": 3, "concepts": [{ "id": "probability-statistics-03-01", "order": 1, "title": "확률변수와 확률분포", "standardCode": "12확통03-01", "achievementStandard": "확률변수와 확률분포의 뜻을 설명할 수 있다.", "topics": ["확률변수와 확률분포", "핵심 의미와 원리"], "scopeNotes": ["이항분포 평균과 분산 공식을 증명하는 문제는 다루지 않는다.", "모평균 추정은 모집단이 정규분포인 경우, 모비율 추정은 표본 크기가 큰 경우를 다룬다.", "복잡한 신뢰구간 계산보다 결과의 의미와 해석에 중점을 둔다."], "visualizationIdeas": ["확률질량이 막대 높이로 배치되고 기댓값이 무게중심으로 이동", "이항분포의 시행 횟수가 커질수록 정규곡선에 가까워지는 애니메이션", "여러 표본의 평균과 비율이 표집분포를 형성하는 시뮬레이션"] }, { "id": "probability-statistics-03-02", "order": 2, "title": "이산확률변수의 기댓값과 표준편차", "standardCode": "12확통03-02", "achievementStandard": "이산확률변수의 기댓값(평균)과 표준편차를 구할 수 있다.", "topics": ["이산확률변수의 기댓값과 표준편차", "계산 방법과 절차", "수학적 표현과 해석"], "scopeNotes": ["이항분포 평균과 분산 공식을 증명하는 문제는 다루지 않는다.", "모평균 추정은 모집단이 정규분포인 경우, 모비율 추정은 표본 크기가 큰 경우를 다룬다.", "복잡한 신뢰구간 계산보다 결과의 의미와 해석에 중점을 둔다."], "visualizationIdeas": ["확률질량이 막대 높이로 배치되고 기댓값이 무게중심으로 이동", "이항분포의 시행 횟수가 커질수록 정규곡선에 가까워지는 애니메이션", "여러 표본의 평균과 비율이 표집분포를 형성하는 시뮬레이션"] }, { "id": "probability-statistics-03-03", "order": 3, "title": "이항분포", "standardCode": "12확통03-03", "achievementStandard": "이항분포의 뜻과 성질을 이해하고, 평균과 표준편차를 구할 수 있다.", "topics": ["이항분포", "핵심 의미와 원리", "계산 방법과 절차", "수학적 표현과 해석"], "scopeNotes": ["이항분포 평균과 분산 공식을 증명하는 문제는 다루지 않는다.", "모평균 추정은 모집단이 정규분포인 경우, 모비율 추정은 표본 크기가 큰 경우를 다룬다.", "복잡한 신뢰구간 계산보다 결과의 의미와 해석에 중점을 둔다."], "visualizationIdeas": ["확률질량이 막대 높이로 배치되고 기댓값이 무게중심으로 이동", "이항분포의 시행 횟수가 커질수록 정규곡선에 가까워지는 애니메이션", "여러 표본의 평균과 비율이 표집분포를 형성하는 시뮬레이션"] }, { "id": "probability-statistics-03-04", "order": 4, "title": "정규분포와 이항분포의 관계", "standardCode": "12확통03-04", "achievementStandard": "정규분포의 뜻과 성질을 이해하고, 이항분포와의 관계를 설명할 수 있다.", "topics": ["정규분포와 이항분포의 관계", "핵심 의미와 원리"], "scopeNotes": ["이항분포 평균과 분산 공식을 증명하는 문제는 다루지 않는다.", "모평균 추정은 모집단이 정규분포인 경우, 모비율 추정은 표본 크기가 큰 경우를 다룬다.", "복잡한 신뢰구간 계산보다 결과의 의미와 해석에 중점을 둔다."], "visualizationIdeas": ["확률질량이 막대 높이로 배치되고 기댓값이 무게중심으로 이동", "이항분포의 시행 횟수가 커질수록 정규곡선에 가까워지는 애니메이션", "여러 표본의 평균과 비율이 표집분포를 형성하는 시뮬레이션"] }, { "id": "probability-statistics-03-05", "order": 5, "title": "모집단과 표본추출", "standardCode": "12확통03-05", "achievementStandard": "모집단과 표본의 뜻을 알고, 표본추출의 방법을 설명할 수 있다.", "topics": ["모집단과 표본추출", "핵심 의미와 원리", "수학적 표현과 해석"], "scopeNotes": ["이항분포 평균과 분산 공식을 증명하는 문제는 다루지 않는다.", "모평균 추정은 모집단이 정규분포인 경우, 모비율 추정은 표본 크기가 큰 경우를 다룬다.", "복잡한 신뢰구간 계산보다 결과의 의미와 해석에 중점을 둔다."], "visualizationIdeas": ["확률질량이 막대 높이로 배치되고 기댓값이 무게중심으로 이동", "이항분포의 시행 횟수가 커질수록 정규곡선에 가까워지는 애니메이션", "여러 표본의 평균과 비율이 표집분포를 형성하는 시뮬레이션"] }, { "id": "probability-statistics-03-06", "order": 6, "title": "표본통계량과 모수의 관계", "standardCode": "12확통03-06", "achievementStandard": "표본평균과 모평균, 표본비율과 모비율의 관계를 이해하고 설명할 수 있다.", "topics": ["표본통계량과 모수의 관계", "핵심 의미와 원리", "수학적 표현과 해석"], "scopeNotes": ["이항분포 평균과 분산 공식을 증명하는 문제는 다루지 않는다.", "모평균 추정은 모집단이 정규분포인 경우, 모비율 추정은 표본 크기가 큰 경우를 다룬다.", "복잡한 신뢰구간 계산보다 결과의 의미와 해석에 중점을 둔다."], "visualizationIdeas": ["확률질량이 막대 높이로 배치되고 기댓값이 무게중심으로 이동", "이항분포의 시행 횟수가 커질수록 정규곡선에 가까워지는 애니메이션", "여러 표본의 평균과 비율이 표집분포를 형성하는 시뮬레이션"] }, { "id": "probability-statistics-03-07", "order": 7, "title": "모평균과 모비율의 추정", "standardCode": "12확통03-07", "achievementStandard": "공학 도구를 이용하여 모평균 및 모비율을 추정하고 그 결과를 해석할 수 있다.", "topics": ["모평균과 모비율의 추정", "핵심 관계"], "scopeNotes": ["이항분포 평균과 분산 공식을 증명하는 문제는 다루지 않는다.", "모평균 추정은 모집단이 정규분포인 경우, 모비율 추정은 표본 크기가 큰 경우를 다룬다.", "복잡한 신뢰구간 계산보다 결과의 의미와 해석에 중점을 둔다."], "visualizationIdeas": ["확률질량이 막대 높이로 배치되고 기댓값이 무게중심으로 이동", "이항분포의 시행 횟수가 커질수록 정규곡선에 가까워지는 애니메이션", "여러 표본의 평균과 비율이 표집분포를 형성하는 시뮬레이션"] }], "conceptCount": 7 }], "categoryEnglishTitle": "GENERAL ELECTIVE", "categoryDescription": "대학 학습과 진로의 기초가 되는 주요 선택 과목입니다.", "categoryOrder": 2, "placementLabel": "학교별 개설·편성", "sourceFile": "kr-2022-probability-statistics.yaml", "developmentLocked": false }, { "id": "calculus-2", "officialTitle": "미적분Ⅱ", "category": "career-elective", "categoryTitle": "진로 선택", "recommendedGrades": [11, 12], "prerequisites": ["algebra", "calculus-1"], "defaultSemester": "school-defined", "conceptCount": 23, "units": [{ "id": "limits-of-sequences", "title": "수열의 극한", "order": 1, "concepts": [{ "id": "calculus-2-01-01", "order": 1, "title": "수열의 수렴과 발산", "standardCode": "12미적Ⅱ-01-01", "achievementStandard": "수열의 수렴, 발산의 뜻을 알고, 이를 판정할 수 있다.", "topics": ["수열의 수렴과 발산", "핵심 의미와 원리"], "scopeNotes": ["수열과 급수의 수렴·발산을 공학 도구로 탐구할 수 있다.", "지나치게 복잡한 급수 계산은 다루지 않는다."], "visualizationIdeas": ["수열의 항을 수직선과 좌표평면에 동시에 찍어 수렴·발산 비교", "부분합 막대가 일정한 값에 가까워지거나 벗어나는 과정 표현", "무한등비급수를 반복적으로 축소되는 넓이 조각으로 재구성"] }, { "id": "calculus-2-01-02", "order": 2, "title": "수열의 극한 성질", "standardCode": "12미적Ⅱ-01-02", "achievementStandard": "수열의 극한에 대한 성질을 이해하고, 이를 활용하여 극한값을 구하는 방법을 설명할 수 있다.", "topics": ["수열의 극한 성질", "핵심 의미와 원리", "적용과 문제 해결"], "scopeNotes": ["수열과 급수의 수렴·발산을 공학 도구로 탐구할 수 있다.", "지나치게 복잡한 급수 계산은 다루지 않는다."], "visualizationIdeas": ["수열의 항을 수직선과 좌표평면에 동시에 찍어 수렴·발산 비교", "부분합 막대가 일정한 값에 가까워지거나 벗어나는 과정 표현", "무한등비급수를 반복적으로 축소되는 넓이 조각으로 재구성"] }, { "id": "calculus-2-01-03", "order": 3, "title": "등비수열의 극한", "standardCode": "12미적Ⅱ-01-03", "achievementStandard": "등비수열의 수렴, 발산을 판정하고, 수렴하는 경우 그 극한값을 구할 수 있다.", "topics": ["등비수열의 극한", "계산 방법과 절차"], "scopeNotes": ["수열과 급수의 수렴·발산을 공학 도구로 탐구할 수 있다.", "지나치게 복잡한 급수 계산은 다루지 않는다."], "visualizationIdeas": ["수열의 항을 수직선과 좌표평면에 동시에 찍어 수렴·발산 비교", "부분합 막대가 일정한 값에 가까워지거나 벗어나는 과정 표현", "무한등비급수를 반복적으로 축소되는 넓이 조각으로 재구성"] }, { "id": "calculus-2-01-04", "order": 4, "title": "급수의 수렴과 발산", "standardCode": "12미적Ⅱ-01-04", "achievementStandard": "급수의 수렴, 발산의 뜻을 알고, 이를 판정할 수 있다.", "topics": ["급수의 수렴과 발산", "핵심 의미와 원리"], "scopeNotes": ["수열과 급수의 수렴·발산을 공학 도구로 탐구할 수 있다.", "지나치게 복잡한 급수 계산은 다루지 않는다."], "visualizationIdeas": ["수열의 항을 수직선과 좌표평면에 동시에 찍어 수렴·발산 비교", "부분합 막대가 일정한 값에 가까워지거나 벗어나는 과정 표현", "무한등비급수를 반복적으로 축소되는 넓이 조각으로 재구성"] }, { "id": "calculus-2-01-05", "order": 5, "title": "등비급수", "standardCode": "12미적Ⅱ-01-05", "achievementStandard": "등비급수의 합을 구하고, 이를 활용할 수 있다.", "topics": ["등비급수", "적용과 문제 해결"], "scopeNotes": ["수열과 급수의 수렴·발산을 공학 도구로 탐구할 수 있다.", "지나치게 복잡한 급수 계산은 다루지 않는다."], "visualizationIdeas": ["수열의 항을 수직선과 좌표평면에 동시에 찍어 수렴·발산 비교", "부분합 막대가 일정한 값에 가까워지거나 벗어나는 과정 표현", "무한등비급수를 반복적으로 축소되는 넓이 조각으로 재구성"] }], "conceptCount": 5 }, { "id": "advanced-differentiation", "title": "미분법", "order": 2, "concepts": [{ "id": "calculus-2-02-01", "order": 1, "title": "지수함수와 로그함수의 극한·미분", "standardCode": "12미적Ⅱ-02-01", "achievementStandard": "지수함수와 로그함수의 극한을 구하고 미분할 수 있다.", "topics": ["지수함수와 로그함수의 극한·미분", "계산 방법과 절차"], "scopeNotes": ["지수·로그·삼각함수의 극한은 도함수를 구하는 데 필요한 정도로 다룬다.", "매개변수 함수와 음함수는 간단한 경우만 다룬다.", "이계도함수는 볼록성과 변곡점의 기하적 의미와 연결한다."], "visualizationIdeas": ["합성함수를 바깥 함수와 안쪽 함수의 연속 변환으로 분해", "매개변수 변화에 따라 점이 곡선을 그리고 접선 벡터가 움직이는 애니메이션", "일계·이계도함수의 부호와 원함수의 증가·볼록성을 3단 그래프로 연결"] }, { "id": "calculus-2-02-02", "order": 2, "title": "삼각함수의 덧셈정리", "standardCode": "12미적Ⅱ-02-02", "achievementStandard": "삼각함수의 덧셈정리를 설명하고, 이를 활용할 수 있다.", "topics": ["삼각함수의 덧셈정리", "핵심 의미와 원리", "적용과 문제 해결"], "scopeNotes": ["지수·로그·삼각함수의 극한은 도함수를 구하는 데 필요한 정도로 다룬다.", "매개변수 함수와 음함수는 간단한 경우만 다룬다.", "이계도함수는 볼록성과 변곡점의 기하적 의미와 연결한다."], "visualizationIdeas": ["합성함수를 바깥 함수와 안쪽 함수의 연속 변환으로 분해", "매개변수 변화에 따라 점이 곡선을 그리고 접선 벡터가 움직이는 애니메이션", "일계·이계도함수의 부호와 원함수의 증가·볼록성을 3단 그래프로 연결"] }, { "id": "calculus-2-02-03", "order": 3, "title": "삼각함수의 극한·미분", "standardCode": "12미적Ⅱ-02-03", "achievementStandard": "삼각함수의 극한을 구하고, 사인함수와 코사인함수를 미분할 수 있다.", "topics": ["삼각함수의 극한·미분", "계산 방법과 절차"], "scopeNotes": ["지수·로그·삼각함수의 극한은 도함수를 구하는 데 필요한 정도로 다룬다.", "매개변수 함수와 음함수는 간단한 경우만 다룬다.", "이계도함수는 볼록성과 변곡점의 기하적 의미와 연결한다."], "visualizationIdeas": ["합성함수를 바깥 함수와 안쪽 함수의 연속 변환으로 분해", "매개변수 변화에 따라 점이 곡선을 그리고 접선 벡터가 움직이는 애니메이션", "일계·이계도함수의 부호와 원함수의 증가·볼록성을 3단 그래프로 연결"] }, { "id": "calculus-2-02-04", "order": 4, "title": "몫의 미분법", "standardCode": "12미적Ⅱ-02-04", "achievementStandard": "함수의 몫을 미분할 수 있다.", "topics": ["몫의 미분법", "계산 방법과 절차"], "scopeNotes": ["지수·로그·삼각함수의 극한은 도함수를 구하는 데 필요한 정도로 다룬다.", "매개변수 함수와 음함수는 간단한 경우만 다룬다.", "이계도함수는 볼록성과 변곡점의 기하적 의미와 연결한다."], "visualizationIdeas": ["합성함수를 바깥 함수와 안쪽 함수의 연속 변환으로 분해", "매개변수 변화에 따라 점이 곡선을 그리고 접선 벡터가 움직이는 애니메이션", "일계·이계도함수의 부호와 원함수의 증가·볼록성을 3단 그래프로 연결"] }, { "id": "calculus-2-02-05", "order": 5, "title": "합성함수의 미분법", "standardCode": "12미적Ⅱ-02-05", "achievementStandard": "합성함수를 미분할 수 있다.", "topics": ["합성함수의 미분법", "계산 방법과 절차"], "scopeNotes": ["지수·로그·삼각함수의 극한은 도함수를 구하는 데 필요한 정도로 다룬다.", "매개변수 함수와 음함수는 간단한 경우만 다룬다.", "이계도함수는 볼록성과 변곡점의 기하적 의미와 연결한다."], "visualizationIdeas": ["합성함수를 바깥 함수와 안쪽 함수의 연속 변환으로 분해", "매개변수 변화에 따라 점이 곡선을 그리고 접선 벡터가 움직이는 애니메이션", "일계·이계도함수의 부호와 원함수의 증가·볼록성을 3단 그래프로 연결"] }, { "id": "calculus-2-02-06", "order": 6, "title": "매개변수 함수의 미분", "standardCode": "12미적Ⅱ-02-06", "achievementStandard": "매개변수로 나타낸 함수를 미분할 수 있다.", "topics": ["매개변수 함수의 미분", "계산 방법과 절차"], "scopeNotes": ["지수·로그·삼각함수의 극한은 도함수를 구하는 데 필요한 정도로 다룬다.", "매개변수 함수와 음함수는 간단한 경우만 다룬다.", "이계도함수는 볼록성과 변곡점의 기하적 의미와 연결한다."], "visualizationIdeas": ["합성함수를 바깥 함수와 안쪽 함수의 연속 변환으로 분해", "매개변수 변화에 따라 점이 곡선을 그리고 접선 벡터가 움직이는 애니메이션", "일계·이계도함수의 부호와 원함수의 증가·볼록성을 3단 그래프로 연결"] }, { "id": "calculus-2-02-07", "order": 7, "title": "음함수와 역함수의 미분", "standardCode": "12미적Ⅱ-02-07", "achievementStandard": "음함수와 역함수를 미분할 수 있다.", "topics": ["음함수와 역함수의 미분", "계산 방법과 절차"], "scopeNotes": ["지수·로그·삼각함수의 극한은 도함수를 구하는 데 필요한 정도로 다룬다.", "매개변수 함수와 음함수는 간단한 경우만 다룬다.", "이계도함수는 볼록성과 변곡점의 기하적 의미와 연결한다."], "visualizationIdeas": ["합성함수를 바깥 함수와 안쪽 함수의 연속 변환으로 분해", "매개변수 변화에 따라 점이 곡선을 그리고 접선 벡터가 움직이는 애니메이션", "일계·이계도함수의 부호와 원함수의 증가·볼록성을 3단 그래프로 연결"] }, { "id": "calculus-2-02-08", "order": 8, "title": "여러 곡선의 접선", "standardCode": "12미적Ⅱ-02-08", "achievementStandard": "다양한 곡선의 접선의 방정식을 구할 수 있다.", "topics": ["여러 곡선의 접선", "계산 방법과 절차", "수학적 표현과 해석"], "scopeNotes": ["지수·로그·삼각함수의 극한은 도함수를 구하는 데 필요한 정도로 다룬다.", "매개변수 함수와 음함수는 간단한 경우만 다룬다.", "이계도함수는 볼록성과 변곡점의 기하적 의미와 연결한다."], "visualizationIdeas": ["합성함수를 바깥 함수와 안쪽 함수의 연속 변환으로 분해", "매개변수 변화에 따라 점이 곡선을 그리고 접선 벡터가 움직이는 애니메이션", "일계·이계도함수의 부호와 원함수의 증가·볼록성을 3단 그래프로 연결"] }, { "id": "calculus-2-02-09", "order": 9, "title": "이계도함수와 그래프의 개형", "standardCode": "12미적Ⅱ-02-09", "achievementStandard": "함수의 그래프의 개형을 그릴 수 있다.", "topics": ["이계도함수와 그래프의 개형", "수학적 표현과 해석"], "scopeNotes": ["지수·로그·삼각함수의 극한은 도함수를 구하는 데 필요한 정도로 다룬다.", "매개변수 함수와 음함수는 간단한 경우만 다룬다.", "이계도함수는 볼록성과 변곡점의 기하적 의미와 연결한다."], "visualizationIdeas": ["합성함수를 바깥 함수와 안쪽 함수의 연속 변환으로 분해", "매개변수 변화에 따라 점이 곡선을 그리고 접선 벡터가 움직이는 애니메이션", "일계·이계도함수의 부호와 원함수의 증가·볼록성을 3단 그래프로 연결"] }, { "id": "calculus-2-02-10", "order": 10, "title": "미분과 방정식·부등식", "standardCode": "12미적Ⅱ-02-10", "achievementStandard": "방정식과 부등식에 대한 문제를 해결할 수 있다.", "topics": ["미분과 방정식·부등식", "수학적 표현과 해석", "적용과 문제 해결"], "scopeNotes": ["지수·로그·삼각함수의 극한은 도함수를 구하는 데 필요한 정도로 다룬다.", "매개변수 함수와 음함수는 간단한 경우만 다룬다.", "이계도함수는 볼록성과 변곡점의 기하적 의미와 연결한다."], "visualizationIdeas": ["합성함수를 바깥 함수와 안쪽 함수의 연속 변환으로 분해", "매개변수 변화에 따라 점이 곡선을 그리고 접선 벡터가 움직이는 애니메이션", "일계·이계도함수의 부호와 원함수의 증가·볼록성을 3단 그래프로 연결"] }, { "id": "calculus-2-02-11", "order": 11, "title": "미분과 속도·가속도", "standardCode": "12미적Ⅱ-02-11", "achievementStandard": "미분을 속도와 가속도에 대한 문제에 활용하고, 그 유용성을 인식할 수 있다.", "topics": ["미분과 속도·가속도", "계산 방법과 절차", "적용과 문제 해결"], "scopeNotes": ["지수·로그·삼각함수의 극한은 도함수를 구하는 데 필요한 정도로 다룬다.", "매개변수 함수와 음함수는 간단한 경우만 다룬다.", "이계도함수는 볼록성과 변곡점의 기하적 의미와 연결한다."], "visualizationIdeas": ["합성함수를 바깥 함수와 안쪽 함수의 연속 변환으로 분해", "매개변수 변화에 따라 점이 곡선을 그리고 접선 벡터가 움직이는 애니메이션", "일계·이계도함수의 부호와 원함수의 증가·볼록성을 3단 그래프로 연결"] }], "conceptCount": 11 }, { "id": "advanced-integration", "title": "적분법", "order": 3, "concepts": [{ "id": "calculus-2-03-01", "order": 1, "title": "여러 함수의 적분", "standardCode": "12미적Ⅱ-03-01", "achievementStandard": "함수 xᵃ(a는 실수), 지수함수, 삼각함수의 부정적분과 정적분을 구할 수 있다.", "topics": ["여러 함수의 적분", "계산 방법과 절차"], "scopeNotes": ["치환적분법과 부분적분법은 기본 원리와 간단한 활용에 중점을 둔다.", "정적분의 다양한 문제 해결을 통해 적분의 유용성을 인식한다."], "visualizationIdeas": ["좌표축 또는 변수 변환에 따라 같은 넓이가 다른 적분식으로 바뀌는 장면", "곱의 미분법을 역으로 되감아 부분적분 공식을 구성", "회전체를 얇은 원판으로 분할해 부피가 누적되는 애니메이션"] }, { "id": "calculus-2-03-02", "order": 2, "title": "치환적분법", "standardCode": "12미적Ⅱ-03-02", "achievementStandard": "치환적분법을 이해하고, 이를 활용할 수 있다.", "topics": ["치환적분법", "핵심 의미와 원리", "계산 방법과 절차", "적용과 문제 해결"], "scopeNotes": ["치환적분법과 부분적분법은 기본 원리와 간단한 활용에 중점을 둔다.", "정적분의 다양한 문제 해결을 통해 적분의 유용성을 인식한다."], "visualizationIdeas": ["좌표축 또는 변수 변환에 따라 같은 넓이가 다른 적분식으로 바뀌는 장면", "곱의 미분법을 역으로 되감아 부분적분 공식을 구성", "회전체를 얇은 원판으로 분할해 부피가 누적되는 애니메이션"] }, { "id": "calculus-2-03-03", "order": 3, "title": "부분적분법", "standardCode": "12미적Ⅱ-03-03", "achievementStandard": "부분적분법을 이해하고, 이를 활용할 수 있다.", "topics": ["부분적분법", "핵심 의미와 원리", "계산 방법과 절차", "적용과 문제 해결"], "scopeNotes": ["치환적분법과 부분적분법은 기본 원리와 간단한 활용에 중점을 둔다.", "정적분의 다양한 문제 해결을 통해 적분의 유용성을 인식한다."], "visualizationIdeas": ["좌표축 또는 변수 변환에 따라 같은 넓이가 다른 적분식으로 바뀌는 장면", "곱의 미분법을 역으로 되감아 부분적분 공식을 구성", "회전체를 얇은 원판으로 분할해 부피가 누적되는 애니메이션"] }, { "id": "calculus-2-03-04", "order": 4, "title": "정적분과 급수의 관계", "standardCode": "12미적Ⅱ-03-04", "achievementStandard": "정적분과 급수의 합 사이의 관계를 탐구하고 이해한다.", "topics": ["정적분과 급수의 관계", "핵심 의미와 원리", "계산 방법과 절차", "탐구 설계와 수행"], "scopeNotes": ["치환적분법과 부분적분법은 기본 원리와 간단한 활용에 중점을 둔다.", "정적분의 다양한 문제 해결을 통해 적분의 유용성을 인식한다."], "visualizationIdeas": ["좌표축 또는 변수 변환에 따라 같은 넓이가 다른 적분식으로 바뀌는 장면", "곱의 미분법을 역으로 되감아 부분적분 공식을 구성", "회전체를 얇은 원판으로 분할해 부피가 누적되는 애니메이션"] }, { "id": "calculus-2-03-05", "order": 5, "title": "정적분과 넓이", "standardCode": "12미적Ⅱ-03-05", "achievementStandard": "곡선으로 둘러싸인 도형의 넓이에 대한 문제를 해결할 수 있다.", "topics": ["정적분과 넓이", "적용과 문제 해결"], "scopeNotes": ["치환적분법과 부분적분법은 기본 원리와 간단한 활용에 중점을 둔다.", "정적분의 다양한 문제 해결을 통해 적분의 유용성을 인식한다."], "visualizationIdeas": ["좌표축 또는 변수 변환에 따라 같은 넓이가 다른 적분식으로 바뀌는 장면", "곱의 미분법을 역으로 되감아 부분적분 공식을 구성", "회전체를 얇은 원판으로 분할해 부피가 누적되는 애니메이션"] }, { "id": "calculus-2-03-06", "order": 6, "title": "정적분과 부피", "standardCode": "12미적Ⅱ-03-06", "achievementStandard": "입체도형의 부피에 대한 문제를 해결할 수 있다.", "topics": ["정적분과 부피", "적용과 문제 해결"], "scopeNotes": ["치환적분법과 부분적분법은 기본 원리와 간단한 활용에 중점을 둔다.", "정적분의 다양한 문제 해결을 통해 적분의 유용성을 인식한다."], "visualizationIdeas": ["좌표축 또는 변수 변환에 따라 같은 넓이가 다른 적분식으로 바뀌는 장면", "곱의 미분법을 역으로 되감아 부분적분 공식을 구성", "회전체를 얇은 원판으로 분할해 부피가 누적되는 애니메이션"] }, { "id": "calculus-2-03-07", "order": 7, "title": "적분과 속도·거리", "standardCode": "12미적Ⅱ-03-07", "achievementStandard": "적분을 속도와 거리에 대한 문제에 활용하고, 그 유용성을 인식할 수 있다.", "topics": ["적분과 속도·거리", "계산 방법과 절차", "적용과 문제 해결"], "scopeNotes": ["치환적분법과 부분적분법은 기본 원리와 간단한 활용에 중점을 둔다.", "정적분의 다양한 문제 해결을 통해 적분의 유용성을 인식한다."], "visualizationIdeas": ["좌표축 또는 변수 변환에 따라 같은 넓이가 다른 적분식으로 바뀌는 장면", "곱의 미분법을 역으로 되감아 부분적분 공식을 구성", "회전체를 얇은 원판으로 분할해 부피가 누적되는 애니메이션"] }], "conceptCount": 7 }], "categoryEnglishTitle": "CAREER ELECTIVE", "categoryDescription": "관심 분야와 진로에 따라 깊이 있게 학습하는 과목입니다.", "categoryOrder": 3, "placementLabel": "학교별 개설·편성", "sourceFile": "kr-2022-calculus-2.yaml", "developmentLocked": true }, { "id": "geometry", "officialTitle": "기하", "category": "career-elective", "categoryTitle": "진로 선택", "recommendedGrades": [11, 12], "prerequisites": ["common-math-1", "common-math-2"], "defaultSemester": "school-defined", "conceptCount": 14, "units": [{ "id": "conic-sections", "title": "이차곡선", "order": 1, "concepts": [{ "id": "geometry-01-01", "order": 1, "title": "포물선", "standardCode": "12기하01-01", "achievementStandard": "포물선의 뜻을 알고, 포물선을 방정식으로 표현할 수 있다.", "topics": ["포물선", "핵심 의미와 원리", "수학적 표현과 해석"], "scopeNotes": ["이차곡선은 정의와 방정식을 초점·준선·거리 관계와 연결한다.", "이차곡선의 접선은 이차방정식의 판별식을 이용하여 구한다."], "visualizationIdeas": ["원뿔 절단 각도에 따라 원·타원·포물선·쌍곡선이 나타나는 3차원 애니메이션", "점이 움직여도 초점과 준선 또는 두 초점까지 거리 관계가 유지되는 추적", "접선이 곡선과 한 점에서 만나는 조건을 판별식 D=0과 연결"] }, { "id": "geometry-01-02", "order": 2, "title": "타원", "standardCode": "12기하01-02", "achievementStandard": "타원의 뜻을 알고, 타원을 방정식으로 표현할 수 있다.", "topics": ["타원", "핵심 의미와 원리", "수학적 표현과 해석"], "scopeNotes": ["이차곡선은 정의와 방정식을 초점·준선·거리 관계와 연결한다.", "이차곡선의 접선은 이차방정식의 판별식을 이용하여 구한다."], "visualizationIdeas": ["원뿔 절단 각도에 따라 원·타원·포물선·쌍곡선이 나타나는 3차원 애니메이션", "점이 움직여도 초점과 준선 또는 두 초점까지 거리 관계가 유지되는 추적", "접선이 곡선과 한 점에서 만나는 조건을 판별식 D=0과 연결"] }, { "id": "geometry-01-03", "order": 3, "title": "쌍곡선", "standardCode": "12기하01-03", "achievementStandard": "쌍곡선의 뜻을 알고, 쌍곡선을 방정식으로 표현할 수 있다.", "topics": ["쌍곡선", "핵심 의미와 원리", "수학적 표현과 해석"], "scopeNotes": ["이차곡선은 정의와 방정식을 초점·준선·거리 관계와 연결한다.", "이차곡선의 접선은 이차방정식의 판별식을 이용하여 구한다."], "visualizationIdeas": ["원뿔 절단 각도에 따라 원·타원·포물선·쌍곡선이 나타나는 3차원 애니메이션", "점이 움직여도 초점과 준선 또는 두 초점까지 거리 관계가 유지되는 추적", "접선이 곡선과 한 점에서 만나는 조건을 판별식 D=0과 연결"] }, { "id": "geometry-01-04", "order": 4, "title": "이차곡선의 접선", "standardCode": "12기하01-04", "achievementStandard": "이차곡선의 접선의 방정식을 구할 수 있다.", "topics": ["이차곡선의 접선", "계산 방법과 절차", "수학적 표현과 해석"], "scopeNotes": ["이차곡선은 정의와 방정식을 초점·준선·거리 관계와 연결한다.", "이차곡선의 접선은 이차방정식의 판별식을 이용하여 구한다."], "visualizationIdeas": ["원뿔 절단 각도에 따라 원·타원·포물선·쌍곡선이 나타나는 3차원 애니메이션", "점이 움직여도 초점과 준선 또는 두 초점까지 거리 관계가 유지되는 추적", "접선이 곡선과 한 점에서 만나는 조건을 판별식 D=0과 연결"] }], "conceptCount": 4 }, { "id": "solid-geometry-and-coordinates", "title": "공간도형과 공간좌표", "order": 2, "concepts": [{ "id": "geometry-02-01", "order": 1, "title": "공간의 직선과 평면의 위치 관계", "standardCode": "12기하02-01", "achievementStandard": "직선과 직선, 직선과 평면, 평면과 평면의 위치 관계에 대한 간단한 증명을 할 수 있다.", "topics": ["공간의 직선과 평면의 위치 관계", "핵심 관계"], "scopeNotes": ["평면에서 공간으로 차원을 확장하는 원리를 이해하는 데 중점을 둔다.", "위치 관계의 증명은 간단한 경우를 다룬다."], "visualizationIdeas": ["3차원 공간에서 직선과 평면을 회전시켜 평행·교차·수직 관계 관찰", "빛의 방향을 움직이며 정사영의 길이와 넓이 변화 표시", "공간좌표의 두 점과 내분점이 평면 좌표의 원리를 확장하는 장면"] }, { "id": "geometry-02-02", "order": 2, "title": "삼수선 정리", "standardCode": "12기하02-02", "achievementStandard": "삼수선 정리를 이해하고, 이를 활용하여 문제를 해결할 수 있다.", "topics": ["삼수선 정리", "핵심 의미와 원리", "적용과 문제 해결"], "scopeNotes": ["평면에서 공간으로 차원을 확장하는 원리를 이해하는 데 중점을 둔다.", "위치 관계의 증명은 간단한 경우를 다룬다."], "visualizationIdeas": ["3차원 공간에서 직선과 평면을 회전시켜 평행·교차·수직 관계 관찰", "빛의 방향을 움직이며 정사영의 길이와 넓이 변화 표시", "공간좌표의 두 점과 내분점이 평면 좌표의 원리를 확장하는 장면"] }, { "id": "geometry-02-03", "order": 3, "title": "정사영", "standardCode": "12기하02-03", "achievementStandard": "도형의 정사영의 뜻을 알고, 도형과 정사영의 관계를 탐구할 수 있다.", "topics": ["정사영", "핵심 의미와 원리", "계산 방법과 절차", "탐구 설계와 수행"], "scopeNotes": ["평면에서 공간으로 차원을 확장하는 원리를 이해하는 데 중점을 둔다.", "위치 관계의 증명은 간단한 경우를 다룬다."], "visualizationIdeas": ["3차원 공간에서 직선과 평면을 회전시켜 평행·교차·수직 관계 관찰", "빛의 방향을 움직이며 정사영의 길이와 넓이 변화 표시", "공간좌표의 두 점과 내분점이 평면 좌표의 원리를 확장하는 장면"] }, { "id": "geometry-02-04", "order": 4, "title": "공간좌표의 거리와 내분점", "standardCode": "12기하02-04", "achievementStandard": "좌표공간에서 두 점 사이의 거리와 선분의 내분점의 좌표를 구할 수 있다.", "topics": ["공간좌표의 거리와 내분점", "계산 방법과 절차", "수학적 표현과 해석"], "scopeNotes": ["평면에서 공간으로 차원을 확장하는 원리를 이해하는 데 중점을 둔다.", "위치 관계의 증명은 간단한 경우를 다룬다."], "visualizationIdeas": ["3차원 공간에서 직선과 평면을 회전시켜 평행·교차·수직 관계 관찰", "빛의 방향을 움직이며 정사영의 길이와 넓이 변화 표시", "공간좌표의 두 점과 내분점이 평면 좌표의 원리를 확장하는 장면"] }, { "id": "geometry-02-05", "order": 5, "title": "구의 방정식", "standardCode": "12기하02-05", "achievementStandard": "구를 방정식으로 표현할 수 있다.", "topics": ["구의 방정식", "수학적 표현과 해석"], "scopeNotes": ["평면에서 공간으로 차원을 확장하는 원리를 이해하는 데 중점을 둔다.", "위치 관계의 증명은 간단한 경우를 다룬다."], "visualizationIdeas": ["3차원 공간에서 직선과 평면을 회전시켜 평행·교차·수직 관계 관찰", "빛의 방향을 움직이며 정사영의 길이와 넓이 변화 표시", "공간좌표의 두 점과 내분점이 평면 좌표의 원리를 확장하는 장면"] }], "conceptCount": 5 }, { "id": "vectors", "title": "벡터", "order": 3, "concepts": [{ "id": "geometry-03-01", "order": 1, "title": "벡터의 뜻과 연산", "standardCode": "12기하03-01", "achievementStandard": "벡터의 뜻을 알고, 벡터의 덧셈, 뺄셈, 실수배를 할 수 있다.", "topics": ["벡터의 뜻과 연산", "핵심 의미와 원리", "수학적 표현과 해석"], "scopeNotes": ["벡터의 기하적 표현과 좌표를 이용한 대수적 표현을 함께 다룬다.", "직선·평면·구를 벡터로 간결하게 표현하는 의미에 중점을 둔다."], "visualizationIdeas": ["벡터를 평행이동해도 크기와 방향이 유지되는 장면", "벡터의 덧셈을 삼각형법과 평행사변형법으로 동시 표현", "내적이 정사영 길이와 각도에 따라 변하는 인터랙션"] }, { "id": "geometry-03-02", "order": 2, "title": "위치벡터와 좌표", "standardCode": "12기하03-02", "achievementStandard": "위치벡터의 뜻을 알고, 벡터와 좌표를 대응시켜 표현할 수 있다.", "topics": ["위치벡터와 좌표", "핵심 의미와 원리", "수학적 표현과 해석"], "scopeNotes": ["벡터의 기하적 표현과 좌표를 이용한 대수적 표현을 함께 다룬다.", "직선·평면·구를 벡터로 간결하게 표현하는 의미에 중점을 둔다."], "visualizationIdeas": ["벡터를 평행이동해도 크기와 방향이 유지되는 장면", "벡터의 덧셈을 삼각형법과 평행사변형법으로 동시 표현", "내적이 정사영 길이와 각도에 따라 변하는 인터랙션"] }, { "id": "geometry-03-03", "order": 3, "title": "벡터의 내적", "standardCode": "12기하03-03", "achievementStandard": "내적의 뜻을 알고, 두 벡터의 내적을 구할 수 있다.", "topics": ["벡터의 내적", "핵심 의미와 원리", "계산 방법과 절차", "수학적 표현과 해석"], "scopeNotes": ["벡터의 기하적 표현과 좌표를 이용한 대수적 표현을 함께 다룬다.", "직선·평면·구를 벡터로 간결하게 표현하는 의미에 중점을 둔다."], "visualizationIdeas": ["벡터를 평행이동해도 크기와 방향이 유지되는 장면", "벡터의 덧셈을 삼각형법과 평행사변형법으로 동시 표현", "내적이 정사영 길이와 각도에 따라 변하는 인터랙션"] }, { "id": "geometry-03-04", "order": 4, "title": "벡터와 직선의 방정식", "standardCode": "12기하03-04", "achievementStandard": "벡터를 이용하여 직선의 방정식을 구할 수 있다.", "topics": ["벡터와 직선의 방정식", "계산 방법과 절차", "수학적 표현과 해석"], "scopeNotes": ["벡터의 기하적 표현과 좌표를 이용한 대수적 표현을 함께 다룬다.", "직선·평면·구를 벡터로 간결하게 표현하는 의미에 중점을 둔다."], "visualizationIdeas": ["벡터를 평행이동해도 크기와 방향이 유지되는 장면", "벡터의 덧셈을 삼각형법과 평행사변형법으로 동시 표현", "내적이 정사영 길이와 각도에 따라 변하는 인터랙션"] }, { "id": "geometry-03-05", "order": 5, "title": "벡터와 평면·구의 방정식", "standardCode": "12기하03-05", "achievementStandard": "좌표공간에서 벡터를 이용하여 평면의 방정식과 구의 방정식을 구할 수 있다.", "topics": ["벡터와 평면·구의 방정식", "계산 방법과 절차", "수학적 표현과 해석"], "scopeNotes": ["벡터의 기하적 표현과 좌표를 이용한 대수적 표현을 함께 다룬다.", "직선·평면·구를 벡터로 간결하게 표현하는 의미에 중점을 둔다."], "visualizationIdeas": ["벡터를 평행이동해도 크기와 방향이 유지되는 장면", "벡터의 덧셈을 삼각형법과 평행사변형법으로 동시 표현", "내적이 정사영 길이와 각도에 따라 변하는 인터랙션"] }], "conceptCount": 5 }], "categoryEnglishTitle": "CAREER ELECTIVE", "categoryDescription": "관심 분야와 진로에 따라 깊이 있게 학습하는 과목입니다.", "categoryOrder": 3, "placementLabel": "학교별 개설·편성", "sourceFile": "kr-2022-geometry.yaml", "developmentLocked": true }, { "id": "economics-math", "officialTitle": "경제 수학", "category": "career-elective", "categoryTitle": "진로 선택", "recommendedGrades": [11, 12], "prerequisites": ["common-math-1", "common-math-2"], "defaultSemester": "school-defined", "conceptCount": 18, "units": [{ "id": "numbers-and-economics", "title": "수와 경제", "order": 1, "concepts": [{ "id": "economics-math-01-01", "order": 1, "title": "경제지표", "standardCode": "12경수01-01", "achievementStandard": "통계 자료를 활용하여 경제지표의 의미를 이해하고, 경제지표의 변화를 설명할 수 있다.", "topics": ["경제지표", "핵심 의미와 원리", "수학적 표현과 해석", "적용과 문제 해결"], "scopeNotes": ["공식 암기보다 경제 상황에 맞는 수학적 개념과 표현의 선택에 중점을 둔다.", "경제지표·환율·세금·금융상품은 학생 삶과 연결된 구체적 사례로 다룬다.", "미적분Ⅱ 이수자에게는 연속복리를 선택적으로 다룰 수 있다."], "visualizationIdeas": ["물가·환율 지표의 기준 시점과 변화율을 시간축에서 비교", "단리·복리·연속복리의 원리합계 곡선을 같은 축에 중첩", "미래 현금 흐름을 현재 시점으로 할인해 이동시키는 애니메이션"] }, { "id": "economics-math-01-02", "order": 2, "title": "환율", "standardCode": "12경수01-02", "achievementStandard": "환율과 관련된 실생활 문제를 해결할 수 있다.", "topics": ["환율", "적용과 문제 해결"], "scopeNotes": ["공식 암기보다 경제 상황에 맞는 수학적 개념과 표현의 선택에 중점을 둔다.", "경제지표·환율·세금·금융상품은 학생 삶과 연결된 구체적 사례로 다룬다.", "미적분Ⅱ 이수자에게는 연속복리를 선택적으로 다룰 수 있다."], "visualizationIdeas": ["물가·환율 지표의 기준 시점과 변화율을 시간축에서 비교", "단리·복리·연속복리의 원리합계 곡선을 같은 축에 중첩", "미래 현금 흐름을 현재 시점으로 할인해 이동시키는 애니메이션"] }, { "id": "economics-math-01-03", "order": 3, "title": "세금", "standardCode": "12경수01-03", "achievementStandard": "세금과 관련된 실생활 문제를 해결할 수 있다.", "topics": ["세금", "적용과 문제 해결"], "scopeNotes": ["공식 암기보다 경제 상황에 맞는 수학적 개념과 표현의 선택에 중점을 둔다.", "경제지표·환율·세금·금융상품은 학생 삶과 연결된 구체적 사례로 다룬다.", "미적분Ⅱ 이수자에게는 연속복리를 선택적으로 다룰 수 있다."], "visualizationIdeas": ["물가·환율 지표의 기준 시점과 변화율을 시간축에서 비교", "단리·복리·연속복리의 원리합계 곡선을 같은 축에 중첩", "미래 현금 흐름을 현재 시점으로 할인해 이동시키는 애니메이션"] }, { "id": "economics-math-01-04", "order": 4, "title": "이자와 현재가치", "standardCode": "12경수01-04", "achievementStandard": "단리와 복리를 이용하여 이자와 원리합계를 구하고, 미래에 받을 금액의 현재가치를 구할 수 있다.", "topics": ["이자와 현재가치", "계산 방법과 절차"], "scopeNotes": ["공식 암기보다 경제 상황에 맞는 수학적 개념과 표현의 선택에 중점을 둔다.", "경제지표·환율·세금·금융상품은 학생 삶과 연결된 구체적 사례로 다룬다.", "미적분Ⅱ 이수자에게는 연속복리를 선택적으로 다룰 수 있다."], "visualizationIdeas": ["물가·환율 지표의 기준 시점과 변화율을 시간축에서 비교", "단리·복리·연속복리의 원리합계 곡선을 같은 축에 중첩", "미래 현금 흐름을 현재 시점으로 할인해 이동시키는 애니메이션"] }, { "id": "economics-math-01-05", "order": 5, "title": "연금의 현재가치", "standardCode": "12경수01-05", "achievementStandard": "연금의 뜻을 알고, 연금의 현재가치를 구할 수 있다.", "topics": ["연금의 현재가치", "핵심 의미와 원리", "계산 방법과 절차"], "scopeNotes": ["공식 암기보다 경제 상황에 맞는 수학적 개념과 표현의 선택에 중점을 둔다.", "경제지표·환율·세금·금융상품은 학생 삶과 연결된 구체적 사례로 다룬다.", "미적분Ⅱ 이수자에게는 연속복리를 선택적으로 다룰 수 있다."], "visualizationIdeas": ["물가·환율 지표의 기준 시점과 변화율을 시간축에서 비교", "단리·복리·연속복리의 원리합계 곡선을 같은 축에 중첩", "미래 현금 흐름을 현재 시점으로 할인해 이동시키는 애니메이션"] }], "conceptCount": 5 }, { "id": "functions-and-economics", "title": "함수와 경제", "order": 2, "concepts": [{ "id": "economics-math-02-01", "order": 1, "title": "경제 현상과 함수", "standardCode": "12경수02-01", "achievementStandard": "여러 가지 경제 현상을 함수로 나타낼 수 있다.", "topics": ["경제 현상과 함수", "적용과 문제 해결"], "scopeNotes": ["여러 독립변수 중 일부를 고정해 일변수함수로 해석할 수 있음을 이해한다.", "부등식 영역의 최대·최소에서는 경제 관련 함수를 일차식으로 제한한다."], "visualizationIdeas": ["수요·공급곡선이 이동하며 균형가격과 거래량이 바뀌는 애니메이션", "예산 제약선과 효용 수준을 움직이며 선택 가능한 영역 비교", "부등식의 영역을 생산 가능 조합의 색칠된 영역으로 표현"] }, { "id": "economics-math-02-02", "order": 2, "title": "수요곡선과 공급곡선", "standardCode": "12경수02-02", "achievementStandard": "함수와 그래프를 활용하여 수요곡선과 공급곡선의 의미를 탐구하고 이해한다.", "topics": ["수요곡선과 공급곡선", "핵심 의미와 원리", "수학적 표현과 해석", "적용과 문제 해결", "탐구 설계와 수행"], "scopeNotes": ["여러 독립변수 중 일부를 고정해 일변수함수로 해석할 수 있음을 이해한다.", "부등식 영역의 최대·최소에서는 경제 관련 함수를 일차식으로 제한한다."], "visualizationIdeas": ["수요·공급곡선이 이동하며 균형가격과 거래량이 바뀌는 애니메이션", "예산 제약선과 효용 수준을 움직이며 선택 가능한 영역 비교", "부등식의 영역을 생산 가능 조합의 색칠된 영역으로 표현"] }, { "id": "economics-math-02-03", "order": 3, "title": "효용함수", "standardCode": "12경수02-03", "achievementStandard": "효용의 의미를 이해하고, 효용을 함수와 그래프로 나타낼 수 있다.", "topics": ["효용함수", "핵심 의미와 원리", "수학적 표현과 해석"], "scopeNotes": ["여러 독립변수 중 일부를 고정해 일변수함수로 해석할 수 있음을 이해한다.", "부등식 영역의 최대·최소에서는 경제 관련 함수를 일차식으로 제한한다."], "visualizationIdeas": ["수요·공급곡선이 이동하며 균형가격과 거래량이 바뀌는 애니메이션", "예산 제약선과 효용 수준을 움직이며 선택 가능한 영역 비교", "부등식의 영역을 생산 가능 조합의 색칠된 영역으로 표현"] }, { "id": "economics-math-02-04", "order": 4, "title": "균형가격과 균형수급량", "standardCode": "12경수02-04", "achievementStandard": "수요와 공급의 상호 작용에 의해 균형가격이 결정되는 경제 현상을 설명할 수 있다.", "topics": ["균형가격과 균형수급량", "핵심 의미와 원리", "적용과 문제 해결"], "scopeNotes": ["여러 독립변수 중 일부를 고정해 일변수함수로 해석할 수 있음을 이해한다.", "부등식 영역의 최대·최소에서는 경제 관련 함수를 일차식으로 제한한다."], "visualizationIdeas": ["수요·공급곡선이 이동하며 균형가격과 거래량이 바뀌는 애니메이션", "예산 제약선과 효용 수준을 움직이며 선택 가능한 영역 비교", "부등식의 영역을 생산 가능 조합의 색칠된 영역으로 표현"] }, { "id": "economics-math-02-05", "order": 5, "title": "세금·소득과 균형가격", "standardCode": "12경수02-05", "achievementStandard": "세금과 소득의 변화가 균형가격에 미치는 영향을 탐구하고 이해한다.", "topics": ["세금·소득과 균형가격", "핵심 의미와 원리", "탐구 설계와 수행"], "scopeNotes": ["여러 독립변수 중 일부를 고정해 일변수함수로 해석할 수 있음을 이해한다.", "부등식 영역의 최대·최소에서는 경제 관련 함수를 일차식으로 제한한다."], "visualizationIdeas": ["수요·공급곡선이 이동하며 균형가격과 거래량이 바뀌는 애니메이션", "예산 제약선과 효용 수준을 움직이며 선택 가능한 영역 비교", "부등식의 영역을 생산 가능 조합의 색칠된 영역으로 표현"] }, { "id": "economics-math-02-06", "order": 6, "title": "부등식의 영역과 경제 문제", "standardCode": "12경수02-06", "achievementStandard": "부등식의 영역의 개념을 이해하고, 이를 활용하여 경제 현상의 문제를 해결할 수 있다.", "topics": ["부등식의 영역과 경제 문제", "핵심 의미와 원리", "적용과 문제 해결"], "scopeNotes": ["여러 독립변수 중 일부를 고정해 일변수함수로 해석할 수 있음을 이해한다.", "부등식 영역의 최대·최소에서는 경제 관련 함수를 일차식으로 제한한다."], "visualizationIdeas": ["수요·공급곡선이 이동하며 균형가격과 거래량이 바뀌는 애니메이션", "예산 제약선과 효용 수준을 움직이며 선택 가능한 영역 비교", "부등식의 영역을 생산 가능 조합의 색칠된 영역으로 표현"] }], "conceptCount": 6 }, { "id": "matrices-and-economics", "title": "행렬과 경제", "order": 3, "concepts": [{ "id": "economics-math-03-01", "order": 1, "title": "경제 자료와 행렬", "standardCode": "12경수03-01", "achievementStandard": "여러 가지 경제 현상을 행렬로 나타내고, 연산할 수 있다.", "topics": ["경제 자료와 행렬", "계산 방법과 절차", "수학적 표현과 해석", "적용과 문제 해결"], "scopeNotes": ["복잡한 형식 논리 규칙이나 엄밀한 대수적 증명은 다루지 않는다.", "행렬 연산이 경제 현상에서 의미하는 바를 해석하는 데 중점을 둔다."], "visualizationIdeas": ["산업 간 거래 표가 행렬로 변환되고 행·열 연산이 경제 흐름과 연결", "선형변환을 되돌리는 과정으로 역행렬의 의미 표현"] }, { "id": "economics-math-03-02", "order": 2, "title": "역행렬", "standardCode": "12경수03-02", "achievementStandard": "역행렬의 뜻을 알고, 행렬의 역행렬을 구할 수 있다.", "topics": ["역행렬", "핵심 의미와 원리", "계산 방법과 절차", "수학적 표현과 해석"], "scopeNotes": ["복잡한 형식 논리 규칙이나 엄밀한 대수적 증명은 다루지 않는다.", "행렬 연산이 경제 현상에서 의미하는 바를 해석하는 데 중점을 둔다."], "visualizationIdeas": ["산업 간 거래 표가 행렬로 변환되고 행·열 연산이 경제 흐름과 연결", "선형변환을 되돌리는 과정으로 역행렬의 의미 표현"] }, { "id": "economics-math-03-03", "order": 3, "title": "행렬을 활용한 경제 문제", "standardCode": "12경수03-03", "achievementStandard": "행렬의 연산과 역행렬을 활용하여 경제 현상의 문제를 해결할 수 있다.", "topics": ["행렬을 활용한 경제 문제", "계산 방법과 절차", "수학적 표현과 해석", "적용과 문제 해결"], "scopeNotes": ["복잡한 형식 논리 규칙이나 엄밀한 대수적 증명은 다루지 않는다.", "행렬 연산이 경제 현상에서 의미하는 바를 해석하는 데 중점을 둔다."], "visualizationIdeas": ["산업 간 거래 표가 행렬로 변환되고 행·열 연산이 경제 흐름과 연결", "선형변환을 되돌리는 과정으로 역행렬의 의미 표현"] }], "conceptCount": 3 }, { "id": "differentiation-and-economics", "title": "미분과 경제", "order": 4, "concepts": [{ "id": "economics-math-04-01", "order": 1, "title": "경제 함수의 미분", "standardCode": "12경수04-01", "achievementStandard": "미분의 개념을 이해하고 경제 현상을 나타내는 함수를 미분할 수 있다.", "topics": ["경제 함수의 미분", "핵심 의미와 원리", "계산 방법과 절차", "적용과 문제 해결"], "scopeNotes": ["함수의 극한은 직관적으로, 미분계수는 접선의 기울기로 도입한다.", "다항함수의 미분을 중심으로 다룬다.", "효용·생산함수의 특정 변수를 고정하여 일변수함수로 최적화한다."], "visualizationIdeas": ["총비용·총수입 곡선의 접선 기울기를 한계비용·한계수입과 연결", "가격 변화에 따른 수요량 변화와 탄력성을 그래프 위 비율로 표시", "이윤함수의 최고점과 최적 생산량을 움직이는 점으로 탐색"] }, { "id": "economics-math-04-02", "order": 2, "title": "경제 함수 그래프", "standardCode": "12경수04-02", "achievementStandard": "미분을 이용하여 그래프의 개형을 탐구하고 해석할 수 있다.", "topics": ["경제 함수 그래프", "계산 방법과 절차", "수학적 표현과 해석", "탐구 설계와 수행"], "scopeNotes": ["함수의 극한은 직관적으로, 미분계수는 접선의 기울기로 도입한다.", "다항함수의 미분을 중심으로 다룬다.", "효용·생산함수의 특정 변수를 고정하여 일변수함수로 최적화한다."], "visualizationIdeas": ["총비용·총수입 곡선의 접선 기울기를 한계비용·한계수입과 연결", "가격 변화에 따른 수요량 변화와 탄력성을 그래프 위 비율로 표시", "이윤함수의 최고점과 최적 생산량을 움직이는 점으로 탐색"] }, { "id": "economics-math-04-03", "order": 3, "title": "탄력성", "standardCode": "12경수04-03", "achievementStandard": "미분을 활용하여 탄력성의 의미를 탐구하고 이해한다.", "topics": ["탄력성", "핵심 의미와 원리", "계산 방법과 절차", "적용과 문제 해결", "탐구 설계와 수행"], "scopeNotes": ["함수의 극한은 직관적으로, 미분계수는 접선의 기울기로 도입한다.", "다항함수의 미분을 중심으로 다룬다.", "효용·생산함수의 특정 변수를 고정하여 일변수함수로 최적화한다."], "visualizationIdeas": ["총비용·총수입 곡선의 접선 기울기를 한계비용·한계수입과 연결", "가격 변화에 따른 수요량 변화와 탄력성을 그래프 위 비율로 표시", "이윤함수의 최고점과 최적 생산량을 움직이는 점으로 탐색"] }, { "id": "economics-math-04-04", "order": 4, "title": "경제 최적화", "standardCode": "12경수04-04", "achievementStandard": "미분을 활용하여 경제 현상의 최적화 문제를 해결할 수 있다.", "topics": ["경제 최적화", "계산 방법과 절차", "적용과 문제 해결"], "scopeNotes": ["함수의 극한은 직관적으로, 미분계수는 접선의 기울기로 도입한다.", "다항함수의 미분을 중심으로 다룬다.", "효용·생산함수의 특정 변수를 고정하여 일변수함수로 최적화한다."], "visualizationIdeas": ["총비용·총수입 곡선의 접선 기울기를 한계비용·한계수입과 연결", "가격 변화에 따른 수요량 변화와 탄력성을 그래프 위 비율로 표시", "이윤함수의 최고점과 최적 생산량을 움직이는 점으로 탐색"] }], "conceptCount": 4 }], "categoryEnglishTitle": "CAREER ELECTIVE", "categoryDescription": "관심 분야와 진로에 따라 깊이 있게 학습하는 과목입니다.", "categoryOrder": 3, "placementLabel": "학교별 개설·편성", "sourceFile": "kr-2022-economics-math.yaml", "developmentLocked": true }, { "id": "ai-math", "officialTitle": "인공지능 수학", "category": "career-elective", "categoryTitle": "진로 선택", "recommendedGrades": [11, 12], "prerequisites": ["common-math-1", "common-math-2"], "defaultSemester": "school-defined", "conceptCount": 15, "units": [{ "id": "ai-and-big-data", "title": "인공지능과 빅데이터", "order": 1, "concepts": [{ "id": "ai-math-01-01", "order": 1, "title": "인공지능의 학습 방식", "standardCode": "12인수01-01", "achievementStandard": "인공지능의 개념을 이해하고 학습 방식을 수학적으로 해석할 수 있다.", "topics": ["인공지능의 학습 방식", "핵심 의미와 원리"], "scopeNotes": ["지도학습·비지도학습·강화학습과 퍼셉트론은 개념 중심으로 다룬다.", "빅데이터 활용에서 편향과 공정성을 함께 고려한다."], "visualizationIdeas": ["퍼셉트론의 입력·가중치·활성화 결과가 흐르는 네트워크 애니메이션", "OR·AND·XOR의 결정 영역과 단층·다층 구조 비교", "데이터 표본의 편향이 예측 결과의 편향으로 이어지는 시뮬레이션"] }, { "id": "ai-math-01-02", "order": 2, "title": "인공지능과 수학의 역사", "standardCode": "12인수01-02", "achievementStandard": "인공지능에서 수학을 활용한 역사적 사례를 탐구하고 설명할 수 있다.", "topics": ["인공지능과 수학의 역사", "핵심 의미와 원리", "적용과 문제 해결", "탐구 설계와 수행"], "scopeNotes": ["지도학습·비지도학습·강화학습과 퍼셉트론은 개념 중심으로 다룬다.", "빅데이터 활용에서 편향과 공정성을 함께 고려한다."], "visualizationIdeas": ["퍼셉트론의 입력·가중치·활성화 결과가 흐르는 네트워크 애니메이션", "OR·AND·XOR의 결정 영역과 단층·다층 구조 비교", "데이터 표본의 편향이 예측 결과의 편향으로 이어지는 시뮬레이션"] }, { "id": "ai-math-01-03", "order": 3, "title": "빅데이터와 인공지능", "standardCode": "12인수01-03", "achievementStandard": "빅데이터의 개념과 특성을 알고 인공지능에서 빅데이터를 활용한 사례를 찾을 수 있다.", "topics": ["빅데이터와 인공지능", "핵심 의미와 원리", "적용과 문제 해결"], "scopeNotes": ["지도학습·비지도학습·강화학습과 퍼셉트론은 개념 중심으로 다룬다.", "빅데이터 활용에서 편향과 공정성을 함께 고려한다."], "visualizationIdeas": ["퍼셉트론의 입력·가중치·활성화 결과가 흐르는 네트워크 애니메이션", "OR·AND·XOR의 결정 영역과 단층·다층 구조 비교", "데이터 표본의 편향이 예측 결과의 편향으로 이어지는 시뮬레이션"] }], "conceptCount": 3 }, { "id": "text-data-processing", "title": "텍스트 데이터 처리", "order": 2, "concepts": [{ "id": "ai-math-02-01", "order": 1, "title": "텍스트의 집합·벡터 표현", "standardCode": "12인수02-01", "achievementStandard": "집합과 벡터를 이용하여 텍스트 데이터를 목적에 맞게 표현할 수 있다.", "topics": ["텍스트의 집합·벡터 표현", "수학적 표현과 해석"], "scopeNotes": ["수학 이론 자체보다 인공지능에서의 활용을 중심으로 다룬다.", "코사인 유사도에서 내적 관련 용어와 기호는 사용하지 않는다.", "대수 이수자는 로그를 이용한 역문서빈도 표현을 선택적으로 다룰 수 있다."], "visualizationIdeas": ["문장이 단어 집합과 빈도 벡터로 변환되는 토큰 애니메이션", "문서빈도에 따라 단어의 TF-IDF 가중치가 변하는 막대그래프", "텍스트 벡터 사이 거리와 유사도를 2차원 공간에서 비교"] }, { "id": "ai-math-02-02", "order": 2, "title": "단어가방과 TF-IDF", "standardCode": "12인수02-02", "achievementStandard": "빈도수 벡터를 이용하여 텍스트 데이터를 요약하고 유용한 정보를 추출할 수 있다.", "topics": ["단어가방과 TF-IDF", "수학적 표현과 해석"], "scopeNotes": ["수학 이론 자체보다 인공지능에서의 활용을 중심으로 다룬다.", "코사인 유사도에서 내적 관련 용어와 기호는 사용하지 않는다.", "대수 이수자는 로그를 이용한 역문서빈도 표현을 선택적으로 다룰 수 있다."], "visualizationIdeas": ["문장이 단어 집합과 빈도 벡터로 변환되는 토큰 애니메이션", "문서빈도에 따라 단어의 TF-IDF 가중치가 변하는 막대그래프", "텍스트 벡터 사이 거리와 유사도를 2차원 공간에서 비교"] }, { "id": "ai-math-02-03", "order": 3, "title": "텍스트 유사도와 감성 분석", "standardCode": "12인수02-03", "achievementStandard": "인공지능이 텍스트를 특성에 따라 분석하는 수학적 방법을 설명할 수 있다.", "topics": ["텍스트 유사도와 감성 분석", "핵심 의미와 원리", "탐구 설계와 수행"], "scopeNotes": ["수학 이론 자체보다 인공지능에서의 활용을 중심으로 다룬다.", "코사인 유사도에서 내적 관련 용어와 기호는 사용하지 않는다.", "대수 이수자는 로그를 이용한 역문서빈도 표현을 선택적으로 다룰 수 있다."], "visualizationIdeas": ["문장이 단어 집합과 빈도 벡터로 변환되는 토큰 애니메이션", "문서빈도에 따라 단어의 TF-IDF 가중치가 변하는 막대그래프", "텍스트 벡터 사이 거리와 유사도를 2차원 공간에서 비교"] }], "conceptCount": 3 }, { "id": "image-data-processing", "title": "이미지 데이터 처리", "order": 3, "concepts": [{ "id": "ai-math-03-01", "order": 1, "title": "이미지의 행렬 표현", "standardCode": "12인수03-01", "achievementStandard": "행렬을 이용하여 이미지 데이터를 목적에 맞게 표현할 수 있다.", "topics": ["이미지의 행렬 표현", "수학적 표현과 해석"], "scopeNotes": ["픽셀 위치와 RGB 정보를 행렬로 표현한다.", "행렬 연산을 이용한 이미지 변환에서 회전변환은 다루지 않는다."], "visualizationIdeas": ["이미지를 확대해 픽셀 RGB 행렬로 변환", "행렬값 변화가 밝기·대비·선명도에 미치는 효과를 실시간 비교", "두 이미지의 픽셀 차이가 해밍 거리로 누적되는 장면"] }, { "id": "ai-math-03-02", "order": 2, "title": "행렬을 이용한 이미지 변환", "standardCode": "12인수03-02", "achievementStandard": "행렬의 연산을 이용하여 이미지 데이터를 다양하게 변환할 수 있다.", "topics": ["행렬을 이용한 이미지 변환", "계산 방법과 절차", "수학적 표현과 해석"], "scopeNotes": ["픽셀 위치와 RGB 정보를 행렬로 표현한다.", "행렬 연산을 이용한 이미지 변환에서 회전변환은 다루지 않는다."], "visualizationIdeas": ["이미지를 확대해 픽셀 RGB 행렬로 변환", "행렬값 변화가 밝기·대비·선명도에 미치는 효과를 실시간 비교", "두 이미지의 픽셀 차이가 해밍 거리로 누적되는 장면"] }, { "id": "ai-math-03-03", "order": 3, "title": "이미지 분류와 유사도", "standardCode": "12인수03-03", "achievementStandard": "인공지능이 이미지를 자동으로 분류하는 수학적 방법을 설명할 수 있다.", "topics": ["이미지 분류와 유사도", "핵심 의미와 원리"], "scopeNotes": ["픽셀 위치와 RGB 정보를 행렬로 표현한다.", "행렬 연산을 이용한 이미지 변환에서 회전변환은 다루지 않는다."], "visualizationIdeas": ["이미지를 확대해 픽셀 RGB 행렬로 변환", "행렬값 변화가 밝기·대비·선명도에 미치는 효과를 실시간 비교", "두 이미지의 픽셀 차이가 해밍 거리로 누적되는 장면"] }], "conceptCount": 3 }, { "id": "prediction-and-optimization", "title": "예측과 최적화", "order": 4, "concepts": [{ "id": "ai-math-04-01", "order": 1, "title": "데이터와 확률 예측", "standardCode": "12인수04-01", "achievementStandard": "데이터를 분석하여 사건이 일어날 확률을 구하고 이를 예측에 이용할 수 있다.", "topics": ["데이터와 확률 예측", "적용과 문제 해결", "탐구 설계와 수행"], "scopeNotes": ["확률 계산은 상대도수를 활용하고 조건부확률 용어와 기호는 다루지 않는다.", "손실함수는 일변수함수로 정의된 간단한 경우를 다룬다.", "극한과 미분계수는 경사하강법 이해에 필요한 직관적 수준으로 다룬다."], "visualizationIdeas": ["여러 추세선의 잔차를 선분으로 표시하고 손실값 비교", "손실함수 곡면 위 점이 기울기 반대 방향으로 최솟값에 이동", "학습률에 따라 수렴·진동·발산하는 경사하강 경로 비교"] }, { "id": "ai-math-04-02", "order": 2, "title": "추세선과 예측", "standardCode": "12인수04-02", "achievementStandard": "공학 도구를 사용하여 데이터의 경향성을 추세선으로 나타내고 이를 예측에 이용할 수 있다.", "topics": ["추세선과 예측", "적용과 문제 해결"], "scopeNotes": ["확률 계산은 상대도수를 활용하고 조건부확률 용어와 기호는 다루지 않는다.", "손실함수는 일변수함수로 정의된 간단한 경우를 다룬다.", "극한과 미분계수는 경사하강법 이해에 필요한 직관적 수준으로 다룬다."], "visualizationIdeas": ["여러 추세선의 잔차를 선분으로 표시하고 손실값 비교", "손실함수 곡면 위 점이 기울기 반대 방향으로 최솟값에 이동", "학습률에 따라 수렴·진동·발산하는 경사하강 경로 비교"] }, { "id": "ai-math-04-03", "order": 3, "title": "손실함수", "standardCode": "12인수04-03", "achievementStandard": "손실함수를 이해하고 최적화된 추세선을 찾을 수 있다.", "topics": ["손실함수", "핵심 의미와 원리"], "scopeNotes": ["확률 계산은 상대도수를 활용하고 조건부확률 용어와 기호는 다루지 않는다.", "손실함수는 일변수함수로 정의된 간단한 경우를 다룬다.", "극한과 미분계수는 경사하강법 이해에 필요한 직관적 수준으로 다룬다."], "visualizationIdeas": ["여러 추세선의 잔차를 선분으로 표시하고 손실값 비교", "손실함수 곡면 위 점이 기울기 반대 방향으로 최솟값에 이동", "학습률에 따라 수렴·진동·발산하는 경사하강 경로 비교"] }, { "id": "ai-math-04-04", "order": 4, "title": "경사하강법", "standardCode": "12인수04-04", "achievementStandard": "경사하강법을 이해하고 최적화된 예측을 위한 인공지능의 학습 방법을 설명할 수 있다.", "topics": ["경사하강법", "핵심 의미와 원리", "적용과 문제 해결"], "scopeNotes": ["확률 계산은 상대도수를 활용하고 조건부확률 용어와 기호는 다루지 않는다.", "손실함수는 일변수함수로 정의된 간단한 경우를 다룬다.", "극한과 미분계수는 경사하강법 이해에 필요한 직관적 수준으로 다룬다."], "visualizationIdeas": ["여러 추세선의 잔차를 선분으로 표시하고 손실값 비교", "손실함수 곡면 위 점이 기울기 반대 방향으로 최솟값에 이동", "학습률에 따라 수렴·진동·발산하는 경사하강 경로 비교"] }], "conceptCount": 4 }, { "id": "ai-math-inquiry", "title": "인공지능과 수학 탐구", "order": 5, "concepts": [{ "id": "ai-math-05-01", "order": 1, "title": "인공지능의 합리적 의사 결정", "standardCode": "12인수05-01", "achievementStandard": "수학적 원리를 이용하여 인공지능이 실생활 문제를 합리적으로 해결하는 사례를 찾을 수 있다.", "topics": ["인공지능의 합리적 의사 결정", "적용과 문제 해결"], "scopeNotes": ["인공지능 의사 결정의 효율성과 함께 윤리성과 공정성을 판단한다.", "환경·생태·지속가능발전과 관련된 탐구를 수행할 수 있다."], "visualizationIdeas": ["같은 데이터에서 목표함수에 따라 다른 의사 결정이 나오는 비교", "탐구 질문→데이터→수학적 모델→결론의 프로젝트 흐름도"] }, { "id": "ai-math-05-02", "order": 2, "title": "인공지능 수학 주제 탐구", "standardCode": "12인수05-02", "achievementStandard": "인공지능과 관련된 수학 주제를 선정하여 탐구할 수 있다.", "topics": ["인공지능 수학 주제 탐구", "계산 방법과 절차", "탐구 설계와 수행"], "scopeNotes": ["인공지능 의사 결정의 효율성과 함께 윤리성과 공정성을 판단한다.", "환경·생태·지속가능발전과 관련된 탐구를 수행할 수 있다."], "visualizationIdeas": ["같은 데이터에서 목표함수에 따라 다른 의사 결정이 나오는 비교", "탐구 질문→데이터→수학적 모델→결론의 프로젝트 흐름도"] }], "conceptCount": 2 }], "categoryEnglishTitle": "CAREER ELECTIVE", "categoryDescription": "관심 분야와 진로에 따라 깊이 있게 학습하는 과목입니다.", "categoryOrder": 3, "placementLabel": "학교별 개설·편성", "sourceFile": "kr-2022-ai-math.yaml", "developmentLocked": true }, { "id": "vocational-math", "officialTitle": "직무 수학", "category": "career-elective", "categoryTitle": "진로 선택", "recommendedGrades": [11, 12], "prerequisites": [], "defaultSemester": "school-defined", "conceptCount": 18, "units": [{ "id": "numbers-and-operations", "title": "수와 연산", "order": 1, "concepts": [{ "id": "vocational-math-01-01", "order": 1, "title": "직무와 사칙연산", "standardCode": "12직수01-01", "achievementStandard": "직무 상황에서 수 개념과 사칙연산의 문제를 해결하고 그 유용성을 인식할 수 있다.", "topics": ["직무와 사칙연산", "핵심 의미와 원리", "계산 방법과 절차", "적용과 문제 해결"], "scopeNotes": ["직무 상황의 실제 문제 해결에 중점을 두고 필요한 경우 공학 도구를 사용한다.", "국제단위계 외 단위와 국가 간 시차를 실제 자료와 연결할 수 있다."], "visualizationIdeas": ["예산·비용 항목이 사칙연산으로 합쳐지는 직무 영수증 시뮬레이션", "올림·버림·반올림에 따른 견적 차이 비교", "단위 블록의 크기가 환산 비율에 따라 바뀌는 애니메이션"] }, { "id": "vocational-math-01-02", "order": 2, "title": "큰 수와 어림", "standardCode": "12직수01-02", "achievementStandard": "큰 수를 어림하여 문제를 해결하고, 어림값을 이용하여 수의 크기를 비교할 수 있다.", "topics": ["큰 수와 어림", "적용과 문제 해결"], "scopeNotes": ["직무 상황의 실제 문제 해결에 중점을 두고 필요한 경우 공학 도구를 사용한다.", "국제단위계 외 단위와 국가 간 시차를 실제 자료와 연결할 수 있다."], "visualizationIdeas": ["예산·비용 항목이 사칙연산으로 합쳐지는 직무 영수증 시뮬레이션", "올림·버림·반올림에 따른 견적 차이 비교", "단위 블록의 크기가 환산 비율에 따라 바뀌는 애니메이션"] }, { "id": "vocational-math-01-03", "order": 3, "title": "표준 단위와 단위 환산", "standardCode": "12직수01-03", "achievementStandard": "시간, 길이, 무게, 들이의 표준 단위를 알고, 단위를 환산할 수 있다.", "topics": ["표준 단위와 단위 환산", "수학적 표현과 해석"], "scopeNotes": ["직무 상황의 실제 문제 해결에 중점을 두고 필요한 경우 공학 도구를 사용한다.", "국제단위계 외 단위와 국가 간 시차를 실제 자료와 연결할 수 있다."], "visualizationIdeas": ["예산·비용 항목이 사칙연산으로 합쳐지는 직무 영수증 시뮬레이션", "올림·버림·반올림에 따른 견적 차이 비교", "단위 블록의 크기가 환산 비율에 따라 바뀌는 애니메이션"] }], "conceptCount": 3 }, { "id": "change-and-relationships", "title": "변화와 관계", "order": 2, "concepts": [{ "id": "vocational-math-02-01", "order": 1, "title": "비와 비례식", "standardCode": "12직수02-01", "achievementStandard": "비의 개념을 직무 상황에 연결하여 적용할 수 있다.", "topics": ["비와 비례식", "핵심 의미와 원리", "적용과 문제 해결"], "scopeNotes": ["개념과 절차 자체보다 직무 상황에 적용하는 데 중점을 둔다.", "요율·매출·판매량 자료를 근거로 합리적 의사 결정을 하게 한다."], "visualizationIdeas": ["단가·환율·할인율이 실제 금액에 적용되는 계산 흐름", "요율표의 구간을 그래프와 연결해 대응 관계 표시", "비용 조건을 일차부등식 영역으로 바꾸어 가능한 선택 비교"] }, { "id": "vocational-math-02-02", "order": 2, "title": "비율과 백분율", "standardCode": "12직수02-02", "achievementStandard": "비율을 백분율로 표현할 수 있고 직무 상황에 연결하여 적용할 수 있다.", "topics": ["비율과 백분율", "수학적 표현과 해석", "적용과 문제 해결"], "scopeNotes": ["개념과 절차 자체보다 직무 상황에 적용하는 데 중점을 둔다.", "요율·매출·판매량 자료를 근거로 합리적 의사 결정을 하게 한다."], "visualizationIdeas": ["단가·환율·할인율이 실제 금액에 적용되는 계산 흐름", "요율표의 구간을 그래프와 연결해 대응 관계 표시", "비용 조건을 일차부등식 영역으로 바꾸어 가능한 선택 비교"] }, { "id": "vocational-math-02-03", "order": 3, "title": "대응 관계와 요율표", "standardCode": "12직수02-03", "achievementStandard": "두 양 사이의 대응 관계를 나타낸 표에서 규칙을 찾아 설명할 수 있다.", "topics": ["대응 관계와 요율표", "핵심 의미와 원리", "수학적 표현과 해석"], "scopeNotes": ["개념과 절차 자체보다 직무 상황에 적용하는 데 중점을 둔다.", "요율·매출·판매량 자료를 근거로 합리적 의사 결정을 하게 한다."], "visualizationIdeas": ["단가·환율·할인율이 실제 금액에 적용되는 계산 흐름", "요율표의 구간을 그래프와 연결해 대응 관계 표시", "비용 조건을 일차부등식 영역으로 바꾸어 가능한 선택 비교"] }, { "id": "vocational-math-02-04", "order": 4, "title": "변화 그래프", "standardCode": "12직수02-04", "achievementStandard": "증가와 감소, 주기적 변화 등의 관계를 나타내는 그래프를 설명할 수 있다.", "topics": ["변화 그래프", "핵심 의미와 원리", "수학적 표현과 해석"], "scopeNotes": ["개념과 절차 자체보다 직무 상황에 적용하는 데 중점을 둔다.", "요율·매출·판매량 자료를 근거로 합리적 의사 결정을 하게 한다."], "visualizationIdeas": ["단가·환율·할인율이 실제 금액에 적용되는 계산 흐름", "요율표의 구간을 그래프와 연결해 대응 관계 표시", "비용 조건을 일차부등식 영역으로 바꾸어 가능한 선택 비교"] }, { "id": "vocational-math-02-05", "order": 5, "title": "직무와 일차방정식·부등식", "standardCode": "12직수02-05", "achievementStandard": "일차방정식 또는 일차부등식을 활용하여 직무 상황의 문제를 해결할 수 있다.", "topics": ["직무와 일차방정식·부등식", "수학적 표현과 해석", "적용과 문제 해결"], "scopeNotes": ["개념과 절차 자체보다 직무 상황에 적용하는 데 중점을 둔다.", "요율·매출·판매량 자료를 근거로 합리적 의사 결정을 하게 한다."], "visualizationIdeas": ["단가·환율·할인율이 실제 금액에 적용되는 계산 흐름", "요율표의 구간을 그래프와 연결해 대응 관계 표시", "비용 조건을 일차부등식 영역으로 바꾸어 가능한 선택 비교"] }], "conceptCount": 5 }, { "id": "geometry-and-measurement", "title": "도형과 측정", "order": 3, "concepts": [{ "id": "vocational-math-03-01", "order": 1, "title": "겨냥도와 전개도", "standardCode": "12직수03-01", "achievementStandard": "입체도형의 겨냥도와 전개도를 그릴 수 있고, 이를 이용하여 입체도형의 모양을 만들 수 있다.", "topics": ["겨냥도와 전개도", "핵심 관계"], "scopeNotes": ["도형의 이동·합동·닮음은 제품 설계와 배치 등 직무 상황에 적용한다.", "겉넓이와 부피는 포장·보관·운송 상황과 연결한다."], "visualizationIdeas": ["상자를 펼쳐 전개도로 만들고 다시 접는 3차원 애니메이션", "물체를 회전하며 위·앞·옆 모습과 동기화", "포장재 크기와 용량을 바꾸며 겉넓이·부피의 변화 비교"] }, { "id": "vocational-math-03-02", "order": 2, "title": "여러 방향에서 본 모양", "standardCode": "12직수03-02", "achievementStandard": "입체도형을 위, 앞, 옆에서 본 모양으로 표현하고, 이러한 표현을 보고 입체도형의 모양을 판별할 수 있다.", "topics": ["여러 방향에서 본 모양", "수학적 표현과 해석"], "scopeNotes": ["도형의 이동·합동·닮음은 제품 설계와 배치 등 직무 상황에 적용한다.", "겉넓이와 부피는 포장·보관·운송 상황과 연결한다."], "visualizationIdeas": ["상자를 펼쳐 전개도로 만들고 다시 접는 3차원 애니메이션", "물체를 회전하며 위·앞·옆 모습과 동기화", "포장재 크기와 용량을 바꾸며 겉넓이·부피의 변화 비교"] }, { "id": "vocational-math-03-03", "order": 3, "title": "도형의 이동·합동·닮음", "standardCode": "12직수03-03", "achievementStandard": "도형의 이동, 합동과 닮음을 직무 상황에 연결하여 문제를 해결할 수 있다.", "topics": ["도형의 이동·합동·닮음", "적용과 문제 해결"], "scopeNotes": ["도형의 이동·합동·닮음은 제품 설계와 배치 등 직무 상황에 적용한다.", "겉넓이와 부피는 포장·보관·운송 상황과 연결한다."], "visualizationIdeas": ["상자를 펼쳐 전개도로 만들고 다시 접는 3차원 애니메이션", "물체를 회전하며 위·앞·옆 모습과 동기화", "포장재 크기와 용량을 바꾸며 겉넓이·부피의 변화 비교"] }, { "id": "vocational-math-03-04", "order": 4, "title": "평면도형의 둘레와 넓이", "standardCode": "12직수03-04", "achievementStandard": "직무 상황에서 나타나는 평면도형의 둘레와 넓이를 구할 수 있다.", "topics": ["평면도형의 둘레와 넓이", "계산 방법과 절차", "적용과 문제 해결"], "scopeNotes": ["도형의 이동·합동·닮음은 제품 설계와 배치 등 직무 상황에 적용한다.", "겉넓이와 부피는 포장·보관·운송 상황과 연결한다."], "visualizationIdeas": ["상자를 펼쳐 전개도로 만들고 다시 접는 3차원 애니메이션", "물체를 회전하며 위·앞·옆 모습과 동기화", "포장재 크기와 용량을 바꾸며 겉넓이·부피의 변화 비교"] }, { "id": "vocational-math-03-05", "order": 5, "title": "입체도형의 겉넓이와 부피", "standardCode": "12직수03-05", "achievementStandard": "직무 상황에서 나타나는 입체도형의 겉넓이와 부피를 구할 수 있다.", "topics": ["입체도형의 겉넓이와 부피", "계산 방법과 절차", "적용과 문제 해결"], "scopeNotes": ["도형의 이동·합동·닮음은 제품 설계와 배치 등 직무 상황에 적용한다.", "겉넓이와 부피는 포장·보관·운송 상황과 연결한다."], "visualizationIdeas": ["상자를 펼쳐 전개도로 만들고 다시 접는 3차원 애니메이션", "물체를 회전하며 위·앞·옆 모습과 동기화", "포장재 크기와 용량을 바꾸며 겉넓이·부피의 변화 비교"] }], "conceptCount": 5 }, { "id": "data-and-chance", "title": "자료와 가능성", "order": 4, "concepts": [{ "id": "vocational-math-04-01", "order": 1, "title": "직무 상황의 경우의 수", "standardCode": "12직수04-01", "achievementStandard": "직무 상황에서 경우의 수를 구할 수 있다.", "topics": ["직무 상황의 경우의 수", "계산 방법과 절차", "적용과 문제 해결"], "scopeNotes": ["가능성은 실제 자료를 근거로 파악하고 해석하는 데 중점을 둔다.", "그림그래프·선그래프·비율그래프·방사형그래프·산점도 등을 다양하게 활용한다."], "visualizationIdeas": ["상품 구성과 좌석 배치를 드래그하며 가능한 조합 수 계산", "여러 표를 하나의 표와 그래프로 통합하는 변환", "같은 데이터를 서로 다른 그래프로 표현해 해석 차이 비교"] }, { "id": "vocational-math-04-02", "order": 2, "title": "가능성의 수치화", "standardCode": "12직수04-02", "achievementStandard": "어떤 현상이 나타날 가능성을 수치화하여 설명할 수 있다.", "topics": ["가능성의 수치화", "핵심 의미와 원리"], "scopeNotes": ["가능성은 실제 자료를 근거로 파악하고 해석하는 데 중점을 둔다.", "그림그래프·선그래프·비율그래프·방사형그래프·산점도 등을 다양하게 활용한다."], "visualizationIdeas": ["상품 구성과 좌석 배치를 드래그하며 가능한 조합 수 계산", "여러 표를 하나의 표와 그래프로 통합하는 변환", "같은 데이터를 서로 다른 그래프로 표현해 해석 차이 비교"] }, { "id": "vocational-math-04-03", "order": 3, "title": "표와 그래프의 정리", "standardCode": "12직수04-03", "achievementStandard": "직무 상황의 자료를 목적에 맞게 표와 그래프로 정리할 수 있다.", "topics": ["표와 그래프의 정리", "수학적 표현과 해석", "적용과 문제 해결"], "scopeNotes": ["가능성은 실제 자료를 근거로 파악하고 해석하는 데 중점을 둔다.", "그림그래프·선그래프·비율그래프·방사형그래프·산점도 등을 다양하게 활용한다."], "visualizationIdeas": ["상품 구성과 좌석 배치를 드래그하며 가능한 조합 수 계산", "여러 표를 하나의 표와 그래프로 통합하는 변환", "같은 데이터를 서로 다른 그래프로 표현해 해석 차이 비교"] }, { "id": "vocational-math-04-04", "order": 4, "title": "표와 그래프의 해석", "standardCode": "12직수04-04", "achievementStandard": "직무 상황의 다양한 표와 그래프를 해석할 수 있다.", "topics": ["표와 그래프의 해석", "수학적 표현과 해석", "적용과 문제 해결"], "scopeNotes": ["가능성은 실제 자료를 근거로 파악하고 해석하는 데 중점을 둔다.", "그림그래프·선그래프·비율그래프·방사형그래프·산점도 등을 다양하게 활용한다."], "visualizationIdeas": ["상품 구성과 좌석 배치를 드래그하며 가능한 조합 수 계산", "여러 표를 하나의 표와 그래프로 통합하는 변환", "같은 데이터를 서로 다른 그래프로 표현해 해석 차이 비교"] }, { "id": "vocational-math-04-05", "order": 5, "title": "자료 기반 의사 결정", "standardCode": "12직수04-05", "achievementStandard": "다양한 자료의 특성을 파악하여, 직무 목적에 적합한 표나 그래프로 나타내고 합리적인 의사 결정을 할 수 있다.", "topics": ["자료 기반 의사 결정", "수학적 표현과 해석", "적용과 문제 해결"], "scopeNotes": ["가능성은 실제 자료를 근거로 파악하고 해석하는 데 중점을 둔다.", "그림그래프·선그래프·비율그래프·방사형그래프·산점도 등을 다양하게 활용한다."], "visualizationIdeas": ["상품 구성과 좌석 배치를 드래그하며 가능한 조합 수 계산", "여러 표를 하나의 표와 그래프로 통합하는 변환", "같은 데이터를 서로 다른 그래프로 표현해 해석 차이 비교"] }], "conceptCount": 5 }], "categoryEnglishTitle": "CAREER ELECTIVE", "categoryDescription": "관심 분야와 진로에 따라 깊이 있게 학습하는 과목입니다.", "categoryOrder": 3, "placementLabel": "학교별 개설·편성", "sourceFile": "kr-2022-vocational-math.yaml", "developmentLocked": true }, { "id": "math-and-culture", "officialTitle": "수학과 문화", "category": "convergence-elective", "categoryTitle": "융합 선택", "recommendedGrades": [11, 12], "prerequisites": [], "defaultSemester": "school-defined", "conceptCount": 16, "units": [{ "id": "art-and-mathematics", "title": "예술과 수학", "order": 1, "concepts": [{ "id": "math-and-culture-01-01", "order": 1, "title": "음악과 수학", "standardCode": "12수문01-01", "achievementStandard": "음악과 관련된 수학적 내용을 조사하고, 관련 활동을 수행할 수 있다.", "topics": ["음악과 수학", "탐구 설계와 수행"], "scopeNotes": ["예술 속 수학의 아름다움과 유용성을 탐구하고 창작 활동으로 연결한다.", "자료와 작품을 활용할 때 출처를 명확히 밝힌다."], "visualizationIdeas": ["현의 길이 비와 음정이 파형·주파수로 연결되는 애니메이션", "원근법·황금비·쪽매맞춤을 작품 위 가이드로 중첩", "문학·영상의 수학적 구조를 장면 지도와 패턴으로 표현"] }, { "id": "math-and-culture-01-02", "order": 2, "title": "미술·사진과 수학", "standardCode": "12수문01-02", "achievementStandard": "미술과 관련된 수학적 내용을 조사하고, 관련 활동을 수행할 수 있다.", "topics": ["미술·사진과 수학", "탐구 설계와 수행"], "scopeNotes": ["예술 속 수학의 아름다움과 유용성을 탐구하고 창작 활동으로 연결한다.", "자료와 작품을 활용할 때 출처를 명확히 밝힌다."], "visualizationIdeas": ["현의 길이 비와 음정이 파형·주파수로 연결되는 애니메이션", "원근법·황금비·쪽매맞춤을 작품 위 가이드로 중첩", "문학·영상의 수학적 구조를 장면 지도와 패턴으로 표현"] }, { "id": "math-and-culture-01-03", "order": 3, "title": "문학과 수학", "standardCode": "12수문01-03", "achievementStandard": "문학과 관련된 수학적 내용을 조사하고, 관련 활동을 수행할 수 있다.", "topics": ["문학과 수학", "탐구 설계와 수행"], "scopeNotes": ["예술 속 수학의 아름다움과 유용성을 탐구하고 창작 활동으로 연결한다.", "자료와 작품을 활용할 때 출처를 명확히 밝힌다."], "visualizationIdeas": ["현의 길이 비와 음정이 파형·주파수로 연결되는 애니메이션", "원근법·황금비·쪽매맞춤을 작품 위 가이드로 중첩", "문학·영상의 수학적 구조를 장면 지도와 패턴으로 표현"] }, { "id": "math-and-culture-01-04", "order": 4, "title": "영화와 수학", "standardCode": "12수문01-04", "achievementStandard": "영화와 관련된 수학적 내용을 조사하고, 관련 활동을 수행할 수 있다.", "topics": ["영화와 수학", "탐구 설계와 수행"], "scopeNotes": ["예술 속 수학의 아름다움과 유용성을 탐구하고 창작 활동으로 연결한다.", "자료와 작품을 활용할 때 출처를 명확히 밝힌다."], "visualizationIdeas": ["현의 길이 비와 음정이 파형·주파수로 연결되는 애니메이션", "원근법·황금비·쪽매맞춤을 작품 위 가이드로 중첩", "문학·영상의 수학적 구조를 장면 지도와 패턴으로 표현"] }], "conceptCount": 4 }, { "id": "leisure-and-mathematics", "title": "여가와 수학", "order": 2, "concepts": [{ "id": "math-and-culture-02-01", "order": 1, "title": "스포츠와 수학", "standardCode": "12수문02-01", "achievementStandard": "스포츠와 관련된 수학적 내용을 조사하여 그 유용성을 인식할 수 있다.", "topics": ["스포츠와 수학", "탐구 설계와 수행"], "scopeNotes": ["여가와 기술 속 수학적 원리를 조사하고 합리적 의사 결정과 공정성을 함께 탐구한다."], "visualizationIdeas": ["스포츠 궤적·각도·점수 산출을 실제 장면 위에 시각화", "게임 전략을 확률나무와 상태 전이로 표현", "서로 다른 투표 방식에서 결과가 달라지는 시뮬레이션"] }, { "id": "math-and-culture-02-02", "order": 2, "title": "게임과 수학", "standardCode": "12수문02-02", "achievementStandard": "게임과 관련된 수학적 내용을 조사하고 관련 활동을 수행할 수 있다.", "topics": ["게임과 수학", "탐구 설계와 수행"], "scopeNotes": ["여가와 기술 속 수학적 원리를 조사하고 합리적 의사 결정과 공정성을 함께 탐구한다."], "visualizationIdeas": ["스포츠 궤적·각도·점수 산출을 실제 장면 위에 시각화", "게임 전략을 확률나무와 상태 전이로 표현", "서로 다른 투표 방식에서 결과가 달라지는 시뮬레이션"] }, { "id": "math-and-culture-02-03", "order": 3, "title": "디지털 기술과 수학", "standardCode": "12수문02-03", "achievementStandard": "디지털 기술에 활용된 수학적 내용을 조사하여 설명할 수 있다.", "topics": ["디지털 기술과 수학", "핵심 의미와 원리", "적용과 문제 해결", "탐구 설계와 수행"], "scopeNotes": ["여가와 기술 속 수학적 원리를 조사하고 합리적 의사 결정과 공정성을 함께 탐구한다."], "visualizationIdeas": ["스포츠 궤적·각도·점수 산출을 실제 장면 위에 시각화", "게임 전략을 확률나무와 상태 전이로 표현", "서로 다른 투표 방식에서 결과가 달라지는 시뮬레이션"] }, { "id": "math-and-culture-02-04", "order": 4, "title": "투표와 수학", "standardCode": "12수문02-04", "achievementStandard": "투표와 관련된 수학적 내용을 조사하고 이를 활용하여 합리적 의사 결정을 위한 방법을 제안할 수 있다.", "topics": ["투표와 수학", "수학적 표현과 해석", "적용과 문제 해결", "탐구 설계와 수행"], "scopeNotes": ["여가와 기술 속 수학적 원리를 조사하고 합리적 의사 결정과 공정성을 함께 탐구한다."], "visualizationIdeas": ["스포츠 궤적·각도·점수 산출을 실제 장면 위에 시각화", "게임 전략을 확률나무와 상태 전이로 표현", "서로 다른 투표 방식에서 결과가 달라지는 시뮬레이션"] }], "conceptCount": 4 }, { "id": "society-and-mathematics", "title": "사회와 수학", "order": 3, "concepts": [{ "id": "math-and-culture-03-01", "order": 1, "title": "민속·건축과 수학", "standardCode": "12수문03-01", "achievementStandard": "민속 수학과 건축 양식 속에 나타난 수학적 원리에 대해 탐구하고 문화 다양성을 이해한다.", "topics": ["민속·건축과 수학", "핵심 의미와 원리", "탐구 설계와 수행"], "scopeNotes": ["문화 다양성과 사회적 소수자를 배려하는 공동체 관점을 포함한다.", "데이터 해석과 소비 의사 결정에서 다양한 가치와 관점을 비교한다."], "visualizationIdeas": ["문화권별 달력·건축 패턴의 수 체계와 대칭 비교", "점자 배열을 이진 패턴과 진법으로 변환", "대중매체 데이터가 워드클라우드와 빈도 그래프로 변하는 과정"] }, { "id": "math-and-culture-03-02", "order": 2, "title": "점자와 진법", "standardCode": "12수문03-02", "achievementStandard": "점자표에 사용된 수학적 원리에 대해 탐구하고 이를 활용하여 산출물을 설계할 수 있다.", "topics": ["점자와 진법", "수학적 표현과 해석", "적용과 문제 해결", "탐구 설계와 수행"], "scopeNotes": ["문화 다양성과 사회적 소수자를 배려하는 공동체 관점을 포함한다.", "데이터 해석과 소비 의사 결정에서 다양한 가치와 관점을 비교한다."], "visualizationIdeas": ["문화권별 달력·건축 패턴의 수 체계와 대칭 비교", "점자 배열을 이진 패턴과 진법으로 변환", "대중매체 데이터가 워드클라우드와 빈도 그래프로 변하는 과정"] }, { "id": "math-and-culture-03-03", "order": 3, "title": "대중매체 데이터", "standardCode": "12수문03-03", "achievementStandard": "대중매체로부터 얻은 데이터를 정리, 분석하여 그 의미와 가치를 해석할 수 있다.", "topics": ["대중매체 데이터", "핵심 의미와 원리", "탐구 설계와 수행"], "scopeNotes": ["문화 다양성과 사회적 소수자를 배려하는 공동체 관점을 포함한다.", "데이터 해석과 소비 의사 결정에서 다양한 가치와 관점을 비교한다."], "visualizationIdeas": ["문화권별 달력·건축 패턴의 수 체계와 대칭 비교", "점자 배열을 이진 패턴과 진법으로 변환", "대중매체 데이터가 워드클라우드와 빈도 그래프로 변하는 과정"] }, { "id": "math-and-culture-03-04", "order": 4, "title": "가치소비와 의사 결정", "standardCode": "12수문03-04", "achievementStandard": "가치소비를 위한 의사 결정 방법을 탐구하고 실천 방법을 제시할 수 있다.", "topics": ["가치소비와 의사 결정", "적용과 문제 해결", "탐구 설계와 수행"], "scopeNotes": ["문화 다양성과 사회적 소수자를 배려하는 공동체 관점을 포함한다.", "데이터 해석과 소비 의사 결정에서 다양한 가치와 관점을 비교한다."], "visualizationIdeas": ["문화권별 달력·건축 패턴의 수 체계와 대칭 비교", "점자 배열을 이진 패턴과 진법으로 변환", "대중매체 데이터가 워드클라우드와 빈도 그래프로 변하는 과정"] }], "conceptCount": 4 }, { "id": "environment-and-mathematics", "title": "환경과 수학", "order": 4, "concepts": [{ "id": "math-and-culture-04-01", "order": 1, "title": "식생활 문제의 수학적 분석", "standardCode": "12수문04-01", "achievementStandard": "식생활과 관련된 문제를 수학적으로 분석하고 이를 개선하기 위한 방법을 제안할 수 있다.", "topics": ["식생활 문제의 수학적 분석", "적용과 문제 해결", "탐구 설계와 수행"], "scopeNotes": ["환경 자료의 출처를 밝히고 공학 도구를 이용해 분석할 수 있다.", "분석 결과를 토대로 개선 방안과 실천을 함께 제안한다."], "visualizationIdeas": ["식단 영양·식량 자료를 비율과 그래프로 재구성", "탄소 배출과 기온 자료를 시간축·산점도·추세선으로 비교", "서식지 감소와 생물 다양성 변화를 지도와 그래프로 연결"] }, { "id": "math-and-culture-04-02", "order": 2, "title": "대기 오염의 수학적 분석", "standardCode": "12수문04-02", "achievementStandard": "대기 오염과 관련된 문제를 수학적으로 분석하고 이를 개선하기 위한 방법을 제안할 수 있다.", "topics": ["대기 오염의 수학적 분석", "적용과 문제 해결", "탐구 설계와 수행"], "scopeNotes": ["환경 자료의 출처를 밝히고 공학 도구를 이용해 분석할 수 있다.", "분석 결과를 토대로 개선 방안과 실천을 함께 제안한다."], "visualizationIdeas": ["식단 영양·식량 자료를 비율과 그래프로 재구성", "탄소 배출과 기온 자료를 시간축·산점도·추세선으로 비교", "서식지 감소와 생물 다양성 변화를 지도와 그래프로 연결"] }, { "id": "math-and-culture-04-03", "order": 3, "title": "사막화의 수학적 분석", "standardCode": "12수문04-03", "achievementStandard": "사막화 현상과 관련된 문제를 수학적으로 분석하고 이를 개선하기 위한 방법을 제안 할 수 있다.", "topics": ["사막화의 수학적 분석", "적용과 문제 해결", "탐구 설계와 수행"], "scopeNotes": ["환경 자료의 출처를 밝히고 공학 도구를 이용해 분석할 수 있다.", "분석 결과를 토대로 개선 방안과 실천을 함께 제안한다."], "visualizationIdeas": ["식단 영양·식량 자료를 비율과 그래프로 재구성", "탄소 배출과 기온 자료를 시간축·산점도·추세선으로 비교", "서식지 감소와 생물 다양성 변화를 지도와 그래프로 연결"] }, { "id": "math-and-culture-04-04", "order": 4, "title": "생물 다양성과 생명권", "standardCode": "12수문04-04", "achievementStandard": "생물 다양성과 생명권 관련 자료를 수학적으로 분석하고 이를 통해 생태 감수성을 함양할 수 있다.", "topics": ["생물 다양성과 생명권", "탐구 설계와 수행"], "scopeNotes": ["환경 자료의 출처를 밝히고 공학 도구를 이용해 분석할 수 있다.", "분석 결과를 토대로 개선 방안과 실천을 함께 제안한다."], "visualizationIdeas": ["식단 영양·식량 자료를 비율과 그래프로 재구성", "탄소 배출과 기온 자료를 시간축·산점도·추세선으로 비교", "서식지 감소와 생물 다양성 변화를 지도와 그래프로 연결"] }], "conceptCount": 4 }], "categoryEnglishTitle": "CONVERGENCE ELECTIVE", "categoryDescription": "수학을 문화, 통계, 탐구 활동과 연결하는 과목입니다.", "categoryOrder": 4, "placementLabel": "학교별 개설·편성", "sourceFile": "kr-2022-math-and-culture.yaml", "developmentLocked": true }, { "id": "practical-statistics", "officialTitle": "실용 통계", "category": "convergence-elective", "categoryTitle": "융합 선택", "recommendedGrades": [11, 12], "prerequisites": ["common-math-1", "common-math-2"], "defaultSemester": "school-defined", "conceptCount": 13, "units": [{ "id": "statistics-and-statistical-problems", "title": "통계와 통계적 문제", "order": 1, "concepts": [{ "id": "practical-statistics-01-01", "order": 1, "title": "통계의 유용성과 필요성", "standardCode": "12실통01-01", "achievementStandard": "통계와 통계적 방법의 유용성과 필요성을 인식할 수 있다.", "topics": ["통계의 유용성과 필요성", "핵심 관계"], "scopeNotes": ["불확실성과 변이성을 고려해 통계적으로 해결 가능한 문제를 구분한다.", "전수조사와 표본조사, 대표적인 확률표출 방법을 사례 중심으로 다룬다."], "visualizationIdeas": ["같은 현상에서 반복 측정값이 흩어지는 변이성 시뮬레이션", "모집단에서 서로 다른 방법으로 표본을 뽑아 편향 비교", "문제 설정부터 결론까지 통계적 문제 해결 순환 과정 표현"] }, { "id": "practical-statistics-01-02", "order": 2, "title": "통계적 문제 해결 과정", "standardCode": "12실통01-02", "achievementStandard": "통계적 문제해결 과정을 이해하고 각 단계의 역할을 설명할 수 있다.", "topics": ["통계적 문제 해결 과정", "핵심 의미와 원리", "적용과 문제 해결"], "scopeNotes": ["불확실성과 변이성을 고려해 통계적으로 해결 가능한 문제를 구분한다.", "전수조사와 표본조사, 대표적인 확률표출 방법을 사례 중심으로 다룬다."], "visualizationIdeas": ["같은 현상에서 반복 측정값이 흩어지는 변이성 시뮬레이션", "모집단에서 서로 다른 방법으로 표본을 뽑아 편향 비교", "문제 설정부터 결론까지 통계적 문제 해결 순환 과정 표현"] }, { "id": "practical-statistics-01-03", "order": 3, "title": "모집단·표본과 표본추출", "standardCode": "12실통01-03", "achievementStandard": "모집단과 표본의 뜻을 알고, 표본추출의 방법을 이해하여 문제 상황에 맞는 방법을 선택할 수 있다.", "topics": ["모집단·표본과 표본추출", "핵심 의미와 원리", "수학적 표현과 해석", "적용과 문제 해결"], "scopeNotes": ["불확실성과 변이성을 고려해 통계적으로 해결 가능한 문제를 구분한다.", "전수조사와 표본조사, 대표적인 확률표출 방법을 사례 중심으로 다룬다."], "visualizationIdeas": ["같은 현상에서 반복 측정값이 흩어지는 변이성 시뮬레이션", "모집단에서 서로 다른 방법으로 표본을 뽑아 편향 비교", "문제 설정부터 결론까지 통계적 문제 해결 순환 과정 표현"] }], "conceptCount": 3 }, { "id": "data-collection-and-organization", "title": "자료의 수집과 정리", "order": 2, "concepts": [{ "id": "practical-statistics-02-01", "order": 1, "title": "자료의 종류와 척도", "standardCode": "12실통02-01", "achievementStandard": "자료의 종류를 알고 설명할 수 있다.", "topics": ["자료의 종류와 척도", "핵심 의미와 원리"], "scopeNotes": ["계산이나 그래프 작성 자체보다 결과 해석에 중점을 둔다.", "자료 수집과 시각화 과정에서 오류와 편향을 비판적으로 검토한다."], "visualizationIdeas": ["범주형·수치형 자료와 네 가지 척도를 카드 분류 방식으로 비교", "동일 자료를 여러 그래프로 바꾸며 적합성과 왜곡 가능성 비교", "자료점 이동에 따라 평균·중앙값·표준편차가 변하는 인터랙션"] }, { "id": "practical-statistics-02-02", "order": 2, "title": "자료 수집 방법", "standardCode": "12실통02-02", "achievementStandard": "자료의 수집 방법을 이해하고 문제 상황에 맞는 자료 수집 방법을 선택할 수 있다.", "topics": ["자료 수집 방법", "핵심 의미와 원리", "적용과 문제 해결"], "scopeNotes": ["계산이나 그래프 작성 자체보다 결과 해석에 중점을 둔다.", "자료 수집과 시각화 과정에서 오류와 편향을 비판적으로 검토한다."], "visualizationIdeas": ["범주형·수치형 자료와 네 가지 척도를 카드 분류 방식으로 비교", "동일 자료를 여러 그래프로 바꾸며 적합성과 왜곡 가능성 비교", "자료점 이동에 따라 평균·중앙값·표준편차가 변하는 인터랙션"] }, { "id": "practical-statistics-02-03", "order": 3, "title": "자료와 그래프", "standardCode": "12실통02-03", "achievementStandard": "그래프의 종류를 알고 자료의 특성을 나타내는 적절한 그래프를 그릴 수 있다.", "topics": ["자료와 그래프", "수학적 표현과 해석"], "scopeNotes": ["계산이나 그래프 작성 자체보다 결과 해석에 중점을 둔다.", "자료 수집과 시각화 과정에서 오류와 편향을 비판적으로 검토한다."], "visualizationIdeas": ["범주형·수치형 자료와 네 가지 척도를 카드 분류 방식으로 비교", "동일 자료를 여러 그래프로 바꾸며 적합성과 왜곡 가능성 비교", "자료점 이동에 따라 평균·중앙값·표준편차가 변하는 인터랙션"] }, { "id": "practical-statistics-02-04", "order": 4, "title": "대푯값과 산포도", "standardCode": "12실통02-04", "achievementStandard": "대푯값과 산포도의 종류를 알고 자료의 특성을 나타내는 값으로 요약할 수 있다.", "topics": ["대푯값과 산포도", "핵심 관계"], "scopeNotes": ["계산이나 그래프 작성 자체보다 결과 해석에 중점을 둔다.", "자료 수집과 시각화 과정에서 오류와 편향을 비판적으로 검토한다."], "visualizationIdeas": ["범주형·수치형 자료와 네 가지 척도를 카드 분류 방식으로 비교", "동일 자료를 여러 그래프로 바꾸며 적합성과 왜곡 가능성 비교", "자료점 이동에 따라 평균·중앙값·표준편차가 변하는 인터랙션"] }], "conceptCount": 4 }, { "id": "data-analysis", "title": "자료의 분석", "order": 3, "concepts": [{ "id": "practical-statistics-03-01", "order": 1, "title": "정규분포와 t분포", "standardCode": "12실통03-01", "achievementStandard": "정규분포와 t 분포를 공학 도구를 이용하여 탐구할 수 있다.", "topics": ["정규분포와 t분포", "계산 방법과 절차", "탐구 설계와 수행"], "scopeNotes": ["이론 전개보다 공학 도구를 이용한 통계적 추론과 결과 해석에 중점을 둔다.", "가설과 유의수준, p값의 의미를 실제 사례와 연결한다."], "visualizationIdeas": ["표본 크기에 따라 정규분포와 t분포 곡선이 가까워지는 애니메이션", "표본을 반복 추출하며 신뢰구간이 모수를 포함하는 빈도 시뮬레이션", "귀무가설 분포에서 관측값과 p값 영역을 색으로 표시"] }, { "id": "practical-statistics-03-02", "order": 2, "title": "모평균 추정", "standardCode": "12실통03-02", "achievementStandard": "실생활에서 공학 도구를 이용하여 모평균을 추정할 수 있다.", "topics": ["모평균 추정", "적용과 문제 해결"], "scopeNotes": ["이론 전개보다 공학 도구를 이용한 통계적 추론과 결과 해석에 중점을 둔다.", "가설과 유의수준, p값의 의미를 실제 사례와 연결한다."], "visualizationIdeas": ["표본 크기에 따라 정규분포와 t분포 곡선이 가까워지는 애니메이션", "표본을 반복 추출하며 신뢰구간이 모수를 포함하는 빈도 시뮬레이션", "귀무가설 분포에서 관측값과 p값 영역을 색으로 표시"] }, { "id": "practical-statistics-03-03", "order": 3, "title": "모비율 추정", "standardCode": "12실통03-03", "achievementStandard": "실생활에서 공학 도구를 이용하여 모비율을 추정할 수 있다.", "topics": ["모비율 추정", "적용과 문제 해결"], "scopeNotes": ["이론 전개보다 공학 도구를 이용한 통계적 추론과 결과 해석에 중점을 둔다.", "가설과 유의수준, p값의 의미를 실제 사례와 연결한다."], "visualizationIdeas": ["표본 크기에 따라 정규분포와 t분포 곡선이 가까워지는 애니메이션", "표본을 반복 추출하며 신뢰구간이 모수를 포함하는 빈도 시뮬레이션", "귀무가설 분포에서 관측값과 p값 영역을 색으로 표시"] }, { "id": "practical-statistics-03-04", "order": 4, "title": "가설검정", "standardCode": "12실통03-04", "achievementStandard": "가설검정을 이해하고, 실생활에서 공학 도구를 이용하여 가설을 검정할 수 있다.", "topics": ["가설검정", "핵심 의미와 원리", "적용과 문제 해결"], "scopeNotes": ["이론 전개보다 공학 도구를 이용한 통계적 추론과 결과 해석에 중점을 둔다.", "가설과 유의수준, p값의 의미를 실제 사례와 연결한다."], "visualizationIdeas": ["표본 크기에 따라 정규분포와 t분포 곡선이 가까워지는 애니메이션", "표본을 반복 추출하며 신뢰구간이 모수를 포함하는 빈도 시뮬레이션", "귀무가설 분포에서 관측값과 p값 영역을 색으로 표시"] }], "conceptCount": 4 }, { "id": "statistical-inquiry", "title": "통계적 탐구", "order": 4, "concepts": [{ "id": "practical-statistics-04-01", "order": 1, "title": "통계적 탐구와 의사 결정", "standardCode": "12실통04-01", "achievementStandard": "실생활에서 통계적 탐구 과정에 따라 문제를 해결하고 합리적인 의사 결정을 할 수 있다.", "topics": ["통계적 탐구와 의사 결정", "적용과 문제 해결", "탐구 설계와 수행"], "scopeNotes": ["표본 조사 설계, 자료 수집, 분석, 결론 도출의 전 과정에서 연구 윤리를 준수한다.", "탐구 목적과 통계 방법의 적합성을 비판적으로 성찰한다."], "visualizationIdeas": ["탐구 질문→조사 설계→자료→분석→결론을 하나의 대시보드 흐름으로 표현", "표본·그래프·분석 방법 선택이 결론에 미치는 영향을 비교"] }, { "id": "practical-statistics-04-02", "order": 2, "title": "통계적 탐구의 성찰", "standardCode": "12실통04-02", "achievementStandard": "통계적 탐구 과정과 그 결과를 비판적으로 성찰할 수 있다.", "topics": ["통계적 탐구의 성찰", "탐구 설계와 수행"], "scopeNotes": ["표본 조사 설계, 자료 수집, 분석, 결론 도출의 전 과정에서 연구 윤리를 준수한다.", "탐구 목적과 통계 방법의 적합성을 비판적으로 성찰한다."], "visualizationIdeas": ["탐구 질문→조사 설계→자료→분석→결론을 하나의 대시보드 흐름으로 표현", "표본·그래프·분석 방법 선택이 결론에 미치는 영향을 비교"] }], "conceptCount": 2 }], "categoryEnglishTitle": "CONVERGENCE ELECTIVE", "categoryDescription": "수학을 문화, 통계, 탐구 활동과 연결하는 과목입니다.", "categoryOrder": 4, "placementLabel": "학교별 개설·편성", "sourceFile": "kr-2022-practical-statistics.yaml", "developmentLocked": true }, { "id": "math-research-project", "officialTitle": "수학과제 탐구", "category": "convergence-elective", "categoryTitle": "융합 선택", "recommendedGrades": [11, 12], "prerequisites": [], "defaultSemester": "school-defined", "conceptCount": 10, "units": [{ "id": "understanding-math-inquiry", "title": "과제 탐구의 이해", "order": 1, "concepts": [{ "id": "math-research-project-01-01", "order": 1, "title": "수학과제 탐구의 의미와 필요성", "standardCode": "12수과01-01", "achievementStandard": "수학과제 탐구의 의미와 필요성을 설명할 수 있다.", "topics": ["수학과제 탐구의 의미와 필요성", "핵심 의미와 원리", "탐구 설계와 수행"], "scopeNotes": ["학생 수준에 맞는 현실적 탐구를 안내하고 과도한 심화는 지양한다.", "표절·조작 방지, 출처 표기, 생명윤리와 안전을 탐구 전 과정에서 준수한다."], "visualizationIdeas": ["일상 질문이 수학적 탐구 문제로 구체화되는 단계별 흐름", "올바른 인용·표절·자료 조작 사례를 비교하는 의사 결정 시나리오"] }, { "id": "math-research-project-01-02", "order": 2, "title": "연구 윤리", "standardCode": "12수과01-02", "achievementStandard": "올바른 연구 윤리를 이해하고, 탐구의 전 과정에서 이를 준수한다.", "topics": ["연구 윤리", "핵심 의미와 원리", "탐구 설계와 수행"], "scopeNotes": ["학생 수준에 맞는 현실적 탐구를 안내하고 과도한 심화는 지양한다.", "표절·조작 방지, 출처 표기, 생명윤리와 안전을 탐구 전 과정에서 준수한다."], "visualizationIdeas": ["일상 질문이 수학적 탐구 문제로 구체화되는 단계별 흐름", "올바른 인용·표절·자료 조작 사례를 비교하는 의사 결정 시나리오"] }], "conceptCount": 2 }, { "id": "inquiry-methods-and-procedures", "title": "과제 탐구의 방법과 절차", "order": 2, "concepts": [{ "id": "math-research-project-02-01", "order": 1, "title": "문헌 조사", "standardCode": "12수과02-01", "achievementStandard": "문헌 조사를 통해 탐구하는 방법과 절차를 이해하고 설명할 수 있다.", "topics": ["문헌 조사", "핵심 의미와 원리", "탐구 설계와 수행"], "scopeNotes": ["탐구 주제에 따라 문헌 조사·사례 조사·수학 실험·개발 연구 중 적절한 방법을 선택한다.", "자료를 허위로 만들거나 임의로 조작하지 않는다."], "visualizationIdeas": ["네 가지 탐구 방법의 입력 자료·절차·산출물을 비교하는 흐름도", "수학적 모델링의 현실 문제→수학 문제→해결→현실 해석 순환 애니메이션", "퍼즐·게임·공학 도구 산출물의 설계와 반복 개선 과정"] }, { "id": "math-research-project-02-02", "order": 2, "title": "사례 조사", "standardCode": "12수과02-02", "achievementStandard": "사례 조사를 통해 탐구하는 방법과 절차를 이해하고 설명할 수 있다.", "topics": ["사례 조사", "핵심 의미와 원리", "탐구 설계와 수행"], "scopeNotes": ["탐구 주제에 따라 문헌 조사·사례 조사·수학 실험·개발 연구 중 적절한 방법을 선택한다.", "자료를 허위로 만들거나 임의로 조작하지 않는다."], "visualizationIdeas": ["네 가지 탐구 방법의 입력 자료·절차·산출물을 비교하는 흐름도", "수학적 모델링의 현실 문제→수학 문제→해결→현실 해석 순환 애니메이션", "퍼즐·게임·공학 도구 산출물의 설계와 반복 개선 과정"] }, { "id": "math-research-project-02-03", "order": 3, "title": "수학 실험", "standardCode": "12수과02-03", "achievementStandard": "수학 실험을 통해 탐구하는 방법과 절차를 이해하고 설명할 수 있다.", "topics": ["수학 실험", "핵심 의미와 원리", "탐구 설계와 수행"], "scopeNotes": ["탐구 주제에 따라 문헌 조사·사례 조사·수학 실험·개발 연구 중 적절한 방법을 선택한다.", "자료를 허위로 만들거나 임의로 조작하지 않는다."], "visualizationIdeas": ["네 가지 탐구 방법의 입력 자료·절차·산출물을 비교하는 흐름도", "수학적 모델링의 현실 문제→수학 문제→해결→현실 해석 순환 애니메이션", "퍼즐·게임·공학 도구 산출물의 설계와 반복 개선 과정"] }, { "id": "math-research-project-02-04", "order": 4, "title": "개발 연구", "standardCode": "12수과02-04", "achievementStandard": "개발 연구를 통해 탐구하는 방법과 절차를 이해하고 설명할 수 있다.", "topics": ["개발 연구", "핵심 의미와 원리", "탐구 설계와 수행"], "scopeNotes": ["탐구 주제에 따라 문헌 조사·사례 조사·수학 실험·개발 연구 중 적절한 방법을 선택한다.", "자료를 허위로 만들거나 임의로 조작하지 않는다."], "visualizationIdeas": ["네 가지 탐구 방법의 입력 자료·절차·산출물을 비교하는 흐름도", "수학적 모델링의 현실 문제→수학 문제→해결→현실 해석 순환 애니메이션", "퍼즐·게임·공학 도구 산출물의 설계와 반복 개선 과정"] }], "conceptCount": 4 }, { "id": "inquiry-execution-and-evaluation", "title": "과제 탐구의 실행 및 평가", "order": 3, "concepts": [{ "id": "math-research-project-03-01", "order": 1, "title": "탐구 주제와 계획", "standardCode": "12수과03-01", "achievementStandard": "여러 가지 현상에서 수학 탐구 주제를 선정하고 탐구 계획을 수립할 수 있다.", "topics": ["탐구 주제와 계획", "탐구 설계와 수행"], "scopeNotes": ["탐구 문제의 명확성·가치·실행 가능성을 고려해 계획을 수립한다.", "과정 중간 점검과 수정, 역할 분담, 자료 기반 의사 결정을 포함한다.", "탐구 목적과 방법의 적합성을 자기·동료 평가로 성찰한다."], "visualizationIdeas": ["주제 후보를 가치·실행 가능성·시간 기준으로 평가하는 매트릭스", "계획→수행→중간 점검→수정→결론의 프로젝트 타임라인", "탐구 산출물의 근거·표현·한계점을 루브릭으로 시각화"] }, { "id": "math-research-project-03-02", "order": 2, "title": "탐구 수행", "standardCode": "12수과03-02", "achievementStandard": "적절한 탐구 방법과 절차에 따라 탐구를 수행할 수 있다.", "topics": ["탐구 수행", "탐구 설계와 수행"], "scopeNotes": ["탐구 문제의 명확성·가치·실행 가능성을 고려해 계획을 수립한다.", "과정 중간 점검과 수정, 역할 분담, 자료 기반 의사 결정을 포함한다.", "탐구 목적과 방법의 적합성을 자기·동료 평가로 성찰한다."], "visualizationIdeas": ["주제 후보를 가치·실행 가능성·시간 기준으로 평가하는 매트릭스", "계획→수행→중간 점검→수정→결론의 프로젝트 타임라인", "탐구 산출물의 근거·표현·한계점을 루브릭으로 시각화"] }, { "id": "math-research-project-03-03", "order": 3, "title": "산출물과 발표", "standardCode": "12수과03-03", "achievementStandard": "탐구 결과를 정리하여 산출물을 만들고 발표할 수 있다.", "topics": ["산출물과 발표", "수학적 표현과 해석", "탐구 설계와 수행"], "scopeNotes": ["탐구 문제의 명확성·가치·실행 가능성을 고려해 계획을 수립한다.", "과정 중간 점검과 수정, 역할 분담, 자료 기반 의사 결정을 포함한다.", "탐구 목적과 방법의 적합성을 자기·동료 평가로 성찰한다."], "visualizationIdeas": ["주제 후보를 가치·실행 가능성·시간 기준으로 평가하는 매트릭스", "계획→수행→중간 점검→수정→결론의 프로젝트 타임라인", "탐구 산출물의 근거·표현·한계점을 루브릭으로 시각화"] }, { "id": "math-research-project-03-04", "order": 4, "title": "탐구 성찰과 평가", "standardCode": "12수과03-04", "achievementStandard": "탐구 과정과 결과를 반성하고 평가할 수 있다.", "topics": ["탐구 성찰과 평가", "탐구 설계와 수행"], "scopeNotes": ["탐구 문제의 명확성·가치·실행 가능성을 고려해 계획을 수립한다.", "과정 중간 점검과 수정, 역할 분담, 자료 기반 의사 결정을 포함한다.", "탐구 목적과 방법의 적합성을 자기·동료 평가로 성찰한다."], "visualizationIdeas": ["주제 후보를 가치·실행 가능성·시간 기준으로 평가하는 매트릭스", "계획→수행→중간 점검→수정→결론의 프로젝트 타임라인", "탐구 산출물의 근거·표현·한계점을 루브릭으로 시각화"] }], "conceptCount": 4 }], "categoryEnglishTitle": "CONVERGENCE ELECTIVE", "categoryDescription": "수학을 문화, 통계, 탐구 활동과 연결하는 과목입니다.", "categoryOrder": 4, "placementLabel": "학교별 개설·편성", "sourceFile": "kr-2022-math-research-project.yaml", "developmentLocked": true }], "catalogStats": { "totalCategories": 4, "totalCourses": 13, "totalUnits": 46, "totalConcepts": 220 }, "sourceFiles": ["kr-2022-ai-math.yaml", "kr-2022-algebra.yaml", "kr-2022-calculus-1.yaml", "kr-2022-calculus-2.yaml", "kr-2022-economics-math.yaml", "kr-2022-g10-math-curri.yaml", "kr-2022-geometry.yaml", "kr-2022-math-and-culture.yaml", "kr-2022-math-research-project.yaml", "kr-2022-practical-statistics.yaml", "kr-2022-probability-statistics.yaml", "kr-2022-vocational-math.yaml"] }) };
    }
  });

  // services/commonMathLearningCatalog.js
  var require_commonMathLearningCatalog = __commonJS({
    "services/commonMathLearningCatalog.js"(exports, module) {
      var CONCEPT_DETAILS = {
        "polynomial-arithmetic": ["다항식의 사칙연산", "동류항을 모으고 분배법칙을 정확히 적용하면 복잡한 다항식도 한 항씩 안전하게 계산할 수 있습니다.", "(A+B)(C+D)=AC+AD+BC+BD"],
        "identity-remainder-theorem": ["항등식과 나머지정리", "항등식은 모든 문자 값에서 성립하고, 나머지정리는 다항식을 직접 나누지 않고도 나머지를 함수값으로 바꾸어 줍니다.", "P(x)=(x-a)Q(x)+P(a)"],
        "polynomial-factorization": ["다항식의 인수분해", "공통인수·곱셈공식·치환을 순서대로 살피면 전개된 다항식을 곱의 구조로 되돌릴 수 있습니다.", "a^2-b^2=(a-b)(a+b)"],
        "complex-numbers": ["복소수", "실수에서 풀리지 않는 이차방정식을 다루기 위해 i²=-1인 허수단위를 도입하고 실수부와 허수부를 각각 계산합니다.", String.raw`i^2=-1,\quad z=a+bi`],
        "quadratic-discriminant": ["이차방정식의 판별식", "판별식은 근을 실제로 구하지 않고도 실근의 개수와 중근 여부를 알려주는 핵심 지표입니다.", "D=b^2-4ac"],
        "quadratic-roots-and-coefficients": ["근과 계수의 관계", "두 근의 합과 곱을 계수에 연결하면 근을 직접 구하지 않고도 대칭식과 새로운 방정식을 계산할 수 있습니다.", String.raw`\alpha+\beta=-\frac ba,\quad \alpha\beta=\frac ca`],
        "quadratic-equation-and-function": ["이차방정식과 이차함수", "방정식의 실근은 포물선과 x축의 교점이므로 대수적 해와 그래프의 위치 관계를 같은 정보로 읽습니다.", String.raw`ax^2+bx+c=0\Longleftrightarrow y=ax^2+bx+c\text{의 x절편}`],
        "parabola-and-line": ["포물선과 직선", "포물선과 직선의 교점 개수는 두 식을 연립해 얻은 이차방정식의 판별식으로 판단합니다.", String.raw`f(x)=mx+n\Longrightarrow D\gtreqless0`],
        "quadratic-max-min-restricted": ["이차함수의 최대·최소", "꼭짓점과 구간의 양 끝을 함께 비교해야 제한된 구간에서의 최대·최소를 빠뜨리지 않습니다.", String.raw`x_v=-\frac b{2a}`],
        "cubic-and-quartic-equations": ["삼차·사차방정식", "인수정리로 한 근을 찾고 차수를 낮춘 뒤, 남은 이차식의 해를 구하는 것이 기본 전략입니다.", String.raw`P(a)=0\Longleftrightarrow(x-a)\mid P(x)`],
        "simultaneous-quadratic-equations": ["연립이차방정식", "한 식에서 치환 대상을 고른 뒤 다른 식에 대입하고, 얻은 해가 원래 두 식을 모두 만족하는지 검산합니다.", String.raw`\text{치환}\to\text{한 문자 방정식}\to\text{검산}`],
        "simultaneous-linear-inequalities": ["연립일차부등식", "각 부등식의 해를 수직선에 나타낸 뒤 공통부분만 취해야 연립부등식의 해가 됩니다.", String.raw`A\cap B`],
        "absolute-linear-inequalities": ["절댓값 일차부등식", "절댓값은 수직선에서의 거리이므로 |x-a|<r은 a에서 r보다 가까운 점, |x-a|>r은 더 먼 점을 뜻합니다.", String.raw`|x-a|<r\Longleftrightarrow a-r<x<a+r`],
        "quadratic-inequalities": ["이차부등식", "이차식의 근과 최고차항의 부호를 이용해 수직선의 부호가 바뀌는 구간을 판정합니다.", String.raw`a(x-\alpha)(x-\beta)\gtreqless0`],
        "addition-and-multiplication-principles": ["합의 법칙과 곱의 법칙", "서로 겹치지 않는 선택은 더하고, 연속된 단계의 선택은 곱하여 경우의 수를 셉니다.", String.raw`n(A\cup B)=n(A)+n(B),\quad n(A\times B)=n(A)n(B)`],
        "permutations": ["순열", "서로 다른 대상을 순서 있게 뽑아 배열하는 경우의 수는 첫 자리부터 가능한 선택 수를 곱해 계산합니다.", String.raw`{}_nP_r=\frac{n!}{(n-r)!}`],
        "combinations": ["조합", "순서를 구별하지 않는 선택은 같은 원소를 배열한 r!가지가 중복되므로 순열을 r!로 나눕니다.", String.raw`{}_nC_r=\frac{n!}{r!(n-r)!}`],
        "matrix-concept": ["행렬의 뜻", "행렬은 수를 행과 열에 맞추어 배열한 표이며, 위치가 같은 성분끼리 대응시켜 읽습니다.", String.raw`A=(a_{ij})_{m\times n}`],
        "matrix-operations": ["행렬의 연산", "덧셈은 같은 위치의 성분끼리, 곱셈은 앞 행렬의 행과 뒤 행렬의 열을 곱해 더합니다.", String.raw`(AB)_{ij}=\sum_k a_{ik}b_{kj}`],
        "distance-and-internal-division": ["두 점 사이의 거리와 내분점", "좌표의 차로 만든 직각삼각형에 피타고라스 정리를 적용하고, 내분점은 반대편 비를 가중치로 사용합니다.", String.raw`AB=\sqrt{(x_2-x_1)^2+(y_2-y_1)^2}`],
        "parallel-and-perpendicular-lines": ["평행·수직인 두 직선", "기울기가 같으면 평행이고, 두 기울기의 곱이 -1이면 수직이라는 조건으로 미지수를 결정합니다.", String.raw`m_1=m_2,\quad m_1m_2=-1`],
        "point-line-distance": ["점과 직선 사이의 거리", "직선의 식을 한쪽으로 정리한 뒤 점의 좌표를 분자에 대입하고 법선벡터의 길이로 나눕니다.", String.raw`d=\frac{|ax_0+by_0+c|}{\sqrt{a^2+b^2}}`],
        "circle-equation": ["원의 방정식", "중심에서의 거리가 반지름과 같다는 정의를 거리 공식으로 나타내면 원의 표준형이 됩니다.", "(x-a)^2+(y-b)^2=r^2"],
        "circle-line-position": ["원과 직선의 위치 관계", "원의 중심과 직선 사이의 거리 d를 반지름 r과 비교하면 교점이 0개·1개·2개인지 판단할 수 있습니다.", "d<r, d=r, d>r"],
        "geometric-translation": ["평행이동", "도형을 (p,q)만큼 옮기면 점의 좌표에는 (p,q)를 더하고, 방정식에는 x-p와 y-q를 대입합니다.", "f(x-p,y-q)=0"],
        "geometric-reflection": ["대칭이동", "대칭축에 따라 좌표의 부호나 순서를 바꾸고, 방정식에도 같은 좌표 변환을 적용합니다.", String.raw`x\text{축}:(x,y)\mapsto(x,-y)`],
        "set-concept-and-representation": ["집합의 뜻과 표현", "조건이 명확한 대상의 모임을 집합이라 하며 원소나열법·조건제시법·벤다이어그램으로 같은 집합을 표현합니다.", "A={xmid P(x)}"],
        "set-inclusion": ["부분집합", "A의 모든 원소가 B에도 속하면 A는 B의 부분집합이며, 서로 포함하면 두 집합은 같습니다.", String.raw`A\subseteq B\Longleftrightarrow\forall x(x\in A\Rightarrow x\in B)`],
        "set-operations": ["집합의 연산", "합집합·교집합·여집합을 벤다이어그램의 영역과 연결하고 드모르간 법칙으로 복잡한 식을 정리합니다.", String.raw`(A\cup B)^c=A^c\cap B^c`],
        "proposition-and-condition": ["명제와 조건", "참과 거짓을 분명히 판별할 수 있는 문장을 명제라 하고, 조건의 진리집합으로 명제의 참·거짓을 판단합니다.", String.raw`p\Rightarrow q`],
        "converse-and-contrapositive": ["역과 대우", "p→q의 역은 q→p이고 대우는 ¬q→¬p이며, 원래 명제와 대우의 참·거짓은 항상 같습니다.", String.raw`p\Rightarrow q\Longleftrightarrow\neg q\Rightarrow\neg p`],
        "sufficient-and-necessary-conditions": ["충분조건과 필요조건", "p가 q를 보장하면 p는 충분조건이고 q는 필요조건이며, 양방향이 모두 성립하면 필요충분조건입니다.", String.raw`p\Rightarrow q,\quad p\Longleftrightarrow q`],
        "proof-by-contrapositive-and-contradiction": ["대우와 귀류법을 이용한 증명", "직접 증명이 어려우면 대우를 증명하거나 결론의 부정을 가정해 모순을 이끌어 냅니다.", String.raw`\neg q\Rightarrow\neg p`],
        "absolute-inequality": ["절대부등식", "문자의 모든 허용값에서 성립하는 부등식은 제곱의 비음수성·산술기하평균·코시형 구조로 증명합니다.", String.raw`a^2+b^2\ge2ab`],
        "function-concept-and-graph": ["함수의 뜻과 그래프", "정의역의 각 원소에 공역의 원소가 정확히 하나씩 대응할 때 함수이며 그래프는 그 순서쌍의 모임입니다.", String.raw`f:X\to Y`],
        "composite-function": ["합성함수", "안쪽 함수를 먼저 계산한 뒤 그 결과를 바깥 함수에 입력하며, 정의역 조건도 함께 확인합니다.", String.raw`(f\circ g)(x)=f(g(x))`],
        "inverse-function": ["역함수", "일대일 대응인 함수에서 입력과 출력을 바꾸면 역함수가 되며 두 그래프는 y=x에 대칭입니다.", String.raw`f^{-1}(f(x))=x`],
        "rational-function": ["유리함수", "분모가 0이 되는 값을 정의역에서 제외하고 점근선과 평행이동을 이용해 그래프의 위치를 읽습니다.", String.raw`y=\frac{a}{x-p}+q`],
        "irrational-function": ["무리함수", "근호 안이 0 이상이라는 정의역 조건을 먼저 세우고 기준 그래프의 이동과 대칭으로 개형을 파악합니다.", String.raw`y=a\sqrt{x-p}+q`]
      };
      var GRAPH_CONCEPT_IDS = /* @__PURE__ */ new Set([
        "quadratic-equation-and-function",
        "parabola-and-line",
        "quadratic-max-min-restricted",
        "distance-and-internal-division",
        "parallel-and-perpendicular-lines",
        "point-line-distance",
        "circle-equation",
        "circle-line-position",
        "geometric-translation",
        "geometric-reflection",
        "function-concept-and-graph",
        "inverse-function",
        "rational-function",
        "irrational-function"
      ]);
      var DIAGRAM_CONCEPT_IDS = /* @__PURE__ */ new Set([
        "simultaneous-linear-inequalities",
        "absolute-linear-inequalities",
        "quadratic-inequalities",
        "addition-and-multiplication-principles",
        "permutations",
        "combinations",
        "matrix-concept",
        "matrix-operations",
        "set-concept-and-representation",
        "set-inclusion",
        "set-operations",
        "composite-function"
      ]);
      function commonMathVisualType(conceptId) {
        if (GRAPH_CONCEPT_IDS.has(conceptId)) return "graph";
        if (DIAGRAM_CONCEPT_IDS.has(conceptId)) return "area-model";
        return "formula";
      }
      function previewBlocksFor(type) {
        if (type === "graph") {
          return [
            { label: "기준 그래프", tone: "secondary" },
            { label: "조건 변화", tone: "primary" },
            { label: "결과 확인", tone: "accent" }
          ];
        }
        if (type === "area-model") {
          return [
            { label: "대상 배치", tone: "secondary" },
            { label: "관계 비교", tone: "primary" },
            { label: "경우 확인", tone: "accent" }
          ];
        }
        return [
          { label: "조건 읽기", tone: "secondary" },
          { label: "식 정리", tone: "primary" },
          { label: "검산", tone: "accent" }
        ];
      }
      function detailedSteps(concept, detail) {
        const topics = Array.isArray(concept.topics) && concept.topics.length ? concept.topics : [concept.title];
        const [title, takeaway, formula] = detail;
        const topicAt = (index) => topics[index % topics.length];
        return [
          ["정의를 먼저 고정합니다", `${topicAt(0)}의 뜻과 기호가 가리키는 대상을 짧게 정리합니다.`],
          ["알맞은 표현을 고릅니다", `${topicAt(1)}을 식·표·도식·좌표평면 중 개념에 꼭 필요한 표현으로 바꿉니다.`],
          ["핵심 관계를 유도합니다", `${formula}가 정의에서 어떤 계산을 거쳐 나오는지 순서대로 연결합니다.`],
          ["대표 조건을 적용합니다", `${topicAt(2)}의 조건을 식으로 번역하고 계산 순서와 답의 범위를 확인합니다.`],
          ["바뀐 조건을 비교합니다", `${topicAt(3)}의 부호·범위·순서가 달라질 때 결론이 어떻게 바뀌는지 비교합니다.`],
          ["검산으로 마무리합니다", `${title}에서 자주 생기는 정의역 누락, 부호 오류, 중복 계산을 마지막에 점검합니다.`]
        ].map(([stepTitle, description], index) => ({ order: index + 1, title: stepTitle, description }));
      }
      function buildCommonMathLessonDefinitions(curriculum) {
        return curriculum.courses.filter((course) => ["common-math-1", "common-math-2"].includes(course.id)).flatMap((course) => course.units.flatMap((unit) => unit.concepts.map((concept) => {
          const detail = CONCEPT_DETAILS[concept.id];
          if (!detail) throw new Error(`공통수학 상세 설명이 없습니다: ${concept.id}`);
          const [title, keyTakeaway, formula] = detail;
          const visualType = commonMathVisualType(concept.id);
          return {
            curriculumId: curriculum.curriculum?.id || "kr-2022",
            courseId: course.id,
            unitId: unit.id,
            conceptId: concept.id,
            content: {
              estimatedMinutes: 28,
              summary: `${title}의 핵심 정의와 판단 기준을 먼저 익힌 뒤, 필요한 표현과 계산 원리를 대표 조건에 적용합니다.`,
              keyTakeaway,
              steps: detailedSteps(concept, detail),
              motion: { assetUrl: null, posterUrl: null, durationSeconds: 18 },
              playgroundKey: `common-math-${concept.id}`,
              practice: { generatorKey: `common-math-${concept.id}`, requiredDistinctTypes: 5 },
              dashboardPreview: {
                type: visualType,
                title,
                formula,
                blocks: previewBlocksFor(visualType)
              },
              isPublished: true
            }
          };
        })));
      }
      module.exports = {
        CONCEPT_DETAILS,
        GRAPH_CONCEPT_IDS,
        DIAGRAM_CONCEPT_IDS,
        commonMathVisualType,
        buildCommonMathLessonDefinitions
      };
    }
  });

  // services/mathTextService.js
  var require_mathTextService = __commonJS({
    "services/mathTextService.js"(exports, module) {
      var SUBSCRIPT_CHARACTERS = {
        "₀": "0",
        "₁": "1",
        "₂": "2",
        "₃": "3",
        "₄": "4",
        "₅": "5",
        "₆": "6",
        "₇": "7",
        "₈": "8",
        "₉": "9",
        "₊": "+",
        "₋": "-",
        "₌": "=",
        "₍": "(",
        "₎": ")",
        "ₙ": "n",
        "ₖ": "k"
      };
      var SUPERSCRIPT_CHARACTERS = {
        "⁰": "0",
        "¹": "1",
        "²": "2",
        "³": "3",
        "⁴": "4",
        "⁵": "5",
        "⁶": "6",
        "⁷": "7",
        "⁸": "8",
        "⁹": "9",
        "⁺": "+",
        "⁻": "-",
        "⁼": "=",
        "⁽": "(",
        "⁾": ")",
        "ⁿ": "n",
        "ᵏ": "k",
        "ᵐ": "m",
        "ᶠ": "f",
        "ᵍ": "g",
        "ˣ": "x"
      };
      var MATH_FRAGMENT_PATTERN = /[A-Za-z0-9πθΣ∫√∛∞′″₀-₉₊₋₌₍₎ₙₖ⁰-⁹⁺⁻⁼⁽⁾ⁿᵏᵐᶠᵍˣ≤≥≠×÷·−±°]/;
      var DASHBOARD_FORMULA_OVERRIDES = {
        "밑>1 증가 · 0<밑<1 감소": "\\(a>1\\): 증가, \\(0<a<1\\): 감소",
        "π rad = 180° · l = rθ": "\\(\\pi\\,\\mathrm{rad}=180^{\\circ},\\quad l=r\\theta\\)",
        "(cosθ, sinθ) · sin²θ + cos²θ = 1": "\\((\\cos\\theta,\\sin\\theta),\\quad \\sin^2\\theta+\\cos^2\\theta=1\\)",
        "a/sinA = 2R · a² = b²+c²−2bc·cosA": "\\(\\frac{a}{\\sin A}=2R,\\quad a^2=b^2+c^2-2bc\\cos A\\)",
        "f′(a) = lim h→0 [f(a+h)-f(a)]/h": "\\(f'(a)=\\displaystyle\\lim_{h\\to0}\\frac{f(a+h)-f(a)}{h}\\)",
        "f′(c) = [f(b)-f(a)]/(b-a)": "\\(f'(c)=\\displaystyle\\frac{f(b)-f(a)}{b-a}\\)",
        "∫xⁿdx = xⁿ⁺¹/(n+1)+C": "\\(\\displaystyle\\int x^n\\,dx=\\frac{x^{n+1}}{n+1}+C\\quad(n\\ne-1)\\)",
        "∫ₐᵇ f = ∫ₐᶜ f + ∫cᵇ f": "\\(\\displaystyle\\int_a^b f(x)\\,dx=\\int_a^c f(x)\\,dx+\\int_c^b f(x)\\,dx\\)",
        "∫ₐᵇ f(x)dx = F(b)-F(a)": "\\(\\displaystyle\\int_a^b f(x)\\,dx=F(b)-F(a)\\)",
        "lim x→a f(x) = f(a)": "\\(\\displaystyle\\lim_{x\\to a}f(x)=f(a)\\)",
        "lim x→a f(x) = L": "\\(\\displaystyle\\lim_{x\\to a}f(x)=L\\)"
      };
      function scriptText(value, characterMap) {
        return Array.from(value).map(
          (character) => characterMap[character] || character
        ).join("");
      }
      function replaceScriptCharacters(value, characterMap, marker) {
        const characters = Object.keys(characterMap).join("");
        const pattern = new RegExp(
          `[${characters}]+`,
          "g"
        );
        return value.replace(pattern, (match) => {
          const content = Array.from(match).map((character) => characterMap[character]).join("");
          return `${marker}{${content}}`;
        });
      }
      function normalizeRootNotation(value) {
        let result = value;
        const superscriptCharacters = Object.keys(SUPERSCRIPT_CHARACTERS).join("");
        result = result.replace(
          new RegExp(
            `([${superscriptCharacters}]+)√\\(([^()]*)\\)`,
            "g"
          ),
          (_, index, radicand) => `\\sqrt[${scriptText(
            index,
            SUPERSCRIPT_CHARACTERS
          )}]{${radicand}}`
        );
        result = result.replace(
          new RegExp(
            `([${superscriptCharacters}]+)√([A-Za-z0-9]+[${superscriptCharacters}]*)`,
            "g"
          ),
          (_, index, radicand) => `\\sqrt[${scriptText(
            index,
            SUPERSCRIPT_CHARACTERS
          )}]{${radicand}}`
        );
        result = result.replace(
          /∛\(([^()]*)\)/g,
          "\\sqrt[3]{$1}"
        );
        result = result.replace(
          /√\(([^()]*)\)/g,
          "\\sqrt{$1}"
        );
        result = result.replace(
          /∛([A-Za-z0-9]+(?:_\{[^}]+\}|\^\{[^}]+\})*)/g,
          "\\sqrt[3]{$1}"
        );
        result = result.replace(
          /√([A-Za-z0-9]+(?:_\{[^}]+\}|\^\{[^}]+\})*)/g,
          "\\sqrt{$1}"
        );
        return result;
      }
      function normalizeMathSource(value) {
        let result = String(value);
        result = result.replace(/−/g, "-").replace(/\+\s*-/g, "-").replace(/½/g, "\\frac{1}{2}").replace(/′/g, "'").replace(/″/g, "''");
        result = normalizeRootNotation(result);
        result = replaceScriptCharacters(
          result,
          SUBSCRIPT_CHARACTERS,
          "_"
        );
        result = replaceScriptCharacters(
          result,
          SUPERSCRIPT_CHARACTERS,
          "^"
        );
        result = result.replace(/\^\(([^()]*)\)/g, "^{$1}").replace(/Σ/g, "\\sum ").replace(/∫/g, "\\int ").replace(/π/g, "\\pi").replace(/θ/g, "\\theta").replace(/∞/g, "\\infty").replace(/≤/g, "\\le ").replace(/≥/g, "\\ge ").replace(/≠/g, "\\ne ").replace(/×/g, "\\times ").replace(/÷/g, "\\div ").replace(/·/g, "\\cdot ").replace(/→/g, "\\to ").replace(/±/g, "\\pm ").replace(/°/g, "^{\\circ}").replace(/⟺|⇔/g, "\\Longleftrightarrow ").replace(/⇒/g, "\\Longrightarrow ").replace(/↔/g, "\\leftrightarrow ").replace(/∧/g, "\\land ").replace(/∀/g, "\\forall ").replace(/\brad\b/g, "\\mathrm{rad}").replace(/\blim\b/g, "\\lim").replace(
          /\b(log|sin|cos|tan)(?=[A-Z])/g,
          "\\$1 "
        ).replace(
          /(^|[^\\A-Za-z])(log|sin|cos|tan)(?=[^A-Za-z]|$)/g,
          "$1\\$2"
        ).replace(/\s+/g, " ").trim();
        return result;
      }
      function wrapMathFragment(fragment) {
        const leadingWhitespace = fragment.match(/^\s*/)?.[0] || "";
        const trailingWhitespace = fragment.match(/\s*$/)?.[0] || "";
        let core = fragment.trim();
        if (!core || !MATH_FRAGMENT_PATTERN.test(core)) {
          return fragment;
        }
        let leadingPunctuation = "";
        let trailingPunctuation = "";
        const punctuationOnly = /^[\s.,;:!?'"‘’“”()[\]{}·×÷+\-=<>≤≥≠±→↔⇒⇔⟺∧∀]+$/;
        if (punctuationOnly.test(core)) {
          return fragment;
        }
        const quoteMatch = core.match(
          /^([,;:'"‘’“”]+\s*)/
        );
        if (quoteMatch) {
          leadingPunctuation = quoteMatch[1];
          core = core.slice(
            leadingPunctuation.length
          );
        }
        const punctuationMatch = core.match(
          /(\s*[,;.!?。]+)$/
        );
        if (punctuationMatch) {
          trailingPunctuation = punctuationMatch[1];
          core = core.slice(
            0,
            -trailingPunctuation.length
          );
        }
        if (core.endsWith("(") && !core.includes(")")) {
          core = core.slice(0, -1).trimEnd();
          trailingPunctuation = ` (${trailingPunctuation}`;
        }
        const normalized = normalizeMathSource(core);
        if (!normalized) return fragment;
        return `${leadingWhitespace}${leadingPunctuation}\\(${normalized}\\)${trailingPunctuation}${trailingWhitespace}`;
      }
      function normalizeDollarMathDelimiters(value) {
        return String(value || "").replace(
          /(?<!\\)\$\$([\s\S]*?)(?<!\\)\$\$/g,
          (_, expression) => `\\[${normalizeMathSource(
            expression
          )}\\]`
        ).replace(
          /(?<!\\)\$([^$\n]+?)(?<!\\)\$/g,
          (_, expression) => `\\(${normalizeMathSource(
            expression
          )}\\)`
        );
      }
      function formatAlgebraMathText(value) {
        if (value === null || value === void 0) {
          return "";
        }
        const source = normalizeDollarMathDelimiters(
          String(value).replace(/−/g, "-").replace(/\+\s*-/g, "-")
        );
        if (source.includes("\\(") || source.includes("\\[")) {
          return source;
        }
        return source.split(/([가-힣]+)/g).map(
          (fragment) => /[가-힣]/.test(fragment) ? fragment : wrapMathFragment(fragment)
        ).join("");
      }
      function formatAdminMath(value) {
        if (value === null || value === void 0 || value === "") {
          return "미응답";
        }
        if (typeof value === "object") {
          try {
            return formatAlgebraMathText(
              JSON.stringify(value)
            );
          } catch (error) {
            return formatAlgebraMathText(
              String(value)
            );
          }
        }
        return formatAlgebraMathText(
          String(value)
        );
      }
      function formatAlgebraLesson(lesson) {
        if (!lesson) return lesson;
        return {
          ...lesson,
          clientMotionCaptions: Array.isArray(
            lesson.steps
          ) ? lesson.steps.map(
            (step) => String(step.description || "")
          ) : [],
          clientMotionStageLabels: Array.isArray(
            lesson.steps
          ) ? lesson.steps.map(
            (step) => String(step.title || "")
          ) : [],
          summary: formatAlgebraMathText(
            lesson.summary
          ),
          keyTakeaway: formatAlgebraMathText(
            lesson.keyTakeaway
          ),
          steps: Array.isArray(lesson.steps) ? lesson.steps.map((step) => ({
            ...step,
            title: formatAlgebraMathText(
              step.title
            ),
            description: formatAlgebraMathText(
              step.description
            )
          })) : [],
          dashboardPreview: lesson.dashboardPreview ? {
            ...lesson.dashboardPreview,
            formula: formatDashboardFormula(
              lesson.dashboardPreview.formula
            )
          } : lesson.dashboardPreview
        };
      }
      function formatDashboardFormula(value) {
        if (value === null || value === void 0) {
          return "";
        }
        const source = String(value);
        return DASHBOARD_FORMULA_OVERRIDES[source] || formatAlgebraMathText(source);
      }
      function formatMathTextForCourse(courseId, value) {
        return [
          "common-math-1",
          "common-math-2",
          "algebra",
          "probability-statistics"
        ].includes(courseId) ? formatAlgebraMathText(value) : String(value ?? "");
      }
      module.exports = {
        formatAdminMath,
        formatAlgebraMathText,
        normalizeDollarMathDelimiters,
        formatAlgebraLesson,
        formatDashboardFormula,
        formatMathTextForCourse
      };
    }
  });

  // services/mathAnswerService.js
  var require_mathAnswerService = __commonJS({
    "services/mathAnswerService.js"(exports, module) {
      function normalizeExpressionSource(value) {
        let source = String(value ?? "").trim().toLowerCase().replace(/^\s*\\\((.*)\\\)\s*$/s, "$1").replace(/^\s*\$(.*)\$\s*$/s, "$1").replace(/−/g, "-").replace(/[×·]/g, "*").replace(/÷/g, "/").replace(/\\(?:times|cdot)/g, "*").replace(/\\div/g, "/").replace(/\\pi/g, "pi").replace(/π/g, "pi").replace(/\s+/g, "");
        for (let index = 0; index < 6; index += 1) {
          const next = source.replace(
            /\\frac\{([^{}]+)\}\{([^{}]+)\}/g,
            "(($1)/($2))"
          ).replace(
            /\\sqrt\{([^{}]+)\}/g,
            "sqrt($1)"
          ).replace(
            /\\sqrt\[3\]\{([^{}]+)\}/g,
            "cbrt($1)"
          );
          if (next === source) break;
          source = next;
        }
        source = source.replace(/∛\(([^()]*)\)/g, "cbrt($1)").replace(/√\(([^()]*)\)/g, "sqrt($1)").replace(/∛(-?\d+(?:\.\d+)?)/g, "cbrt($1)").replace(/√(-?\d+(?:\.\d+)?)/g, "sqrt($1)").replace(/\bsqrt\{([^{}]+)\}/g, "sqrt($1)").replace(/\bcbrt\{([^{}]+)\}/g, "cbrt($1)").replace(
          /(?<=[0-9.)])x(?=[0-9.(+-])/g,
          "*"
        );
        return source;
      }
      function tokenizeExpression(source) {
        const tokens = [];
        let index = 0;
        while (index < source.length) {
          const rest = source.slice(index);
          const number = rest.match(
            /^(?:\d+(?:\.\d*)?|\.\d+)(?:e[+-]?\d+)?/
          );
          if (number) {
            tokens.push({
              type: "number",
              value: Number(number[0])
            });
            index += number[0].length;
            continue;
          }
          const name = rest.match(
            /^(sqrt|cbrt|pi)/
          );
          if (name) {
            tokens.push({
              type: "name",
              value: name[1]
            });
            index += name[1].length;
            continue;
          }
          const character = source[index];
          if ("+-*/^()".includes(character)) {
            tokens.push({
              type: character === "(" || character === ")" ? "paren" : "operator",
              value: character
            });
            index += 1;
            continue;
          }
          return null;
        }
        return tokens;
      }
      function parseNumericExpression(value) {
        const source = normalizeExpressionSource(value);
        const tokens = tokenizeExpression(source);
        if (!tokens?.length) return null;
        let cursor = 0;
        const peek = () => tokens[cursor];
        const consume = () => tokens[cursor++];
        const startsPrimary = (token) => token?.type === "number" || token?.type === "name" || token?.type === "paren" && token.value === "(";
        function parsePrimary() {
          const token = consume();
          if (!token) {
            throw new Error("표현이 끝났습니다.");
          }
          if (token.type === "number") {
            return token.value;
          }
          if (token.type === "name" && token.value === "pi") {
            return Math.PI;
          }
          if (token.type === "name" && ["sqrt", "cbrt"].includes(
            token.value
          )) {
            const opening = consume();
            if (opening?.type !== "paren" || opening.value !== "(") {
              throw new Error("근호 괄호가 필요합니다.");
            }
            const inner = parseExpression();
            const closing = consume();
            if (closing?.type !== "paren" || closing.value !== ")") {
              throw new Error("근호 괄호가 닫히지 않았습니다.");
            }
            if (token.value === "sqrt") {
              if (inner < 0) {
                throw new Error("실수 범위의 근호가 아닙니다.");
              }
              return Math.sqrt(inner);
            }
            return Math.cbrt(inner);
          }
          if (token.type === "paren" && token.value === "(") {
            const inner = parseExpression();
            const closing = consume();
            if (closing?.type !== "paren" || closing.value !== ")") {
              throw new Error("괄호가 닫히지 않았습니다.");
            }
            return inner;
          }
          throw new Error("숫자 표현이 아닙니다.");
        }
        function parseUnary() {
          const token = peek();
          if (token?.type === "operator" && ["+", "-"].includes(token.value)) {
            consume();
            const value2 = parseUnary();
            return token.value === "-" ? -value2 : value2;
          }
          return parsePrimary();
        }
        function parsePower() {
          let left = parseUnary();
          const token = peek();
          if (token?.type === "operator" && token.value === "^") {
            consume();
            left = left ** parsePower();
          }
          return left;
        }
        function parseTerm() {
          let left = parsePower();
          while (true) {
            const token = peek();
            const explicit = token?.type === "operator" && ["*", "/"].includes(
              token.value
            );
            const implicit = startsPrimary(token);
            if (!explicit && !implicit) break;
            if (explicit) consume();
            const right = parsePower();
            left = explicit && token.value === "/" ? left / right : left * right;
          }
          return left;
        }
        function parseExpression() {
          let left = parseTerm();
          while (true) {
            const token = peek();
            if (token?.type !== "operator" || !["+", "-"].includes(
              token.value
            )) {
              break;
            }
            consume();
            const right = parseTerm();
            left = token.value === "+" ? left + right : left - right;
          }
          return left;
        }
        try {
          const result = parseExpression();
          if (cursor !== tokens.length || !Number.isFinite(result)) {
            return null;
          }
          return result;
        } catch (error) {
          return null;
        }
      }
      function normalizeAnswerText(value) {
        return String(value ?? "").trim().toLowerCase().replace(/−/g, "-").replace(/[;，]/g, ",").replace(/\s+/g, "");
      }
      function answersEquivalent(expected, submitted) {
        const expectedText = normalizeAnswerText(expected);
        const submittedText = normalizeAnswerText(submitted);
        if (expectedText.includes(",") || submittedText.includes(",")) {
          const expectedParts = expectedText.split(",");
          const submittedParts = submittedText.split(",");
          return expectedParts.length === submittedParts.length && expectedParts.every(
            (part, index) => answersEquivalent(
              part,
              submittedParts[index]
            )
          );
        }
        const expectedNumber = parseNumericExpression(expectedText);
        const submittedNumber = parseNumericExpression(submittedText);
        if (expectedNumber !== null && submittedNumber !== null) {
          return Math.abs(
            expectedNumber - submittedNumber
          ) <= Math.max(
            1e-7,
            Math.abs(expectedNumber) * 1e-7
          );
        }
        return expectedText === submittedText;
      }
      module.exports = {
        normalizeExpressionSource,
        parseNumericExpression,
        normalizeAnswerText,
        answersEquivalent
      };
    }
  });

  // services/problemGenerators/utils.js
  var require_utils = __commonJS({
    "services/problemGenerators/utils.js"(exports, module) {
      function randomInteger(min, max) {
        return Math.floor(Math.random() * (max - min + 1)) + min;
      }
      function nonZeroInteger(min = -5, max = 5) {
        let value = 0;
        while (value === 0) {
          value = randomInteger(min, max);
        }
        return value;
      }
      var {
        answersEquivalent
      } = require_mathAnswerService();
      function isCorrectAnswer(expected, submitted) {
        return answersEquivalent(
          expected,
          submitted
        );
      }
      var InvalidGeneratedProblemError = class extends Error {
        constructor(message) {
          super(message);
          this.name = "InvalidGeneratedProblemError";
        }
      };
      var CALCULATOR_REQUIRED_PATTERN = /(?:계산기\s*(?:사용|필요|권장)|calculator\s*(?:required|recommended))/i;
      function validateCalculatorFreeProblem(problem, problemType) {
        const typeLabel = problemType?.id || "unknown-type";
        const calculatorFree = problem?.validation?.calculatorFree ?? problem?.calculatorFree ?? problemType?.calculatorFree;
        if (calculatorFree === false) {
          throw new InvalidGeneratedProblemError(
            `${typeLabel}: 계산기 없이 풀 수 있는 문제로 검증되지 않았습니다.`
          );
        }
        const readableText = `${problem?.prompt || ""} ${problem?.solution || ""}`;
        if (CALCULATOR_REQUIRED_PATTERN.test(readableText)) {
          throw new InvalidGeneratedProblemError(
            `${typeLabel}: 계산기 사용이 필요한 문구가 포함되어 있습니다.`
          );
        }
        const answer = String(problem?.answer ?? "").trim();
        if (!answer || answer.length > 120 || /NaN|undefined|null/i.test(answer)) {
          throw new InvalidGeneratedProblemError(
            `${typeLabel}: 계산기 없이 검산할 수 있는 정답 범위를 벗어났습니다.`
          );
        }
        if (problem?.calculatorValidation?.passed === false) {
          throw new InvalidGeneratedProblemError(
            `${typeLabel}: 유형별 계산 복잡도 검증에 실패했습니다.`
          );
        }
        return true;
      }
      function hasOnlyFiniteNumbers(value) {
        if (typeof value === "number") {
          return Number.isFinite(value);
        }
        if (Array.isArray(value)) {
          return value.every(hasOnlyFiniteNumbers);
        }
        if (value && typeof value === "object") {
          return Object.values(value).every(
            hasOnlyFiniteNumbers
          );
        }
        return true;
      }
      function validateGeneratedProblem(problem, problemType) {
        const typeLabel = problemType?.id || "unknown-type";
        if (!problem || typeof problem !== "object") {
          throw new InvalidGeneratedProblemError(
            `${typeLabel}: 생성 결과가 객체가 아닙니다.`
          );
        }
        if (typeof problem.prompt !== "string" || !problem.prompt.trim()) {
          throw new InvalidGeneratedProblemError(
            `${typeLabel}: 문제 문장이 비어 있습니다.`
          );
        }
        const dollarCount = (problem.prompt.match(/\$/g) || []).length;
        if (dollarCount % 2 !== 0) {
          throw new InvalidGeneratedProblemError(
            `${typeLabel}: 문제의 수식 구분자($)가 닫히지 않았습니다.`
          );
        }
        if (!["short-answer", "multiple-choice"].includes(
          problem.inputMode
        )) {
          throw new InvalidGeneratedProblemError(
            `${typeLabel}: 지원하지 않는 입력 방식입니다.`
          );
        }
        if (problem.answer === void 0 || problem.answer === null || String(problem.answer).trim() === "") {
          throw new InvalidGeneratedProblemError(
            `${typeLabel}: 정답이 비어 있습니다.`
          );
        }
        if (typeof problem.answer === "number" && !Number.isFinite(problem.answer)) {
          throw new InvalidGeneratedProblemError(
            `${typeLabel}: 정답이 유한한 수가 아닙니다.`
          );
        }
        if (typeof problem.solution !== "string" || !problem.solution.trim()) {
          throw new InvalidGeneratedProblemError(
            `${typeLabel}: 풀이가 비어 있습니다.`
          );
        }
        validateCalculatorFreeProblem(problem, problemType);
        if (typeof problem.hintText !== "string" || !problem.hintText.trim()) {
          throw new InvalidGeneratedProblemError(
            `${typeLabel}: 힌트가 비어 있습니다.`
          );
        }
        if (problem.inputMode === "multiple-choice") {
          if (!Array.isArray(problem.choices) || problem.choices.length < 2) {
            throw new InvalidGeneratedProblemError(
              `${typeLabel}: 객관식 보기가 부족합니다.`
            );
          }
          const choiceKeys = problem.choices.map(
            (choice) => String(choice.key)
          );
          const choiceTexts = problem.choices.map(
            (choice) => String(choice.text).replace(/\s+/g, "").trim()
          );
          const uniqueChoiceKeys = new Set(choiceKeys);
          const uniqueChoiceTexts = new Set(
            choiceTexts
          );
          if (uniqueChoiceKeys.size !== choiceKeys.length) {
            throw new InvalidGeneratedProblemError(
              `${typeLabel}: 객관식 보기 키가 중복됩니다.`
            );
          }
          if (!uniqueChoiceKeys.has(
            String(problem.answer)
          )) {
            throw new InvalidGeneratedProblemError(
              `${typeLabel}: 정답과 일치하는 보기가 없습니다.`
            );
          }
          if (uniqueChoiceTexts.size !== choiceTexts.length) {
            throw new InvalidGeneratedProblemError(
              `${typeLabel}: 같은 내용의 보기가 중복됩니다.`
            );
          }
        }
        if (problem.visualization && !hasOnlyFiniteNumbers(
          problem.visualization
        )) {
          throw new InvalidGeneratedProblemError(
            `${typeLabel}: 그래프 데이터에 유효하지 않은 수가 있습니다.`
          );
        }
        const validityChecks = Array.isArray(
          problem.validityChecks
        ) ? problem.validityChecks : [];
        const failedCheck = validityChecks.find(
          (check) => !check?.passed
        );
        if (failedCheck) {
          throw new InvalidGeneratedProblemError(
            `${typeLabel}: ${failedCheck.message || failedCheck.name || "수학적 출제 조건을 만족하지 않습니다."}`
          );
        }
        if (typeof problemType?.validate === "function" && !problemType.validate(problem)) {
          throw new InvalidGeneratedProblemError(
            `${typeLabel}: 유형별 검증에 실패했습니다.`
          );
        }
        return true;
      }
      function generateValidProblem(problemType, maximumAttempts = 30) {
        let lastValidationError = null;
        for (let attempt = 0; attempt < maximumAttempts; attempt += 1) {
          let problem = null;
          try {
            problem = problemType.generate();
            validateGeneratedProblem(
              problem,
              problemType
            );
            return problem;
          } catch (error2) {
            if (!(error2 instanceof InvalidGeneratedProblemError)) {
              throw error2;
            }
            lastValidationError = error2;
          }
        }
        const error = new Error(
          `유효한 문제를 생성하지 못했습니다: ${problemType?.id || "unknown-type"}`
        );
        error.cause = lastValidationError;
        error.status = 503;
        throw error;
      }
      module.exports = {
        randomInteger,
        nonZeroInteger,
        isCorrectAnswer,
        validateCalculatorFreeProblem,
        validateGeneratedProblem,
        generateValidProblem
      };
    }
  });

  // services/problemGenerators/commonMath/generators.js
  var require_generators = __commonJS({
    "services/problemGenerators/commonMath/generators.js"(exports, module) {
      var { loadCurriculum } = require_catalog();
      var { CONCEPT_DETAILS } = require_commonMathLearningCatalog();
      var { formatAlgebraMathText } = require_mathTextService();
      var { isCorrectAnswer } = require_utils();
      var TYPE_BLUEPRINTS = [
        ["core-definition", "핵심 정의 판별", 1],
        ["formula-meaning", "대표 관계식 해석", 2],
        ["condition-reading", "조건과 범위 확인", 2],
        ["visual-representation", "그림·그래프·표로 표현", 2],
        ["calculation-plan", "계산 순서 설계", 3],
        ["reverse-reasoning", "결론에서 조건 역추론", 3],
        ["error-diagnosis", "잘못된 풀이 진단", 3],
        ["parameter-change", "조건 변화 비교", 4],
        ["application-model", "실생활·도형 상황 모델링", 4],
        ["integrated-reasoning", "복합 조건 종합", 5]
      ];
      function shuffled(values) {
        const result = values.slice();
        for (let index = result.length - 1; index > 0; index -= 1) {
          const target = Math.floor(Math.random() * (index + 1));
          [result[index], result[target]] = [result[target], result[index]];
        }
        return result;
      }
      function unique(values) {
        return [...new Set(values.map((value) => String(value || "").trim()).filter(Boolean))];
      }
      function finalConsonantIndex(value) {
        const lastCharacter = Array.from(String(value || "").trim()).at(-1) || "";
        const codePoint = lastCharacter.codePointAt(0);
        if (codePoint < 44032 || codePoint > 55203) return 0;
        return (codePoint - 44032) % 28;
      }
      function objectParticle(value) {
        return finalConsonantIndex(value) ? "을" : "를";
      }
      function withObjectParticle(value) {
        return `${value}${objectParticle(value)}`;
      }
      function withDirectionalParticle(value) {
        const consonant = finalConsonantIndex(value);
        return `${value}${consonant && consonant !== 8 ? "으로" : "로"}`;
      }
      function multipleChoice({ prompt, correct, distractors, solution, hintText, visualization }) {
        const candidates = unique([correct, ...distractors]).slice(0, 4);
        while (candidates.length < 4) candidates.push(`조건 ${candidates.length + 1}만 확인한다.`);
        const choices = shuffled(candidates.map((text, originalIndex) => ({ text, isCorrect: originalIndex === 0 }))).map((choice, index) => ({
          key: ["a", "b", "c", "d"][index],
          text: formatAlgebraMathText(choice.text),
          isCorrect: choice.isCorrect
        }));
        return {
          prompt: formatAlgebraMathText(prompt),
          inputMode: "multiple-choice",
          choices,
          answer: choices.find((choice) => choice.isCorrect).key,
          solution: formatAlgebraMathText(solution),
          hintText: formatAlgebraMathText(hintText),
          visualization: visualization || null,
          validityChecks: [{ name: "common-math-choice", passed: choices.length === 4 }]
        };
      }
      function makeProblem({ concept, unitConcepts, variant, detail }) {
        const [title, takeaway, formula] = detail;
        const topics = concept.topics?.length ? concept.topics : [title];
        const visuals = concept.visualizationIdeas?.length ? concept.visualizationIdeas : [`${title}의 조건을 식과 그림으로 함께 나타내기`];
        const otherDetails = unitConcepts.filter((item) => item.id !== concept.id).map((item) => CONCEPT_DETAILS[item.id]).filter(Boolean);
        const otherTakeaways = otherDetails.map((item) => item[1]);
        const otherFormulas = otherDetails.map((item) => item[2]);
        const topic = topics[variant % topics.length];
        const sharedDistractors = [
          "정의역과 조건은 확인하지 않고 마지막 계산값만 비교한다.",
          "모든 기호를 같은 값으로 두면 언제나 성립한다고 본다.",
          "식의 모양이 비슷하면 조건과 관계없이 같은 공식을 사용한다."
        ];
        switch (variant) {
          case 0:
            return multipleChoice({
              prompt: `${title}의 핵심 의미로 가장 알맞은 것을 고르세요.`,
              correct: takeaway,
              distractors: otherTakeaways.concat(sharedDistractors),
              solution: `${title}에서는 ${takeaway}`,
              hintText: "계산보다 먼저 정의가 어떤 대상을 연결하는지 확인하세요."
            });
          case 1:
            return multipleChoice({
              prompt: `${withObjectParticle(title)} 설명하는 대표 관계식으로 가장 알맞은 것을 고르세요.`,
              correct: formula,
              distractors: otherFormulas.concat(["x=0", "a+b=ab"]),
              solution: `대표 관계는 ${formula}입니다. 각 기호의 조건까지 함께 기억해야 합니다.`,
              hintText: `${title}의 정의를 식으로 옮긴 관계를 찾으세요.`
            });
          case 2:
            return multipleChoice({
              prompt: `${title} 문제에서 ‘${topic}’${objectParticle(topic)} 다룰 때 가장 먼저 할 일은 무엇인가요?`,
              correct: "주어진 대상의 범위와 성립 조건을 표시한다.",
              distractors: sharedDistractors,
              solution: "조건과 범위를 먼저 표시해야 이후의 식 변형과 계산이 허용되는지 판단할 수 있습니다.",
              hintText: "답을 계산하기 전에 무엇이 허용되는지 먼저 확인하세요."
            });
          case 3:
            return multipleChoice({
              prompt: `${title}의 ‘${topic}’${objectParticle(topic)} 시각적으로 확인하는 방법으로 가장 적절한 것은 무엇인가요?`,
              correct: visuals[variant % visuals.length],
              distractors: ["조건과 무관한 장식용 그래프를 그린다.", "모든 값을 한 점에 겹쳐 표시한다.", "계산 결과만 적고 관계는 나타내지 않는다."],
              solution: `${visuals[variant % visuals.length]} 방식은 조건과 결과가 함께 변하는 모습을 보여줍니다.`,
              hintText: "문제의 조건이 변할 때 그림의 어느 부분이 함께 움직이는지 생각하세요.",
              visualization: { kind: "common-math-concept", conceptId: concept.id, focus: topic }
            });
          case 4:
            return multipleChoice({
              prompt: `${title} 계산을 가장 안전하게 진행하는 순서를 고르세요.`,
              correct: "정의 확인 → 조건 표시 → 관계식 적용 → 계산 → 원래 조건으로 검산",
              distractors: ["계산 → 공식 선택 → 조건 생략 → 답", "공식 암기 → 숫자 대입 → 정의 확인", "답 추측 → 조건 변경 → 계산 생략"],
              solution: "정의와 조건을 먼저 확인하고 계산 후 원래 조건에 대입해 검산해야 불필요한 해와 부호 오류를 막을 수 있습니다.",
              hintText: "계산 전과 계산 후에 각각 확인할 항목을 찾으세요."
            });
          case 5:
            return multipleChoice({
              prompt: `${title}에서 결론이 주어졌을 때 조건을 역으로 찾는 올바른 방법은 무엇인가요?`,
              correct: "결론을 대표 관계식에 대입하고, 역과 원래 명제가 모두 성립하는지 검산한다.",
              distractors: sharedDistractors,
              solution: "역추론에서는 역이 항상 참인 것이 아니므로 얻은 후보를 반드시 원래 조건에 다시 대입해야 합니다.",
              hintText: "필요조건으로 얻은 후보와 실제 해를 구분하세요."
            });
          case 6:
            return multipleChoice({
              prompt: `${title} 풀이에서 가장 먼저 수정해야 할 잘못된 접근을 고르세요.`,
              correct: "정의역·부호·중복 가능성을 확인하지 않고 식의 모양만 보고 공식을 적용한다.",
              distractors: ["기호의 뜻을 먼저 적는다.", "계산 뒤 원래 조건에 대입한다.", "식과 그림의 결과를 서로 비교한다."],
              solution: "공식은 성립 조건 안에서만 사용할 수 있으므로 정의역, 부호, 중복 여부를 먼저 점검해야 합니다.",
              hintText: "공식 자체보다 공식이 성립하는 조건을 보세요."
            });
          case 7:
            return multipleChoice({
              prompt: `${title}에서 수나 조건 하나가 바뀌었을 때 가장 타당한 대응은 무엇인가요?`,
              correct: "바뀐 조건이 정의·부호·범위에 미치는 영향을 먼저 확인한 뒤 같은 해결 절차를 다시 적용한다.",
              distractors: sharedDistractors,
              solution: "조건 변화는 답만 바꾸는 것이 아니라 사용할 수 있는 성질과 해의 범위를 바꿀 수 있습니다.",
              hintText: "변한 숫자보다 그 숫자가 맡은 역할을 확인하세요."
            });
          case 8:
            return multipleChoice({
              prompt: `실제 상황을 ${withDirectionalParticle(title)} 모델링할 때 가장 알맞은 첫 단계는 무엇인가요?`,
              correct: "상황의 대상과 조건을 변수·집합·좌표·경우 중 알맞은 수학적 대상으로 번역한다.",
              distractors: sharedDistractors,
              solution: "모델링은 문장 속 대상과 제한을 수학적 기호와 조건으로 정확히 번역하는 것에서 시작합니다.",
              hintText: "문장 속 무엇을 변수로 둘지 먼저 정하세요."
            });
          default:
            return multipleChoice({
              prompt: `${title}의 ‘${topic}’${objectParticle(topic)} 포함한 종합 문제를 해결할 때 반드시 지켜야 할 원칙을 고르세요.`,
              correct: `${takeaway} 그리고 계산 결과가 원래 조건과 학습 범위를 모두 만족하는지 검산한다.`,
              distractors: sharedDistractors.concat(otherTakeaways),
              solution: `${title}의 핵심은 ${takeaway} 마지막에는 원래 조건과 학습 범위를 모두 만족하는지 확인합니다.`,
              hintText: "핵심 관계와 최종 검산 조건을 동시에 포함한 선택지를 찾으세요."
            });
        }
      }
      function buildGeneratorMap() {
        const curriculum = loadCurriculum();
        const map = /* @__PURE__ */ new Map();
        for (const course of curriculum.courses.filter((item) => ["common-math-1", "common-math-2"].includes(item.id))) {
          for (const unit of course.units) {
            for (const concept of unit.concepts) {
              const detail = CONCEPT_DETAILS[concept.id];
              if (!detail) throw new Error(`공통수학 문제 메타데이터가 없습니다: ${concept.id}`);
              const problemTypes = TYPE_BLUEPRINTS.map(([id, label, difficulty], variant) => ({
                id: `${concept.id}-${id}`,
                label: `유형 ${variant + 1} · ${label}`,
                difficulty,
                generate: () => makeProblem({ concept, unitConcepts: unit.concepts, variant, detail })
              }));
              map.set([course.id, unit.id, concept.id].join("/"), {
                key: `common-math-${concept.id}`,
                requiredDistinctTypes: 5,
                problemTypes,
                isCorrectAnswer
              });
            }
          }
        }
        return map;
      }
      var generatorMap = buildGeneratorMap();
      module.exports = { TYPE_BLUEPRINTS, generatorMap };
    }
  });

  // services/assessmentTemplates/commonMath/index.js
  var require_commonMath = __commonJS({
    "services/assessmentTemplates/commonMath/index.js"(exports, module) {
      var {
        generatorMap
      } = require_generators();
      var {
        generateValidProblem
      } = require_utils();
      var UNIT_CONCEPTS = [
        {
          courseId: "common-math-1",
          unitId: "polynomials",
          conceptIds: [
            "polynomial-arithmetic",
            "identity-remainder-theorem",
            "polynomial-factorization"
          ]
        },
        {
          courseId: "common-math-1",
          unitId: "equations-and-inequalities",
          conceptIds: [
            "complex-numbers",
            "quadratic-discriminant",
            "quadratic-roots-and-coefficients",
            "quadratic-equation-and-function",
            "parabola-and-line",
            "quadratic-max-min-restricted",
            "cubic-and-quartic-equations",
            "simultaneous-quadratic-equations",
            "simultaneous-linear-inequalities",
            "absolute-linear-inequalities",
            "quadratic-inequalities"
          ]
        },
        {
          courseId: "common-math-1",
          unitId: "counting",
          conceptIds: [
            "addition-and-multiplication-principles",
            "permutations",
            "combinations"
          ]
        },
        {
          courseId: "common-math-1",
          unitId: "matrices",
          conceptIds: ["matrix-concept", "matrix-operations"]
        },
        {
          courseId: "common-math-2",
          unitId: "coordinate-geometry",
          conceptIds: [
            "distance-and-internal-division",
            "parallel-and-perpendicular-lines",
            "point-line-distance",
            "circle-equation",
            "circle-line-position",
            "geometric-translation",
            "geometric-reflection"
          ]
        },
        {
          courseId: "common-math-2",
          unitId: "sets-and-propositions",
          conceptIds: [
            "set-concept-and-representation",
            "set-inclusion",
            "set-operations",
            "proposition-and-condition",
            "converse-and-contrapositive",
            "sufficient-and-necessary-conditions",
            "proof-by-contrapositive-and-contradiction",
            "absolute-inequality"
          ]
        },
        {
          courseId: "common-math-2",
          unitId: "functions-and-graphs",
          conceptIds: [
            "function-concept-and-graph",
            "composite-function",
            "inverse-function",
            "rational-function",
            "irrational-function"
          ]
        }
      ];
      function problemTypesForUnit({
        courseId,
        unitId,
        conceptIds
      }) {
        return conceptIds.flatMap((conceptId) => {
          const generator = generatorMap.get(
            [courseId, unitId, conceptId].join("/")
          );
          if (!generator) {
            throw new Error(
              `${courseId}/${unitId}/${conceptId}: 공통수학 문제 생성기가 없습니다.`
            );
          }
          return generator.problemTypes.map((problemType) => ({
            conceptId,
            problemType
          }));
        });
      }
      function makeAdvancedTemplates(config) {
        const records = problemTypesForUnit(config);
        if (records.length < 20) {
          throw new Error(
            `${config.courseId}/${config.unitId}: 평가용 유형이 20개 미만입니다.`
          );
        }
        return records.slice(0, 20).map(({ conceptId, problemType }, index) => {
          const generateAdvancedProblem = () => {
            const problem = generateValidProblem(problemType);
            return {
              ...problem,
              prompt: `다음은 ${problemType.label}을 여러 조건과 함께 판단하는 심화 문항입니다. ` + problem.prompt
            };
          };
          return {
            id: `${config.courseId}:${config.unitId}:advanced:${problemType.id}`,
            title: `심화 유형 ${index + 1} · ${problemType.label}`,
            difficulty: 4,
            level: "advanced",
            estimatedMinutes: 10,
            reasoningSteps: [
              "문제의 대상과 성립 조건을 식·표·그래프 중 알맞은 표현으로 바꾼다.",
              "핵심 정의와 관계식을 적용해 가능한 결론을 단계적으로 좁힌다.",
              "구한 결과를 원래 조건에 다시 대입해 정의역·부호·중복을 검산한다."
            ],
            requiredConceptIds: [conceptId],
            stages: [
              {
                id: "learned-concepts-only",
                requiredConceptIds: [conceptId],
                generate: generateAdvancedProblem
              }
            ],
            referenceArchetypeId: problemType.id,
            sourcePattern: "공통수학 정의·조건·시각표현을 결합한 다단계 추론",
            generate: generateAdvancedProblem,
            validate(problem) {
              return Array.isArray(problem?.validityChecks) && problem.validityChecks.every((check) => check.passed);
            }
          };
        });
      }
      var configs = UNIT_CONCEPTS.map((config) => ({
        ...config,
        requiredConceptIds: config.conceptIds.slice(),
        minimumAppliedPoolSize: 15,
        appliedPolicy: {
          includeBankTypes: false,
          minimumLocalDifficulty: 2
        },
        advancedTemplates: makeAdvancedTemplates(config)
      }));
      module.exports = configs;
    }
  });

  // services/assessmentTemplates/shared.js
  var require_shared = __commonJS({
    "services/assessmentTemplates/shared.js"(exports, module) {
      var {
        isCorrectAnswer
      } = require_utils();
      function randomInteger(min, max) {
        return Math.floor(
          Math.random() * (max - min + 1)
        ) + min;
      }
      function choose(values) {
        return values[randomInteger(
          0,
          values.length - 1
        )];
      }
      function nonZeroInteger(min = -5, max = 5) {
        let value = 0;
        while (value === 0) {
          value = randomInteger(
            min,
            max
          );
        }
        return value;
      }
      function gcd(left, right) {
        let a = Math.abs(left);
        let b = Math.abs(right);
        while (b) {
          [a, b] = [b, a % b];
        }
        return a || 1;
      }
      function fraction(numerator, denominator) {
        if (denominator === 0) {
          throw new Error(
            "분모는 0일 수 없습니다."
          );
        }
        const sign = denominator < 0 ? -1 : 1;
        const common = gcd(
          numerator,
          denominator
        );
        const top = sign * numerator / common;
        const bottom = Math.abs(denominator) / common;
        return bottom === 1 ? String(top) : `${top}/${bottom}`;
      }
      function nCr(n, r) {
        if (r < 0 || r > n || !Number.isInteger(n) || !Number.isInteger(r)) {
          return 0;
        }
        const k = Math.min(r, n - r);
        let value = 1;
        for (let index = 1; index <= k; index += 1) {
          value = value * (n - k + index) / index;
        }
        return Math.round(value);
      }
      function power(value, exponent) {
        return value ** exponent;
      }
      function signed(value) {
        if (value === 0) return "";
        return value > 0 ? `+${value}` : `${value}`;
      }
      function polynomialTerm(coefficient, exponent, variable = "x") {
        if (coefficient === 0) return "";
        const magnitude = Math.abs(coefficient);
        const coefficientText = exponent > 0 && magnitude === 1 ? "" : String(magnitude);
        const variableText = exponent === 0 ? "" : exponent === 1 ? variable : `${variable}^{${exponent}}`;
        return `${coefficient < 0 ? "-" : ""}${coefficientText}${variableText}`;
      }
      function polynomialTex(coefficients, variable = "x") {
        let result = "";
        for (let exponent = coefficients.length - 1; exponent >= 0; exponent -= 1) {
          const coefficient = coefficients[exponent];
          if (!coefficient) continue;
          const term = polynomialTerm(
            coefficient,
            exponent,
            variable
          );
          if (!result) {
            result = term;
          } else if (coefficient > 0) {
            result += `+${term}`;
          } else {
            result += term;
          }
        }
        return result || "0";
      }
      function linearFactor(root, variable = "x") {
        if (root === 0) return variable;
        return root > 0 ? `${variable}-${root}` : `${variable}+${Math.abs(
          root
        )}`;
      }
      function finiteAnswer(answer) {
        if (typeof answer === "number") {
          return Number.isFinite(answer);
        }
        const value = String(answer).trim();
        return Boolean(value) && !/NaN|Infinity|undefined|null/.test(
          value
        );
      }
      function makeShortAnswer({
        prompt,
        answer,
        independentAnswer,
        solution,
        hintText,
        visualization = null,
        checks = []
      }) {
        const verified = independentAnswer === void 0 ? answer : independentAnswer;
        return {
          prompt,
          inputMode: "short-answer",
          choices: [],
          answer,
          solution,
          hintText,
          visualization,
          validityChecks: [
            {
              name: "finite-answer",
              passed: finiteAnswer(answer),
              message: "정답이 유한한 값이어야 합니다."
            },
            {
              name: "independent-solution-check",
              passed: isCorrectAnswer(
                answer,
                verified
              ),
              message: "생성식과 독립 검산식의 답이 다릅니다."
            },
            {
              name: "unique-solution",
              passed: true,
              message: "주어진 조건에서 정답이 하나로 결정되어야 합니다."
            },
            ...checks
          ]
        };
      }
      function defineAdvancedTemplates({
        courseId,
        unitId,
        requiredConceptIds,
        families
      }) {
        return families.flatMap(
          (family, familyIndex) => [0, 1].map((mode) => {
            const reasoningSteps = family.reasoningSteps[mode] || family.reasoningSteps[0];
            const title = family.titles[mode];
            const id = `${courseId}:${unitId}:advanced:${family.id}-${mode + 1}`;
            const templateRequiredConceptIds = (family.requiredConceptIds || requiredConceptIds).slice();
            if (!Array.isArray(
              reasoningSteps
            ) || reasoningSteps.length < 3) {
              throw new Error(
                `${id}: 심화 유형은 풀이 단계가 3개 이상이어야 합니다.`
              );
            }
            return {
              id,
              title,
              difficulty: 4,
              level: "advanced",
              estimatedMinutes: family.estimatedMinutes?.[mode] || family.estimatedMinutes || 10,
              reasoningSteps,
              requiredConceptIds: templateRequiredConceptIds,
              stages: (family.stages || [
                {
                  id: family.stageId || "learned-concepts-only",
                  requiredConceptIds: templateRequiredConceptIds,
                  generate: family.generate
                }
              ]).map((stage) => ({
                id: stage.id,
                requiredConceptIds: (stage.requiredConceptIds || templateRequiredConceptIds).slice(),
                generate: () => stage.generate(mode)
              })),
              referenceArchetypeId: family.referenceArchetypeId || family.id,
              sourcePattern: family.sourcePattern,
              generate() {
                return family.generate(
                  mode
                );
              },
              validate(problem) {
                return finiteAnswer(
                  problem.answer
                ) && problem.validityChecks.every(
                  (check) => check.passed
                );
              }
            };
          })
        );
      }
      function selectDeepestLearnedStage(stages, allowedConceptIds) {
        const allowed = new Set(
          allowedConceptIds
        );
        return stages.filter(
          (stage) => (stage.requiredConceptIds || []).every(
            (conceptId) => allowed.has(conceptId)
          )
        ).sort(
          (left, right) => (right.requiredConceptIds || []).length - (left.requiredConceptIds || []).length
        )[0] || null;
      }
      module.exports = {
        randomInteger,
        choose,
        nonZeroInteger,
        gcd,
        fraction,
        nCr,
        power,
        signed,
        polynomialTerm,
        polynomialTex,
        linearFactor,
        makeShortAnswer,
        defineAdvancedTemplates,
        selectDeepestLearnedStage
      };
    }
  });

  // services/assessmentTemplates/algebra/exponentialLogarithmicFunctions.js
  var require_exponentialLogarithmicFunctions = __commonJS({
    "services/assessmentTemplates/algebra/exponentialLogarithmicFunctions.js"(exports, module) {
      var {
        randomInteger,
        choose,
        fraction,
        power,
        makeShortAnswer,
        defineAdvancedTemplates
      } = require_shared();
      var courseId = "algebra";
      var unitId = "exponential-logarithmic-functions";
      var requiredConceptIds = [
        "algebra-01-01",
        "algebra-01-02",
        "algebra-01-03",
        "algebra-01-04",
        "algebra-01-05",
        "algebra-01-06",
        "algebra-01-07",
        "algebra-01-08"
      ];
      var families = [
        {
          id: "exponential-quadratic-roots",
          titles: [
            "지수 치환 이차방정식의 두 해 합",
            "지수 치환 이차방정식의 두 해 곱"
          ],
          sourcePattern: "지수방정식을 a^x에 대한 이차식으로 치환한 뒤 양수 조건과 로그를 차례로 적용",
          estimatedMinutes: [10, 10],
          reasoningSteps: [
            [
              "t=a^x로 치환한다.",
              "t에 대한 이차방정식을 인수분해한다.",
              "각 t를 지수 꼴로 되돌려 x를 구한다.",
              "두 해의 합을 계산한다."
            ],
            [
              "t=a^x로 치환한다.",
              "t의 두 양의 근을 구한다.",
              "지수함수의 일대일성을 이용해 x를 복원한다.",
              "두 해의 곱을 계산한다."
            ]
          ],
          generate(mode) {
            const base = choose([2, 3]);
            const left = randomInteger(
              1,
              3
            );
            const right = left + randomInteger(2, 4);
            const sum = power(base, left) + power(base, right);
            const product = power(
              base,
              left + right
            );
            const answer = mode === 0 ? left + right : left * right;
            return makeShortAnswer({
              prompt: `$${base}^{2x}-${sum}\\cdot${base}^{x}+${product}=0$의 서로 다른 두 실근을 $\\alpha,\\beta$라 할 때, $${mode === 0 ? "\\alpha+\\beta" : "\\alpha\\beta"}$의 값을 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? left + right : left * right,
              solution: `$t=${base}^{x}>0$으로 놓으면 $(t-${power(
                base,
                left
              )})(t-${power(
                base,
                right
              )})=0$이다. 따라서 $x=${left},${right}$이고, 요구한 값은 $${answer}$이다.`,
              hintText: "지수식 전체를 한 문자로 치환한 뒤 양의 근만 되돌리세요."
            });
          }
        },
        {
          id: "log-system-order",
          titles: [
            "로그 합·제곱합에서 로그의 차 복원",
            "로그 합·제곱합에서 가중 로그 복원"
          ],
          sourcePattern: "로그값을 두 미지수로 놓고 대칭식과 대소 조건으로 각각의 값을 복원",
          estimatedMinutes: [11, 12],
          reasoningSteps: [
            [
              "u=log_a x, v=log_a y로 놓는다.",
              "합과 제곱합에서 uv를 구한다.",
              "u,v를 두 근으로 갖는 이차방정식을 만든다.",
              "x>y 조건으로 순서를 정해 차를 계산한다."
            ],
            [
              "두 로그를 u,v로 치환한다.",
              "대칭식으로 곱 uv를 구한다.",
              "이차방정식과 대소 조건으로 u,v를 구분한다.",
              "로그 성질로 목표식을 선형결합한다."
            ]
          ],
          generate(mode) {
            const base = choose([2, 3, 5]);
            const low = randomInteger(1, 3);
            const high = low + randomInteger(2, 4);
            const sum = low + high;
            const squares = low ** 2 + high ** 2;
            const answer = mode === 0 ? high - low : 2 * high + low;
            return makeShortAnswer({
              prompt: `양수 $x,y$가 $x>y$, $\\log_{${base}}x+\\log_{${base}}y=${sum}$, $(\\log_{${base}}x)^2+(\\log_{${base}}y)^2=${squares}$를 만족한다. $${mode === 0 ? `\\log_{${base}}\\dfrac{x}{y}` : `\\log_{${base}}(x^2y)`}$의 값을 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? high - low : 2 * high + low,
              solution: `$u=\\log_{${base}}x$, $v=\\log_{${base}}y$라 하자. $uv=\\{${sum}^2-${squares}\\}/2=${high * low}$이므로 $u,v$는 $t^2-${sum}t+${high * low}=0$의 두 근이다. $x>y$에서 $u=${high},v=${low}$이므로 답은 $${answer}$이다.`,
              hintText: "두 로그값의 합과 곱을 먼저 만든 뒤 이차방정식의 두 근으로 보세요."
            });
          }
        },
        {
          id: "symmetric-exponential-intersections",
          titles: [
            "대칭 지수함수 교점의 x좌표 합",
            "대칭 지수함수 교점 사이 거리"
          ],
          sourcePattern: "a^x+a^{m-x}의 대칭성과 지수 치환을 함께 이용하는 교점 유형",
          estimatedMinutes: [11, 11],
          reasoningSteps: [
            [
              "t=a^x로 치환해 분모를 제거한다.",
              "t에 대한 이차방정식을 인수분해한다.",
              "두 교점의 x좌표를 복원한다.",
              "대칭축을 확인해 합을 검산한다."
            ],
            [
              "지수 치환으로 두 양의 근을 찾는다.",
              "일대일성을 이용해 두 x좌표를 구한다.",
              "두 좌표의 순서를 정한다.",
              "교점 사이의 거리를 계산한다."
            ]
          ],
          generate(mode) {
            const base = choose([2, 3]);
            const total = randomInteger(
              5,
              8
            );
            const left = randomInteger(
              1,
              Math.floor(total / 2) - 1
            );
            const right = total - left;
            const constant = power(base, left) + power(base, right);
            const answer = mode === 0 ? total : right - left;
            return makeShortAnswer({
              prompt: `방정식 $${base}^{x}+${base}^{${total}-x}=${constant}$의 서로 다른 두 실근을 $\\alpha<\\beta$라 할 때, $${mode === 0 ? "\\alpha+\\beta" : "\\beta-\\alpha"}$의 값을 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? left + right : right - left,
              solution: `$t=${base}^{x}$로 놓고 ${base}^{x}를 곱해 정리하면 $t^2-${constant}t+${power(
                base,
                total
              )}=0$이다. 두 근은 $${base}^{${left}},${base}^{${right}}$이므로 $\\alpha=${left},\\beta=${right}$이고 답은 $${answer}$이다.`,
              hintText: "두 번째 지수항을 a^m/a^x로 바꾼 뒤 a^x를 치환하세요."
            });
          }
        },
        {
          id: "common-log-place-value",
          titles: [
            "상용로그로 큰 수의 자릿수 판정",
            "상용로그로 작은 수의 첫 유효자리 위치 판정"
          ],
          sourcePattern: "상용로그의 정수부분을 실제 수의 자릿수 또는 소수점 위치로 해석",
          estimatedMinutes: [10, 10],
          reasoningSteps: [
            [
              "주어진 로그값으로 밑의 상용로그를 만든다.",
              "거듭제곱의 로그를 계산한다.",
              "로그의 정수부분을 찾는다.",
              "정수의 자릿수로 변환한다."
            ],
            [
              "음의 지수의 상용로그를 계산한다.",
              "특성의 범위를 정한다.",
              "원래 수가 놓이는 10의 거듭제곱 구간을 찾는다.",
              "소수점 아래 첫 유효자리 위치를 결정한다."
            ]
          ],
          generate(mode) {
            const exponent = randomInteger(
              18,
              32
            );
            const log2 = 0.301;
            const logValue = exponent * log2;
            const digits = Math.floor(logValue) + 1;
            const firstPlace = Math.floor(logValue) + 1;
            const answer = mode === 0 ? digits : firstPlace;
            return makeShortAnswer({
              prompt: `$\\log 2=0.3010$으로 계산할 때, ${mode === 0 ? `$2^{${exponent}}$의 자릿수` : `$2^{-${exponent}}$에서 소수점 아래 처음으로 0이 아닌 숫자가 나타나는 자리`}를 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? Math.floor(
                exponent * 0.301
              ) + 1 : Math.floor(
                exponent * 0.301
              ) + 1,
              solution: `$${exponent}\\log2=${logValue.toFixed(
                4
              )}$. ${mode === 0 ? `따라서 $10^{${digits - 1}}<2^{${exponent}}<10^{${digits}}$이므로 ${digits}자리이다.` : `따라서 $10^{-${firstPlace}}<2^{-${exponent}}<10^{-${firstPlace - 1}}$의 경계를 해석하면 첫 유효숫자는 소수점 아래 ${firstPlace}번째에 나타난다.`}`,
              hintText: "상용로그의 정수부분을 10의 거듭제곱 구간으로 바꾸세요."
            });
          }
        },
        {
          id: "exponential-inequality-integers",
          titles: [
            "지수 이차부등식의 정수해 개수",
            "로그 이차부등식의 자연수해 개수"
          ],
          sourcePattern: "치환 부등식의 근 구간을 원래 변수의 정수·자연수 조건과 결합",
          estimatedMinutes: [12, 12],
          reasoningSteps: [
            [
              "t=a^x로 치환한다.",
              "이차부등식의 t 구간을 구한다.",
              "지수함수의 단조성으로 x 구간을 복원한다.",
              "끝점 포함 여부를 확인해 정수해를 센다."
            ],
            [
              "u=log_a x로 치환한다.",
              "u에 대한 이차부등식을 푼다.",
              "로그의 단조성으로 x 범위를 구한다.",
              "자연수 조건을 적용해 개수를 센다."
            ]
          ],
          generate(mode) {
            const base = choose([2, 3]);
            const left = randomInteger(
              1,
              2
            );
            const right = left + randomInteger(2, 3);
            const answer = mode === 0 ? right - left + 1 : power(base, right) - power(base, left) + 1;
            if (mode === 0) {
              const sum = power(base, left) + power(base, right);
              const product = power(
                base,
                left + right
              );
              return makeShortAnswer({
                prompt: `부등식 $${base}^{2x}-${sum}\\cdot${base}^{x}+${product}\\le0$을 만족하는 정수 $x$의 개수를 구하시오.`,
                answer,
                independentAnswer: right - left + 1,
                solution: `$t=${base}^{x}$로 놓으면 $(t-${power(
                  base,
                  left
                )})(t-${power(
                  base,
                  right
                )})\\le0$이다. 따라서 $${left}\\le x\\le${right}$이고 정수해는 ${answer}개이다.`,
                hintText: "지수 치환 후 근 사이 구간을 구하고 다시 x의 범위로 돌아오세요."
              });
            }
            return makeShortAnswer({
              prompt: `부등식 $(\\log_{${base}}x-${left})(\\log_{${base}}x-${right})\\le0$을 만족하는 자연수 $x$의 개수를 구하시오.`,
              answer,
              independentAnswer: power(base, right) - power(base, left) + 1,
              solution: `$${left}\\le\\log_{${base}}x\\le${right}$이고 밑이 1보다 크므로 $${power(
                base,
                left
              )}\\le x\\le${power(
                base,
                right
              )}$. 자연수는 ${answer}개이다.`,
              hintText: "로그값의 범위를 먼저 구한 뒤 밑이 1보다 큰지 확인하세요."
            });
          }
        },
        {
          id: "nested-change-of-base",
          titles: [
            "연쇄 로그 조건에서 밑변환 값 복원",
            "로그의 밑이 이어지는 조건에서 역수 로그 계산"
          ],
          sourcePattern: "log_a x와 log_x y를 연결해 log_a y를 만든 뒤 밑변환과 역수 관계를 적용",
          estimatedMinutes: [11, 12],
          reasoningSteps: [
            [
              "주어진 두 로그를 지수 관계로 바꾼다.",
              "연쇄 관계로 log_a y를 계산한다.",
              "밑변환 공식으로 목표 로그를 표현한다.",
              "요구한 선형결합을 계산한다."
            ],
            [
              "log_a y를 두 주어진 로그의 곱으로 만든다.",
              "로그의 역수 관계를 적용한다.",
              "분수를 기약분수로 정리한다.",
              "원래 조건에 대입해 검산한다."
            ]
          ],
          generate(mode) {
            const p = randomInteger(2, 4);
            const q = randomInteger(2, 5);
            const product = p * q;
            const answer = mode === 0 ? product + p : fraction(1, product);
            return makeShortAnswer({
              prompt: `양수 $a,x,y$에 대하여 $a\\ne1$, $\\log_a x=${p}$, $\\log_x y=${q}$이다. $${mode === 0 ? "\\log_a y+\\log_a x" : "\\log_y a"}$의 값을 구하시오.${mode === 1 ? " (기약분수로 입력)" : ""}`,
              answer,
              independentAnswer: mode === 0 ? p * q + p : fraction(1, p * q),
              solution: `$\\log_a y=(\\log_a x)(\\log_x y)=${p}\\cdot${q}=${product}$이다. ${mode === 0 ? `따라서 요구한 값은 $${product}+${p}=${answer}$이다.` : `$\\log_y a=1/\\log_a y=${answer}$이다.`}`,
              hintText: "중간 밑 x가 소거되도록 두 로그를 곱해 보세요."
            });
          }
        },
        {
          id: "absolute-exponential-roots",
          titles: [
            "절댓값 지수방정식의 두 근 대칭성",
            "절댓값 지수방정식의 두 근 곱"
          ],
          sourcePattern: "지수함수의 일대일성으로 절댓값 방정식을 만들고 중심 대칭인 두 근을 복원",
          estimatedMinutes: [10, 11],
          reasoningSteps: [
            [
              "지수함수의 일대일성으로 지수를 비교한다.",
              "절댓값 방정식을 두 일차방정식으로 나눈다.",
              "두 근을 중심 기준으로 정렬한다.",
              "두 근의 합을 계산한다."
            ],
            [
              "밑이 양수이고 1이 아님을 확인한다.",
              "절댓값을 풀어 두 근을 구한다.",
              "두 근이 서로 다른지 확인한다.",
              "두 근의 곱을 계산한다."
            ]
          ],
          generate(mode) {
            const base = choose([2, 3, 5]);
            const center = randomInteger(3, 8);
            const distance = randomInteger(1, 3);
            const left = center - distance;
            const right = center + distance;
            const answer = mode === 0 ? left + right : left * right;
            return makeShortAnswer({
              prompt: `방정식 $${base}^{|x-${center}|}=${base}^{${distance}}$의 서로 다른 두 실근을 $\\alpha<\\beta$라 할 때, $${mode === 0 ? "\\alpha+\\beta" : "\\alpha\\beta"}$의 값을 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? 2 * center : (center - distance) * (center + distance),
              solution: `지수함수의 일대일성에서 $|x-${center}|=${distance}$. 따라서 $\\alpha=${left},\\beta=${right}$이고 요구한 값은 $${answer}$이다.`,
              hintText: "밑이 같은 지수식이므로 먼저 지수끼리 비교하세요."
            });
          }
        },
        {
          id: "log-domain-quadratic",
          titles: [
            "로그 진수 조건을 포함한 이차방정식의 근 합",
            "로그 진수 조건을 포함한 이차방정식의 근 곱"
          ],
          sourcePattern: "로그의 일대일성과 진수 양수 조건을 함께 적용해 이차방정식의 후보근을 검증",
          estimatedMinutes: [12, 12],
          reasoningSteps: [
            [
              "로그의 밑과 진수 조건을 확인한다.",
              "로그의 일대일성으로 진수끼리 같게 놓는다.",
              "완전제곱 방정식의 두 근을 구한다.",
              "두 근을 진수 조건에 대입한 뒤 합을 계산한다."
            ],
            [
              "정의역을 먼저 기록한다.",
              "로그를 제거해 이차방정식을 만든다.",
              "후보근 모두가 정의역에 속하는지 검사한다.",
              "남은 두 근의 곱을 계산한다."
            ]
          ],
          generate(mode) {
            const base = choose([2, 3, 5]);
            const center = randomInteger(0, 5);
            const inner = choose([1, 2, 3]);
            const outer = inner + 2;
            const constant = outer ** 2 - inner ** 2;
            const left = center - outer;
            const right = center + outer;
            const answer = mode === 0 ? left + right : left * right;
            return makeShortAnswer({
              prompt: `방정식 $\\log_{${base}}\\{(x-${center})^2-${inner ** 2}\\}=\\log_{${base}}${constant}$의 서로 다른 두 실근을 $\\alpha,\\beta$라 할 때, $${mode === 0 ? "\\alpha+\\beta" : "\\alpha\\beta"}$의 값을 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? 2 * center : center ** 2 - outer ** 2,
              solution: `로그의 일대일성에서 $(x-${center})^2-${inner ** 2}=${constant}$, 즉 $(x-${center})^2=${outer ** 2}$이다. 두 근에서는 진수가 $${constant}>0$이므로 모두 가능하다. 근은 $${left},${right}$이고 답은 $${answer}$이다.`,
              hintText: "로그를 없애기 전에 진수가 양수여야 한다는 조건을 적어 두세요."
            });
          }
        },
        {
          id: "inverse-exponential-function",
          titles: [
            "평행이동한 지수함수의 역함숫값",
            "지수함수와 역함수의 대응점 결합"
          ],
          sourcePattern: "평행이동한 지수함수의 식을 역으로 풀어 역함숫값과 대칭 대응점을 계산",
          estimatedMinutes: [10, 11],
          reasoningSteps: [
            [
              "y=f(x)를 x에 대해 푼다.",
              "역함수의 정의역 조건을 확인한다.",
              "주어진 함숫값에 대응하는 지수를 찾는다.",
              "평행이동량을 반영해 역함숫값을 구한다."
            ],
            [
              "f와 f^{-1}의 좌표가 y=x에 대칭임을 사용한다.",
              "주어진 출력값을 만드는 입력을 구한다.",
              "역함수의 대응값을 기록한다.",
              "두 대응 좌표의 결합값을 계산한다."
            ]
          ],
          generate(mode) {
            const base = choose([2, 3]);
            const horizontal = randomInteger(1, 4);
            const vertical = randomInteger(1, 5);
            const exponent = randomInteger(2, 4);
            const target = power(base, exponent) + vertical;
            const inverseValue = exponent + horizontal;
            const answer = mode === 0 ? inverseValue : inverseValue + target;
            return makeShortAnswer({
              prompt: `함수 $f(x)=${base}^{x-${horizontal}}+${vertical}$의 역함수를 $g$라 하자. $${mode === 0 ? `g(${target})` : `g(${target})+${target}`}$의 값을 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? exponent + horizontal : exponent + horizontal + target,
              solution: `$f(${exponent + horizontal})=${base}^{${exponent}}+${vertical}=${target}$이므로 $g(${target})=${inverseValue}$. 따라서 답은 $${answer}$이다.`,
              hintText: "역함숫값 g(y)는 f(x)=y를 만족하는 입력 x입니다."
            });
          }
        },
        {
          id: "exponential-amgm-minimum",
          titles: [
            "서로 역수인 지수항의 최솟값",
            "지수 치환과 산술·기하평균의 등호 조건"
          ],
          sourcePattern: "a^x를 양수 변수로 치환하고 산술·기하평균과 등호 조건으로 최솟값과 위치를 결정",
          estimatedMinutes: [12, 13],
          reasoningSteps: [
            [
              "t=a^x>0으로 치환한다.",
              "두 양수항의 곱이 일정함을 확인한다.",
              "산술·기하평균으로 최솟값을 구한다.",
              "등호 조건에서 x를 구해 목표값을 계산한다."
            ],
            [
              "지수식 두 항을 t와 상수/t로 바꾼다.",
              "AM-GM 부등식을 적용한다.",
              "등호가 성립하는 t를 찾는다.",
              "지수함수의 일대일성으로 x를 복원한다."
            ]
          ],
          generate(mode) {
            const base = choose([2, 3]);
            const center = randomInteger(1, 4);
            const minimum = 2 * power(base, center);
            const answer = mode === 0 ? minimum : minimum + center;
            return makeShortAnswer({
              prompt: `실수 $x$에 대하여 $F(x)=${base}^{x}+${base}^{${2 * center}-x}$라 하자. $F(x)$의 최솟값을 $m$, 그때의 $x$를 $p$라 할 때, $${mode === 0 ? "m" : "m+p"}$의 값을 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? 2 * power(base, center) : 2 * power(base, center) + center,
              solution: `$t=${base}^{x}>0$이라 하면 $F=t+${base}^{2 * center}/t\\ge2${base}^{center}=${minimum}$. 등호는 $t=${base}^{center}$, 즉 $x=${center}$일 때 성립한다. 따라서 답은 $${answer}$이다.`,
              hintText: "두 지수항의 곱이 x와 무관하다는 점을 이용하세요."
            });
          }
        }
      ];
      module.exports = {
        courseId,
        unitId,
        requiredConceptIds,
        minimumAppliedPoolSize: 15,
        appliedPolicy: {
          includeBankTypes: true,
          minimumLocalDifficulty: 3
        },
        advancedTemplates: defineAdvancedTemplates({
          courseId,
          unitId,
          requiredConceptIds,
          families
        })
      };
    }
  });

  // services/assessmentTemplates/algebra/trigonometricFunctions.js
  var require_trigonometricFunctions = __commonJS({
    "services/assessmentTemplates/algebra/trigonometricFunctions.js"(exports, module) {
      var {
        randomInteger,
        choose,
        fraction,
        makeShortAnswer,
        defineAdvancedTemplates
      } = require_shared();
      var courseId = "algebra";
      var unitId = "trigonometric-functions";
      var requiredConceptIds = [
        "algebra-02-01",
        "algebra-02-02",
        "algebra-02-03"
      ];
      var families = [
        {
          id: "graph-parameter-recovery",
          titles: [
            "최대·최소·주기에서 삼각함수 식 복원",
            "그래프 정보에서 진폭·주기계수 결합값 복원"
          ],
          sourcePattern: "삼각함수 그래프의 최댓값·최솟값·주기를 역으로 읽어 식의 계수를 결정",
          estimatedMinutes: [10, 10],
          reasoningSteps: [
            [
              "최댓값과 최솟값의 차로 진폭을 구한다.",
              "두 값의 평균으로 평행이동량을 구한다.",
              "최소 양의 주기로 x의 계수를 구한다.",
              "요구한 계수 결합값을 계산한다."
            ],
            [
              "그래프의 중심선을 찾는다.",
              "진폭을 복원한다.",
              "주기 공식으로 각속도 계수를 구한다.",
              "세 매개변수의 결합값을 계산한다."
            ]
          ],
          generate(mode) {
            const amplitude = randomInteger(2, 5);
            const frequency = randomInteger(2, 4);
            const shift = randomInteger(-3, 3);
            const maximum = shift + amplitude;
            const minimum = shift - amplitude;
            const answer = mode === 0 ? amplitude + frequency + shift : amplitude * frequency - shift;
            return makeShortAnswer({
              prompt: `함수 $f(x)=a\\sin(bx)+c$에서 $a>0,b>0$이다. 최댓값이 ${maximum}, 최솟값이 ${minimum}, 최소 양의 주기가 $\\dfrac{2\\pi}{${frequency}}$일 때, $${mode === 0 ? "a+b+c" : "ab-c"}$의 값을 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? amplitude + frequency + shift : amplitude * frequency - shift,
              solution: `$a=(${maximum}-(${minimum}))/2=${amplitude}$, $c=(${maximum}+(${minimum}))/2=${shift}$이다. $2\\pi/b=2\\pi/${frequency}$에서 $b=${frequency}$. 따라서 답은 ${answer}이다.`,
              hintText: "최댓값·최솟값의 평균과 차, 그리고 주기 공식을 각각 사용하세요.",
              visualization: {
                kind: "algebra-trig",
                functionName: "sin",
                amplitude,
                frequency,
                verticalShift: shift,
                xUnit: "radian",
                minimum,
                maximum,
                periodNumerator: 2,
                periodDenominator: frequency,
                note: "그래프의 최댓값·최솟값과 한 주기의 길이를 문제의 조건과 함께 확인하세요."
              }
            });
          }
        },
        {
          id: "sum-identity-quadrant",
          titles: [
            "삼각함수 합과 사분면에서 곱 복원",
            "삼각함수 합과 대소 조건에서 탄젠트 복원"
          ],
          sourcePattern: "(sinθ+cosθ)^2 항등식과 사분면·대소 조건을 함께 사용",
          estimatedMinutes: [10, 11],
          reasoningSteps: [
            [
              "주어진 합을 제곱한다.",
              "sin²θ+cos²θ=1을 대입한다.",
              "sinθcosθ를 고립시킨다.",
              "사분면 조건과 부호가 맞는지 검산한다."
            ],
            [
              "합의 제곱으로 곱을 구한다.",
              "합과 곱으로 sinθ,cosθ의 이차방정식을 만든다.",
              "대소·사분면 조건으로 두 값을 구분한다.",
              "비를 취해 tanθ를 계산한다."
            ]
          ],
          generate(mode) {
            const swapped = randomInteger(0, 1) === 1;
            const sinNumerator = swapped ? 4 : 3;
            const cosNumerator = swapped ? 3 : 4;
            const sum = sinNumerator + cosNumerator;
            const product = fraction(
              sinNumerator * cosNumerator,
              25
            );
            const tangent = fraction(
              sinNumerator,
              cosNumerator
            );
            return makeShortAnswer({
              prompt: `제1사분면의 각 $\\theta$가 $\\sin\\theta+\\cos\\theta=\\dfrac{${sum}}5$를 만족한다. $\\sin\\theta ${sinNumerator > cosNumerator ? ">" : "<"}\\cos\\theta$일 때, $${mode === 0 ? "\\sin\\theta\\cos\\theta" : "\\tan\\theta"}$의 값을 구하시오. (기약분수로 입력)`,
              answer: mode === 0 ? product : tangent,
              independentAnswer: mode === 0 ? fraction(12, 25) : fraction(
                sinNumerator,
                cosNumerator
              ),
              solution: `합을 제곱하면 $\\dfrac{${sum ** 2}}{25}=1+2\\sin\\theta\\cos\\theta$이므로 $\\sin\\theta\\cos\\theta=\\dfrac{12}{25}$. 두 값은 $3/5,4/5$이고 대소 조건으로 $\\sin\\theta=${sinNumerator}/5$, $\\cos\\theta=${cosNumerator}/5$이다. 따라서 답은 ${mode === 0 ? product : tangent}이다.`,
              hintText: "(sinθ+cosθ)²을 전개한 뒤 두 값을 근으로 갖는 이차방정식을 생각하세요."
            });
          }
        },
        {
          id: "triangle-three-invariants",
          titles: [
            "세 변에서 넓이와 외접원의 반지름 연쇄 계산",
            "코사인법칙·넓이·사인법칙 결합"
          ],
          sourcePattern: "코사인법칙으로 각을 찾고 넓이와 확장 사인법칙까지 이어지는 삼각형 유형",
          estimatedMinutes: [12, 12],
          reasoningSteps: [
            [
              "가장 긴 변에 대한 코사인법칙을 적용한다.",
              "끼인각을 판정한다.",
              "두 변과 사잇각으로 넓이를 구한다.",
              "확장 사인법칙으로 외접반지름을 구해 결합한다."
            ],
            [
              "세 변으로 한 각의 코사인을 구한다.",
              "삼각함수 항등식으로 사인을 구한다.",
              "넓이를 계산한다.",
              "사인법칙으로 외접원의 지름을 구한다."
            ]
          ],
          generate(mode) {
            const scale = randomInteger(1, 4);
            const area = 6 * scale ** 2;
            const diameter = 5 * scale;
            const answer = mode === 0 ? area + diameter : area - diameter;
            return makeShortAnswer({
              prompt: `삼각형 ABC의 세 변의 길이가 각각 $${3 * scale},${4 * scale},${5 * scale}$이다. 삼각형의 넓이를 $K$, 외접원의 지름을 $D$라 할 때, $${mode === 0 ? "K+D" : "K-D"}$의 값을 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? 6 * scale ** 2 + 5 * scale : 6 * scale ** 2 - 5 * scale,
              solution: `코사인법칙에서 $(${5 * scale})^2=(${3 * scale})^2+(${4 * scale})^2$이므로 가장 긴 변의 대각은 $90^\\circ$이다. $K=\\frac12\\cdot${3 * scale}\\cdot${4 * scale}=${area}$이고, 확장 사인법칙에서 빗변이 외접원의 지름이므로 $D=${diameter}$. 답은 ${answer}이다.`,
              hintText: "먼저 코사인법칙으로 직각삼각형인지 확인한 뒤 넓이와 확장 사인법칙을 쓰세요."
            });
          }
        },
        {
          id: "sector-reverse-chain",
          titles: [
            "호의 길이에서 반지름과 부채꼴 넓이 역산",
            "부채꼴 정보와 삼각함수 값 결합"
          ],
          sourcePattern: "호도법의 호의 길이·넓이 공식을 역으로 적용한 뒤 특수각 값을 연결",
          estimatedMinutes: [10, 11],
          reasoningSteps: [
            [
              "호도법으로 중심각을 확인한다.",
              "l=rθ에서 반지름을 구한다.",
              "S=1/2 r²θ로 넓이를 구한다.",
              "π의 계수를 요구한 형식으로 정리한다."
            ],
            [
              "호의 길이로 반지름을 복원한다.",
              "중심각의 삼각함수 값을 구한다.",
              "부채꼴 넓이를 계산한다.",
              "두 결과를 결합한다."
            ]
          ],
          generate(mode) {
            const angle = choose([
              {
                denominator: 2,
                sin: 1
              },
              {
                denominator: 6,
                sin: 0.5
              }
            ]);
            const radius = angle.denominator === 2 ? randomInteger(2, 6) : 6;
            const arcCoefficient = radius / angle.denominator;
            const areaCoefficient = radius ** 2 / (2 * angle.denominator);
            const answer = mode === 0 ? areaCoefficient : areaCoefficient + radius * angle.sin;
            return makeShortAnswer({
              prompt: `중심각의 크기가 $\\dfrac{\\pi}{${angle.denominator}}$이고 호의 길이가 $${arcCoefficient}\\pi$인 부채꼴의 반지름을 $r$, 넓이를 $S$라 하자. $${mode === 0 ? "S/\\pi" : `S/\\pi+r\\sin\\dfrac{\\pi}{${angle.denominator}}`}$의 값을 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? radius ** 2 / (2 * angle.denominator) : radius ** 2 / (2 * angle.denominator) + radius * angle.sin,
              solution: `$r\\cdot\\pi/${angle.denominator}=${arcCoefficient}\\pi$에서 $r=${radius}$. $S/\\pi=\\frac12r^2/${angle.denominator}=${areaCoefficient}$. ${mode === 0 ? "" : `또한 $r\\sin(\\pi/${angle.denominator})=${radius * angle.sin}$이다. `}따라서 답은 ${answer}이다.`,
              hintText: "호의 길이 공식 l=rθ로 반지름을 먼저 복원하세요."
            });
          }
        },
        {
          id: "isosceles-cosine-sine-chain",
          titles: [
            "이등변삼각형에서 높이·넓이·외접반지름 결합",
            "코사인법칙으로 각을 복원한 뒤 사인법칙 적용"
          ],
          sourcePattern: "이등변삼각형의 세 변 조건을 코사인법칙·넓이·사인법칙으로 연쇄 해석",
          estimatedMinutes: [12, 13],
          reasoningSteps: [
            [
              "코사인법칙으로 꼭짓각의 코사인을 구한다.",
              "사인값 또는 높이를 구한다.",
              "삼각형의 넓이를 계산한다.",
              "확장 사인법칙으로 외접반지름을 구해 결합한다."
            ],
            [
              "세 변을 코사인법칙에 대입한다.",
              "sin²+cos²=1로 사인을 구한다.",
              "넓이로 계산을 검산한다.",
              "사인법칙으로 외접반지름을 구한다."
            ]
          ],
          generate(mode) {
            const scale = randomInteger(1, 3);
            const equalSide = 5 * scale;
            const base = 6 * scale;
            const height = 4 * scale;
            const area = 12 * scale ** 2;
            const radius = fraction(
              25 * scale,
              8
            );
            const answer = mode === 0 ? area + height : radius;
            return makeShortAnswer({
              prompt: `이등변삼각형 ABC에서 $AB=AC=${equalSide}$, $BC=${base}$이다. $K$를 넓이, $h$를 A에서 BC에 내린 높이, $R$을 외접원의 반지름이라 할 때, $${mode === 0 ? "K+h" : "R"}$의 값을 구하시오.${mode === 1 ? " (기약분수로 입력)" : ""}`,
              answer,
              independentAnswer: mode === 0 ? 12 * scale ** 2 + 4 * scale : fraction(
                25 * scale,
                8
              ),
              solution: `높이는 밑변을 이등분하므로 $h=\\sqrt{${equalSide}^2-${3 * scale}^2}=${height}$. $K=\\frac12\\cdot${base}\\cdot${height}=${area}$. 또 $K=abc/(4R)$에서 $R=${radius}$. 따라서 답은 ${answer}이다.`,
              hintText: "이등변삼각형의 높이가 밑변을 이등분한다는 점에서 시작하세요."
            });
          }
        },
        {
          id: "trigonometric-equation-root-count",
          titles: [
            "주기와 영점으로 삼각방정식의 해 개수 계산",
            "끝점 포함 여부를 구분하는 삼각방정식 해 개수"
          ],
          sourcePattern: "삼각함수의 영점 간격을 구한 뒤 주어진 구간의 양 끝점 포함 여부까지 세는 유형",
          estimatedMinutes: [11, 12],
          reasoningSteps: [
            [
              "sin(kx)=0의 일반해를 구한다.",
              "해 사이의 간격을 계산한다.",
              "일반해가 주어진 닫힌구간에 속하는 조건을 푼다.",
              "정수 매개변수의 개수를 센다."
            ],
            [
              "cos(kx)=0의 일반해를 구한다.",
              "구간 양 끝점이 해인지 각각 검사한다.",
              "허용되는 정수 지표의 범위를 구한다.",
              "끝점을 제외한 해의 개수를 계산한다."
            ]
          ],
          generate(mode) {
            const frequency = randomInteger(2, 5);
            const length = randomInteger(2, 4);
            const answer = mode === 0 ? frequency * length + 1 : frequency * length;
            return makeShortAnswer({
              prompt: mode === 0 ? `방정식 $\\sin(${frequency}x)=0$이 닫힌구간 $[0,${length}\\pi]$에서 갖는 서로 다른 실근의 개수를 구하시오.` : `방정식 $\\cos(${frequency}x)=0$이 열린구간 $(0,${length}\\pi)$에서 갖는 서로 다른 실근의 개수를 구하시오.`,
              answer,
              independentAnswer: frequency * length + (mode === 0 ? 1 : 0),
              solution: mode === 0 ? `$x=n\\pi/${frequency}$이고 $0\\le n\\le${frequency * length}$이므로 해는 ${answer}개이다.` : `$x=(2n+1)\\pi/(2${frequency})$이다. $(0,${length}\\pi)$ 안에 ${frequency * length}개의 해가 있으므로 답은 ${answer}이다.`,
              hintText: "일반해를 먼저 쓴 뒤 정수 n의 범위를 세세요."
            });
          }
        },
        {
          id: "phase-shift-extrema",
          titles: [
            "위상이 이동한 코사인함수의 첫 최댓값 위치",
            "위상이 이동한 사인함수의 첫 최솟값 위치"
          ],
          sourcePattern: "평행이동한 삼각함수의 위상이 특정 각이 되는 첫 양의 위치를 주기와 함께 결정",
          estimatedMinutes: [10, 11],
          reasoningSteps: [
            [
              "최댓값이 되는 코사인의 위상을 찾는다.",
              "위상에 2π의 정수배를 더한 일반해를 쓴다.",
              "양수인 해 중 가장 작은 값을 고른다.",
              "기약분수의 분자와 분모를 결합한다."
            ],
            [
              "사인함수가 최솟값을 갖는 위상을 찾는다.",
              "평행이동량을 반영한 일반해를 세운다.",
              "최소 양의 해를 구한다.",
              "π의 유리수 배를 기약분수로 정리한다."
            ]
          ],
          generate(mode) {
            const denominator = choose([3, 4, 6]);
            const shiftNumerator = 1;
            const numerator = mode === 0 ? shiftNumerator : 3 * denominator + 2 * shiftNumerator;
            const reduced = fraction(
              numerator,
              2 * denominator
            ).split("/");
            const top = Number(reduced[0]);
            const bottom = Number(
              reduced[1] || 1
            );
            const answer = top + bottom;
            return makeShortAnswer({
              prompt: mode === 0 ? `함수 $f(x)=3\\cos(2x-\\dfrac{\\pi}{${denominator}})+1$이 최댓값을 갖는 가장 작은 양수 $x$를 $\\dfrac{p}{q}\\pi$라 하자. 서로소인 자연수 $p,q$에 대하여 $p+q$를 구하시오.` : `함수 $g(x)=2\\sin(2x-\\dfrac{\\pi}{${denominator}})-3$이 최솟값을 갖는 가장 작은 양수 $x$를 $\\dfrac{p}{q}\\pi$라 하자. 서로소인 자연수 $p,q$에 대하여 $p+q$를 구하시오.`,
              answer,
              independentAnswer: top + bottom,
              solution: mode === 0 ? `최댓값은 $2x-\\pi/${denominator}=0$에서 처음 나타나므로 $x=\\pi/${2 * denominator}$. 따라서 $p+q=${answer}$이다.` : `최솟값은 $2x-\\pi/${denominator}=3\\pi/2$에서 처음 나타난다. 따라서 $x=${fraction(numerator, 2 * denominator)}\\pi$이고 $p+q=${answer}$이다.`,
              hintText: "코사인의 최대 위상은 0, 사인의 최소 위상은 3π/2입니다."
            });
          }
        },
        {
          id: "included-angle-triangle",
          titles: [
            "끼인각의 코사인에서 제3변과 넓이 결합",
            "두 변과 끼인각에서 넓이·둘레 연쇄 계산"
          ],
          sourcePattern: "한 각의 사인·코사인과 두 인접변을 이용해 코사인법칙과 넓이 공식을 함께 적용",
          estimatedMinutes: [12, 13],
          reasoningSteps: [
            [
              "주어진 코사인으로 사인값을 복원한다.",
              "코사인법칙으로 제3변을 구한다.",
              "두 변과 끼인각으로 넓이를 계산한다.",
              "제3변과 넓이를 결합한다."
            ],
            [
              "코사인법칙에 두 변과 끼인각을 대입한다.",
              "제3변의 양의 길이를 선택한다.",
              "사인값으로 넓이를 계산한다.",
              "넓이와 둘레의 차를 구한다."
            ]
          ],
          generate(mode) {
            const scale = randomInteger(1, 3);
            const sideA = 3 * scale;
            const sideB = 4 * scale;
            const sideC = 5 * scale;
            const area = 6 * scale ** 2;
            const perimeter = 12 * scale;
            const answer = mode === 0 ? sideC + area : area + perimeter;
            return makeShortAnswer({
              prompt: `삼각형에서 두 변의 길이가 $${sideA},${sideB}$이고 그 끼인각을 $\\theta$라 하자. $\\cos\\theta=0$일 때 제3변의 길이를 $c$, 넓이를 $K$라 하면 ${mode === 0 ? "$c+K$" : "둘레를 $P$라 할 때 $K+P$"}의 값을 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? 5 * scale + 6 * scale ** 2 : 6 * scale ** 2 + 12 * scale,
              solution: `$\\theta=90^\\circ$이므로 코사인법칙에서 $c=${sideC}$이고 $K=\\frac12\\cdot${sideA}\\cdot${sideB}=${area}$. ${mode === 0 ? "" : `둘레는 ${perimeter}이므로 `}답은 ${answer}이다.`,
              hintText: "cosθ=0이면 끼인각이 직각입니다. 코사인법칙과 넓이 공식을 차례로 쓰세요."
            });
          }
        },
        {
          id: "sine-law-two-triangle-chain",
          titles: [
            "공유변을 가진 두 삼각형의 사인법칙 연쇄",
            "한 삼각형에서 구한 변을 다음 삼각형에 전달"
          ],
          sourcePattern: "첫 삼각형의 확장 사인법칙으로 공유변을 구한 뒤 두 번째 삼각형의 사인법칙에 대입",
          estimatedMinutes: [13, 14],
          reasoningSteps: [
            [
              "첫 삼각형에서 확장 사인법칙으로 공유변을 구한다.",
              "두 번째 삼각형에서 주어진 각의 사인값을 확인한다.",
              "공유변을 두 번째 사인법칙에 대입한다.",
              "목표 변과 공유변을 결합한다."
            ],
            [
              "첫 삼각형의 외접원 지름을 계산한다.",
              "공유변의 대각을 이용해 길이를 구한다.",
              "두 번째 삼각형에서 다시 사인법칙을 적용한다.",
              "두 단계에서 얻은 길이의 차를 계산한다."
            ]
          ],
          generate(mode) {
            const scale = randomInteger(2, 6);
            const shared = scale;
            const target = 2 * scale;
            const answer = mode === 0 ? shared + target : target - shared;
            return makeShortAnswer({
              prompt: `삼각형 ABC에서 $\\angle A=30^\\circ$이고 외접원의 지름이 $${2 * scale}$이다. 선분 BC를 공유하는 삼각형 BCD에서 $\\angle C=90^\\circ$, $\\angle D=30^\\circ$이다. $${mode === 0 ? "BC+BD" : "BD-BC"}$의 값을 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? 3 * scale : scale,
              solution: `확장 사인법칙에서 첫 삼각형의 $BC=2R\\sin30^\\circ=${scale}$이다. 두 번째 삼각형에서 $BC=BD\\sin30^\\circ$이므로 $BD=${target}$. 따라서 답은 ${answer}이다.`,
              hintText: "각 변은 외접원의 지름과 그 대각의 사인의 곱입니다."
            });
          }
        },
        {
          id: "chord-sector-coefficient",
          titles: [
            "현의 길이와 부채꼴 넓이의 계수 결합",
            "중심각에서 현·호·부채꼴을 함께 계산"
          ],
          sourcePattern: "중심각을 이용해 이등변삼각형의 현과 부채꼴 넓이를 각각 구한 뒤 계수를 결합",
          estimatedMinutes: [11, 12],
          reasoningSteps: [
            [
              "중심각 60도인 삼각형의 세 변을 판정한다.",
              "현의 길이를 구한다.",
              "부채꼴 넓이 공식에 중심각을 대입한다.",
              "π의 계수와 현의 길이를 결합한다."
            ],
            [
              "호도법으로 중심각을 변환한다.",
              "호의 길이와 부채꼴 넓이를 계산한다.",
              "코사인법칙으로 현의 길이를 확인한다.",
              "요구한 세 양의 계수를 합한다."
            ]
          ],
          generate(mode) {
            const radius = 6 * randomInteger(1, 3);
            const sectorCoefficient = radius ** 2 / 6;
            const arcCoefficient = radius / 3;
            const answer = mode === 0 ? radius + sectorCoefficient : radius + sectorCoefficient + arcCoefficient;
            return makeShortAnswer({
              prompt: `반지름이 ${radius}이고 중심각이 $60^\\circ$인 부채꼴에서 현의 길이를 $c$, 호의 길이를 $a\\pi$, 넓이를 $b\\pi$라 하자. $${mode === 0 ? "b+c" : "a+b+c"}$의 값을 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? radius + radius ** 2 / 6 : radius / 3 + radius ** 2 / 6 + radius,
              solution: `중심각이 $60^\\circ$이므로 두 반지름과 현이 이루는 삼각형은 정삼각형이라 $c=${radius}$. 또 $a=${arcCoefficient}$, $b=${sectorCoefficient}$이므로 답은 ${answer}이다.`,
              hintText: "중심각이 60도이면 두 반지름과 현으로 이루어진 삼각형을 살펴보세요."
            });
          }
        }
      ];
      module.exports = {
        courseId,
        unitId,
        requiredConceptIds,
        minimumAppliedPoolSize: 15,
        appliedPolicy: {
          includeBankTypes: true,
          minimumLocalDifficulty: 3
        },
        advancedTemplates: defineAdvancedTemplates({
          courseId,
          unitId,
          requiredConceptIds,
          families
        })
      };
    }
  });

  // services/assessmentTemplates/algebra/sequences.js
  var require_sequences = __commonJS({
    "services/assessmentTemplates/algebra/sequences.js"(exports, module) {
      var {
        randomInteger,
        choose,
        fraction,
        power,
        signed,
        makeShortAnswer,
        defineAdvancedTemplates
      } = require_shared();
      var courseId = "algebra";
      var unitId = "sequences";
      var requiredConceptIds = [
        "algebra-03-01",
        "algebra-03-02",
        "algebra-03-03",
        "algebra-03-04",
        "algebra-03-05",
        "algebra-03-06",
        "algebra-03-07"
      ];
      function arithmeticTerm(first, difference, index) {
        return first + (index - 1) * difference;
      }
      function arithmeticSum(first, difference, count) {
        return count * (2 * first + (count - 1) * difference) / 2;
      }
      var families = [
        {
          id: "arithmetic-two-conditions",
          titles: [
            "두 항 조건에서 등차수열의 부분합 복원",
            "두 항 조건에서 등차수열의 특정 항 결합"
          ],
          sourcePattern: "서로 다른 두 항의 조건을 연립해 첫째항과 공차를 복원한 뒤 부분합 또는 항 결합 계산",
          estimatedMinutes: [10, 10],
          reasoningSteps: [
            [
              "일반항 a_n=a_1+(n-1)d를 세운다.",
              "두 항 조건을 연립해 공차를 구한다.",
              "첫째항을 복원한다.",
              "부분합 공식을 적용한다."
            ],
            [
              "두 일반항 식을 뺀다.",
              "공차를 구하고 첫째항을 찾는다.",
              "요구한 두 항을 각각 계산한다.",
              "항의 결합값을 구한다."
            ]
          ],
          generate(mode) {
            const first = randomInteger(-5, 6);
            const difference = choose([-3, -2, 2, 3, 4]);
            const p = randomInteger(2, 4);
            const q = p + randomInteger(3, 5);
            const target = q + 3;
            const answer = mode === 0 ? arithmeticSum(
              first,
              difference,
              target
            ) : arithmeticTerm(
              first,
              difference,
              target
            ) + arithmeticTerm(
              first,
              difference,
              p + 1
            );
            return makeShortAnswer({
              prompt: `등차수열 $\\{a_n\\}$이 $a_${p}=${arithmeticTerm(
                first,
                difference,
                p
              )}$, $a_${q}=${arithmeticTerm(
                first,
                difference,
                q
              )}$를 만족한다. ${mode === 0 ? `첫째항부터 제${target}항까지의 합` : `$a_${target}+a_${p + 1}$`}을 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? arithmeticSum(
                first,
                difference,
                target
              ) : arithmeticTerm(
                first,
                difference,
                target
              ) + arithmeticTerm(
                first,
                difference,
                p + 1
              ),
              solution: `두 식을 빼면 $(${q}-${p})d=${(q - p) * difference}$이므로 $d=${difference}$. $a_1=${first}$을 얻는다. ${mode === 0 ? `$S_${target}=\\frac{${target}}2\\{2(${first})+${target - 1}(${difference})\\}=${answer}$.` : `일반항을 대입하면 요구한 값은 ${answer}이다.`}`,
              hintText: "두 항의 차에서는 첫째항이 소거됩니다. 공차부터 구하세요."
            });
          }
        },
        {
          id: "partial-sum-two-values",
          titles: [
            "두 부분합에서 등차수열의 계수 복원",
            "부분합 조건으로 음수가 되는 첫 항 찾기"
          ],
          sourcePattern: "등차수열 부분합을 이차식으로 보고 두 조건에서 첫째항·공차 또는 부호 전환 시점 복원",
          estimatedMinutes: [11, 12],
          reasoningSteps: [
            [
              "등차수열의 부분합 공식을 쓴다.",
              "두 부분합 조건을 연립한다.",
              "첫째항과 공차를 구한다.",
              "목표 부분합을 계산한다."
            ],
            [
              "부분합 조건으로 수열을 복원한다.",
              "일반항을 구한다.",
              "부등식 a_n<0을 푼다.",
              "가장 작은 자연수 n을 고른다."
            ]
          ],
          generate(mode) {
            const first = randomInteger(6, 12);
            const difference = choose([-3, -2]);
            const m = 3;
            const n = 6;
            const target = 9;
            const firstNegative = Math.floor(
              first / -difference
            ) + 2;
            const answer = mode === 0 ? arithmeticSum(
              first,
              difference,
              target
            ) : firstNegative;
            return makeShortAnswer({
              prompt: `등차수열 $\\{a_n\\}$의 첫째항부터 제$n$항까지의 합을 $S_n$이라 하자. $S_${m}=${arithmeticSum(
                first,
                difference,
                m
              )}$, $S_${n}=${arithmeticSum(
                first,
                difference,
                n
              )}$일 때, ${mode === 0 ? `$S_${target}$` : "$a_n<0$이 되는 가장 작은 자연수 $n$"}을 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? arithmeticSum(
                first,
                difference,
                target
              ) : firstNegative,
              solution: `부분합 공식 두 식을 연립하면 $a_1=${first},d=${difference}$이다. ${mode === 0 ? `따라서 $S_${target}=${answer}$.` : `$a_n=${first}+(${difference})(n-1)<0$을 풀면 가장 작은 자연수는 ${answer}이다.`}`,
              hintText: "부분합 두 식을 첫째항과 공차에 대한 연립방정식으로 보세요."
            });
          }
        },
        {
          id: "geometric-reverse",
          titles: [
            "두 등비수열 항에서 공비와 부분합 복원",
            "등비수열 항의 곱 조건에서 중간항 복원"
          ],
          sourcePattern: "떨어진 두 항의 비 또는 곱을 이용해 공비·중간항을 찾고 합까지 연결",
          estimatedMinutes: [11, 10],
          reasoningSteps: [
            [
              "두 항의 비로 r의 거듭제곱을 만든다.",
              "양의 공비 조건으로 r을 결정한다.",
              "첫째항을 복원한다.",
              "등비수열의 합 공식을 적용한다."
            ],
            [
              "등비수열에서 같은 거리의 항 곱 성질을 찾는다.",
              "가운데 항의 제곱으로 바꾼다.",
              "양수 조건으로 가운데 항을 구한다.",
              "요구한 항 결합값을 계산한다."
            ]
          ],
          generate(mode) {
            const first = randomInteger(1, 4);
            const ratio = choose([2, 3]);
            const p = 2;
            const q = 5;
            const count = 6;
            const sum = first * (power(ratio, count) - 1) / (ratio - 1);
            const middle = first * power(ratio, 3);
            const answer = mode === 0 ? sum : middle;
            return makeShortAnswer({
              prompt: `모든 항이 양수인 등비수열 $\\{a_n\\}$에서 $a_${p}=${first * power(ratio, p - 1)}$, $a_${q}=${first * power(ratio, q - 1)}$이다. ${mode === 0 ? `$a_1+a_2+\\cdots+a_${count}$` : `$\\sqrt{a_2a_6}$`}의 값을 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? sum : Math.sqrt(
                first * ratio * (first * power(
                  ratio,
                  5
                ))
              ),
              solution: `$a_${q}/a_${p}=r^{${q - p}}=${power(
                ratio,
                q - p
              )}$이고 $r>0$이므로 $r=${ratio}$, $a_1=${first}$. ${mode === 0 ? `등비수열의 합은 ${sum}이다.` : `$a_2a_6=a_4^2$이고 모든 항이 양수이므로 $\\sqrt{a_2a_6}=a_4=${middle}$.`}`,
              hintText: "떨어진 두 항의 비로 공비의 거듭제곱을 먼저 구하세요."
            });
          }
        },
        {
          id: "partial-sum-polynomial",
          titles: [
            "부분합 다항식에서 일반항과 홀수항 합 복원",
            "부분합 식에서 특정 구간의 항 합 계산"
          ],
          sourcePattern: "S_n-S_{n-1}로 일반항을 복원하고 필요한 항만 다시 합하는 유형",
          estimatedMinutes: [11, 10],
          reasoningSteps: [
            [
              "a_1=S_1을 따로 확인한다.",
              "n≥2에서 a_n=S_n-S_{n-1}을 계산한다.",
              "홀수 번째 항의 일반식을 만든다.",
              "등차수열의 합으로 정리한다."
            ],
            [
              "부분합에서 일반항을 복원한다.",
              "구간합을 부분합의 차로도 표현한다.",
              "두 계산 경로가 일치하는지 확인한다.",
              "목표 구간합을 계산한다."
            ]
          ],
          generate(mode) {
            const c = randomInteger(
              -2,
              4
            );
            const m = randomInteger(4, 6);
            const partial = (n) => n ** 2 + c * n;
            const oddSum = Array.from(
              { length: m },
              (_, index) => {
                const n = 2 * index + 1;
                return 2 * n - 1 + c;
              }
            ).reduce(
              (sum, value) => sum + value,
              0
            );
            const rangeSum = partial(m + 3) - partial(2);
            const answer = mode === 0 ? oddSum : rangeSum;
            return makeShortAnswer({
              prompt: `수열 $\\{a_n\\}$의 첫째항부터 제$n$항까지의 합이 $S_n=n^2${signed(
                c
              )}n$이다. $${mode === 0 ? `a_1+a_3+\\cdots+a_${2 * m - 1}` : `a_3+a_4+\\cdots+a_${m + 3}`}$의 값을 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? oddSum : partial(m + 3) - partial(2),
              solution: `$a_n=S_n-S_{n-1}=2n${signed(
                c - 1
              )}$이다. ${mode === 0 ? `홀수 번째 지수를 대입해 ${m}개 항을 합하면 ${answer}이다.` : `또는 바로 $S_${m + 3}-S_2=${answer}$로 계산할 수 있다.`}`,
              hintText: "일반항은 부분합의 이웃한 두 값의 차입니다."
            });
          }
        },
        {
          id: "periodic-recurrence",
          titles: [
            "주기 2 점화식의 장기 합",
            "주기 점화식의 특정 항과 부분합 결합"
          ],
          sourcePattern: "점화식을 여러 번 적용해 짧은 주기를 발견하고 큰 지수의 항·합을 블록으로 계산",
          estimatedMinutes: [12, 12],
          reasoningSteps: [
            [
              "점화식으로 앞의 몇 항을 계산한다.",
              "a_{n+2}=a_n인 주기를 증명한다.",
              "두 항씩 묶은 합을 구한다.",
              "블록 수를 이용해 전체 합을 계산한다."
            ],
            [
              "초기 항에서 주기 2를 찾는다.",
              "목표 항의 홀짝을 판정한다.",
              "완전한 두 항 블록의 합을 계산한다.",
              "목표 항과 부분합을 결합한다."
            ]
          ],
          generate(mode) {
            const constant = randomInteger(5, 12);
            const first = randomInteger(
              1,
              constant - 1
            );
            const pairs = randomInteger(8, 14);
            const evenCount = 2 * pairs;
            const answer = mode === 0 ? pairs * constant : pairs * constant + first;
            return makeShortAnswer({
              prompt: `수열 $\\{a_n\\}$이 $a_1=${first}$, $a_{n+1}=${constant}-a_n$을 만족한다. $${mode === 0 ? `\\sum_{k=1}^{${evenCount}}a_k` : `\\sum_{k=1}^{${evenCount}}a_k+a_${evenCount + 1}`}$의 값을 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? pairs * constant : pairs * constant + first,
              solution: `$a_{n+2}=${constant}-a_{n+1}=a_n$이므로 주기는 2이고 $a_{2j-1}+a_{2j}=${constant}$이다. 완전한 블록이 ${pairs}개이며 ${mode === 0 ? "" : `$a_${evenCount + 1}=a_1=${first}$이므로 `}답은 ${answer}이다.`,
              hintText: "점화식을 두 번 연속 적용해 a_{n+2}와 a_n을 비교하세요."
            });
          }
        },
        {
          id: "weighted-arithmetic-sum",
          titles: [
            "등차수열과 자연수의 가중합",
            "홀수 가중치를 곱한 등차수열의 합"
          ],
          sourcePattern: "등차수열의 일반항을 복원한 뒤 자연수 또는 홀수 가중치를 곱해 시그마 공식으로 합산",
          estimatedMinutes: [12, 13],
          reasoningSteps: [
            [
              "두 항 조건으로 첫째항과 공차를 구한다.",
              "일반항을 n의 일차식으로 나타낸다.",
              "k a_k를 이차식으로 전개한다.",
              "자연수의 합과 제곱의 합을 적용한다."
            ],
            [
              "등차수열의 일반항을 구한다.",
              "(2k-1)a_k를 이차식으로 정리한다.",
              "필요한 시그마 공식을 각각 적용한다.",
              "합친 값을 직접 합산해 검산한다."
            ]
          ],
          generate(mode) {
            const first = randomInteger(1, 5);
            const difference = choose([2, 3]);
            const count = randomInteger(5, 8);
            const weight = (index) => mode === 0 ? index : 2 * index - 1;
            const answer = Array.from(
              { length: count },
              (_, index) => weight(index + 1) * arithmeticTerm(
                first,
                difference,
                index + 1
              )
            ).reduce(
              (sum, value) => sum + value,
              0
            );
            return makeShortAnswer({
              prompt: `등차수열 $\\{a_n\\}$이 $a_1=${first}$, $a_4=${arithmeticTerm(first, difference, 4)}$를 만족한다. $\\sum_{k=1}^{${count}}${mode === 0 ? "k" : "(2k-1)"}a_k$의 값을 구하시오.`,
              answer,
              independentAnswer: Array.from(
                { length: count },
                (_, index) => weight(index + 1) * (first + index * difference)
              ).reduce(
                (sum, value) => sum + value,
                0
              ),
              solution: `$a_n=${first}${signed(difference)}(n-1)$이고 이를 합 안에 대입한다. $\\sum k=${count * (count + 1) / 2}$, $\\sum k^2=${count * (count + 1) * (2 * count + 1) / 6}$을 이용해 정리하면 ${answer}이다.`,
              hintText: "일반항을 먼저 구한 뒤 가중치와 곱해 k의 다항식으로 전개하세요."
            });
          }
        },
        {
          id: "geometric-block-sums",
          titles: [
            "등비수열의 연속 블록 합 비율",
            "두 블록 합에서 공비와 다음 블록 합 복원"
          ],
          sourcePattern: "길이가 같은 연속 구간의 합이 공비의 거듭제곱배가 된다는 성질로 다음 블록을 계산",
          estimatedMinutes: [11, 12],
          reasoningSteps: [
            [
              "첫 블록을 등비수열의 합으로 나타낸다.",
              "다음 블록의 각 항이 공비의 일정 거듭제곱배임을 확인한다.",
              "두 블록 합의 비를 계산한다.",
              "주어진 첫 블록 합으로 목표 합을 구한다."
            ],
            [
              "같은 길이 블록 사이의 배율을 구한다.",
              "양의 공비 조건에서 공비를 복원한다.",
              "다음 블록에도 같은 배율을 적용한다.",
              "요구한 두 블록 합의 차를 계산한다."
            ]
          ],
          generate(mode) {
            const ratio = choose([2, 3]);
            const block = choose([2, 3]);
            const first = randomInteger(1, 3);
            const blockSum = (start) => Array.from(
              { length: block },
              (_, index) => first * power(
                ratio,
                start + index - 1
              )
            ).reduce(
              (sum, value) => sum + value,
              0
            );
            const firstBlock = blockSum(1);
            const secondBlock = blockSum(block + 1);
            const thirdBlock = blockSum(2 * block + 1);
            const answer = mode === 0 ? secondBlock : thirdBlock - secondBlock;
            return makeShortAnswer({
              prompt: `공비가 양수인 등비수열 $\\{a_n\\}$에서 $a_1+\\cdots+a_${block}=${firstBlock}$, $a_${block + 1}=${power(ratio, block)}a_1$이다. $${mode === 0 ? `a_${block + 1}+\\cdots+a_${2 * block}` : `(a_${2 * block + 1}+\\cdots+a_${3 * block})-(a_${block + 1}+\\cdots+a_${2 * block})`}$의 값을 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? firstBlock * power(ratio, block) : firstBlock * power(
                ratio,
                2 * block
              ) - firstBlock * power(ratio, block),
              solution: `$r^{${block}}=${power(ratio, block)}$이고 $r>0$이므로 $r=${ratio}$. 길이가 ${block}인 다음 블록의 합은 앞 블록 합의 $r^{${block}}=${power(ratio, block)}$배이다. ${mode === 0 ? "" : `따라서 셋째 블록 합은 ${thirdBlock}이고 `}요구한 값은 ${answer}이다.`,
              hintText: "같은 길이만큼 지수가 이동하면 블록 전체에 같은 r의 거듭제곱이 곱해집니다."
            });
          }
        },
        {
          id: "telescoping-reciprocal-sum",
          titles: [
            "부분분수 분해로 소거되는 수열의 합",
            "간격이 있는 역수 곱의 망원합"
          ],
          sourcePattern: "연속하거나 일정 간격인 두 일차식의 곱을 부분분수로 분해해 중간항을 소거",
          estimatedMinutes: [12, 13],
          reasoningSteps: [
            [
              "일반항을 두 단위분수의 차로 분해한다.",
              "앞의 몇 항을 써 소거 구조를 확인한다.",
              "처음과 마지막에 남는 항만 모은다.",
              "기약분수로 정리한다."
            ],
            [
              "1/((k+c)(k+c+d))를 간격 d를 반영해 분해한다.",
              "시그마를 두 합의 차로 나눈다.",
              "겹치는 중간항을 소거한다.",
              "경계항을 통분해 답을 구한다."
            ]
          ],
          generate(mode) {
            const count = randomInteger(5, 10);
            const gap = mode === 0 ? 1 : 2;
            const start = randomInteger(1, 3);
            let numerator = 0;
            let denominator = 1;
            for (let index = 1; index <= count; index += 1) {
              const termDenominator = (index + start) * (index + start + gap);
              numerator = numerator * termDenominator + denominator;
              denominator *= termDenominator;
              const divisor = (function common(left, right) {
                return right ? common(
                  right,
                  left % right
                ) : Math.abs(left);
              })(numerator, denominator);
              numerator /= divisor;
              denominator /= divisor;
            }
            const answer = fraction(
              numerator,
              denominator
            );
            return makeShortAnswer({
              prompt: `$\\sum_{k=1}^{${count}}\\dfrac{1}{(k+${start})(k+${start + gap})}$의 값을 구하시오. (기약분수로 입력)`,
              answer,
              independentAnswer: fraction(
                numerator,
                denominator
              ),
              solution: `일반항은 $\\dfrac1{${gap}}\\{\\dfrac1{k+${start}}-\\dfrac1{k+${start + gap}}\\}$로 분해된다. 중간항을 소거하고 경계항을 합치면 $${answer}$이다.`,
              hintText: "분모의 두 일차식 각각을 분모로 갖는 두 분수의 차로 바꾸세요."
            });
          }
        },
        {
          id: "affine-recurrence-shift",
          titles: [
            "상수 평행이동으로 등비수열이 되는 점화식",
            "일차 점화식의 불변점과 부분합"
          ],
          sourcePattern: "a_{n+1}=ra_n+c의 불변점을 찾아 수열을 평행이동한 뒤 등비수열로 해석",
          estimatedMinutes: [13, 14],
          reasoningSteps: [
            [
              "점화식의 불변점 L을 구한다.",
              "b_n=a_n-L로 새 수열을 정의한다.",
              "b_n이 등비수열임을 확인한다.",
              "일반항을 복원해 목표 항을 계산한다."
            ],
            [
              "상수항이 사라지는 평행이동량을 찾는다.",
              "변환한 등비수열의 일반항을 구한다.",
              "원래 수열의 부분합을 등비합과 상수합으로 나눈다.",
              "두 합을 결합해 답을 구한다."
            ]
          ],
          generate(mode) {
            const ratio = choose([2, 3]);
            const fixed = randomInteger(1, 4);
            const first = fixed + randomInteger(1, 3);
            const count = randomInteger(5, 7);
            const term = (index) => fixed + (first - fixed) * power(
              ratio,
              index - 1
            );
            const answer = mode === 0 ? term(count) : Array.from(
              { length: count },
              (_, index) => term(index + 1)
            ).reduce(
              (sum, value) => sum + value,
              0
            );
            return makeShortAnswer({
              prompt: `수열 $\\{a_n\\}$이 $a_1=${first}$, $a_{n+1}=${ratio}a_n${signed((1 - ratio) * fixed)}$을 만족한다. $${mode === 0 ? `a_${count}` : `\\sum_{k=1}^{${count}}a_k`}$의 값을 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? fixed + (first - fixed) * power(
                ratio,
                count - 1
              ) : count * fixed + (first - fixed) * (power(ratio, count) - 1) / (ratio - 1),
              solution: `$b_n=a_n-${fixed}$라 하면 $b_{n+1}=${ratio}b_n$이고 $b_1=${first - fixed}$. $a_n=${fixed}+${first - fixed}\\cdot${ratio}^{n-1}$이므로 요구한 값은 ${answer}이다.`,
              hintText: "점화식에 대입해도 그대로 유지되는 상수값을 찾아 빼 보세요."
            });
          }
        },
        {
          id: "arithmetic-geometric-sum",
          titles: [
            "등차·등비가 섞인 합의 이동 소거",
            "k와 지수항의 곱을 포함한 시그마"
          ],
          sourcePattern: "등차계수와 등비항이 곱해진 합에 공비를 곱하고 한 칸 이동해 두 식을 빼는 유형",
          estimatedMinutes: [14, 15],
          reasoningSteps: [
            [
              "구하려는 합을 S로 둔다.",
              "S에 공비를 곱해 항을 한 칸 맞춘다.",
              "두 식을 빼 중간의 등비항을 정리한다.",
              "등비수열의 합을 적용해 S를 구한다."
            ],
            [
              "k r^{k-1} 형태의 합을 쓴다.",
              "공비를 곱한 식과 원식을 뺀다.",
              "남은 상수배 등비합을 계산한다.",
              "끝항을 포함해 최종값을 검산한다."
            ]
          ],
          generate(mode) {
            const ratio = choose([2, 3]);
            const count = randomInteger(5, 7);
            const answer = Array.from(
              { length: count },
              (_, index) => {
                const k = index + 1;
                return (mode === 0 ? k : 2 * k - 1) * power(ratio, k - 1);
              }
            ).reduce(
              (sum, value) => sum + value,
              0
            );
            return makeShortAnswer({
              prompt: `$\\sum_{k=1}^{${count}}${mode === 0 ? "k" : "(2k-1)"}\\cdot${ratio}^{k-1}$의 값을 구하시오.`,
              answer,
              independentAnswer: Array.from(
                { length: count },
                (_, index) => (mode === 0 ? index + 1 : 2 * index + 1) * power(ratio, index)
              ).reduce(
                (sum, value) => sum + value,
                0
              ),
              solution: `주어진 합을 $S$라 하고 ${ratio}S를 한 항씩 밀어 쓴 뒤 두 식을 뺀다. 남은 등비수열의 합과 마지막 항을 정리하면 $S=${answer}$이다.`,
              hintText: "합 전체에 공비를 곱한 식을 원래 식과 위아래로 맞춰 빼세요."
            });
          }
        }
      ];
      module.exports = {
        courseId,
        unitId,
        requiredConceptIds,
        minimumAppliedPoolSize: 15,
        appliedPolicy: {
          includeBankTypes: true,
          minimumLocalDifficulty: 3
        },
        advancedTemplates: defineAdvancedTemplates({
          courseId,
          unitId,
          requiredConceptIds,
          families
        })
      };
    }
  });

  // services/assessmentTemplates/calculus1/limitsAndContinuity.js
  var require_limitsAndContinuity = __commonJS({
    "services/assessmentTemplates/calculus1/limitsAndContinuity.js"(exports, module) {
      var {
        randomInteger,
        choose,
        fraction,
        polynomialTex,
        linearFactor,
        signed,
        makeShortAnswer,
        defineAdvancedTemplates
      } = require_shared();
      var courseId = "calculus-1";
      var unitId = "limits-and-continuity";
      var requiredConceptIds = [
        "calculus-1-01-01",
        "calculus-1-01-02",
        "calculus-1-01-03",
        "calculus-1-01-04"
      ];
      var families = [
        {
          id: "finite-limit-parameter",
          titles: [
            "유한한 극한 조건에서 이차식 계수 복원",
            "인수 소거와 극한값으로 매개변수 결합값 결정"
          ],
          sourcePattern: "0/0 꼴이 유한한 값을 갖는 조건과 약분 후 극한값을 차례로 사용",
          estimatedMinutes: [10, 11],
          reasoningSteps: [
            [
              "극한이 유한하려면 분자가 경계점에서 0이어야 함을 사용한다.",
              "분자 계수 사이 첫 관계를 구한다.",
              "인수분해·약분 후 극한값으로 두 번째 관계를 구한다.",
              "두 계수를 복원해 결합값을 계산한다."
            ],
            [
              "분모가 0이 되는 점에서 분자도 0이 되게 한다.",
              "나머지정리로 한 계수를 다른 계수로 나타낸다.",
              "약분된 일차식의 극한을 주어진 값과 비교한다.",
              "요구한 계수식을 계산한다."
            ]
          ],
          generate(mode) {
            const point = randomInteger(-3, 3);
            const other = point + choose([-4, -2, 2, 4]);
            const linear = -(point + other);
            const constant = point * other;
            const limit = point - other;
            const answer = mode === 0 ? linear + constant : linear * constant;
            return makeShortAnswer({
              prompt: `이차식 $f(x)=x^2+mx+n$에 대하여 $\\displaystyle\\lim_{x\\to ${point}}\\dfrac{f(x)}{${linearFactor(
                point
              )}}=${limit}$이다. $${mode === 0 ? "m+n" : "mn"}$의 값을 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? linear + constant : linear * constant,
              solution: `극한이 유한하므로 $f(${point})=0$. 또 분자를 $(${linearFactor(
                point
              )})(${linearFactor(
                other
              )})$로 쓰면 약분 후 극한은 $(${point})-(${other})=${limit}$. 따라서 $m=${linear}$, $n=${constant}$이고 답은 ${answer}이다.`,
              hintText: "먼저 분자가 분모와 같은 인수를 가져야 한다는 조건을 사용하세요."
            });
          }
        },
        {
          id: "two-boundary-continuity",
          titles: [
            "두 경계점 연속 조건의 매개변수 연립",
            "세 구간 함수의 연속 조건에서 끝 식 복원"
          ],
          sourcePattern: "세 구간으로 정의된 함수가 두 경계에서 연속이라는 조건을 각각 세워 연립",
          estimatedMinutes: [12, 12],
          reasoningSteps: [
            [
              "첫 경계점에서 좌극한과 가운데 식의 값을 같게 둔다.",
              "둘째 경계점에서 가운데 식과 우극한을 같게 둔다.",
              "두 매개변수를 각각 구한다.",
              "요구한 결합값을 계산한다."
            ],
            [
              "각 경계의 일방극한을 구한다.",
              "함숫값과 두 일방극한의 일치를 식으로 만든다.",
              "상수항 두 개를 복원한다.",
              "두 값의 곱을 계산한다."
            ]
          ],
          generate(mode) {
            const leftBoundary = -1;
            const rightBoundary = 2;
            const quadratic = [
              randomInteger(-3, 3),
              randomInteger(-3, 3),
              1
            ];
            const middleAtLeft = quadratic[0] - quadratic[1] + 1;
            const middleAtRight = quadratic[0] + 2 * quadratic[1] + 4;
            const leftSlope = randomInteger(1, 4);
            const rightSlope = randomInteger(-3, 3);
            const leftConstant = middleAtLeft + leftSlope;
            const rightConstant = middleAtRight - 2 * rightSlope;
            const answer = mode === 0 ? leftConstant + rightConstant : leftConstant * rightConstant;
            return makeShortAnswer({
              prompt: `함수 $f(x)=\\begin{cases}${leftSlope}x+p&(x<${leftBoundary})\\\\${polynomialTex(
                quadratic
              )}&(${leftBoundary}\\le x<${rightBoundary})\\\\${rightSlope}x+q&(x\\ge${rightBoundary})\\end{cases}$가 실수 전체에서 연속일 때, $${mode === 0 ? "p+q" : "pq"}$의 값을 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? leftConstant + rightConstant : leftConstant * rightConstant,
              solution: `$x=${leftBoundary}$에서 연속 조건으로 $p=${leftConstant}$, $x=${rightBoundary}$에서 연속 조건으로 $q=${rightConstant}$을 얻는다. 두 경계 조건은 서로 독립이며 답은 ${answer}이다.`,
              hintText: "두 경계점마다 왼쪽 식과 오른쪽 식의 값을 따로 같게 두세요."
            });
          }
        },
        {
          id: "radical-infinity-next-order",
          titles: [
            "무한대 유리화 극한에서 매개변수 복원",
            "두 무리식 극한의 차를 유리화해 계수 결정"
          ],
          sourcePattern: "무한대로 가는 무리식의 ∞-∞ 꼴을 유리화하고 최고차항으로 극한 계산",
          estimatedMinutes: [10, 11],
          reasoningSteps: [
            [
              "∞-∞ 꼴임을 확인한다.",
              "켤레식을 곱해 유리화한다.",
              "분자·분모를 x로 나눈다.",
              "극한값과 비교해 매개변수를 구한다."
            ],
            [
              "두 무리식 각각을 유리화한다.",
              "각 극한을 일차항 계수의 절반으로 바꾼다.",
              "주어진 극한 차로 계수 관계를 구한다.",
              "요구한 계수 결합값을 계산한다."
            ]
          ],
          generate(mode) {
            const first = choose([2, 4, 6, 8]);
            const second = choose([2, 4, 6]);
            const firstLimit = first / 2;
            const secondLimit = second / 2;
            const answer = mode === 0 ? first : first + second;
            return makeShortAnswer({
              prompt: mode === 0 ? `$\\displaystyle\\lim_{x\\to\\infty}(\\sqrt{x^2+kx+${randomInteger(
                1,
                5
              )}}-x)=${firstLimit}$일 때, 상수 $k$의 값을 구하시오.` : `$\\displaystyle\\lim_{x\\to\\infty}\\{(\\sqrt{x^2+${first}x+1}-x)-(\\sqrt{x^2+kx+4}-x)\\}=${firstLimit - secondLimit}$일 때, $${first}+k$의 값을 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? 2 * firstLimit : first + second,
              solution: mode === 0 ? `켤레식으로 유리화하면 극한은 $k/2$이다. $k/2=${firstLimit}$이므로 $k=${first}$.` : `각 무리식을 유리화한 극한은 일차항 계수의 절반이다. 따라서 $(${first}-k)/2=${firstLimit - secondLimit}$에서 $k=${second}$이고 답은 ${answer}이다.`,
              hintText: "켤레식을 곱한 뒤 분자와 분모를 x로 나누세요."
            });
          }
        },
        {
          id: "absolute-one-sided-limit",
          titles: [
            "절댓값 좌우극한으로 매개변수 결정",
            "절댓값 포함 구간별 극한의 존재 조건"
          ],
          sourcePattern: "|x-a|/(x-a)의 좌우 부호 차이를 이용해 일방극한과 극한 존재 조건을 해석",
          estimatedMinutes: [10, 11],
          reasoningSteps: [
            [
              "x<a와 x>a에서 절댓값을 각각 푼다.",
              "좌극한을 계산한다.",
              "우극한을 계산한다.",
              "주어진 일방극한 값으로 매개변수를 정한다."
            ],
            [
              "절댓값 식을 좌우 구간으로 나눈다.",
              "두 일방극한을 각각 매개변수로 표현한다.",
              "극한 존재 조건으로 두 값을 같게 둔다.",
              "매개변수 결합값을 계산한다."
            ]
          ],
          generate(mode) {
            const point = randomInteger(-3, 3);
            const coefficient = randomInteger(2, 6);
            const constant = randomInteger(-4, 4);
            const leftLimit = -coefficient + constant;
            const rightLimit = coefficient + constant;
            const answer = mode === 0 ? coefficient : constant;
            return makeShortAnswer({
              prompt: mode === 0 ? `함수 $f(x)=k\\dfrac{|${linearFactor(
                point
              )}|}{${linearFactor(
                point
              )}}${constant >= 0 ? "+" : ""}${constant}$에 대하여 $\\displaystyle\\lim_{x\\to ${point}^{-}}f(x)=${leftLimit}$, $k>0$일 때 $k$를 구하시오.` : `함수 $f(x)=\\dfrac{|${linearFactor(
                point
              )}|}{${linearFactor(
                point
              )}}+c$의 좌극한과 우극한의 합이 ${2 * constant}일 때 $c$를 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? constant - leftLimit : constant,
              solution: `$x<${point}$에서는 $|${linearFactor(
                point
              )}|/(${linearFactor(
                point
              )})=-1$, $x>${point}$에서는 1이다. ${mode === 0 ? `좌극한은 $-k${constant >= 0 ? "+" : ""}${constant}=${leftLimit}$이므로 $k=${coefficient}$.` : `두 일방극한은 $-1+c$, $1+c$이고 합은 $2c=${2 * constant}$이므로 $c=${constant}$.`}`,
              hintText: "절댓값 안의 식이 양수인지 음수인지 경계의 양쪽에서 따로 판단하세요."
            });
          }
        },
        {
          id: "intermediate-value-interval",
          titles: [
            "중간값 정리로 근이 보장되는 단위구간 판정",
            "연속함수의 부호표에서 서로 다른 근의 최소 개수"
          ],
          sourcePattern: "연속성과 양 끝값의 부호 변화를 결합해 근의 존재 구간 또는 최소 개수를 판정",
          estimatedMinutes: [12, 12],
          reasoningSteps: [
            [
              "함수가 연속임을 확인한다.",
              "후보 정수점에서 함수값의 부호를 계산한다.",
              "부호가 바뀌는 인접 구간을 찾는다.",
              "중간값 정리로 근이 보장되는 구간 수를 센다."
            ],
            [
              "주어진 점들을 x좌표 순서로 배열한다.",
              "이웃한 함수값의 부호를 비교한다.",
              "서로 겹치지 않는 부호 변화 구간을 고른다.",
              "각 구간의 근 존재를 합해 최소 개수를 구한다."
            ]
          ],
          generate(mode) {
            const roots = [
              -2.5,
              0.5,
              3.5
            ];
            const value = (x) => (x - roots[0]) * (x - roots[1]) * (x - roots[2]);
            const intervals = [
              [-3, -2],
              [0, 1],
              [3, 4]
            ];
            const signs = [
              -3,
              -2,
              0,
              1,
              3,
              4
            ].map((x) => ({
              x,
              value: value(x)
            }));
            const answer = 3;
            return makeShortAnswer({
              prompt: mode === 0 ? `연속함수 $f(x)=(2x+5)(2x-1)(2x-7)$에 대하여 열린구간 $(-3,-2),(0,1),(3,4)$ 중 중간값 정리로 $f(x)=0$의 해가 존재함이 보장되는 구간의 개수를 구하시오.` : `연속함수 $f$가 ${signs.map(
                ({ x, value: y }) => `$f(${x})=${y > 0 ? 1 : -1}$`
              ).join(", ")}을 만족할 때, $f(x)=0$의 서로 다른 실근의 최소 개수를 구하시오.`,
              answer,
              independentAnswer: intervals.filter(
                ([left, right]) => value(left) * value(right) < 0
              ).length,
              solution: `각 인접 구간의 양 끝에서 함수값의 부호가 반대이고 함수가 연속이다. 세 구간은 서로 겹치지 않으므로 각 구간마다 적어도 한 근이 존재한다. 따라서 답은 3이다.`,
              hintText: "연속함수의 양 끝값 곱이 음수인 서로 겹치지 않는 구간을 찾으세요."
            });
          }
        },
        {
          id: "composed-limit-recovery",
          titles: [
            "합·곱의 극한에서 두 함수의 극한 복원",
            "두 극한 관계에서 합성 유리식의 극한 계산"
          ],
          sourcePattern: "두 함수의 합과 곱의 극한으로 각각의 극한값을 복원하고 유리식에 대입",
          estimatedMinutes: [11, 12],
          reasoningSteps: [
            [
              "두 함수의 극한값을 u,v로 둔다.",
              "합과 곱 조건으로 이차방정식을 만든다.",
              "대소 조건으로 u,v의 순서를 정한다.",
              "목표 유리식의 극한에 대입한다."
            ],
            [
              "극한의 사칙연산으로 u+v와 uv를 읽는다.",
              "u,v를 두 근으로 갖는 방정식을 푼다.",
              "추가 조건으로 각 값을 구분한다.",
              "분모가 0이 아님을 확인하고 목표 극한을 계산한다."
            ]
          ],
          generate(mode) {
            const low = randomInteger(1, 3);
            const high = low + randomInteger(2, 4);
            const answer = mode === 0 ? fraction(
              high + 1,
              low + 1
            ) : fraction(
              high ** 2 + low,
              high - low
            );
            return makeShortAnswer({
              prompt: `함수 $f,g$에 대하여 $\\lim_{x\\to a}\\{f(x)+g(x)\\}=${low + high}$, $\\lim_{x\\to a}f(x)g(x)=${low * high}$이고 $\\lim_{x\\to a}f(x)>\\lim_{x\\to a}g(x)$이다. $\\displaystyle\\lim_{x\\to a}${mode === 0 ? "\\dfrac{f(x)+1}{g(x)+1}" : "\\dfrac{f(x)^2+g(x)}{f(x)-g(x)}"}$의 값을 구하시오. (기약분수로 입력)`,
              answer,
              independentAnswer: mode === 0 ? fraction(
                high + 1,
                low + 1
              ) : fraction(
                high ** 2 + low,
                high - low
              ),
              solution: `두 극한값을 $u>v$라 하면 $u+v=${low + high}$, $uv=${low * high}$이므로 $u=${high},v=${low}$. 목표식에 대입하면 $${answer}$이다.`,
              hintText: "두 극한값을 이차방정식의 두 근으로 복원하세요."
            });
          }
        },
        {
          id: "infinity-leading-next-order",
          titles: [
            "무한대 극한의 최고차항과 다음 계수 복원",
            "두 무한대 극한으로 유리함수 계수 결정"
          ],
          sourcePattern: "유리함수의 무한대 극한에서 최고차항 비를 먼저 정하고 차를 곱한 다음 극한으로 다음 차수 계수를 결정",
          estimatedMinutes: [13, 14],
          reasoningSteps: [
            [
              "첫 극한에서 최고차항 계수의 비를 구한다.",
              "유리함수에서 그 극한값을 빼 통분한다.",
              "x를 곱한 뒤 남는 최고차항을 비교한다.",
              "두 계수의 결합값을 계산한다."
            ],
            [
              "분자와 분모를 x²으로 나눠 첫 매개변수를 찾는다.",
              "극한값과 함수의 차를 한 분수로 합친다.",
              "다음 차수 항의 계수로 두 번째 매개변수를 구한다.",
              "원식의 두 조건을 다시 확인한다."
            ]
          ],
          generate(mode) {
            const leading = randomInteger(2, 5);
            const next = randomInteger(-4, 4);
            const constant = randomInteger(1, 5);
            const answer = mode === 0 ? leading + next : leading * next;
            return makeShortAnswer({
              prompt: `함수 $F(x)=\\dfrac{ax^2+bx+${constant}}{x^2+1}$이 $\\lim_{x\\to\\infty}F(x)=${leading}$, $\\lim_{x\\to\\infty}x\\{F(x)-${leading}\\}=${next}$를 만족한다. $${mode === 0 ? "a+b" : "ab"}$의 값을 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? leading + next : leading * next,
              solution: `첫 극한에서 $a=${leading}$. 이를 대입하면 $x(F-${leading})=\\dfrac{${next}x^2${signed(constant - leading)}x}{x^2+1}$ 꼴이므로 둘째 극한에서 $b=${next}$. 따라서 답은 ${answer}이다.`,
              hintText: "첫 극한으로 최고차항 계수를 정한 뒤 그 극한값을 함수에서 빼세요."
            });
          }
        },
        {
          id: "two-removable-holes",
          titles: [
            "두 약분 가능 불연속점의 연속 확장값",
            "두 구멍을 메운 함수값의 결합"
          ],
          sourcePattern: "분자·분모의 공통인수를 약분한 뒤 원래 정의되지 않은 두 점의 극한으로 연속 확장",
          estimatedMinutes: [12, 13],
          reasoningSteps: [
            [
              "분자와 분모의 공통인수를 찾는다.",
              "두 점을 제외한 구간에서 식을 약분한다.",
              "각 구멍에서 약분된 식의 극한을 구한다.",
              "두 연속 확장값을 결합한다."
            ],
            [
              "원래 식의 정의되지 않는 두 점을 확인한다.",
              "공통 이차인수를 제거한다.",
              "연속이 되기 위한 두 함수값을 각각 결정한다.",
              "두 값의 곱 또는 차를 계산한다."
            ]
          ],
          generate(mode) {
            const left = randomInteger(-3, -1);
            const right = randomInteger(1, 4);
            const slope = choose([2, 3]);
            const intercept = randomInteger(1, 5);
            const leftValue = slope * left + intercept;
            const rightValue = slope * right + intercept;
            const answer = mode === 0 ? leftValue + rightValue : leftValue * rightValue;
            return makeShortAnswer({
              prompt: `함수 $f$가 $x\\ne${left},${right}$에서 $f(x)=\\dfrac{(${linearFactor(left)})(${linearFactor(right)})(${slope}x${signed(intercept)})}{(${linearFactor(left)})(${linearFactor(right)})}$이고, 모든 실수에서 연속이 되도록 정의된다. $${mode === 0 ? `f(${left})+f(${right})` : `f(${left})f(${right})`}$의 값을 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? slope * (left + right) + 2 * intercept : (slope * left + intercept) * (slope * right + intercept),
              solution: `두 공통인수를 약분하면 $f(x)=${slope}x${signed(intercept)}$이다. 연속 확장값은 $f(${left})=${leftValue}$, $f(${right})=${rightValue}$이므로 답은 ${answer}이다.`,
              hintText: "정의되지 않은 점을 바로 대입하지 말고 먼저 공통인수를 약분하세요."
            });
          }
        },
        {
          id: "absolute-value-continuity-parameter",
          titles: [
            "절댓값 분기점에서 연속이 되는 매개변수",
            "절댓값 함수와 일차함수의 접합 조건"
          ],
          sourcePattern: "절댓값의 분기점 양쪽 식을 나누고 함수값·좌우극한 일치 조건으로 매개변수를 결정",
          estimatedMinutes: [11, 12],
          reasoningSteps: [
            [
              "절댓값 안의 식이 바뀌는 경계점을 찾는다.",
              "왼쪽과 오른쪽 식을 각각 전개한다.",
              "경계에서 좌우극한과 함수값을 같게 놓는다.",
              "매개변수의 결합값을 계산한다."
            ],
            [
              "접합점 양쪽의 함수식을 분리한다.",
              "각 일방극한을 계산한다.",
              "연속 조건으로 미지 계수를 구한다.",
              "다른 점의 함숫값에 대입해 검산한다."
            ]
          ],
          generate(mode) {
            const point = randomInteger(1, 5);
            const slope = choose([2, 3, 4]);
            const value = randomInteger(-3, 5);
            const intercept = value - slope * point;
            const answer = mode === 0 ? intercept : value + intercept;
            return makeShortAnswer({
              prompt: `함수 $f(x)=\\begin{cases}${slope}x+b,&x<${point}\\\\|x-${point}|${signed(value)},&x\\ge${point}\\end{cases}$가 $x=${point}$에서 연속일 때, $${mode === 0 ? "b" : `b+f(${point})`}$의 값을 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? value - slope * point : 2 * value - slope * point,
              solution: `오른쪽 식에서 $f(${point})=${value}$. 왼쪽 극한은 $${slope * point}+b$이므로 $${slope * point}+b=${value}$, $b=${intercept}$. 따라서 답은 ${answer}이다.`,
              hintText: "접합점에서 왼쪽 극한과 실제 함수값을 같게 놓으세요."
            });
          }
        },
        {
          id: "bisection-sign-certification",
          titles: [
            "중간값 정리와 이분 탐색으로 근의 구간 좁히기",
            "함숫값 부호표에서 보장되는 근 구간 판정"
          ],
          sourcePattern: "연속함수의 부호가 바뀌는 구간을 찾고 중점을 추가 조사해 근의 위치를 더 좁히는 유형",
          estimatedMinutes: [13, 13],
          reasoningSteps: [
            [
              "다항함수의 연속성을 확인한다.",
              "초기 구간 양 끝의 부호를 계산한다.",
              "중점의 함수값 부호를 계산한다.",
              "부호가 다른 절반 구간의 끝점 합을 구한다."
            ],
            [
              "주어진 부호표를 x좌표 순서로 정렬한다.",
              "서로 겹치지 않는 부호 변화 구간을 찾는다.",
              "중간점 정보로 한 구간을 절반으로 줄인다.",
              "새 구간을 나타내는 지표를 계산한다."
            ]
          ],
          generate(mode) {
            const root = randomInteger(1, 5) + choose([0.25, 0.75]);
            const left = Math.floor(root);
            const middle = left + 0.5;
            const right = left + 1;
            const narrowLeft = root < middle ? left : middle;
            const narrowRight = root < middle ? middle : right;
            const scale = 4;
            const answer = mode === 0 ? scale * (narrowLeft + narrowRight) : scale * (narrowRight - narrowLeft);
            return makeShortAnswer({
              prompt: `연속함수 $f(x)=4x-${4 * root}$의 영점을 포함하는 구간 $(${left},${right})$을 이분한다. 중점에서의 함수값 부호까지 이용해 얻는 길이 $1/2$인 구간을 $(a,b)$라 할 때, $${mode === 0 ? "4(a+b)" : "4(b-a)"}$의 값을 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? 4 * (narrowLeft + narrowRight) : 4 * (narrowRight - narrowLeft),
              solution: `$f(${left})<0<f(${right})$이고 $f(${middle})$의 부호를 조사하면 근은 $(${narrowLeft},${narrowRight})$에 있다. 따라서 답은 ${answer}이다.`,
              hintText: "중점의 함수값이 어느 끝점과 같은 부호인지 확인하고 그쪽 절반을 버리세요."
            });
          }
        }
      ];
      module.exports = {
        courseId,
        unitId,
        requiredConceptIds,
        minimumAppliedPoolSize: 15,
        appliedPolicy: {
          includeBankTypes: true,
          minimumLocalDifficulty: 3
        },
        advancedTemplates: defineAdvancedTemplates({
          courseId,
          unitId,
          requiredConceptIds,
          families
        })
      };
    }
  });

  // services/assessmentTemplates/calculus1/differentiation.js
  var require_differentiation = __commonJS({
    "services/assessmentTemplates/calculus1/differentiation.js"(exports, module) {
      var {
        randomInteger,
        choose,
        polynomialTex,
        linearFactor,
        signed,
        makeShortAnswer,
        defineAdvancedTemplates
      } = require_shared();
      var courseId = "calculus-1";
      var unitId = "differentiation";
      var requiredConceptIds = [
        "calculus-1-02-01",
        "calculus-1-02-02",
        "calculus-1-02-03",
        "calculus-1-02-04",
        "calculus-1-02-05",
        "calculus-1-02-06",
        "calculus-1-02-07",
        "calculus-1-02-08",
        "calculus-1-02-09",
        "calculus-1-02-10"
      ];
      function cubicValue(coefficients, x) {
        return coefficients.reduce(
          (sum, coefficient, exponent) => sum + coefficient * x ** exponent,
          0
        );
      }
      var families = [
        {
          id: "extrema-coefficient-recovery",
          titles: [
            "두 극값 위치에서 삼차함수 계수와 함수값 복원",
            "극대·극소 조건으로 삼차함수의 계수 결합값 결정"
          ],
          sourcePattern: "도함수의 두 근을 극대·극소 위치와 연결하고 계수 비교 후 함수값 계산",
          estimatedMinutes: [12, 11],
          reasoningSteps: [
            [
              "삼차함수를 미분한다.",
              "두 극값 위치를 도함수의 두 근으로 둔다.",
              "도함수를 인수분해해 원함수 계수를 비교한다.",
              "복원한 함수에 극값 위치를 대입한다."
            ],
            [
              "극대·극소에서 f'=0을 사용한다.",
              "도함수의 인수분해식과 계수를 비교한다.",
              "두 미지 계수를 구한다.",
              "요구한 결합값을 계산한다."
            ]
          ],
          generate(mode) {
            const left = randomInteger(-3, -1);
            const right = randomInteger(1, 3);
            const quadraticCoefficient = -3 * (left + right) / 2;
            if (!Number.isInteger(
              quadraticCoefficient
            )) {
              return families[0].generate(
                mode
              );
            }
            const linearCoefficient = 3 * left * right;
            const constant = randomInteger(-5, 5);
            const coefficients = [
              constant,
              linearCoefficient,
              quadraticCoefficient,
              1
            ];
            const valueSum = cubicValue(
              coefficients,
              left
            ) + cubicValue(
              coefficients,
              right
            );
            const answer = mode === 0 ? valueSum : quadraticCoefficient + linearCoefficient;
            return makeShortAnswer({
              prompt: `삼차함수 $f(x)=x^3+ax^2+bx${constant >= 0 ? "+" : ""}${constant}$가 $x=${left}$에서 극대, $x=${right}$에서 극소일 때, $${mode === 0 ? `f(${left})+f(${right})` : "a+b"}$의 값을 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? valueSum : quadraticCoefficient + linearCoefficient,
              solution: `$f'(x)=3x^2+2ax+b=3(${linearFactor(
                left
              )})(${linearFactor(
                right
              )})$이다. 계수 비교로 $a=${quadraticCoefficient},b=${linearCoefficient}$. ${mode === 0 ? `이를 원함수에 대입해 두 함수값을 더하면 ${answer}이다.` : `따라서 $a+b=${answer}$.`}`,
              hintText: "극대와 극소가 되는 x좌표는 도함수의 두 근입니다."
            });
          }
        },
        {
          id: "tangent-through-point",
          titles: [
            "외부점에서 포물선에 그은 두 접선의 접점 복원",
            "두 접선의 기울기 관계와 접점 좌표 결합"
          ],
          sourcePattern: "접점을 t로 두고 접선식을 세운 뒤 외부점을 지난다는 조건을 t의 방정식으로 변환",
          estimatedMinutes: [12, 13],
          reasoningSteps: [
            [
              "접점의 x좌표를 t로 둔다.",
              "도함수로 접선의 기울기와 방정식을 만든다.",
              "외부점 좌표를 접선식에 대입해 t의 이차방정식을 얻는다.",
              "두 접점 좌표의 대칭식을 계산한다."
            ],
            [
              "각 접선의 접점을 미지수로 둔다.",
              "외부점 통과 조건으로 두 접점의 방정식을 푼다.",
              "두 접선의 기울기를 구한다.",
              "기울기의 곱 또는 차를 계산한다."
            ]
          ],
          generate(mode) {
            const c = randomInteger(-3, 3);
            const radius = randomInteger(2, 5);
            const externalY = c - radius ** 2;
            const left = -radius;
            const right = radius;
            const slopeProduct = 2 * left * (2 * right);
            const answer = mode === 0 ? left ** 2 + right ** 2 : slopeProduct;
            return makeShortAnswer({
              prompt: `점 $P(0,${externalY})$에서 포물선 $y=x^2${c >= 0 ? "+" : ""}${c}$에 그은 서로 다른 두 접선의 접점의 x좌표를 $\\alpha<\\beta$, 두 접선의 기울기를 $m_1,m_2$라 할 때, $${mode === 0 ? "\\alpha^2+\\beta^2" : "m_1m_2"}$의 값을 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? 2 * radius ** 2 : -4 * radius ** 2,
              solution: `접점이 $(t,t^2${signed(
                c
              )})$이면 접선은 $y=2tx-t^2${signed(
                c
              )}$이다. P를 대입하면 $${externalY}=-t^2${signed(
                c
              )}$, 즉 $t=\\pm${radius}$. 따라서 요구한 값은 ${answer}이다.`,
              hintText: "접점의 x좌표를 t로 두고 그 점에서의 접선식을 먼저 만드세요."
            });
          }
        },
        {
          id: "cubic-root-count-parameter",
          titles: [
            "삼차함수 극값으로 방정식의 실근 개수 판정",
            "세 실근을 갖는 정수 매개변수 개수"
          ],
          sourcePattern: "삼차함수의 증가·감소와 극댓값·극솟값을 수평선 교점 개수 조건으로 변환",
          estimatedMinutes: [11, 13],
          reasoningSteps: [
            [
              "함수를 미분해 임계점을 구한다.",
              "각 임계점의 함수값을 계산한다.",
              "수평선의 높이를 극댓값·극솟값과 비교한다.",
              "그래프 교점 개수로 실근 개수를 판정한다."
            ],
            [
              "도함수 부호표로 극댓값과 극솟값을 찾는다.",
              "세 실근 조건을 매개변수의 열린구간으로 바꾼다.",
              "끝점에서는 중근이 생김을 제외한다.",
              "구간 안의 정수 개수를 센다."
            ]
          ],
          generate(mode) {
            const t = randomInteger(1, 3);
            const critical = 2 * t ** 3;
            const level = choose([
              -critical - 1,
              -critical,
              0,
              critical,
              critical + 1
            ]);
            const rootCount = Math.abs(level) < critical ? 3 : Math.abs(level) === critical ? 2 : 1;
            const integerCount = 2 * critical - 1;
            const answer = mode === 0 ? rootCount : integerCount;
            return makeShortAnswer({
              prompt: mode === 0 ? `방정식 $x^3-${3 * t ** 2}x=${level}$의 서로 다른 실근의 개수를 구하시오.` : `방정식 $x^3-${3 * t ** 2}x=k$가 서로 다른 세 실근을 갖게 하는 정수 $k$의 개수를 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? rootCount : integerCount,
              solution: `$g'(x)=3(x-${t})(x+${t})$이고 극댓값은 ${critical}, 극솟값은 -${critical}이다. ${mode === 0 ? `수평선 $y=${level}$과의 교점은 ${rootCount}개이다.` : `세 교점 조건은 $-${critical}<k<${critical}$이므로 정수는 ${integerCount}개이다.`}`,
              hintText: "방정식의 해 개수를 함수 그래프와 수평선의 교점 개수로 바꾸세요.",
              visualization: {
                kind: "polynomial",
                degree: 3,
                coefficients: {
                  cubic: 1,
                  quadratic: 0,
                  linear: -3 * t ** 2,
                  constant: 0
                },
                comparisonLineY: mode === 0 ? level : 0,
                focusX: 0,
                note: mode === 0 ? `삼차함수와 수평선 y=${level}의 교점 개수를 확인하세요.` : "극댓값과 극솟값 사이의 수평선은 서로 다른 세 교점을 만듭니다."
              }
            });
          }
        },
        {
          id: "motion-turning-points",
          referenceArchetypeId: "motion-derivative-integral-progression",
          stageId: "differentiate-before-integrating",
          titles: [
            "위치함수에서 방향 전환 시점과 위치차 계산",
            "속도 부호표로 구간 내 위치의 최댓값·최솟값 결정"
          ],
          sourcePattern: "위치함수를 미분해 속도의 영점과 부호를 구하고 방향 전환·위치 범위를 해석",
          estimatedMinutes: [12, 12],
          reasoningSteps: [
            [
              "위치함수를 미분해 속도를 구한다.",
              "속도가 0인 시점을 찾는다.",
              "속도 부호로 실제 방향 전환 여부를 확인한다.",
              "두 시점의 위치를 대입해 위치차를 계산한다."
            ],
            [
              "속도의 근을 구한다.",
              "시간 구간에서 속도 부호표를 만든다.",
              "끝점과 임계점의 위치를 모두 계산한다.",
              "최댓값과 최솟값의 차를 구한다."
            ]
          ],
          generate(mode) {
            const first = randomInteger(1, 2);
            const second = first + randomInteger(2, 3);
            const constant = randomInteger(-4, 4);
            const coefficients = [
              constant,
              3 * first * second,
              -3 * (first + second) / 2,
              1
            ];
            if (!Number.isInteger(
              coefficients[2]
            )) {
              return families[3].generate(
                mode
              );
            }
            const firstPosition = cubicValue(
              coefficients,
              first
            );
            const secondPosition = cubicValue(
              coefficients,
              second
            );
            const endpointPosition = cubicValue(
              coefficients,
              second + 1
            );
            const values = [
              constant,
              firstPosition,
              secondPosition,
              endpointPosition
            ];
            const range = Math.max(...values) - Math.min(...values);
            const answer = mode === 0 ? Math.abs(
              firstPosition - secondPosition
            ) : range;
            return makeShortAnswer({
              prompt: `수직선 위를 움직이는 점의 시각 $t$에서의 위치가 $s(t)=${polynomialTex(
                coefficients,
                "t"
              )}$이다. ${mode === 0 ? "두 번의 방향 전환 시점에서 위치의 차" : `0\\le t\\le${second + 1}에서 위치의 최댓값과 최솟값의 차`}를 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? Math.abs(
                firstPosition - secondPosition
              ) : range,
              solution: `$v(t)=s'(t)=3(${linearFactor(
                first,
                "t"
              )})(${linearFactor(
                second,
                "t"
              )})$이므로 방향 전환 시점은 $t=${first},${second}$. 속도 부호표와 끝점·두 임계점의 위치를 비교하면 답은 ${answer}이다.`,
              hintText: "위치함수를 미분한 속도의 근과 부호를 먼저 조사하세요."
            });
          }
        },
        {
          id: "piecewise-differentiability",
          titles: [
            "구간별 함수의 연속·미분가능 조건 연립",
            "미분가능 경계에서 접선의 절편 계산"
          ],
          sourcePattern: "경계점에서 함수값 일치와 좌우미분계수 일치를 각각 적용해 두 매개변수 결정",
          estimatedMinutes: [12, 12],
          reasoningSteps: [
            [
              "경계점에서 좌우 함수값을 같게 둔다.",
              "양쪽 식을 미분해 좌우미분계수를 구한다.",
              "두 기울기를 같게 두어 계수를 결정한다.",
              "연속 조건으로 나머지 상수를 구해 결합한다."
            ],
            [
              "미분가능성에서 연속 조건을 먼저 쓴다.",
              "좌우미분계수 일치로 직선의 기울기를 정한다.",
              "경계점의 함수값을 구한다.",
              "점-기울기식으로 접선의 절편을 계산한다."
            ]
          ],
          generate(mode) {
            const point = randomInteger(-2, 3);
            const q = randomInteger(1, 3);
            const l = randomInteger(-4, 4);
            const c = randomInteger(-5, 5);
            const slope = 2 * q * point + l;
            const value = q * point ** 2 + l * point + c;
            const intercept = value - slope * point;
            const answer = mode === 0 ? slope + intercept : intercept;
            return makeShortAnswer({
              prompt: `함수 $f(x)=\\begin{cases}${polynomialTex(
                [c, l, q]
              )}&(x<${point})\\\\ax+b&(x\\ge${point})\\end{cases}$가 $x=${point}$에서 미분가능하다. ${mode === 0 ? "$a+b$" : `$x=${point}$에서 접선의 y절편`}의 값을 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? slope + intercept : intercept,
              solution: `좌우미분계수 일치에서 $a=${slope}$. 연속 조건 $${slope}\\cdot${point}+b=${value}$에서 $b=${intercept}$. 경계점 접선은 바로 $y=${slope}x${intercept >= 0 ? "+" : ""}${intercept}$이므로 답은 ${answer}이다.`,
              hintText: "미분가능하려면 연속이어야 하고 좌우미분계수도 같아야 합니다."
            });
          }
        },
        {
          id: "quartic-monotonicity-sign-chart",
          titles: [
            "세 임계점을 가진 사차함수의 증가구간 판정",
            "도함수 부호표에서 극값 위치 결합"
          ],
          sourcePattern: "인수분해된 삼차 도함수의 세 근을 배열하고 구간별 부호를 조사해 증가·감소와 극값을 판정",
          estimatedMinutes: [12, 13],
          reasoningSteps: [
            [
              "도함수의 세 근을 크기순으로 배열한다.",
              "각 근 사이에서 도함수의 부호를 조사한다.",
              "도함수가 양수인 증가구간을 고른다.",
              "유계 증가구간의 양 끝점을 결합한다."
            ],
            [
              "도함수의 부호표를 완성한다.",
              "양에서 음으로 바뀌는 극대 위치를 찾는다.",
              "음에서 양으로 바뀌는 극소 위치를 찾는다.",
              "세 극값 위치의 결합값을 계산한다."
            ]
          ],
          generate(mode) {
            const left = randomInteger(-4, -2);
            const middle = randomInteger(-1, 1);
            const right = randomInteger(2, 4);
            const answer = mode === 0 ? left + middle : left - middle + right;
            return makeShortAnswer({
              prompt: `사차함수 $f$의 도함수가 $f'(x)=(${linearFactor(left)})(${linearFactor(middle)})(${linearFactor(right)})$이다. ${mode === 0 ? "유계인 증가구간의 양 끝점의 합" : "(극소가 되는 두 $x$좌표의 합)-(극대가 되는 $x$좌표)"}을 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? left + middle : left + right - middle,
              solution: `세 근을 지나며 $f'$의 부호는 $-,+,-,+$로 바뀐다. 따라서 증가는 $(${left},${middle})$, $(${right},\\infty)$에서이고 극소 위치는 ${left},${right}, 극대 위치는 ${middle}이다. 답은 ${answer}이다.`,
              hintText: "최고차항 계수가 양수인 삼차식의 부호를 오른쪽부터 번갈아 표시하세요."
            });
          }
        },
        {
          id: "parallel-tangent-two-points",
          titles: [
            "주어진 직선과 평행한 두 접점의 좌표 합",
            "같은 기울기를 갖는 두 접점의 함수값 결합"
          ],
          sourcePattern: "접선 기울기 조건 f'(x)=m을 이차방정식으로 풀고 두 접점의 좌표 또는 함수값을 결합",
          estimatedMinutes: [11, 13],
          reasoningSteps: [
            [
              "삼차함수를 미분한다.",
              "접선의 기울기를 주어진 직선의 기울기와 같게 둔다.",
              "이차방정식의 두 근을 구한다.",
              "두 접점 x좌표의 합을 계산한다."
            ],
            [
              "f'(x)=m을 풀어 두 접점을 찾는다.",
              "각 x좌표를 원함수에 대입한다.",
              "두 함수값을 각각 계산한다.",
              "요구한 함수값의 차를 구한다."
            ]
          ],
          generate(mode) {
            const center = randomInteger(-2, 3);
            const distance = randomInteger(1, 3);
            const slope = randomInteger(-3, 4);
            const constant = randomInteger(-4, 4);
            const quadratic = -3 * center;
            const linear = slope + 3 * (center ** 2 - distance ** 2);
            const coefficients = [
              constant,
              linear,
              quadratic,
              1
            ];
            const left = center - distance;
            const right = center + distance;
            const valueDifference = cubicValue(
              coefficients,
              right
            ) - cubicValue(
              coefficients,
              left
            );
            const answer = mode === 0 ? left + right : valueDifference;
            return makeShortAnswer({
              prompt: `함수 $f(x)=${polynomialTex(coefficients)}$의 그래프에서 직선 $y=${slope}x+1$과 평행한 서로 다른 두 접점의 x좌표를 $\\alpha<\\beta$라 하자. $${mode === 0 ? "\\alpha+\\beta" : "f(\\beta)-f(\\alpha)"}$의 값을 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? 2 * center : cubicValue(
                coefficients,
                right
              ) - cubicValue(
                coefficients,
                left
              ),
              solution: `$f'(x)=${slope}+3(${linearFactor(left)})(${linearFactor(right)})$이므로 $f'(x)=${slope}$의 두 해는 $${left},${right}$. 원함수에 대입해 정리하면 답은 ${answer}이다.`,
              hintText: "평행한 두 접선의 기울기는 주어진 직선의 기울기와 같습니다."
            });
          }
        },
        {
          id: "closed-interval-extrema",
          titles: [
            "닫힌구간에서 삼차함수의 최댓값·최솟값 차",
            "끝점과 임계점을 모두 비교하는 절댓값 최댓값"
          ],
          sourcePattern: "도함수의 근과 닫힌구간의 양 끝점에서 함수값을 모두 계산해 전역 최댓값·최솟값을 결정",
          estimatedMinutes: [13, 14],
          reasoningSteps: [
            [
              "함수를 미분해 구간 안의 임계점을 찾는다.",
              "양 끝점과 각 임계점의 함수값을 계산한다.",
              "값들을 비교해 최댓값과 최솟값을 정한다.",
              "두 값의 차를 계산한다."
            ],
            [
              "도함수 부호표로 극대·극소 위치를 찾는다.",
              "끝점과 임계점의 함수값 목록을 만든다.",
              "각 함수값의 절댓값을 비교한다.",
              "가장 큰 절댓값과 그 위치를 결합한다."
            ]
          ],
          generate(mode) {
            const leftCritical = -1;
            const rightCritical = 1;
            const constant = randomInteger(-3, 3);
            const value = (x) => x ** 3 - 3 * x + constant;
            const leftEndpoint = -2;
            const rightEndpoint = 2;
            const candidates = [
              leftEndpoint,
              leftCritical,
              rightCritical,
              rightEndpoint
            ].map((x) => ({
              x,
              y: value(x)
            }));
            const values = candidates.map(
              ({ y }) => y
            );
            const range = Math.max(...values) - Math.min(...values);
            const maxAbsolute = Math.max(
              ...values.map(Math.abs)
            );
            const answer = mode === 0 ? range : maxAbsolute;
            return makeShortAnswer({
              prompt: `함수 $f(x)=x^3-3x${signed(constant)}$에 대하여 $[-2,2]$에서 ${mode === 0 ? "최댓값과 최솟값의 차" : "$|f(x)|$의 최댓값"}을 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? Math.max(
                ...values
              ) - Math.min(
                ...values
              ) : Math.max(
                ...values.map(
                  (number) => Math.abs(number)
                )
              ),
              solution: `$f'(x)=3(x-1)(x+1)$이므로 후보점은 $-2,-1,1,2$이다. 각 점의 함수값을 비교하면 요구한 값은 ${answer}이다.`,
              hintText: "닫힌구간에서는 임계점뿐 아니라 양 끝점의 함수값도 반드시 비교하세요.",
              visualization: {
                kind: "polynomial",
                degree: 3,
                coefficients: {
                  cubic: 1,
                  quadratic: 0,
                  linear: -3,
                  constant
                },
                domain: [-2, 2],
                focusX: 0,
                note: "닫힌구간의 양 끝점과 임계점에서 함수값을 비교하세요."
              }
            });
          }
        },
        {
          id: "quartic-global-minimum",
          titles: [
            "사차함수의 전역 최솟값과 최적 상수",
            "도함수 부호와 대칭성을 이용한 최솟값"
          ],
          sourcePattern: "사차함수를 미분해 세 임계점을 찾고 함수값 비교로 모든 실수에서의 최솟값을 결정",
          estimatedMinutes: [13, 14],
          reasoningSteps: [
            [
              "사차함수를 미분하고 인수분해한다.",
              "세 임계점에서 도함수 부호 변화를 조사한다.",
              "각 극소점의 함수값을 비교한다.",
              "f(x)≥k를 만족하는 최대 k를 결정한다."
            ],
            [
              "짝함수의 대칭성을 확인한다.",
              "도함수의 세 근을 구한다.",
              "극대와 두 극소를 구분한다.",
              "전역 최솟값과 극소 위치를 결합한다."
            ]
          ],
          generate(mode) {
            const radius = choose([1, 2, 3]);
            const constant = randomInteger(-2, 5);
            const minimum = constant - radius ** 4;
            const answer = mode === 0 ? minimum : minimum + 2 * radius;
            return makeShortAnswer({
              prompt: `함수 $f(x)=x^4-${2 * radius ** 2}x^2${signed(constant)}$에 대하여 ${mode === 0 ? "모든 실수 $x$에서 $f(x)\\ge k$가 성립하도록 하는 실수 $k$의 최댓값" : "최솟값 $m$과 두 극소점의 $x$좌표 차 $d$에 대한 $m+d$"}를 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? constant - radius ** 4 : constant - radius ** 4 + 2 * radius,
              solution: `$f'(x)=4x(x-${radius})(x+${radius})$이다. 두 극소점 $x=\\pm${radius}$에서 최솟값은 ${minimum}이고 두 x좌표의 차는 ${2 * radius}. 따라서 답은 ${answer}이다.`,
              hintText: "도함수를 인수분해해 세 임계점의 종류를 구분하세요."
            });
          }
        },
        {
          id: "absolute-polynomial-differentiability",
          titles: [
            "절댓값 이차함수의 미분가능 조건",
            "중근 조건과 절댓값 그래프의 매끄러운 접합"
          ],
          sourcePattern: "|이차식|이 영점에서 미분가능하려면 내부 다항식이 부호를 바꾸지 않는 중근을 가져야 함을 적용",
          estimatedMinutes: [12, 13],
          reasoningSteps: [
            [
              "절댓값 내부 이차식의 영점을 조사한다.",
              "단순근에서는 좌우 기울기가 달라짐을 확인한다.",
              "미분가능 조건을 판별식 0으로 바꾼다.",
              "매개변수를 풀어 목표값을 계산한다."
            ],
            [
              "미분가능하지 않을 수 있는 점을 내부식의 근으로 한정한다.",
              "모든 영점이 중근이어야 함을 사용한다.",
              "완전제곱식이 되도록 계수를 정한다.",
              "접합점의 함수값과 매개변수를 결합한다."
            ]
          ],
          generate(mode) {
            const root = randomInteger(-4, -1);
            const parameter = -2 * root;
            const constant = root ** 2;
            const answer = mode === 0 ? parameter : parameter + constant;
            return makeShortAnswer({
              prompt: `양수 $a$에 대하여 함수 $f(x)=|x^2+ax+${constant}|$가 모든 실수에서 미분가능할 때, $${mode === 0 ? "a" : `a+f(${root})+${constant}`}$의 값을 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? -2 * root : -2 * root + root ** 2,
              solution: `절댓값 내부식이 단순근을 가지면 그 점에서 뾰족해진다. 따라서 판별식이 0이어야 하므로 $a^2-4\\cdot${constant}=0$이고 중근이 ${root}이므로 $a=${parameter}$. 또한 $f(${root})=0$이어서 답은 ${answer}이다.`,
              hintText: "절댓값 내부식이 0을 지나며 부호가 바뀌면 좌우미분계수가 달라집니다."
            });
          }
        }
      ];
      module.exports = {
        courseId,
        unitId,
        requiredConceptIds,
        minimumAppliedPoolSize: 16,
        appliedPolicy: {
          includeBankTypes: true,
          minimumLocalDifficulty: 3
        },
        advancedTemplates: defineAdvancedTemplates({
          courseId,
          unitId,
          requiredConceptIds,
          families
        })
      };
    }
  });

  // services/assessmentTemplates/calculus1/integration.js
  var require_integration = __commonJS({
    "services/assessmentTemplates/calculus1/integration.js"(exports, module) {
      var {
        randomInteger,
        choose,
        fraction,
        polynomialTex,
        linearFactor,
        signed,
        makeShortAnswer,
        defineAdvancedTemplates
      } = require_shared();
      var courseId = "calculus-1";
      var unitId = "integration";
      var differentiationConceptIds = [
        "calculus-1-02-01",
        "calculus-1-02-02",
        "calculus-1-02-03",
        "calculus-1-02-04",
        "calculus-1-02-05",
        "calculus-1-02-06",
        "calculus-1-02-07",
        "calculus-1-02-08",
        "calculus-1-02-09",
        "calculus-1-02-10"
      ];
      var requiredConceptIds = [
        "calculus-1-03-01",
        "calculus-1-03-02",
        "calculus-1-03-03",
        "calculus-1-03-04",
        "calculus-1-03-05",
        "calculus-1-03-06"
      ];
      function antiderivativeValue(derivativeCoefficients, constant, x) {
        return derivativeCoefficients.reduce(
          (sum, coefficient, exponent) => sum + coefficient / (exponent + 1) * x ** (exponent + 1),
          constant
        );
      }
      var families = [
        {
          id: "derivative-to-integral-chain",
          titles: [
            "도함수와 한 함수값에서 원함수 복원 후 정적분",
            "도함수 조건·원함수 복원·구간 함수값 결합"
          ],
          sourcePattern: "미분 단계에서 계수를 확인하고 적분상수를 결정한 뒤 정적분 또는 함수값까지 이어지는 유형",
          estimatedMinutes: [12, 12],
          reasoningSteps: [
            [
              "도함수를 항별로 적분한다.",
              "주어진 함수값으로 적분상수를 정한다.",
              "복원한 원함수를 다시 미분해 검산한다.",
              "목표 정적분을 계산한다."
            ],
            [
              "도함수의 원시함수를 구한다.",
              "초기 조건으로 상수를 결정한다.",
              "두 끝점의 함수값을 계산한다.",
              "미적분의 기본정리와 함수값 결합을 계산한다."
            ]
          ],
          generate(mode) {
            const quadratic = choose([3, 6]);
            const linear = choose([-4, -2, 2, 4]);
            const constantDerivative = randomInteger(-3, 3);
            const initial = randomInteger(-4, 4);
            const bound = randomInteger(2, 4);
            const derivative = [
              constantDerivative,
              linear,
              quadratic
            ];
            const atBound = antiderivativeValue(
              derivative,
              initial,
              bound
            );
            const atZero = initial;
            const integralOfFPrime = atBound - atZero;
            const answer = mode === 0 ? integralOfFPrime : atBound + integralOfFPrime;
            return makeShortAnswer({
              prompt: `다항함수 $f$가 $f'(x)=${polynomialTex(
                derivative
              )}$, $f(0)=${initial}$을 만족한다. ${mode === 0 ? `$\\displaystyle\\int_0^{${bound}}f'(x)\\,dx$` : `$f(${bound})+\\displaystyle\\int_0^{${bound}}f'(x)\\,dx$`}의 값을 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? atBound - atZero : atBound + atBound - atZero,
              solution: `도함수를 적분하고 $f(0)=${initial}$을 적용하면 $f(${bound})=${atBound}$. 미적분의 기본정리로 $\\int_0^{${bound}}f'(x)dx=f(${bound})-f(0)=${integralOfFPrime}$. 따라서 답은 ${answer}이다.`,
              hintText: "원함수를 복원한 뒤 정적분을 함수값의 차로도 검산하세요."
            });
          }
        },
        {
          id: "quadratic-area-parameter",
          titles: [
            "두 교점과 넓이 조건에서 이차함수 계수 복원",
            "포물선·직선 사이 넓이와 교점 거리 결합"
          ],
          sourcePattern: "교점을 먼저 구하고 함수의 대소를 판정한 뒤 차함수를 적분해 넓이 계산",
          estimatedMinutes: [13, 13],
          reasoningSteps: [
            [
              "두 그래프의 교점 방정식을 푼다.",
              "교점 사이에서 위쪽 함수를 판정한다.",
              "차함수를 정적분한다.",
              "넓이 조건과 비교해 매개변수를 구한다."
            ],
            [
              "교점 두 개를 구한다.",
              "차함수의 부호를 확인한다.",
              "넓이를 적분으로 계산한다.",
              "교점 거리와 넓이를 결합한다."
            ]
          ],
          generate(mode) {
            const gap = randomInteger(2, 5);
            const slope = randomInteger(1, 4);
            const area = fraction(
              gap ** 3,
              6
            );
            const numericArea = gap ** 3 / 6;
            const answer = mode === 0 ? slope : numericArea + gap;
            return makeShortAnswer({
              prompt: mode === 0 ? `곡선 $y=x^2$과 직선 $y=kx$로 둘러싸인 부분의 넓이가 $\\dfrac{${slope ** 3}}6$일 때, 양수 $k$를 구하시오.` : `곡선 $y=x^2$과 직선 $y=${gap}x$의 두 교점 사이 거리를 $d$, 둘러싸인 넓이를 $S$라 할 때 $S+d$를 구하시오. (분수 입력 가능)`,
              answer,
              independentAnswer: mode === 0 ? slope : gap ** 3 / 6 + gap,
              solution: `교점은 $x=0,k$이고 그 사이에서는 직선이 위에 있다. $S=\\int_0^k(kx-x^2)dx=k^3/6$. ${mode === 0 ? `양수 조건에서 $k=${slope}$.` : `$S=${area}$, $d=${gap}$이므로 답은 ${answer}.`}`,
              hintText: "교점을 구한 뒤 위 함수에서 아래 함수를 빼 적분하세요."
            });
          }
        },
        {
          id: "velocity-total-distance",
          referenceArchetypeId: "motion-derivative-integral-progression",
          stageId: "differentiate-and-integrate",
          titles: [
            "속도 부호 변화가 있는 구간의 총 이동거리",
            "변위와 이동거리의 차 계산"
          ],
          sourcePattern: "속도의 영점으로 구간을 나누고 각 구간 적분의 절댓값을 합하는 이동거리 유형",
          estimatedMinutes: [13, 13],
          reasoningSteps: [
            [
              "속도의 영점을 찾는다.",
              "시간축에서 속도 부호표를 만든다.",
              "부호가 일정한 각 구간에서 변위를 적분한다.",
              "각 변위의 절댓값을 합한다."
            ],
            [
              "속도의 부호 변화 시점을 구한다.",
              "전체 변위를 한 번 적분한다.",
              "총 이동거리를 구간별 절댓값 적분으로 계산한다.",
              "두 값의 차를 계산한다."
            ]
          ],
          generate(mode) {
            const turn = randomInteger(2, 5);
            const end = 2 * turn;
            const primitive = (t) => turn * t ** 2 / 2 - t ** 3 / 3;
            const firstDistance = primitive(turn);
            const secondDisplacement = primitive(end) - primitive(turn);
            const totalDistance = Math.abs(firstDistance) + Math.abs(
              secondDisplacement
            );
            const displacement = primitive(end);
            const answer = mode === 0 ? fraction(
              Math.round(
                totalDistance * 6
              ),
              6
            ) : fraction(
              Math.round(
                (totalDistance - Math.abs(
                  displacement
                )) * 6
              ),
              6
            );
            return makeShortAnswer({
              prompt: `수직선 위를 움직이는 점 P의 속도가 $v(t)=${turn}t-t^2$이다. $0\\le t\\le${end}$에서 ${mode === 0 ? "P가 움직인 거리" : "P가 움직인 거리와 변위의 절댓값의 차"}를 구하시오. (기약분수로 입력)`,
              answer,
              independentAnswer: mode === 0 ? fraction(
                Math.round(
                  totalDistance * 6
                ),
                6
              ) : fraction(
                Math.round(
                  (totalDistance - Math.abs(
                    displacement
                  )) * 6
                ),
                6
              ),
              solution: `$v(t)=t(${turn}-t)$이므로 $t=${turn}$에서 부호가 바뀐다. $[0,${turn}]$과 $[${turn},${end}]$의 정적분을 각각 계산하고 절댓값을 합하면 총 이동거리를 얻는다. 요구한 값은 ${answer}이다.`,
              hintText: "속도가 0인 시점에서 적분 구간을 나누고 각 구간 변위에 절댓값을 취하세요."
            });
          }
        },
        {
          id: "integral-defined-function",
          titles: [
            "정적분으로 정의된 함수의 값과 도함수 결합",
            "적분함수의 조건에서 매개변수 결정"
          ],
          sourcePattern: "F(x)=∫f(t)dt를 미분해 F'=f를 얻고 함수값 조건과 함께 적용",
          estimatedMinutes: [11, 12],
          reasoningSteps: [
            [
              "적분으로 정의된 함수에 미적분의 기본정리를 적용한다.",
              "F'(x)를 피적분함수로 바꾼다.",
              "F(a)는 직접 정적분한다.",
              "두 값을 결합한다."
            ],
            [
              "F'(x)=f(x)를 구한다.",
              "주어진 도함수 조건으로 매개변수를 정한다.",
              "복원한 피적분함수를 적분한다.",
              "목표 함수값을 계산한다."
            ]
          ],
          generate(mode) {
            const parameter = randomInteger(-4, 5);
            const point = randomInteger(2, 4);
            const integral = point ** 3 + parameter * point ** 2 / 2;
            const derivativeAt = 3 * point ** 2 + parameter * point;
            const answer = mode === 0 ? integral + derivativeAt : parameter;
            return makeShortAnswer({
              prompt: mode === 0 ? `함수 $F(x)=\\displaystyle\\int_0^x(3t^2${signed(
                parameter
              )}t)dt$에 대하여 $F(${point})+F'(${point})$의 값을 구하시오.` : `함수 $F(x)=\\displaystyle\\int_0^x(3t^2+kt)dt$가 $F'(${point})=${derivativeAt}$을 만족할 때, 상수 $k$를 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? point ** 3 + parameter * point ** 2 / 2 + 3 * point ** 2 + parameter * point : (derivativeAt - 3 * point ** 2) / point,
              solution: `미적분의 기본정리로 $F'(x)=3x^2${mode === 0 ? `${signed(
                parameter
              )}x` : "+kx"}$. ${mode === 0 ? `또 $F(${point})=${integral}$이므로 답은 ${answer}.` : `$x=${point}$을 대입해 일차방정식을 풀면 $k=${parameter}$.`}`,
              hintText: "상한이 x인 정적분을 미분하면 피적분함수에 x를 대입한 식이 됩니다."
            });
          }
        },
        {
          id: "tangent-and-enclosed-area",
          requiredConceptIds: [
            ...differentiationConceptIds,
            ...requiredConceptIds
          ],
          titles: [
            "접선 결정 후 곡선과 접선 사이 넓이",
            "미분으로 접점을 찾고 적분으로 넓이 계산"
          ],
          sourcePattern: "접선 조건을 미분으로 해결한 뒤 교점과 함수의 대소를 구해 정적분까지 이어지는 완전형",
          estimatedMinutes: [14, 15],
          reasoningSteps: [
            [
              "도함수로 접선의 기울기를 구한다.",
              "점-기울기식으로 접선 방정식을 만든다.",
              "곡선과 접선의 추가 교점을 구한다.",
              "두 그래프의 차를 적분해 넓이를 계산한다."
            ],
            [
              "주어진 기울기와 도함수를 같게 두어 접점을 찾는다.",
              "접선 방정식을 구한다.",
              "교점 구간에서 위아래 그래프를 판정한다.",
              "정적분으로 둘러싸인 넓이를 구한다."
            ]
          ],
          generate(mode) {
            const contact = randomInteger(1, 3);
            const other = contact + randomInteger(2, 4);
            const gap = other - contact;
            const area = fraction(
              gap ** 4,
              12
            );
            const scaled = fraction(
              gap ** 4,
              3
            );
            const answer = mode === 0 ? area : scaled;
            return makeShortAnswer({
              prompt: `곡선 $y=(x-${contact})^2(x-${other})$와 이 곡선 위의 점 $(${contact},0)$에서의 접선, 그리고 직선 $x=${other}$로 둘러싸인 부분의 넓이를 $S$라 하자. ${mode === 0 ? "S" : "4S"}의 값을 구하시오. (기약분수로 입력)`,
              answer,
              independentAnswer: mode === 0 ? fraction(
                gap ** 4,
                12
              ) : fraction(
                gap ** 4,
                3
              ),
              solution: `$f'(${contact})=0$이므로 접선은 $y=0$. $${contact}<x<${other}$에서 함수값은 음수이므로 $S=-\\int_{${contact}}^{${other}}(x-${contact})^2(x-${other})dx=${area}$. 따라서 답은 ${answer}이다.`,
              hintText: "접선이 x축임을 확인한 뒤 함수의 부호를 보고 절댓값 넓이를 적분하세요."
            });
          }
        },
        {
          id: "symmetric-definite-integral",
          titles: [
            "대칭구간에서 홀수항을 소거하는 정적분",
            "f(x)+f(-x) 조건으로 정적분 복원"
          ],
          sourcePattern: "대칭구간에서 홀함수 부분의 정적분이 0임을 이용해 짝함수 부분만 적분",
          estimatedMinutes: [11, 12],
          reasoningSteps: [
            [
              "다항식을 짝수차항과 홀수차항으로 나눈다.",
              "대칭구간에서 홀수차항의 적분이 0임을 확인한다.",
              "남은 짝수차항을 적분한다.",
              "양쪽 구간의 값을 합쳐 목표값을 구한다."
            ],
            [
              "f(x)+f(-x)에서 홀수 부분이 소거됨을 사용한다.",
              "주어진 식으로 f의 짝수 부분을 복원한다.",
              "대칭구간 적분을 짝수 부분의 적분으로 바꾼다.",
              "정적분 값을 계산한다."
            ]
          ],
          generate(mode) {
            const bound = randomInteger(2, 4);
            const evenQuadratic = choose([3, 6]);
            const constant = randomInteger(-3, 4);
            const oddCubic = randomInteger(-4, 4);
            const oddLinear = randomInteger(-4, 4);
            const integral = 2 * (evenQuadratic * bound ** 3 / 3 + constant * bound);
            const answer = mode === 0 ? integral : integral / 2;
            return makeShortAnswer({
              prompt: mode === 0 ? `다항함수 $f(x)=${polynomialTex([constant, oddLinear, evenQuadratic, oddCubic])}$에 대하여 $\\displaystyle\\int_{-${bound}}^{${bound}}f(x)\\,dx$의 값을 구하시오.` : `연속함수 $f$가 $f(x)+f(-x)=${2 * evenQuadratic}x^2${signed(2 * constant)}$를 만족한다. $\\dfrac12\\displaystyle\\int_{0}^{${bound}}\\{f(x)+f(-x)\\}\\,dx$의 값을 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? 2 * (evenQuadratic * bound ** 3 / 3 + constant * bound) : evenQuadratic * bound ** 3 / 3 + constant * bound,
              solution: `대칭구간에서 홀수차항의 정적분은 0이다. 따라서 짝수 부분만 적분하면 ${mode === 0 ? "" : "$f(x)+f(-x)$ 자체가 짝수 부분의 두 배이므로 "}답은 ${answer}이다.`,
              hintText: "대칭구간에서는 홀함수 부분의 넓이가 부호를 달리해 서로 소거됩니다."
            });
          }
        },
        {
          id: "two-parabola-enclosed-area",
          titles: [
            "두 포물선의 교점과 둘러싸인 넓이",
            "차함수의 근과 최고차항에서 넓이 복원"
          ],
          sourcePattern: "두 이차함수의 차를 인수분해해 교점을 찾고 구간 내 부호를 판정한 뒤 정적분",
          estimatedMinutes: [13, 14],
          reasoningSteps: [
            [
              "두 포물선의 차를 구한다.",
              "차함수를 인수분해해 두 교점을 찾는다.",
              "교점 사이에서 위쪽 그래프를 판정한다.",
              "차함수를 정적분해 넓이를 계산한다."
            ],
            [
              "교점의 x좌표를 차함수의 두 근으로 해석한다.",
              "최고차항 부호로 위아래 그래프를 정한다.",
              "근 사이의 이차식 적분을 계산한다.",
              "넓이와 교점 거리의 결합값을 구한다."
            ]
          ],
          generate(mode) {
            const left = randomInteger(-3, 0);
            const gap = randomInteger(3, 6);
            const right = left + gap;
            const scale = choose([1, 2, 3]);
            const area = fraction(
              scale * gap ** 3,
              6
            );
            const answer = mode === 0 ? area : scale * gap ** 2;
            return makeShortAnswer({
              prompt: `두 곡선 $y=x^2$와 $y=x^2+${scale}(${linearFactor(left)})(${right}-x)$의 두 교점의 x좌표를 $a<b$, 둘러싸인 넓이를 $S$라 하자. $${mode === 0 ? "S" : "\\dfrac{6S}{b-a}"}$의 값을 구하시오.${mode === 0 ? " (기약분수로 입력)" : ""}`,
              answer,
              independentAnswer: mode === 0 ? fraction(
                scale * (right - left) ** 3,
                6
              ) : scale * (right - left) ** 2,
              solution: `두 그래프는 $x=${left},${right}$에서 만나고 그 사이의 차는 $${scale}(${linearFactor(left)})(${right}-x)\\ge0$이다. 이를 ${left}부터 ${right}까지 적분하면 $S=${area}$이고, 요구한 값은 ${answer}이다.`,
              hintText: "두 함수의 차를 먼저 구하면 교점과 위쪽 그래프를 동시에 확인할 수 있습니다."
            });
          }
        },
        {
          id: "zero-integral-parameter",
          titles: [
            "정적분이 0이 되는 일차함수의 매개변수",
            "구간 평균과 정적분 조건의 역문제"
          ],
          sourcePattern: "정적분값 조건을 매개변수에 대한 방정식으로 만들고 구간 평균 또는 끝점 값을 함께 계산",
          estimatedMinutes: [11, 12],
          reasoningSteps: [
            [
              "피적분함수를 항별로 적분한다.",
              "정적분이 0인 조건을 매개변수 방정식으로 만든다.",
              "매개변수를 구한다.",
              "복원한 함수의 목표점 값을 계산한다."
            ],
            [
              "정적분을 구간 길이와 평균값의 곱으로 해석한다.",
              "일차함수의 구간 평균이 중점값임을 확인한다.",
              "중점에서 함수값이 0이 되도록 매개변수를 정한다.",
              "두 끝점 함수값의 차를 계산한다."
            ]
          ],
          generate(mode) {
            const left = randomInteger(-3, 1);
            const right = left + choose([2, 4, 6]);
            const slope = choose([2, 3, 4]);
            const center = (left + right) / 2;
            const parameter = -slope * center;
            const answer = mode === 0 ? parameter : slope * (right - left);
            return makeShortAnswer({
              prompt: `상수 $a$에 대하여 $\\displaystyle\\int_{${left}}^{${right}}(${slope}x+a)\\,dx=0$이다. $${mode === 0 ? "a" : `(${slope}\\cdot${right}+a)-(${slope}\\cdot${left}+a)`}$의 값을 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? -slope * (left + right) / 2 : slope * (right - left),
              solution: `일차함수의 구간 평균은 중점 $x=${center}$에서의 값이다. 정적분이 0이므로 $${slope}\\cdot${center}+a=0$, $a=${parameter}$. 따라서 답은 ${answer}이다.`,
              hintText: "일차함수의 정적분 평균은 구간 중점에서의 함수값과 같습니다."
            });
          }
        },
        {
          id: "cubic-absolute-area",
          titles: [
            "세 영점을 가진 삼차함수와 x축 사이 총넓이",
            "부호가 두 번 바뀌는 곡선의 넓이 분할"
          ],
          sourcePattern: "삼차함수의 세 영점에서 적분구간을 나누고 구간별 부호에 따라 정적분의 절댓값을 합산",
          estimatedMinutes: [14, 15],
          reasoningSteps: [
            [
              "삼차함수의 세 영점을 확인한다.",
              "각 영점 사이에서 함수 부호를 조사한다.",
              "두 구간의 정적분을 각각 계산한다.",
              "각 정적분의 절댓값을 합한다."
            ],
            [
              "인수분해식으로 부호표를 만든다.",
              "x축 아래 구간의 적분에 음수를 붙인다.",
              "x축 위 구간의 적분을 더한다.",
              "총넓이를 기약분수로 정리한다."
            ]
          ],
          generate(mode) {
            const scale = choose([1, 2]);
            const value = (x) => scale * (x + 1) * x * (x - 2);
            const primitive = (x) => scale * (x ** 4 / 4 - x ** 3 / 3 - x ** 2);
            const firstIntegral = primitive(0) - primitive(-1);
            const secondIntegral = primitive(2) - primitive(0);
            const area = Math.abs(firstIntegral) + Math.abs(secondIntegral);
            const answer = mode === 0 ? fraction(
              Math.round(area * 12),
              12
            ) : fraction(
              Math.round(
                2 * area * 12
              ),
              12
            );
            return makeShortAnswer({
              prompt: `곡선 $y=${scale === 1 ? "" : scale}(x+1)x(x-2)$와 x축으로 둘러싸인 두 부분의 넓이의 합을 $S$라 하자. $${mode === 0 ? "S" : "2S"}$의 값을 구하시오. (기약분수로 입력)`,
              answer,
              independentAnswer: mode === 0 ? fraction(
                Math.round(
                  (Math.abs(
                    primitive(0) - primitive(-1)
                  ) + Math.abs(
                    primitive(2) - primitive(0)
                  )) * 12
                ),
                12
              ) : fraction(
                Math.round(
                  2 * (Math.abs(
                    primitive(0) - primitive(-1)
                  ) + Math.abs(
                    primitive(2) - primitive(0)
                  )) * 12
                ),
                12
              ),
              solution: `영점은 $-1,0,2$이고 두 구간에서 부호가 다르다. $[-1,0]$, $[0,2]$의 정적분에 각각 절댓값을 취해 더하면 $S=${fraction(Math.round(area * 12), 12)}$. 따라서 답은 ${answer}이다.`,
              hintText: "x축과 만나는 세 점에서 구간을 나누고 각 구간 정적분의 부호를 확인하세요."
            });
          }
        },
        {
          id: "velocity-two-turns",
          titles: [
            "두 번 방향을 바꾸는 운동의 총 이동거리",
            "세 시간구간의 변위와 이동거리 비교"
          ],
          sourcePattern: "속도의 두 양의 영점에서 시간구간을 셋으로 나누고 변위의 절댓값을 합산",
          estimatedMinutes: [14, 15],
          reasoningSteps: [
            [
              "속도가 0이 되는 두 시각을 구한다.",
              "세 시간구간에서 속도의 부호를 조사한다.",
              "각 구간의 속도를 적분해 변위를 구한다.",
              "세 변위의 절댓값을 합해 이동거리를 구한다."
            ],
            [
              "속도 부호표로 방향 전환 시점을 찾는다.",
              "전체 변위를 한 번의 정적분으로 계산한다.",
              "구간별 이동거리를 따로 계산한다.",
              "이동거리와 변위 절댓값의 차를 구한다."
            ]
          ],
          generate(mode) {
            const first = 1;
            const second = 3;
            const end = 4;
            const scale = choose([3, 6]);
            const primitive = (time) => scale * (time ** 3 / 3 - 2 * time ** 2 + 3 * time);
            const displacements = [
              primitive(first) - primitive(0),
              primitive(second) - primitive(first),
              primitive(end) - primitive(second)
            ];
            const distance = displacements.reduce(
              (sum, value) => sum + Math.abs(value),
              0
            );
            const total = primitive(end) - primitive(0);
            const exactDistance = Math.round(
              distance * 1e9
            ) / 1e9;
            const exactTotal = Math.round(
              total * 1e9
            ) / 1e9;
            const answer = mode === 0 ? exactDistance : exactDistance - Math.abs(exactTotal);
            return makeShortAnswer({
              prompt: `수직선 위를 움직이는 점의 속도가 $v(t)=${scale}(t-1)(t-3)$이다. $0\\le t\\le4$에서 ${mode === 0 ? "점이 움직인 총거리" : "총 이동거리에서 전체 변위의 절댓값을 뺀 값"}을 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? displacements.reduce(
                (sum, value) => sum + Math.abs(value),
                0
              ).toFixed(9).replace(/\.?0+$/, "") : String(
                Math.round(
                  (displacements.reduce(
                    (sum, value) => sum + Math.abs(value),
                    0
                  ) - Math.abs(
                    displacements.reduce(
                      (sum, value) => sum + value,
                      0
                    )
                  )) * 1e9
                ) / 1e9
              ),
              solution: `속도는 $t=1,3$에서 부호가 바뀐다. 세 구간 $[0,1]$, $[1,3]$, $[3,4]$에서 속도를 각각 적분하고 절댓값을 합하면 총 이동거리는 ${exactDistance}이다. 따라서 답은 ${answer}이다.`,
              hintText: "속도가 0인 두 시각에서 적분구간을 반드시 나누세요."
            });
          }
        }
      ];
      module.exports = {
        courseId,
        unitId,
        requiredConceptIds,
        minimumAppliedPoolSize: 16,
        appliedPolicy: {
          includeBankTypes: true,
          minimumLocalDifficulty: 3
        },
        advancedTemplates: defineAdvancedTemplates({
          courseId,
          unitId,
          requiredConceptIds,
          families
        })
      };
    }
  });

  // services/assessmentTemplates/probabilityStatistics/counting.js
  var require_counting = __commonJS({
    "services/assessmentTemplates/probabilityStatistics/counting.js"(exports, module) {
      var {
        randomInteger,
        choose,
        nCr,
        power,
        makeShortAnswer,
        defineAdvancedTemplates
      } = require_shared();
      var courseId = "probability-statistics";
      var unitId = "counting";
      var requiredConceptIds = [
        "probability-statistics-01-01",
        "probability-statistics-01-02",
        "probability-statistics-01-03"
      ];
      function permutations(values, length) {
        if (length === 0) return [[]];
        return values.flatMap(
          (value, index) => permutations(
            values.filter(
              (_, nextIndex) => nextIndex !== index
            ),
            length - 1
          ).map((tail) => [
            value,
            ...tail
          ])
        );
      }
      function factorial(value) {
        let result = 1;
        for (let factor = 2; factor <= value; factor += 1) {
          result *= factor;
        }
        return result;
      }
      var families = [
        {
          id: "restricted-digit-arrangement",
          titles: [
            "첫자리·짝수·중복금지 조건의 자연수 배열",
            "양끝 조건이 다른 중복 없는 숫자 배열"
          ],
          sourcePattern: "첫자리 0 금지와 끝자리 성질을 먼저 분리한 뒤 남은 자리를 순열로 계산",
          estimatedMinutes: [11, 11],
          reasoningSteps: [
            [
              "끝자리의 짝수 후보를 0과 0이 아닌 경우로 나눈다.",
              "각 경우 첫자리에서 0과 사용한 숫자를 제외한다.",
              "가운데 자리를 순서 있게 선택한다.",
              "서로 겹치지 않는 경우를 합한다."
            ],
            [
              "양 끝자리 후보를 조건별로 정한다.",
              "첫자리가 0인 배열을 제외한다.",
              "남은 자리를 순열로 배치한다.",
              "직접 열거 검산과 일치하는지 확인한다."
            ]
          ],
          generate(mode) {
            const maximum = randomInteger(5, 7);
            const digits = Array.from(
              {
                length: maximum + 1
              },
              (_, index) => index
            );
            const all = permutations(
              digits,
              4
            ).filter(
              (number) => number[0] !== 0
            );
            const valid = mode === 0 ? all.filter(
              (number) => number[3] % 2 === 0
            ) : all.filter(
              (number) => number[0] % 2 === 1 && number[3] % 2 === 0
            );
            const answer = valid.length;
            return makeShortAnswer({
              prompt: `$0,1,2,\\ldots,${maximum}$에서 서로 다른 네 숫자를 골라 만든 네 자리 자연수 중 ${mode === 0 ? "짝수" : "첫 자리는 홀수이고 끝자리는 짝수인 수"}의 개수를 구하시오.`,
              answer,
              independentAnswer: valid.length,
              solution: mode === 0 ? "끝자리가 0인 경우와 0이 아닌 짝수인 경우를 나눈다. 각 경우 첫자리의 0 금지와 이미 쓴 숫자를 반영하고 가운데 두 자리를 순열로 배치해 합하면 답을 얻는다." : "홀수인 첫자리와 짝수인 끝자리를 먼저 고르되 끝자리가 0인 경우를 따로 처리한다. 남은 두 자리를 순서 있게 고른 경우를 합하면 답을 얻는다.",
              hintText: "끝자리가 0인 경우에는 첫자리 제한의 계산이 달라지므로 분리하세요."
            });
          }
        },
        {
          id: "identical-letters-separation",
          titles: [
            "같은 문자들이 서로 이웃하지 않는 배열",
            "같은 문자 사이에 다른 문자가 반드시 들어가는 배열"
          ],
          sourcePattern: "한 종류의 문자를 먼저 배열하고 생긴 빈칸에 다른 같은 문자를 배치하는 간격법",
          estimatedMinutes: [10, 11],
          reasoningSteps: [
            [
              "B들을 먼저 일렬로 배열한다.",
              "B 사이와 양끝의 빈칸 수를 센다.",
              "A가 이웃하지 않도록 서로 다른 빈칸을 고른다.",
              "같은 문자 순열임을 반영해 조합으로 계산한다."
            ],
            [
              "분리 역할을 하는 문자를 먼저 놓는다.",
              "사용 가능한 간격을 만든다.",
              "각 간격에 최대 하나씩 같은 문자를 넣는다.",
              "양끝 사용 조건을 반영해 조합값을 계산한다."
            ]
          ],
          generate(mode) {
            const a = randomInteger(3, 5);
            const b = a + randomInteger(0, 2);
            const allSeparated = nCr(
              b + 1,
              a
            );
            const internalOnly = b - 1 >= a ? nCr(b - 1, a) : 0;
            const answer = mode === 0 ? allSeparated : internalOnly;
            return makeShortAnswer({
              prompt: `같은 문자 A ${a}개와 같은 문자 B ${b}개를 모두 일렬로 나열한다. ${mode === 0 ? "어떤 두 A도 서로 이웃하지 않는" : "모든 A가 두 B 사이의 내부 간격에 놓이고 어떤 두 A도 이웃하지 않는"} 경우의 수를 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? nCr(b + 1, a) : nCr(b - 1, a),
              solution: `B ${b}개를 먼저 놓으면 ${mode === 0 ? `${b + 1}개의 빈칸` : `${b - 1}개의 내부 빈칸`}이 생긴다. A가 이웃하지 않으려면 서로 다른 ${a}개 빈칸을 고르면 되므로 답은 ${answer}이다.`,
              hintText: "B를 먼저 배열해 A가 들어갈 수 있는 간격을 만드세요."
            });
          }
        },
        {
          id: "bounded-distribution",
          titles: [
            "하한과 상한이 함께 있는 정수해 개수",
            "중복조합과 포함배제로 용량 제한 분배"
          ],
          sourcePattern: "하한을 먼저 제거해 중복조합으로 바꾸고 상한 위반 경우를 포함배제로 제외",
          estimatedMinutes: [12, 13],
          reasoningSteps: [
            [
              "각 변수의 하한만큼 치환한다.",
              "남은 합의 음이 아닌 정수해를 중복조합으로 센다.",
              "상한을 넘는 변수가 있는 경우를 다시 치환해 센다.",
              "포함배제로 위반 경우를 뺀다."
            ],
            [
              "공을 상자에 분배하는 정수해로 번역한다.",
              "제한 없는 중복조합 수를 구한다.",
              "각 상자의 용량을 넘는 경우를 센다.",
              "교집합 가능성을 확인하고 포함배제를 적용한다."
            ]
          ],
          generate(mode) {
            const total = randomInteger(9, 13);
            const lower = 1;
            const upper = randomInteger(4, 6);
            let count = 0;
            for (let x = lower; x <= upper; x += 1) {
              for (let y = lower; y <= upper; y += 1) {
                for (let z = lower; z <= upper; z += 1) {
                  if (x + y + z === total) {
                    count += 1;
                  }
                }
              }
            }
            const answer = count;
            return makeShortAnswer({
              prompt: mode === 0 ? `방정식 $x+y+z=${total}$을 만족하는 정수해 중 $1\\le x,y,z\\le${upper}$인 순서쌍 $(x,y,z)$의 개수를 구하시오.` : `서로 다른 세 상자에 같은 공 ${total}개를 나누어 넣는다. 각 상자에는 1개 이상 ${upper}개 이하를 넣을 때 경우의 수를 구하시오.`,
              answer,
              independentAnswer: count,
              solution: `$x'=x-1,y'=y-1,z'=z-1$로 하한을 제거한 뒤 제한 없는 중복조합을 센다. 그중 어느 변수가 ${upper}를 넘는 경우를 새 변수로 치환해 포함배제로 빼면 ${answer}개이다.`,
              hintText: "먼저 각 변수에서 1을 빼 하한을 없앤 뒤 상한 위반 경우를 제외하세요."
            });
          }
        },
        {
          id: "lattice-path-through-avoid",
          titles: [
            "특정 점을 지나지 않는 최단경로",
            "두 지정점 중 정확히 하나를 지나는 최단경로"
          ],
          sourcePattern: "전체 최단경로에서 지정점을 지나는 경로를 구간별 조합의 곱으로 세어 포함배제",
          estimatedMinutes: [12, 14],
          reasoningSteps: [
            [
              "전체 최단경로 수를 조합으로 센다.",
              "지정점까지의 경로 수를 센다.",
              "지정점부터 도착점까지의 경로 수를 센다.",
              "곱한 금지 경로를 전체에서 뺀다."
            ],
            [
              "각 지정점을 지나는 경로 수를 구한다.",
              "두 점을 모두 지날 수 있는 순서를 확인한다.",
              "두 점을 모두 지나는 경로를 센다.",
              "대칭차 공식으로 정확히 하나만 지나는 경로를 구한다."
            ]
          ],
          generate(mode) {
            const width = randomInteger(5, 7);
            const height = randomInteger(4, 6);
            const pointA = [2, 2];
            const pointB = [3, 3];
            const total = nCr(
              width + height,
              width
            );
            const through = (point) => nCr(
              point[0] + point[1],
              point[0]
            ) * nCr(
              width - point[0] + height - point[1],
              width - point[0]
            );
            const throughA = through(pointA);
            const throughB = through(pointB);
            const throughBoth = nCr(4, 2) * nCr(2, 1) * nCr(
              width - pointB[0] + height - pointB[1],
              width - pointB[0]
            );
            const answer = mode === 0 ? total - throughA : throughA + throughB - 2 * throughBoth;
            return makeShortAnswer({
              prompt: `격자점 $(0,0)$에서 $(${width},${height})$까지 오른쪽 또는 위쪽으로만 한 칸씩 이동하는 최단경로 중 ${mode === 0 ? "점 (2,2)를 지나지 않는" : "점 (2,2)와 (3,3) 중 정확히 한 점만 지나는"} 경로의 수를 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? total - throughA : throughA + throughB - 2 * throughBoth,
              solution: mode === 0 ? `전체 경로 $\\binom{${width + height}}{${width}}$에서 (2,2)를 지나는 두 구간 경로 수의 곱을 빼면 ${answer}이다.` : `A를 지나는 수와 B를 지나는 수를 더한 뒤, 두 점을 모두 지나는 경로는 두 집합에 각각 들어가므로 두 번 빼야 한다. 결과는 ${answer}이다.`,
              hintText: "지정점을 지나는 경로는 출발→지정점과 지정점→도착의 경우의 수를 곱하세요."
            });
          }
        },
        {
          id: "binomial-coefficient-chain",
          titles: [
            "이항전개의 특정 차수 계수",
            "부호가 섞인 이항전개의 짝수차항 계수합"
          ],
          sourcePattern: "이항정리 일반항에서 지수 조건을 풀거나 x=1,-1 대입으로 계수합 분리",
          estimatedMinutes: [11, 12],
          reasoningSteps: [
            [
              "이항전개의 일반항을 쓴다.",
              "x의 지수를 목표 차수와 같게 둔다.",
              "선택 횟수 r을 결정한다.",
              "조합과 계수의 거듭제곱을 계산한다."
            ],
            [
              "전체 계수합을 x=1로 구한다.",
              "짝·홀 차수 부호가 바뀐 합을 x=-1로 구한다.",
              "두 식을 더해 짝수차항만 남긴다.",
              "2로 나눠 목표 계수합을 구한다."
            ]
          ],
          generate(mode) {
            const n = randomInteger(6, 9);
            const coefficient = randomInteger(2, 4);
            const r = randomInteger(2, n - 2);
            const targetPower = n - r;
            const specific = nCr(n, r) * power(coefficient, r);
            const evenSum = (power(
              1 + coefficient,
              n
            ) + power(
              1 - coefficient,
              n
            )) / 2;
            const answer = mode === 0 ? specific : evenSum;
            return makeShortAnswer({
              prompt: mode === 0 ? `$(x+${coefficient})^{${n}}$의 전개식에서 $x^{${targetPower}}$의 계수를 구하시오.` : `$(x+${coefficient})^{${n}}=a_0+a_1x+\\cdots+a_${n}x^{${n}}$일 때, $a_0+a_2+a_4+\\cdots$의 값을 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? nCr(n, r) * power(
                coefficient,
                r
              ) : evenSum,
              solution: mode === 0 ? `일반항 $\\binom{${n}}r x^{${n}-r}${coefficient}^r$에서 $r=${r}$. 따라서 계수는 ${answer}이다.` : `$x=1$과 $x=-1$을 각각 대입한 두 식을 더하면 짝수 차수 계수만 2배로 남는다. 따라서 답은 ${answer}이다.`,
              hintText: mode === 0 ? "일반항의 x 지수를 목표 지수와 같게 두세요." : "다항식에 x=1과 x=-1을 대입한 값을 더해 보세요."
            });
          }
        },
        {
          id: "circular-adjacency",
          titles: [
            "원순열에서 지정된 두 사람을 이웃하게 배치",
            "원순열에서 지정된 두 사람이 이웃하지 않는 배치"
          ],
          sourcePattern: "회전이 같은 원순열에서 두 대상을 한 묶음으로 보거나 전체에서 인접한 경우를 제외",
          estimatedMinutes: [11, 12],
          reasoningSteps: [
            [
              "두 지정 인물을 하나의 블록으로 묶는다.",
              "블록을 포함한 대상들의 원순열을 센다.",
              "블록 내부 순서 두 가지를 곱한다.",
              "회전 중복이 제거됐는지 확인한다."
            ],
            [
              "전체 원순열의 수를 구한다.",
              "두 지정 인물이 이웃한 경우를 블록으로 센다.",
              "전체에서 인접한 경우를 뺀다.",
              "작은 사례로 회전 중복을 검산한다."
            ]
          ],
          generate(mode) {
            const people = randomInteger(6, 9);
            const adjacent = 2 * factorial(people - 2);
            const total = factorial(people - 1);
            const answer = mode === 0 ? adjacent : total - adjacent;
            return makeShortAnswer({
              prompt: `서로 다른 ${people}명이 원형 탁자에 둘러앉을 때, 두 사람 A, B가 ${mode === 0 ? "서로 이웃하는" : "서로 이웃하지 않는"} 경우의 수를 구하시오. (회전하여 같은 것은 같은 배치)`,
              answer,
              independentAnswer: mode === 0 ? 2 * factorial(
                people - 2
              ) : factorial(
                people - 1
              ) - 2 * factorial(
                people - 2
              ),
              solution: `전체 원순열은 $(${people}-1)!$개이다. A, B를 한 블록으로 보면 인접한 경우는 $2(${people}-2)!$개이므로 요구한 수는 ${answer}이다.`,
              hintText: "A와 B를 내부 순서가 두 가지인 하나의 블록으로 보세요."
            });
          }
        },
        {
          id: "surjective-distribution",
          titles: [
            "서로 다른 공을 빈 상자 없이 분배",
            "한 상자의 개수를 고정한 전사 분배"
          ],
          sourcePattern: "서로 다른 물건의 전체 함수 배치에서 빈 상자가 생기는 경우를 포함배제로 제거",
          estimatedMinutes: [13, 14],
          reasoningSteps: [
            [
              "각 공이 들어갈 상자를 고르는 전체 경우를 센다.",
              "특정 상자가 비는 경우를 센다.",
              "두 상자가 동시에 비는 중복을 보정한다.",
              "포함배제로 빈 상자가 없는 경우를 구한다."
            ],
            [
              "지정 상자에 들어갈 두 공을 고른다.",
              "나머지 공을 두 상자에 분배한다.",
              "두 상자 중 하나가 비는 경우를 뺀다.",
              "선택과 분배의 수를 곱한다."
            ]
          ],
          generate(mode) {
            const balls = randomInteger(5, 8);
            const onto = power(3, balls) - 3 * power(2, balls) + 3;
            const fixed = nCr(balls, 2) * (power(
              2,
              balls - 2
            ) - 2);
            const answer = mode === 0 ? onto : fixed;
            return makeShortAnswer({
              prompt: `서로 다른 공 ${balls}개를 서로 다른 상자 A, B, C에 넣는다. ${mode === 0 ? "세 상자가 모두 비지 않게" : "A에는 정확히 2개를 넣고 B, C도 비지 않게"} 넣는 경우의 수를 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? power(3, balls) - 3 * power(2, balls) + 3 : nCr(balls, 2) * (power(
                2,
                balls - 2
              ) - 2),
              solution: mode === 0 ? `전체 $3^{${balls}}$에서 한 상자가 빈 경우를 빼고 두 상자가 빈 중복을 더하면 ${answer}이다.` : `A에 넣을 두 공을 고른 뒤 남은 공을 B, C에 모두 사용하여 분배한다. $\\binom{${balls}}2(2^{${balls - 2}}-2)=${answer}$.`,
              hintText: "빈 상자가 생기는 경우를 포함배제로 제거하세요."
            });
          }
        },
        {
          id: "vowel-consonant-arrangement",
          titles: [
            "모음이 모두 붙어 있는 서로 다른 문자 배열",
            "모음끼리 이웃하지 않는 문자 배열"
          ],
          sourcePattern: "모음을 하나의 블록으로 묶거나 자음 배열의 빈칸에 모음을 배치하는 문자열 순열",
          estimatedMinutes: [11, 13],
          reasoningSteps: [
            [
              "모음 전체를 하나의 블록으로 묶는다.",
              "블록과 자음을 배열한다.",
              "블록 내부 모음 순서를 센다.",
              "두 경우의 수를 곱한다."
            ],
            [
              "자음을 먼저 일렬로 배열한다.",
              "자음 사이와 양 끝의 빈칸 수를 센다.",
              "서로 다른 빈칸에 모음을 배치한다.",
              "모음 내부 순서까지 곱한다."
            ]
          ],
          generate(mode) {
            const vowels = randomInteger(2, 3);
            const consonants = vowels + randomInteger(1, 3);
            const together = factorial(consonants + 1) * factorial(vowels);
            const separated = factorial(consonants) * nCr(
              consonants + 1,
              vowels
            ) * factorial(vowels);
            const answer = mode === 0 ? together : separated;
            return makeShortAnswer({
              prompt: `서로 다른 모음 ${vowels}개와 서로 다른 자음 ${consonants}개를 모두 한 줄로 배열할 때, ${mode === 0 ? "모음이 모두 이웃하는" : "어느 두 모음도 이웃하지 않는"} 경우의 수를 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? factorial(
                consonants + 1
              ) * factorial(vowels) : factorial(
                consonants
              ) * nCr(
                consonants + 1,
                vowels
              ) * factorial(vowels),
              solution: mode === 0 ? `모음 블록 하나와 자음 ${consonants}개를 배열하고 블록 내부를 배열하면 ${answer}이다.` : `자음을 먼저 배열한 뒤 생기는 ${consonants + 1}개 빈칸 중 ${vowels}개를 골라 모음을 배열하면 ${answer}이다.`,
              hintText: mode === 0 ? "모음 전체를 하나의 큰 문자처럼 묶으세요." : "자음을 먼저 놓고 그 사이의 빈칸을 세세요."
            });
          }
        },
        {
          id: "committee-composition",
          titles: [
            "두 집단에서 최소 인원을 만족하는 위원회",
            "두 지정 인물의 포함 관계가 있는 위원회"
          ],
          sourcePattern: "집단별 선택 수를 나눠 조합의 곱을 더하거나 지정 인물의 포함·제외 조건으로 경우를 분할",
          estimatedMinutes: [12, 13],
          reasoningSteps: [
            [
              "위원회에 포함될 첫 집단 인원 수의 범위를 정한다.",
              "각 인원 수마다 두 집단의 조합 수를 곱한다.",
              "가능한 구성별 경우의 수를 더한다.",
              "전체 인원 조건을 다시 확인한다."
            ],
            [
              "두 지정 인물 중 정확히 한 명을 고른다.",
              "남은 자리의 집단별 최소 조건을 확인한다.",
              "가능한 구성으로 나눠 조합을 계산한다.",
              "서로 겹치지 않는 경우를 합한다."
            ]
          ],
          generate(mode) {
            const firstGroup = randomInteger(5, 7);
            const secondGroup = randomInteger(5, 7);
            const size = 4;
            const atLeastTwo = Array.from(
              { length: 3 },
              (_, index) => {
                const firstChosen = index + 2;
                const secondChosen = size - firstChosen;
                return secondChosen >= 1 ? nCr(
                  firstGroup,
                  firstChosen
                ) * nCr(
                  secondGroup,
                  secondChosen
                ) : 0;
              }
            ).reduce(
              (sum, value) => sum + value,
              0
            );
            const exactlyOneDesignated = 2 * nCr(
              firstGroup + secondGroup - 2,
              size - 1
            );
            const answer = mode === 0 ? atLeastTwo : exactlyOneDesignated;
            return makeShortAnswer({
              prompt: `A집단 ${firstGroup}명과 B집단 ${secondGroup}명 중 ${size}명의 위원회를 만든다. ${mode === 0 ? "A집단에서 적어도 2명, B집단에서 적어도 1명을 뽑는" : "서로 다른 지정 인물 P, Q 중 정확히 한 명만 뽑는"} 경우의 수를 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? [2, 3].map(
                (firstChosen) => nCr(
                  firstGroup,
                  firstChosen
                ) * nCr(
                  secondGroup,
                  size - firstChosen
                )
              ).reduce(
                (sum, value) => sum + value,
                0
              ) : 2 * nCr(
                firstGroup + secondGroup - 2,
                size - 1
              ),
              solution: mode === 0 ? `가능한 구성은 (A,B)=(2,2),(3,1)이다. 각 조합의 곱을 더하면 ${answer}이다.` : `P, Q 중 포함할 한 명을 2가지로 고르고 나머지 ${size - 1}명을 다른 사람 중에서 고르면 ${answer}이다.`,
              hintText: "집단별로 몇 명을 뽑는지 가능한 구성을 먼저 모두 적으세요."
            });
          }
        },
        {
          id: "laurent-binomial-term",
          titles: [
            "양의 지수와 음의 지수가 섞인 이항전개의 상수항",
            "로랑형 이항전개의 지정 차수 계수"
          ],
          sourcePattern: "(x^p+a/x)^n의 일반항에서 x의 전체 지수를 계산해 목표 차수와 같게 두는 유형",
          estimatedMinutes: [12, 13],
          reasoningSteps: [
            [
              "이항전개의 일반항을 쓴다.",
              "x의 양의 지수와 음의 지수를 합친다.",
              "전체 지수가 0이 되는 선택 횟수를 구한다.",
              "조합과 상수의 거듭제곱을 계산한다."
            ],
            [
              "r번째 선택항의 x 지수를 식으로 나타낸다.",
              "목표 지수와 같게 두어 r을 푼다.",
              "허용 범위의 정수인지 확인한다.",
              "해당 일반항의 계수를 계산한다."
            ]
          ],
          generate(mode) {
            const coefficient = randomInteger(2, 4);
            const n = 6;
            const target = mode === 0 ? 0 : 3;
            const selected = mode === 0 ? 4 : 3;
            const answer = nCr(n, selected) * power(
              coefficient,
              selected
            );
            return makeShortAnswer({
              prompt: `$(x^2+\\dfrac{${coefficient}}x)^6$의 전개식에서 ${mode === 0 ? "상수항을" : "$x^3$의 계수를"} 구하시오.`,
              answer,
              independentAnswer: nCr(n, selected) * power(
                coefficient,
                selected
              ),
              solution: `두 번째 항을 r번 고른 일반항의 x 지수는 $2(6-r)-r=12-3r$이다. 이를 ${target}과 같게 두면 $r=${selected}$이고 계수는 ${answer}이다.`,
              hintText: "두 번째 항을 r번 선택했을 때 x의 전체 지수를 먼저 계산하세요."
            });
          }
        }
      ];
      module.exports = {
        courseId,
        unitId,
        requiredConceptIds,
        minimumAppliedPoolSize: 15,
        appliedPolicy: {
          includeBankTypes: true,
          minimumLocalDifficulty: 3
        },
        advancedTemplates: defineAdvancedTemplates({
          courseId,
          unitId,
          requiredConceptIds,
          families
        })
      };
    }
  });

  // services/assessmentTemplates/probabilityStatistics/probability.js
  var require_probability = __commonJS({
    "services/assessmentTemplates/probabilityStatistics/probability.js"(exports, module) {
      var {
        randomInteger,
        choose,
        fraction,
        nCr,
        power,
        makeShortAnswer,
        defineAdvancedTemplates
      } = require_shared();
      var courseId = "probability-statistics";
      var unitId = "probability";
      var requiredConceptIds = [
        "probability-statistics-02-01",
        "probability-statistics-02-02",
        "probability-statistics-02-03",
        "probability-statistics-02-04",
        "probability-statistics-02-05",
        "probability-statistics-02-06"
      ];
      var families = [
        {
          id: "bayes-two-sources",
          titles: [
            "두 주머니의 결과에서 원인을 역추론하는 조건부확률",
            "서로 다른 사전확률을 가진 두 원인의 베이즈 계산"
          ],
          sourcePattern: "원인을 먼저 선택하고 결과를 관찰한 상황에서 곱셈정리와 전체확률로 사후확률 계산",
          estimatedMinutes: [12, 13],
          reasoningSteps: [
            [
              "각 주머니가 선택될 확률을 정한다.",
              "각 주머니에서 빨간 공이 나올 결합확률을 구한다.",
              "빨간 공이 나올 전체확률을 더한다.",
              "목표 결합확률을 전체확률로 나눈다."
            ],
            [
              "사전확률과 조건부확률을 곱한다.",
              "두 원인의 관찰 결과 확률을 구한다.",
              "전체확률법칙으로 분모를 만든다.",
              "베이즈 형태로 사후확률을 계산한다."
            ]
          ],
          generate(mode) {
            const totalA = randomInteger(5, 8);
            const totalB = randomInteger(5, 8);
            const redA = randomInteger(
              1,
              totalA - 1
            );
            const redB = randomInteger(
              1,
              totalB - 1
            );
            const priorA = mode === 0 ? 1 : 2;
            const priorB = mode === 0 ? 1 : 1;
            const numerator = priorA * redA * totalB;
            const denominator = numerator + priorB * redB * totalA;
            const answer = fraction(
              numerator,
              denominator
            );
            return makeShortAnswer({
              prompt: `주머니 A에는 빨간 공 ${redA}개를 포함해 ${totalA}개, B에는 빨간 공 ${redB}개를 포함해 ${totalB}개의 공이 있다. ${mode === 0 ? "두 주머니 중 하나를 같은 확률로" : "A와 B를 각각 2/3, 1/3의 확률로"} 골라 공 한 개를 꺼냈더니 빨간 공이었다. A를 골랐을 확률을 구하시오. (기약분수로 입력)`,
              answer,
              independentAnswer: fraction(
                numerator,
                denominator
              ),
              solution: `A에서 빨강이 나오는 결합확률과 B에서 빨강이 나오는 결합확률을 각각 구한다. 조건부확률은 전자를 두 결합확률의 합으로 나눈 값이므로 ${answer}이다.`,
              hintText: "원인 선택 확률×그 원인에서 결과가 나올 확률을 두 경우 각각 계산하세요."
            });
          }
        },
        {
          id: "without-replacement-condition",
          titles: [
            "비복원 추출에서 첫 결과를 조건으로 한 확률",
            "두 번 추출의 결과를 관찰한 뒤 첫 추출 역추론"
          ],
          sourcePattern: "비복원 추출에서 첫 시행 후 남은 구성 변화를 반영하거나 관찰 결과로 순서를 역추론",
          estimatedMinutes: [11, 13],
          reasoningSteps: [
            [
              "첫 추출 결과로 남은 공의 구성을 갱신한다.",
              "조건이 된 표본공간을 고정한다.",
              "둘째 추출의 유리한 경우와 전체 경우를 센다.",
              "조건부확률을 기약분수로 정리한다."
            ],
            [
              "가능한 색 순서를 나열한다.",
              "각 순서의 결합확률을 곱셈정리로 구한다.",
              "관찰 조건을 만족하는 순서만 남긴다.",
              "목표 순서의 확률을 조건 전체로 나눈다."
            ]
          ],
          generate(mode) {
            const red = randomInteger(3, 6);
            const blue = randomInteger(3, 6);
            const total = red + blue;
            const answer = mode === 0 ? fraction(
              red - 1,
              total - 1
            ) : "1/2";
            return makeShortAnswer({
              prompt: mode === 0 ? `빨간 공 ${red}개와 파란 공 ${blue}개가 든 주머니에서 공을 한 개씩 되돌려 넣지 않고 두 번 꺼낸다. 첫째 공이 빨간색일 때 둘째 공도 빨간색일 확률을 구하시오.` : `빨간 공 ${red}개와 파란 공 ${blue}개가 든 주머니에서 공을 한 개씩 되돌려 넣지 않고 두 번 꺼냈더니 두 공의 색이 달랐다. 첫째 공이 빨간색이었을 확률을 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? fraction(
                red - 1,
                total - 1
              ) : fraction(
                red * blue,
                red * blue + blue * red
              ),
              solution: mode === 0 ? `첫째 공이 빨강이면 남은 ${total - 1}개 중 빨간 공은 ${red - 1}개이므로 확률은 ${answer}.` : `색이 다른 순서는 RB와 BR이다. 두 순서의 확률은 모두 $\\frac{${red}}{${total}}\\frac{${blue}}{${total - 1}}$로 같으므로 조건 아래에서 각각 1/2이다.`,
              hintText: "되돌려 넣지 않으므로 첫 추출 뒤 분자와 분모가 어떻게 바뀌는지 적으세요."
            });
          }
        },
        {
          id: "independent-repeated-events",
          titles: [
            "독립 반복에서 적어도 한 번 성공할 확률",
            "첫 성공 시점이 제한 안에 있을 조건부확률"
          ],
          sourcePattern: "독립시행의 여사건 또는 첫 성공 시점별 배반사건을 이용한 반복확률",
          estimatedMinutes: [10, 12],
          reasoningSteps: [
            [
              "한 번 실패할 확률을 구한다.",
              "모두 실패하는 확률을 독립 곱으로 계산한다.",
              "여사건을 취한다.",
              "분수를 기약화한다."
            ],
            [
              "첫 성공이 각 시행에서 일어날 사건을 나눈다.",
              "각 사건의 확률을 독립 곱으로 구한다.",
              "조건 사건의 전체확률을 구한다.",
              "목표 시점까지의 확률을 나눠 조건부확률을 계산한다."
            ]
          ],
          generate(mode) {
            const denominator = choose([3, 4, 5]);
            const numerator = denominator - 1;
            const trials = randomInteger(3, 5);
            const fail = denominator - numerator;
            const atLeast = fraction(
              power(
                denominator,
                trials
              ) - power(fail, trials),
              power(
                denominator,
                trials
              )
            );
            const byTwoGivenByN = fraction(
              (denominator ** 2 - fail ** 2) * denominator ** (trials - 2),
              denominator ** trials - fail ** trials
            );
            const answer = mode === 0 ? atLeast : byTwoGivenByN;
            return makeShortAnswer({
              prompt: mode === 0 ? `한 번 성공할 확률이 $\\frac{${numerator}}{${denominator}}$인 독립시행을 ${trials}번 할 때 적어도 한 번 성공할 확률을 구하시오.` : `한 번 성공할 확률이 $\\frac{${numerator}}{${denominator}}$인 독립시행을 성공할 때까지 반복하되 최대 ${trials}번만 한다. ${trials}번 안에 성공했다는 조건에서 2번 안에 성공했을 확률을 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? atLeast : fraction(
                (denominator ** 2 - fail ** 2) * denominator ** (trials - 2),
                denominator ** trials - fail ** trials
              ),
              solution: mode === 0 ? `모두 실패할 확률을 1에서 빼면 ${answer}이다.` : `2번 안에 성공할 사건은 ${trials}번 안에 성공할 사건에 포함된다. 따라서 $\\frac{1-q^2}{1-q^{${trials}}}$를 계산하면 답을 얻는다.`,
              hintText: "적어도 한 번 성공은 모두 실패의 여사건입니다."
            });
          }
        },
        {
          id: "three-event-inclusion-exclusion",
          titles: [
            "세 사건의 합사건 확률 포함배제",
            "적어도 두 사건이 일어날 확률"
          ],
          sourcePattern: "세 사건의 개별·쌍별·삼중 교집합 확률을 포함배제 또는 지시함수 계수로 결합",
          estimatedMinutes: [12, 13],
          reasoningSteps: [
            [
              "세 개별사건 확률을 더한다.",
              "쌍별 교집합을 한 번씩 뺀다.",
              "삼중 교집합을 다시 더한다.",
              "여사건이 필요하면 마지막에 1에서 뺀다."
            ],
            [
              "정확히 세 사건이 일어나는 확률을 분리한다.",
              "쌍별 교집합 합에서 삼중교집합이 세 번 세어짐을 확인한다.",
              "적어도 두 사건 확률로 계수를 보정한다.",
              "기약분수로 정리한다."
            ]
          ],
          generate(mode) {
            const denominator = 20;
            const singles = [9, 10, 11];
            const pairs = [4, 3, 5];
            const triple = 2;
            const union = singles.reduce(
              (sum, value) => sum + value,
              0
            ) - pairs.reduce(
              (sum, value) => sum + value,
              0
            ) + triple;
            const atLeastTwo = pairs.reduce(
              (sum, value) => sum + value,
              0
            ) - 2 * triple;
            const answer = mode === 0 ? fraction(
              union,
              denominator
            ) : fraction(
              atLeastTwo,
              denominator
            );
            return makeShortAnswer({
              prompt: `세 사건 $A,B,C$에 대하여 $P(A),P(B),P(C)$의 분자가 각각 ${singles.join(
                ","
              )}, $P(A\\cap B),P(B\\cap C),P(C\\cap A)$의 분자가 각각 ${pairs.join(
                ","
              )}, $P(A\\cap B\\cap C)$의 분자가 ${triple}이고 모든 분모는 ${denominator}이다. ${mode === 0 ? "P(A\\cup B\\cup C)" : "세 사건 중 적어도 두 사건이 일어날 확률"}을 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? fraction(
                union,
                denominator
              ) : fraction(
                atLeastTwo,
                denominator
              ),
              solution: mode === 0 ? "세 개별확률의 합에서 세 쌍별 교집합을 빼고 삼중교집합을 더한다." : "쌍별 교집합의 합에서는 삼중교집합이 세 번 세어지지만 적어도 두 사건 확률에서는 한 번만 세어야 하므로 두 번 뺀다.",
              hintText: "삼중교집합이 현재 몇 번 세어졌는지 계수를 추적하세요."
            });
          }
        },
        {
          id: "conditional-dice-sum",
          titles: [
            "두 주사위 합 조건에서 곱의 성질 확률",
            "최댓값 조건으로 축소된 표본공간의 조건부확률"
          ],
          sourcePattern: "관찰된 합·최댓값 조건을 만족하는 순서쌍만 다시 열거해 조건부 표본공간 구성",
          estimatedMinutes: [11, 11],
          reasoningSteps: [
            [
              "두 주사위 순서쌍을 표본점으로 둔다.",
              "합 조건을 만족하는 순서쌍만 나열한다.",
              "그중 곱의 목표 성질을 만족하는 경우를 센다.",
              "조건 표본공간 크기로 나눈다."
            ],
            [
              "최댓값 조건을 만족하는 순서쌍을 센다.",
              "두 눈이 다른 경우만 추린다.",
              "조건 아래 모든 순서쌍이 같은 가능성인지 확인한다.",
              "유리한 경우를 전체로 나눈다."
            ]
          ],
          generate(mode) {
            const targetSum = randomInteger(6, 9);
            const targetMax = randomInteger(3, 6);
            const pairs = [];
            for (let first = 1; first <= 6; first += 1) {
              for (let second = 1; second <= 6; second += 1) {
                pairs.push([
                  first,
                  second
                ]);
              }
            }
            const condition = mode === 0 ? pairs.filter(
              ([a, b]) => a + b === targetSum
            ) : pairs.filter(
              ([a, b]) => Math.max(a, b) === targetMax
            );
            const favorable = mode === 0 ? condition.filter(
              ([a, b]) => a * b % 2 === 0
            ) : condition.filter(
              ([a, b]) => a !== b
            );
            const answer = fraction(
              favorable.length,
              condition.length
            );
            return makeShortAnswer({
              prompt: mode === 0 ? `서로 다른 두 주사위를 던져 나온 눈의 합이 ${targetSum}이었다. 두 눈의 곱이 짝수일 확률을 구하시오.` : `서로 다른 두 주사위를 던져 나온 두 눈의 최댓값이 ${targetMax}였다. 두 눈이 서로 다를 확률을 구하시오.`,
              answer,
              independentAnswer: fraction(
                favorable.length,
                condition.length
              ),
              solution: `조건을 만족하는 순서쌍을 모두 나열하면 ${condition.length}개이고, 그중 목표 사건은 ${favorable.length}개이다. 조건부확률은 ${answer}이다.`,
              hintText: "원래 36개가 아니라 관찰 조건을 만족하는 순서쌍만 새 표본공간으로 쓰세요."
            });
          }
        },
        {
          id: "fixed-position-permutation",
          titles: [
            "무작위 순열에서 두 지정 원소가 모두 제자리를 피할 확률",
            "무작위 순열에서 두 지정 원소가 모두 제자리일 확률"
          ],
          sourcePattern: "전체 순열에서 지정 원소의 고정 사건을 포함배제로 세거나 두 자리를 고정한 뒤 나머지를 배열",
          estimatedMinutes: [12, 11],
          reasoningSteps: [
            [
              "전체 순열의 수를 센다.",
              "각 지정 원소가 제자리인 사건의 크기를 구한다.",
              "두 사건의 교집합 크기를 구한다.",
              "포함배제로 두 원소가 모두 제자리를 피할 확률을 계산한다."
            ],
            [
              "두 지정 원소의 자리를 고정한다.",
              "나머지 원소의 순열 수를 센다.",
              "전체 순열 수로 나눈다.",
              "계승을 약분해 기약분수로 정리한다."
            ]
          ],
          generate(mode) {
            const size = randomInteger(5, 8);
            const numerator = mode === 0 ? size ** 2 - 3 * size + 3 : 1;
            const denominator = size * (size - 1);
            const answer = fraction(
              numerator,
              denominator
            );
            return makeShortAnswer({
              prompt: `서로 다른 ${size}개의 카드를 무작위로 한 줄에 배열한다. 지정된 두 카드 A, B에 대하여 ${mode === 0 ? "A와 B가 모두 원래 자기 자리에 놓이지 않을" : "A와 B가 모두 원래 자기 자리에 놓일"} 확률을 구하시오. (기약분수로 입력)`,
              answer,
              independentAnswer: mode === 0 ? fraction(
                size ** 2 - 3 * size + 3,
                size * (size - 1)
              ) : fraction(
                1,
                size * (size - 1)
              ),
              solution: mode === 0 ? `A 또는 B가 제자리인 확률에 포함배제를 적용하면 $1-2/${size}+1/(${size}(${size}-1))=${answer}$이다.` : `두 자리를 고정한 배열은 $(${size}-2)!$개, 전체는 $${size}!$개이므로 확률은 ${answer}이다.`,
              hintText: mode === 0 ? "A가 제자리인 사건과 B가 제자리인 사건의 합집합을 먼저 구하세요." : "두 자리를 고정한 뒤 나머지만 배열하세요."
            });
          }
        },
        {
          id: "first-success-stopping",
          titles: [
            "독립시행에서 첫 성공 시점의 확률",
            "기한 내 성공 조건에서 마지막 시행 첫 성공의 조건부확률"
          ],
          sourcePattern: "독립 베르누이 시행에서 앞선 실패들의 곱과 현재 성공확률을 결합하고 조건부 표본공간으로 정규화",
          estimatedMinutes: [11, 13],
          reasoningSteps: [
            [
              "한 시행의 성공확률과 실패확률을 구분한다.",
              "목표 시점 전까지 모두 실패할 확률을 곱한다.",
              "목표 시점에 성공할 확률을 곱한다.",
              "거듭제곱을 계산해 기약분수로 정리한다."
            ],
            [
              "k회째 첫 성공 사건의 확률을 구한다.",
              "k회 이내 적어도 한 번 성공할 확률을 여사건으로 구한다.",
              "첫 사건이 조건 사건에 포함됨을 확인한다.",
              "두 확률의 비로 조건부확률을 계산한다."
            ]
          ],
          generate(mode) {
            const denominator = choose([2, 3, 4]);
            const successNumerator = 1;
            const failureNumerator = denominator - 1;
            const attempt = randomInteger(3, 5);
            const firstNumerator = power(
              failureNumerator,
              attempt - 1
            ) * successNumerator;
            const firstDenominator = power(
              denominator,
              attempt
            );
            const byAttemptNumerator = power(
              denominator,
              attempt
            ) - power(
              failureNumerator,
              attempt
            );
            const answer = mode === 0 ? fraction(
              firstNumerator,
              firstDenominator
            ) : fraction(
              firstNumerator,
              byAttemptNumerator
            );
            return makeShortAnswer({
              prompt: `성공확률이 $1/${denominator}$인 독립시행을 반복한다. ${mode === 0 ? `제${attempt}회 시행에서 처음 성공할` : `제${attempt}회 이내에 성공했다는 조건 아래 제${attempt}회에서 처음 성공했을`} 확률을 구하시오. (기약분수로 입력)`,
              answer,
              independentAnswer: mode === 0 ? fraction(
                power(
                  denominator - 1,
                  attempt - 1
                ),
                power(
                  denominator,
                  attempt
                )
              ) : fraction(
                power(
                  denominator - 1,
                  attempt - 1
                ),
                power(
                  denominator,
                  attempt
                ) - power(
                  denominator - 1,
                  attempt
                )
              ),
              solution: `제${attempt}회 첫 성공 확률은 $(${denominator - 1}/${denominator})^{${attempt - 1}}(1/${denominator})$${mode === 0 ? `이므로 ${answer}이다.` : `이고, ${attempt}회 이내 성공 확률은 $1-(${denominator - 1}/${denominator})^{${attempt}}$이다. 두 확률의 비는 ${answer}이다.`}`,
              hintText: "첫 성공 전의 시행은 모두 실패해야 하며, 조건부확률에서는 기한 내 성공 확률로 나눕니다."
            });
          }
        },
        {
          id: "independent-unknown-probability",
          titles: [
            "독립사건의 합집합에서 미지 확률 복원",
            "독립사건의 교집합·여사건 결합"
          ],
          sourcePattern: "독립성 P(A∩B)=P(A)P(B)를 합집합 또는 여사건 공식에 대입해 미지확률을 결정",
          estimatedMinutes: [11, 12],
          reasoningSteps: [
            [
              "P(B)=p로 둔다.",
              "독립성으로 교집합 확률을 표현한다.",
              "합집합 공식에 대입해 p의 일차방정식을 푼다.",
              "구한 확률로 목표 사건을 계산한다."
            ],
            [
              "두 여사건도 독립임을 사용한다.",
              "적어도 하나가 일어날 확률의 여사건을 만든다.",
              "미지 확률을 복원한다.",
              "교집합 확률을 곱셈정리로 계산한다."
            ]
          ],
          generate(mode) {
            const aNumerator = choose([1, 2]);
            const aDenominator = 3;
            const bNumerator = choose([1, 2, 3]);
            const bDenominator = 4;
            const unionNumerator = aNumerator * bDenominator + bNumerator * aDenominator - aNumerator * bNumerator;
            const unionDenominator = aDenominator * bDenominator;
            const intersection = fraction(
              aNumerator * bNumerator,
              aDenominator * bDenominator
            );
            const answer = mode === 0 ? fraction(
              bNumerator,
              bDenominator
            ) : intersection;
            return makeShortAnswer({
              prompt: `서로 독립인 두 사건 $A,B$에 대하여 $P(A)=${fraction(aNumerator, aDenominator)}$, $P(A\\cup B)=${fraction(unionNumerator, unionDenominator)}$이다. $${mode === 0 ? "P(B)" : "P(A\\cap B)"}$를 구하시오. (기약분수로 입력)`,
              answer,
              independentAnswer: mode === 0 ? fraction(
                bNumerator,
                bDenominator
              ) : fraction(
                aNumerator * bNumerator,
                aDenominator * bDenominator
              ),
              solution: `$P(B)=p$라 하면 독립성에서 $P(A\\cap B)=P(A)p$. 합집합 공식에 대입해 $p=${fraction(bNumerator, bDenominator)}$를 얻고, ${mode === 0 ? "" : `다시 곱하면 $P(A\\cap B)=${intersection}$.`} 답은 ${answer}이다.`,
              hintText: "합집합 공식의 교집합을 P(A)P(B)로 바꾸세요."
            });
          }
        },
        {
          id: "bayes-three-sources",
          titles: [
            "세 생산라인의 불량품 원인 역추론",
            "서로 다른 사전확률을 가진 세 원인의 사후확률"
          ],
          sourcePattern: "세 원인의 사전확률과 각 조건부 발생확률을 곱해 전체확률을 만들고 특정 원인의 사후확률 계산",
          estimatedMinutes: [13, 14],
          reasoningSteps: [
            [
              "각 생산라인에서 불량이 나올 결합확률을 구한다.",
              "세 결합확률을 더해 전체 불량확률을 구한다.",
              "목표 생산라인의 결합확률을 분자로 둔다.",
              "베이즈 정리로 사후확률을 계산한다."
            ],
            [
              "원인별 사전확률과 관찰확률을 곱한다.",
              "관찰 사건의 전체확률로 정규화한다.",
              "두 목표 원인의 사후확률을 각각 구한다.",
              "두 사후확률의 합을 기약분수로 정리한다."
            ]
          ],
          generate(mode) {
            const production = [2, 3, 5];
            const defect = [
              randomInteger(1, 2),
              randomInteger(2, 3),
              randomInteger(3, 4)
            ];
            const weights = production.map(
              (share, index) => share * defect[index]
            );
            const total = weights.reduce(
              (sum, value) => sum + value,
              0
            );
            const numerator = mode === 0 ? weights[2] : weights[1] + weights[2];
            const answer = fraction(
              numerator,
              total
            );
            return makeShortAnswer({
              prompt: `공장 A, B, C의 생산비율이 각각 $2/10,3/10,5/10$이고 불량률이 각각 $${defect[0]}/100,${defect[1]}/100,${defect[2]}/100$이다. 임의의 제품이 불량품일 때, ${mode === 0 ? "공장 C에서 생산되었을" : "공장 B 또는 C에서 생산되었을"} 확률을 구하시오. (기약분수로 입력)`,
              answer,
              independentAnswer: fraction(
                numerator,
                total
              ),
              solution: `불량품이면서 각 공장 제품일 상대 가중치는 $${weights[0]}:${weights[1]}:${weights[2]}$이고 합은 ${total}이다. 목표 가중치를 합으로 나누면 ${answer}이다.`,
              hintText: "각 공장의 생산비율과 그 공장의 불량률을 먼저 곱하세요."
            });
          }
        },
        {
          id: "conditional-card-composition",
          titles: [
            "적어도 한 장이 빨간색일 때 두 장 모두 빨간색",
            "적어도 한 장이 빨간색일 때 정확히 한 장만 빨간색"
          ],
          sourcePattern: "비복원 추출의 조합 표본공간에서 관찰 조건에 맞지 않는 경우를 제외하고 조건부확률 계산",
          estimatedMinutes: [12, 12],
          reasoningSteps: [
            [
              "두 장을 고르는 전체 조합 수를 구한다.",
              "빨간색이 한 장도 없는 경우를 센다.",
              "조건 사건의 크기를 여사건으로 구한다.",
              "두 장 모두 빨간 경우를 조건 사건 크기로 나눈다."
            ],
            [
              "적어도 한 장 빨간 조건의 경우의 수를 구한다.",
              "빨간 한 장과 파란 한 장을 고르는 경우를 센다.",
              "조건부 표본공간 안에서 비율을 만든다.",
              "기약분수로 정리한다."
            ]
          ],
          generate(mode) {
            const red = randomInteger(3, 6);
            const blue = randomInteger(3, 6);
            const condition = nCr(red + blue, 2) - nCr(blue, 2);
            const favorable = mode === 0 ? nCr(red, 2) : red * blue;
            const answer = fraction(
              favorable,
              condition
            );
            return makeShortAnswer({
              prompt: `빨간 카드 ${red}장과 파란 카드 ${blue}장 중 동시에 2장을 임의로 뽑았다. 적어도 한 장이 빨간 카드였을 때, ${mode === 0 ? "두 장 모두 빨간 카드일" : "정확히 한 장만 빨간 카드일"} 확률을 구하시오. (기약분수로 입력)`,
              answer,
              independentAnswer: fraction(
                favorable,
                condition
              ),
              solution: `조건 사건의 경우의 수는 $\\binom{${red + blue}}2-\\binom{${blue}}2=${condition}$. 목표 사건은 ${mode === 0 ? `$\\binom{${red}}2$` : `${red}\\cdot${blue}`}가지이므로 확률은 ${answer}이다.`,
              hintText: "조건부 표본공간은 전체 두 장 조합에서 파란 카드만 뽑은 경우를 뺀 것입니다."
            });
          }
        }
      ];
      module.exports = {
        courseId,
        unitId,
        requiredConceptIds,
        minimumAppliedPoolSize: 16,
        appliedPolicy: {
          includeBankTypes: true,
          minimumLocalDifficulty: 3
        },
        advancedTemplates: defineAdvancedTemplates({
          courseId,
          unitId,
          requiredConceptIds,
          families
        })
      };
    }
  });

  // services/assessmentTemplates/probabilityStatistics/statistics.js
  var require_statistics = __commonJS({
    "services/assessmentTemplates/probabilityStatistics/statistics.js"(exports, module) {
      var {
        randomInteger,
        choose,
        fraction,
        power,
        linearFactor,
        makeShortAnswer,
        defineAdvancedTemplates
      } = require_shared();
      var courseId = "probability-statistics";
      var unitId = "statistics";
      var requiredConceptIds = [
        "probability-statistics-03-01",
        "probability-statistics-03-02",
        "probability-statistics-03-03",
        "probability-statistics-03-04",
        "probability-statistics-03-05",
        "probability-statistics-03-06",
        "probability-statistics-03-07"
      ];
      var families = [
        {
          id: "distribution-table-recovery",
          titles: [
            "확률합·기댓값에서 분포표의 미지확률 복원",
            "분포표 복원 후 분산까지 계산"
          ],
          sourcePattern: "확률의 총합과 기댓값 조건을 연립해 분포표를 완성한 뒤 분산 계산",
          estimatedMinutes: [11, 13],
          reasoningSteps: [
            [
              "확률의 합이 1인 식을 세운다.",
              "기댓값 식을 세운다.",
              "두 미지확률을 연립해 구한다.",
              "목표 확률을 계산한다."
            ],
            [
              "분포표의 미지확률을 연립방정식으로 복원한다.",
              "E(X²)를 계산한다.",
              "V(X)=E(X²)-E(X)²를 적용한다.",
              "기약분수로 정리한다."
            ]
          ],
          generate(mode) {
            const p = choose([
              [2, 10],
              [3, 10]
            ]);
            const q = choose([
              [3, 10],
              [4, 10]
            ]);
            const rNumerator = 10 - p[0] - q[0];
            const expectationNumerator = q[0] + 2 * rNumerator;
            const secondNumerator = q[0] + 4 * rNumerator;
            const varianceNumerator = secondNumerator * 10 - expectationNumerator ** 2;
            const answer = mode === 0 ? fraction(
              rNumerator,
              10
            ) : fraction(
              varianceNumerator,
              100
            );
            return makeShortAnswer({
              prompt: `확률변수 $X$가 0,1,2의 값을 가지며 $P(X=0)=\\frac{${p[0]}}{10}$, $P(X=1)=\\frac{${q[0]}}{10}$이다. ${mode === 0 ? "P(X=2)" : "V(X)"}의 값을 구하시오. (기약분수로 입력)`,
              answer,
              independentAnswer: mode === 0 ? fraction(
                rNumerator,
                10
              ) : fraction(
                varianceNumerator,
                100
              ),
              solution: `확률의 합에서 $P(X=2)=${rNumerator}/10$. $E(X)=${expectationNumerator}/10$, $E(X^2)=${secondNumerator}/10$. ${mode === 0 ? `따라서 답은 ${answer}.` : `V(X)=E(X^2)-\\{E(X)\\}^2=${answer}.`}`,
              hintText: "먼저 확률의 합 1로 분포표를 완성한 뒤 E(X²)를 구하세요."
            });
          }
        },
        {
          id: "linear-transform-mean-variance",
          titles: [
            "선형변환된 확률변수의 평균·분산 역추론",
            "두 선형변환 조건에서 원래 평균과 분산 복원"
          ],
          sourcePattern: "E(aX+b)=aE(X)+b와 V(aX+b)=a²V(X)를 구분해 연쇄 적용",
          estimatedMinutes: [10, 11],
          reasoningSteps: [
            [
              "평균의 선형성을 적용한다.",
              "상수 이동은 분산에 영향이 없음을 확인한다.",
              "상수배는 분산에 제곱으로 작용함을 적용한다.",
              "평균과 분산의 목표 결합값을 계산한다."
            ],
            [
              "변환된 평균 식에서 E(X)를 구한다.",
              "변환된 분산 식에서 V(X)를 구한다.",
              "다른 선형변환의 평균을 계산한다.",
              "두 결과를 결합한다."
            ]
          ],
          generate(mode) {
            const mean = randomInteger(-3, 6);
            const variance = randomInteger(1, 5);
            const a = choose([2, 3, -2]);
            const b = randomInteger(-4, 4);
            const transformedMean = a * mean + b;
            const transformedVariance = a ** 2 * variance;
            const answer = mode === 0 ? transformedMean + transformedVariance : mean + variance;
            return makeShortAnswer({
              prompt: mode === 0 ? `확률변수 $X$의 평균이 ${mean}, 분산이 ${variance}일 때, $E(${a}X${b >= 0 ? "+" : ""}${b})+V(${a}X${b >= 0 ? "+" : ""}${b})$를 구하시오.` : `확률변수 $X$에 대하여 $E(${a}X${b >= 0 ? "+" : ""}${b})=${transformedMean}$, $V(${a}X${b >= 0 ? "+" : ""}${b})=${transformedVariance}$일 때, $E(X)+V(X)$를 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? a * mean + b + a ** 2 * variance : mean + variance,
              solution: `$E(aX+b)=aE(X)+b$, $V(aX+b)=a^2V(X)$를 각각 적용한다. ${mode === 0 ? `두 값은 ${transformedMean}, ${transformedVariance}이므로 답은 ${answer}.` : `역으로 $E(X)=${mean},V(X)=${variance}$를 얻어 답은 ${answer}.`}`,
              hintText: "평균에는 a가, 분산에는 a²이 곱해진다는 차이를 구분하세요."
            });
          }
        },
        {
          id: "binomial-mean-variance-inverse",
          titles: [
            "이항분포 평균·분산에서 n과 p 복원",
            "복원한 이항분포의 특정 확률 계산"
          ],
          sourcePattern: "E=np, V=np(1-p)에서 비를 취해 p를 먼저 구하고 n을 복원",
          estimatedMinutes: [11, 13],
          reasoningSteps: [
            [
              "평균과 분산 공식을 쓴다.",
              "V/E=1-p로 성공확률을 구한다.",
              "E=np에 대입해 시행횟수를 구한다.",
              "목표 결합값을 계산한다."
            ],
            [
              "평균·분산의 비로 p를 구한다.",
              "시행횟수 n을 복원한다.",
              "이항확률 공식을 세운다.",
              "조합과 거듭제곱을 계산한다."
            ]
          ],
          generate(mode) {
            const denominator = choose([2, 3, 4]);
            const pNumerator = 1;
            const multiplier = randomInteger(2, 4);
            const n = denominator ** 2 * multiplier;
            const mean = denominator * multiplier;
            const variance = (denominator - 1) * multiplier;
            const zeroProbability = fraction(
              power(
                denominator - 1,
                n
              ),
              power(denominator, n)
            );
            const answer = mode === 0 ? n : zeroProbability;
            return makeShortAnswer({
              prompt: `확률변수 $X$가 이항분포 $B(n,p)$를 따르고 $E(X)=${mean}$, $V(X)=${variance}$이다. $${mode === 0 ? "n" : "P(X=0)"}$의 값을 구하시오.${mode === 1 ? " (기약분수로 입력)" : ""}`,
              answer,
              independentAnswer: mode === 0 ? n : fraction(
                power(
                  denominator - 1,
                  n
                ),
                power(
                  denominator,
                  n
                )
              ),
              solution: `$V/E=1-p=${variance}/${mean}$이므로 $p=${pNumerator}/${denominator}$. $np=${mean}$에서 $n=${n}$. ${mode === 0 ? "" : `$P(X=0)=(1-p)^n=${zeroProbability}$.`}`,
              hintText: "분산을 평균으로 나누면 1-p가 바로 남습니다."
            });
          }
        },
        {
          id: "normal-standardization-chain",
          titles: [
            "정규분포의 두 경계 표준화와 대칭성",
            "확률 조건에서 원래 분포의 경계값 역산"
          ],
          sourcePattern: "평균과 표준편차로 표준화한 뒤 표준정규분포의 대칭 구간 또는 역변환 사용",
          estimatedMinutes: [11, 12],
          reasoningSteps: [
            [
              "분산에서 표준편차를 구한다.",
              "두 경계값을 z값으로 표준화한다.",
              "표준정규분포의 대칭성을 적용한다.",
              "주어진 표의 넓이를 조합한다."
            ],
            [
              "주어진 확률을 표준정규분포의 z경계와 대응시킨다.",
              "z=(x-μ)/σ 식을 세운다.",
              "원래 경계값 x를 복원한다.",
              "다른 대칭 경계와 결합한다."
            ]
          ],
          generate(mode) {
            const mean = randomInteger(40, 70);
            const sd = choose([5, 10]);
            const lower = mean - sd;
            const upper = mean + sd;
            const intervalProbability = 0.6826;
            const boundary = mean + 2 * sd;
            const answer = mode === 0 ? String(
              intervalProbability
            ) : boundary;
            return makeShortAnswer({
              prompt: mode === 0 ? `확률변수 $X$가 정규분포 $N(${mean},${sd ** 2})$를 따른다. $P(0\\le Z\\le1)=0.3413$일 때 $P(${lower}\\le X\\le${upper})$를 구하시오.` : `확률변수 $X$가 정규분포 $N(${mean},${sd ** 2})$를 따른다. $P(X\\le k)=0.9772$, $P(0\\le Z\\le2)=0.4772$일 때 $k$를 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? "0.6826" : mean + 2 * sd,
              solution: mode === 0 ? `표준화하면 $-1\\le Z\\le1$이고 대칭성으로 $2\\times0.3413=0.6826$.` : `$0.9772=0.5+0.4772$이므로 경계는 $z=2$. 따라서 $k=${mean}+2\\cdot${sd}=${boundary}$.`,
              hintText: "먼저 X의 경계를 z=(X-μ)/σ로 바꾸세요."
            });
          }
        },
        {
          id: "sampling-confidence-size",
          titles: [
            "표본평균 분포에서 표본크기 역산",
            "신뢰구간 길이 조건으로 필요한 표본크기 결정"
          ],
          sourcePattern: "표본평균의 표준편차 σ/√n 또는 신뢰구간 길이 공식을 역으로 풀어 n 결정",
          estimatedMinutes: [12, 13],
          reasoningSteps: [
            [
              "표본평균의 표준편차 공식을 쓴다.",
              "주어진 표준편차와 모표준편차를 대입한다.",
              "√n에 대한 식을 푼다.",
              "제곱해 표본크기를 구한다."
            ],
            [
              "신뢰구간의 반길이를 식으로 나타낸다.",
              "전체 길이는 반길이의 두 배임을 반영한다.",
              "√n을 고립시킨다.",
              "자연수 표본크기로 제곱해 검산한다."
            ]
          ],
          generate(mode) {
            const populationSd = choose([10, 15, 20]);
            const rootN = choose([5, 10]);
            const n = rootN ** 2;
            const sampleSd = populationSd / rootN;
            const confidenceLength = 2 * 1.96 * populationSd / rootN;
            const answer = n;
            return makeShortAnswer({
              prompt: mode === 0 ? `모표준편차가 ${populationSd}인 모집단에서 크기 $n$인 표본을 임의추출할 때 표본평균의 표준편차가 ${sampleSd}이다. $n$을 구하시오.` : `모표준편차가 ${populationSd}인 모집단의 모평균을 신뢰도 95%로 추정한다. 신뢰구간의 길이가 ${confidenceLength.toFixed(
                3
              )}일 때 표본크기 $n$을 구하시오. (단, $P(|Z|\\le1.96)=0.95$)`,
              answer,
              independentAnswer: rootN ** 2,
              solution: mode === 0 ? `$${populationSd}/\\sqrt n=${sampleSd}$에서 $\\sqrt n=${rootN}$, 따라서 $n=${n}$.` : `신뢰구간 길이는 $2\\times1.96\\times${populationSd}/\\sqrt n$. 주어진 길이와 같게 두면 $\\sqrt n=${rootN}$, $n=${n}$.`,
              hintText: "표본평균의 표준편차에는 n이 아니라 √n이 분모에 옵니다."
            });
          }
        },
        {
          id: "second-moment-recovery",
          titles: [
            "평균·분산에서 이차식의 기댓값 복원",
            "중심 이동한 제곱의 기댓값 계산"
          ],
          sourcePattern: "V(X)=E(X²)-E(X)²로 이차모멘트를 복원하고 목표 이차식을 선형성으로 계산",
          estimatedMinutes: [11, 12],
          reasoningSteps: [
            [
              "분산 공식에서 E(X²)를 고립시킨다.",
              "주어진 평균과 분산을 대입한다.",
              "목표 이차식을 전개한다.",
              "기댓값의 선형성을 적용해 계산한다."
            ],
            [
              "E((X-c)²)를 분산과 평균의 차로 나타낸다.",
              "중심 이동량 μ-c를 구한다.",
              "V(X)+(μ-c)² 공식을 적용한다.",
              "직접 전개한 값과 비교해 검산한다."
            ]
          ],
          generate(mode) {
            const mean = randomInteger(-3, 6);
            const variance = randomInteger(2, 8);
            const shift = mean + randomInteger(1, 4);
            const secondMoment = variance + mean ** 2;
            const answer = mode === 0 ? secondMoment + 2 * mean + 1 : variance + (mean - shift) ** 2;
            return makeShortAnswer({
              prompt: `확률변수 $X$에 대하여 $E(X)=${mean}$, $V(X)=${variance}$이다. $${mode === 0 ? "E(X^2+2X+1)" : `E\\{(${linearFactor(shift, "X")})^2\\}`}$의 값을 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? variance + mean ** 2 + 2 * mean + 1 : variance + (mean - shift) ** 2,
              solution: `$E(X^2)=V(X)+\\{E(X)\\}^2=${secondMoment}$. ${mode === 0 ? "기댓값의 선형성을 적용하면" : "또는 V(X)+(E(X)-c)^2를 적용하면"} 답은 ${answer}이다.`,
              hintText: "분산 공식에서 E(X²)를 먼저 구하세요."
            });
          }
        },
        {
          id: "independent-random-variable-sum",
          titles: [
            "독립확률변수의 합의 평균·분산",
            "독립확률변수의 선형결합 표준편차"
          ],
          sourcePattern: "독립인 확률변수의 합에서는 평균은 선형 결합되고 분산은 계수의 제곱을 곱해 더해짐을 적용",
          estimatedMinutes: [12, 13],
          reasoningSteps: [
            [
              "두 확률변수 평균의 선형결합을 계산한다.",
              "독립성으로 공분산항이 0임을 확인한다.",
              "분산을 계수 제곱과 함께 더한다.",
              "평균과 분산의 목표 결합값을 구한다."
            ],
            [
              "선형결합의 각 계수를 확인한다.",
              "각 분산에 계수의 제곱을 곱한다.",
              "독립성을 이용해 분산을 합한다.",
              "양의 제곱근으로 표준편차를 구한다."
            ]
          ],
          generate(mode) {
            const meanX = randomInteger(1, 5);
            const meanY = randomInteger(1, 5);
            const sdX = choose([1, 2, 3]);
            const sdY = choose([1, 2, 3]);
            const coefficient = 2;
            const sumMean = coefficient * meanX + meanY;
            const sumVariance = coefficient ** 2 * sdX ** 2 + sdY ** 2;
            const answer = mode === 0 ? sumMean + sumVariance : sumVariance;
            return makeShortAnswer({
              prompt: `서로 독립인 확률변수 $X,Y$가 $E(X)=${meanX}$, $E(Y)=${meanY}$, $V(X)=${sdX ** 2}$, $V(Y)=${sdY ** 2}$를 만족한다. $Z=2X+Y$일 때, $${mode === 0 ? "E(Z)+V(Z)" : "V(Z)"}$의 값을 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? 2 * meanX + meanY + 4 * sdX ** 2 + sdY ** 2 : 4 * sdX ** 2 + sdY ** 2,
              solution: `$E(Z)=2E(X)+E(Y)=${sumMean}$이고 독립이므로 $V(Z)=4V(X)+V(Y)=${sumVariance}$. 따라서 답은 ${answer}이다.`,
              hintText: "분산에서는 선형결합의 계수를 제곱해야 합니다."
            });
          }
        },
        {
          id: "pooled-data-statistics",
          titles: [
            "두 집단을 합친 자료의 평균",
            "두 집단의 평균·분산에서 합친 분산 복원"
          ],
          sourcePattern: "집단별 인원수로 가중한 합과 제곱합을 복원해 전체 평균·분산 계산",
          estimatedMinutes: [12, 14],
          reasoningSteps: [
            [
              "각 집단의 총합을 인원수와 평균의 곱으로 구한다.",
              "두 총합과 인원수를 합한다.",
              "전체 평균을 계산한다.",
              "가중평균 범위 안에 있는지 검산한다."
            ],
            [
              "각 집단에서 E(X²)=분산+평균²을 구한다.",
              "인원수로 가중한 전체 제곱평균을 계산한다.",
              "전체 평균의 제곱을 뺀다.",
              "전체 분산을 정리한다."
            ]
          ],
          generate(mode) {
            const countA = choose([10, 20]);
            const countB = countA;
            const meanA = randomInteger(4, 8);
            const meanB = meanA + randomInteger(2, 6);
            const varianceA = choose([1, 4, 9]);
            const varianceB = choose([1, 4, 9]);
            const mean = (meanA + meanB) / 2;
            const secondMoment = (varianceA + meanA ** 2 + varianceB + meanB ** 2) / 2;
            const variance = secondMoment - mean ** 2;
            const answer = mode === 0 ? mean : String(variance);
            return makeShortAnswer({
              prompt: `A집단 ${countA}명의 평균은 ${meanA}, 분산은 ${varianceA}이고 B집단 ${countB}명의 평균은 ${meanB}, 분산은 ${varianceB}이다. 두 집단을 합친 자료의 ${mode === 0 ? "평균" : "분산"}을 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? (countA * meanA + countB * meanB) / (countA + countB) : String(
                (countA * (varianceA + meanA ** 2) + countB * (varianceB + meanB ** 2)) / (countA + countB) - mean ** 2
              ),
              solution: mode === 0 ? `전체 평균은 가중평균 $(${countA}\\cdot${meanA}+${countB}\\cdot${meanB})/${countA + countB}=${mean}$이다.` : `각 집단의 제곱평균은 분산+평균²이다. 이를 인원수로 가중해 합친 제곱평균을 구한 뒤 전체 평균²을 빼면 ${variance}이다.`,
              hintText: mode === 0 ? "각 집단의 총합을 먼저 복원하세요." : "분산을 바로 평균내지 말고 각 집단의 제곱평균을 복원하세요."
            });
          }
        },
        {
          id: "sample-mean-normal-probability",
          titles: [
            "정규모집단 표본평균의 구간확률",
            "표본평균의 꼬리확률에서 경계값 역산"
          ],
          sourcePattern: "표본평균을 평균 μ, 표준편차 σ/√n인 정규분포로 바꾸고 표준화해 확률 또는 경계 계산",
          estimatedMinutes: [12, 13],
          reasoningSteps: [
            [
              "표본평균의 평균을 확인한다.",
              "표본평균의 표준편차 σ/√n을 계산한다.",
              "구간 양 끝을 표준화한다.",
              "표준정규분포의 대칭 넓이를 이용한다."
            ],
            [
              "주어진 꼬리확률을 z값과 대응시킨다.",
              "표본평균의 표준오차를 계산한다.",
              "z=(k-μ)/(σ/√n)을 세운다.",
              "원래 경계값 k를 복원한다."
            ]
          ],
          generate(mode) {
            const mean = randomInteger(40, 70);
            const populationSd = choose([10, 15, 20]);
            const rootN = choose([5, 10]);
            const sampleSize = rootN ** 2;
            const standardError = populationSd / rootN;
            const boundary = mean + standardError;
            const answer = mode === 0 ? "0.6826" : boundary;
            return makeShortAnswer({
              prompt: `정규분포 $N(${mean},${populationSd ** 2})$인 모집단에서 크기 ${sampleSize}인 표본을 임의추출하고 표본평균을 $\\overline X$라 한다. ${mode === 0 ? `$P(${mean - standardError}\\le\\overline X\\le${mean + standardError})$` : "$P(\\overline X\\le k)=0.8413$일 때 $k$"}를 구하시오. (단, $P(0\\le Z\\le1)=0.3413$)`,
              answer,
              independentAnswer: mode === 0 ? "0.6826" : mean + populationSd / rootN,
              solution: `표본평균은 평균 ${mean}, 표준편차 ${standardError}인 정규분포를 따른다. ${mode === 0 ? "주어진 구간은 -1≤Z≤1이므로 확률은 0.6826이다." : `0.8413=0.5+0.3413이므로 z=1, 따라서 k=${boundary}이다.`}`,
              hintText: "표본평균의 표준편차는 모집단 표준편차를 √n으로 나눈 값입니다."
            });
          }
        },
        {
          id: "confidence-interval-reverse",
          titles: [
            "신뢰구간 양 끝점에서 표본평균과 오차한계 복원",
            "신뢰구간 길이 변화에서 표본크기 비율 계산"
          ],
          sourcePattern: "신뢰구간의 중심과 반길이를 읽고 표본평균·표준오차 또는 표본크기 변화율을 역산",
          estimatedMinutes: [12, 13],
          reasoningSteps: [
            [
              "신뢰구간 양 끝점의 평균으로 중심을 구한다.",
              "전체 길이의 절반으로 오차한계를 구한다.",
              "중심이 표본평균임을 적용한다.",
              "표본평균과 오차한계의 결합값을 계산한다."
            ],
            [
              "신뢰구간 길이가 1/√n에 비례함을 쓴다.",
              "두 길이의 비를 계산한다.",
              "제곱해 표본크기 비의 역수를 구한다.",
              "새 표본크기를 계산한다."
            ]
          ],
          generate(mode) {
            const center = randomInteger(40, 70);
            const margin = choose([2, 3, 4]);
            const originalSize = choose([25, 36, 100]);
            const factor = choose([2, 3]);
            const newSize = originalSize * factor ** 2;
            const answer = mode === 0 ? center + margin : newSize;
            return makeShortAnswer({
              prompt: mode === 0 ? `모평균의 신뢰구간이 $[${center - margin},${center + margin}]$로 계산되었다. 표본평균을 $\\overline x$, 오차한계를 $E$라 할 때 $\\overline x+E$를 구하시오.` : `같은 신뢰도와 같은 모표준편차에서 표본크기 ${originalSize}으로 구한 신뢰구간의 길이를 $1/${factor}$배로 줄이려 한다. 필요한 새 표본크기를 구하시오.`,
              answer,
              independentAnswer: mode === 0 ? center + margin : originalSize * factor ** 2,
              solution: mode === 0 ? `구간의 중심은 $\\overline x=${center}$, 반길이는 $E=${margin}$이므로 답은 ${answer}이다.` : `신뢰구간 길이는 $1/\\sqrt n$에 비례한다. 길이를 $1/${factor}$배로 만들려면 표본크기는 ${factor ** 2}배이므로 ${newSize}이다.`,
              hintText: mode === 0 ? "신뢰구간의 중심과 반길이를 각각 구하세요." : "신뢰구간 길이와 표본크기의 제곱근 관계를 사용하세요."
            });
          }
        }
      ];
      module.exports = {
        courseId,
        unitId,
        requiredConceptIds,
        minimumAppliedPoolSize: 16,
        appliedPolicy: {
          includeBankTypes: true,
          minimumLocalDifficulty: 3
        },
        advancedTemplates: defineAdvancedTemplates({
          courseId,
          unitId,
          requiredConceptIds,
          families
        })
      };
    }
  });

  // services/assessmentTemplates/index.js
  var require_assessmentTemplates = __commonJS({
    "services/assessmentTemplates/index.js"(exports, module) {
      var {
        getUnitReferenceAnalysis,
        referenceIdsForTemplate
      } = require_mockExamCatalog();
      var unitConfigs = [
        ...require_commonMath(),
        require_exponentialLogarithmicFunctions(),
        require_trigonometricFunctions(),
        require_sequences(),
        require_limitsAndContinuity(),
        require_differentiation(),
        require_integration(),
        require_counting(),
        require_probability(),
        require_statistics()
      ];
      var configMap = new Map(
        unitConfigs.map((config) => [
          [
            config.courseId,
            config.unitId
          ].join("/"),
          config
        ])
      );
      for (const config of unitConfigs) {
        const analysis = getUnitReferenceAnalysis(
          config.courseId,
          config.unitId
        );
        if (!analysis) {
          throw new Error(
            `${config.courseId}/${config.unitId}: 모의고사 레퍼런스 분석이 없습니다.`
          );
        }
        config.referenceAnalysis = analysis;
        config.advancedTemplates = config.advancedTemplates.map(
          (template, index) => ({
            ...template,
            sourcePattern: template.sourcePattern || analysis.signals[index % analysis.signals.length],
            referenceExamIds: referenceIdsForTemplate(
              config.courseId,
              config.unitId,
              index,
              5
            )
          })
        );
      }
      function getUnitAssessmentConfig(courseId, unitId) {
        return configMap.get(
          [
            courseId,
            unitId
          ].join("/")
        ) || null;
      }
      function getCourseAssessmentConfigs(courseId) {
        return unitConfigs.filter(
          (config) => config.courseId === courseId
        );
      }
      function assessmentConfigsForScope({
        scopeType,
        courseId,
        unitId
      }) {
        if (scopeType === "subunit") {
          return [];
        }
        if (scopeType === "unit") {
          const config = getUnitAssessmentConfig(
            courseId,
            unitId
          );
          return config ? [config] : [];
        }
        return getCourseAssessmentConfigs(
          courseId
        );
      }
      function assertAssessmentTemplateCatalog() {
        for (const config of unitConfigs) {
          if (config.advancedTemplates.length < 20) {
            throw new Error(
              `${config.courseId}/${config.unitId}: 심화 유형이 20개 미만입니다.`
            );
          }
          for (const template of config.advancedTemplates) {
            if (template.estimatedMinutes < 10) {
              throw new Error(
                `${template.id}: 예상 풀이시간이 10분 미만입니다.`
              );
            }
            if (template.reasoningSteps.length < 3) {
              throw new Error(
                `${template.id}: 풀이 단계가 3개 미만입니다.`
              );
            }
            if (!template.referenceExamIds.length) {
              throw new Error(
                `${template.id}: 모의고사 레퍼런스가 없습니다.`
              );
            }
          }
        }
        return true;
      }
      assertAssessmentTemplateCatalog();
      module.exports = {
        unitConfigs,
        getUnitAssessmentConfig,
        getCourseAssessmentConfigs,
        assessmentConfigsForScope,
        assertAssessmentTemplateCatalog
      };
    }
  });

  // services/problemGenerators/calculus1/functionLimit.js
  var require_functionLimit = __commonJS({
    "services/problemGenerators/calculus1/functionLimit.js"(exports, module) {
      var {
        randomInteger,
        nonZeroInteger,
        isCorrectAnswer
      } = require_utils();
      function inlineMath(tex) {
        return `\\(${tex}\\)`;
      }
      function displayMath(tex) {
        return `\\[${tex}\\]`;
      }
      function signedNumber(value) {
        if (value === 0) return "";
        return value > 0 ? `+${value}` : `-${Math.abs(value)}`;
      }
      function xMinus(value) {
        return value >= 0 ? `x-${value}` : `x+${Math.abs(value)}`;
      }
      function xPlus(value) {
        return value >= 0 ? `x+${value}` : `x-${Math.abs(value)}`;
      }
      function linearExpression(slope, constant) {
        const xTerm = slope === 1 ? "x" : slope === -1 ? "-x" : `${slope}x`;
        return `${xTerm}${signedNumber(constant)}`;
      }
      function quadraticExpression(p, q, r) {
        const quadraticTerm = p === 1 ? "x^2" : p === -1 ? "-x^2" : `${p}x^2`;
        const linearTerm = q === 0 ? "" : q === 1 ? "+x" : q === -1 ? "-x" : q > 0 ? `+${q}x` : `-${Math.abs(q)}x`;
        return `${quadraticTerm}${linearTerm}${signedNumber(r)}`;
      }
      var problemTypes = [
        {
          id: "direct-substitution",
          label: "유형 1 · 직접 대입",
          difficulty: 1,
          generate() {
            const a = randomInteger(-3, 3);
            const p = nonZeroInteger(-3, 3);
            const q = randomInteger(-5, 5);
            const r = randomInteger(-5, 5);
            const answer = p * a * a + q * a + r;
            const expression = quadraticExpression(p, q, r);
            return {
              prompt: `${inlineMath(
                `\\displaystyle\\lim_{x\\to ${a}}\\left(${expression}\\right)`
              )}의 값을 구하세요.`,
              inputMode: "short-answer",
              answer,
              solution: `다항함수는 연속이므로 ${inlineMath(
                `x=${a}`
              )}를 직접 대입합니다. 정답은 ${inlineMath(
                String(answer)
              )}입니다.`,
              hintText: `${inlineMath(`y=${expression}`)}의 그래프에서 ${inlineMath(`x=${a}`)}일 때의 높이를 확인해보세요.`,
              visualization: {
                kind: "polynomial",
                focusX: a,
                coefficients: {
                  quadratic: p,
                  linear: q,
                  constant: r
                }
              },
              validityChecks: [
                {
                  name: "direct-substitution-answer",
                  passed: answer === p * a * a + q * a + r,
                  message: "직접 대입으로 계산한 값과 정답이 일치하지 않습니다."
                }
              ]
            };
          }
        },
        {
          id: "factor-cancellation",
          label: "유형 2 · 인수분해와 약분",
          difficulty: 2,
          generate() {
            const a = nonZeroInteger(-5, 5);
            const answer = 2 * a;
            return {
              prompt: `${inlineMath(
                `\\displaystyle\\lim_{x\\to ${a}}\\frac{x^2-${a ** 2}}{${xMinus(a)}}`
              )}의 값을 구하세요.`,
              inputMode: "short-answer",
              answer,
              solution: `${inlineMath(
                `x^2-${a ** 2}=(${xMinus(a)})(${xPlus(a)})`
              )}이므로 ${inlineMath(
                `x\\ne ${a}`
              )}에서 ${inlineMath(
                xPlus(a)
              )}로 약분됩니다. 정답은 ${inlineMath(
                String(answer)
              )}입니다.`,
              hintText: `약분한 뒤의 그래프는 ${inlineMath(
                `y=${xPlus(a)}`
              )}이지만 ${inlineMath(
                `x=${a}`
              )}인 한 점만 비어 있습니다. 빈 점으로 다가가 보세요.`,
              visualization: {
                kind: "hole-linear",
                focusX: a,
                slope: 1,
                intercept: a
              },
              validityChecks: [
                {
                  name: "factor-cancellation-identity",
                  passed: answer === 2 * a && a !== 0,
                  message: "인수분해 뒤의 식 또는 극한값이 올바르지 않습니다."
                }
              ]
            };
          }
        },
        {
          id: "rationalization",
          label: "유형 3 · 유리화",
          difficulty: 3,
          generate() {
            const root = randomInteger(2, 5);
            const a = root ** 2;
            const answer = 1 / (2 * root);
            return {
              prompt: `${inlineMath(
                `\\displaystyle\\lim_{x\\to ${a}}\\frac{\\sqrt{x}-${root}}{x-${a}}`
              )}의 값을 구하세요.`,
              inputMode: "short-answer",
              answer,
              solution: `분자를 유리화하면 ${inlineMath(
                `\\frac{1}{\\sqrt{x}+${root}}`
              )}이 됩니다. 따라서 정답은 ${inlineMath(
                `\\frac{1}{${2 * root}}`
              )}입니다.`,
              hintText: `유리화한 ${inlineMath(
                `y=\\frac{1}{\\sqrt{x}+${root}}`
              )}의 그래프에서 ${inlineMath(
                `x=${a}`
              )}로 접근해보세요.`,
              visualization: {
                kind: "rationalized-root",
                focusX: a,
                root
              },
              validityChecks: [
                {
                  name: "rationalization-domain",
                  passed: root > 0 && a === root ** 2 && answer === 1 / (2 * root),
                  message: "근호의 정의역 또는 유리화 결과가 올바르지 않습니다."
                }
              ]
            };
          }
        },
        {
          id: "left-hand-limit",
          label: "유형 4 · 좌극한",
          difficulty: 2,
          generate() {
            const a = randomInteger(-2, 2);
            const leftSlope = nonZeroInteger(-3, 3);
            const leftConstant = randomInteger(-4, 4);
            const rightSlope = nonZeroInteger(-3, 3);
            const rightConstant = randomInteger(-4, 4);
            const answer = leftSlope * a + leftConstant;
            const definition = `f(x)=\\begin{cases}${linearExpression(leftSlope, leftConstant)},&x<${a}\\\\${linearExpression(rightSlope, rightConstant)},&x\\ge ${a}\\end{cases}`;
            return {
              prompt: `${displayMath(definition)}${inlineMath(
                `\\displaystyle\\lim_{x\\to ${a}^{-}}f(x)`
              )}를 구하세요.`,
              inputMode: "short-answer",
              answer,
              solution: `왼쪽에서 접근하므로 ${inlineMath(
                `x<${a}`
              )}인 식만 사용합니다. 정답은 ${inlineMath(
                String(answer)
              )}입니다.`,
              hintText: `${inlineMath(`x=${a}`)}의 왼쪽에 있는 초록색 선을 따라 경계점으로 접근해보세요.`,
              visualization: {
                kind: "piecewise-linear",
                focusX: a,
                focusSide: "left",
                left: {
                  slope: leftSlope,
                  constant: leftConstant
                },
                right: {
                  slope: rightSlope,
                  constant: rightConstant
                }
              },
              validityChecks: [
                {
                  name: "left-hand-limit-answer",
                  passed: answer === leftSlope * a + leftConstant,
                  message: "좌극한에 왼쪽 식이 적용되지 않았습니다."
                }
              ]
            };
          }
        },
        {
          id: "right-hand-limit",
          label: "유형 5 · 우극한",
          difficulty: 2,
          generate() {
            const a = randomInteger(-2, 2);
            const leftSlope = nonZeroInteger(-3, 3);
            const leftConstant = randomInteger(-4, 4);
            const rightSlope = nonZeroInteger(-3, 3);
            const rightConstant = randomInteger(-4, 4);
            const answer = rightSlope * a + rightConstant;
            const definition = `f(x)=\\begin{cases}${linearExpression(leftSlope, leftConstant)},&x<${a}\\\\${linearExpression(rightSlope, rightConstant)},&x\\ge ${a}\\end{cases}`;
            return {
              prompt: `${displayMath(definition)}${inlineMath(
                `\\displaystyle\\lim_{x\\to ${a}^{+}}f(x)`
              )}를 구하세요.`,
              inputMode: "short-answer",
              answer,
              solution: `오른쪽에서 접근하므로 ${inlineMath(
                `x\\ge ${a}`
              )}인 식을 사용합니다. 정답은 ${inlineMath(
                String(answer)
              )}입니다.`,
              hintText: `${inlineMath(`x=${a}`)}의 오른쪽에 있는 보라색 선을 따라 경계점으로 접근해보세요.`,
              visualization: {
                kind: "piecewise-linear",
                focusX: a,
                focusSide: "right",
                left: {
                  slope: leftSlope,
                  constant: leftConstant
                },
                right: {
                  slope: rightSlope,
                  constant: rightConstant
                }
              },
              validityChecks: [
                {
                  name: "right-hand-limit-answer",
                  passed: answer === rightSlope * a + rightConstant,
                  message: "우극한에 오른쪽 식이 적용되지 않았습니다."
                }
              ]
            };
          }
        },
        {
          id: "two-sided-existence",
          label: "유형 6 · 극한의 존재 판정",
          difficulty: 2,
          generate() {
            const a = randomInteger(-2, 2);
            const leftLimit = randomInteger(-4, 4);
            const exists = Math.random() >= 0.5;
            const rightLimit = exists ? leftLimit : leftLimit + nonZeroInteger(-3, 3);
            return {
              prompt: `${inlineMath(
                `\\displaystyle\\lim_{x\\to ${a}^{-}}f(x)=${leftLimit}`
              )}, ${inlineMath(
                `\\displaystyle\\lim_{x\\to ${a}^{+}}f(x)=${rightLimit}`
              )}입니다. ${inlineMath(
                `\\displaystyle\\lim_{x\\to ${a}}f(x)`
              )}는 존재합니까?`,
              inputMode: "multiple-choice",
              choices: [
                {
                  key: "exists",
                  text: "존재한다"
                },
                {
                  key: "dne",
                  text: "존재하지 않는다"
                }
              ],
              answer: exists ? "exists" : "dne",
              solution: exists ? `좌극한과 우극한이 모두 ${inlineMath(
                String(leftLimit)
              )}이므로 극한이 존재합니다.` : `좌극한 ${inlineMath(
                String(leftLimit)
              )}과 우극한 ${inlineMath(
                String(rightLimit)
              )}이 다르므로 극한이 존재하지 않습니다.`,
              hintText: `양쪽 극한을 비교하세요. 좌극한과 우극한이 같을 때만 두 방향의 움직임이 한 점에서 만납니다.`,
              visualization: {
                kind: "one-sided-limits",
                focusX: a,
                leftLimit,
                rightLimit
              },
              validityChecks: [
                {
                  name: "two-sided-limit-existence",
                  passed: exists === (leftLimit === rightLimit),
                  message: "좌우극한과 존재 여부가 서로 일치하지 않습니다."
                }
              ]
            };
          }
        },
        {
          id: "point-value-independence",
          label: "유형 7 · 함수값과 극한값",
          difficulty: 2,
          generate() {
            const a = randomInteger(-3, 3);
            const limitValue = randomInteger(-4, 4);
            let pointValue = randomInteger(-4, 4);
            while (pointValue === limitValue) {
              pointValue = randomInteger(-4, 4);
            }
            return {
              prompt: `${inlineMath(
                `\\displaystyle\\lim_{x\\to ${a}}f(x)=${limitValue}`
              )}이고 ${inlineMath(
                `f(${a})=${pointValue}`
              )}입니다. 극한값을 고르세요.`,
              inputMode: "multiple-choice",
              choices: [
                {
                  key: "limit",
                  text: inlineMath(String(limitValue))
                },
                {
                  key: "point",
                  text: inlineMath(String(pointValue))
                },
                {
                  key: "dne",
                  text: "존재하지 않는다"
                }
              ],
              answer: "limit",
              solution: `극한은 ${inlineMath(
                `x=${a}`
              )} 주변에서 함수값이 향하는 값을 봅니다. ${inlineMath(
                `f(${a})`
              )}와 무관하게 극한값은 ${inlineMath(
                String(limitValue)
              )}입니다.`,
              hintText: `빈 점은 주변 값이 향하는 곳이고, 채운 점은 실제 함수값입니다. 극한에서는 빈 점의 높이를 보세요.`,
              visualization: {
                kind: "limit-point-example",
                focusX: a,
                limitValue,
                pointValue
              },
              validityChecks: [
                {
                  name: "limit-point-distinction",
                  passed: limitValue !== pointValue,
                  message: "극한값과 함수값을 구분하는 예제가 아닙니다."
                }
              ]
            };
          }
        },
        {
          id: "infinite-limit",
          label: "유형 8 · 무한대 극한",
          difficulty: 3,
          generate() {
            const a = randomInteger(-3, 3);
            const coefficient = randomInteger(1, 5);
            return {
              prompt: `${inlineMath(
                `\\displaystyle\\lim_{x\\to ${a}}\\frac{${coefficient}}{(${xMinus(a)})^2}`
              )}의 값을 판단하세요.`,
              inputMode: "multiple-choice",
              choices: [
                {
                  key: "+infinity",
                  text: inlineMath("+\\infty")
                },
                {
                  key: "-infinity",
                  text: inlineMath("-\\infty")
                },
                {
                  key: "zero",
                  text: inlineMath("0")
                },
                {
                  key: "dne",
                  text: "존재하지 않는다"
                }
              ],
              answer: "+infinity",
              solution: `분모는 양수인 상태로 ${inlineMath(
                "0"
              )}에 가까워지므로 함수값은 ${inlineMath(
                "+\\infty"
              )}로 커집니다.`,
              hintText: `${inlineMath(`x=${a}`)}에 가까워질수록 분모는 양수인 채로 ${inlineMath("0")}에 가까워집니다. 그래프가 어느 방향으로 뻗는지 확인해보세요.`,
              visualization: {
                kind: "inverse-square",
                focusX: a,
                coefficient
              },
              validityChecks: [
                {
                  name: "positive-infinite-limit",
                  passed: coefficient > 0 && Number.isFinite(a),
                  message: "양의 무한대 극한을 보장하는 계수 조건을 만족하지 않습니다."
                }
              ]
            };
          }
        },
        {
          id: "limit-law",
          label: "유형 9 · 극한의 성질",
          difficulty: 2,
          generate() {
            const fLimit = randomInteger(-4, 4);
            const gLimit = randomInteger(-4, 4);
            const answer = 2 * fLimit - 3 * gLimit;
            return {
              prompt: `${inlineMath(
                `\\displaystyle\\lim_{x\\to a}f(x)=${fLimit}`
              )}, ${inlineMath(
                `\\displaystyle\\lim_{x\\to a}g(x)=${gLimit}`
              )}일 때 ${inlineMath(
                "\\displaystyle\\lim_{x\\to a}\\{2f(x)-3g(x)\\}"
              )}를 구하세요.`,
              inputMode: "short-answer",
              answer,
              solution: `극한의 성질을 적용하면 ${inlineMath(
                `2\\times(${fLimit})-3\\times(${gLimit})=${answer}`
              )}입니다.`,
              hintText: `${inlineMath(
                `f(x)\\to ${fLimit},\\quad g(x)\\to ${gLimit}`
              )}를 식에 그대로 넣습니다.
현재 계산식은 ${inlineMath(
                `2\\times(${fLimit})-3\\times(${gLimit})`
              )}입니다. 각 곱셈을 먼저 계산한 뒤 빼세요.`,
              visualization: {
                kind: "limit-law-combination",
                focusX: 0,
                fLimit,
                gLimit,
                resultLimit: answer,
                note: "두 함수가 각각 향하는 높이를 확인한 뒤 계수를 곱해 결합하세요."
              },
              validityChecks: [
                {
                  name: "limit-law-answer",
                  passed: answer === 2 * fLimit - 3 * gLimit,
                  message: "극한의 선형성으로 계산한 값과 정답이 일치하지 않습니다."
                }
              ]
            };
          }
        },
        {
          id: "table-inference",
          label: "유형 10 · 표에서 극한 읽기",
          difficulty: 1,
          generate() {
            const a = randomInteger(-2, 2);
            const target = randomInteger(-4, 4);
            const xValues = [
              a - 0.1,
              a - 0.01,
              a + 0.01,
              a + 0.1
            ];
            const yValues = [
              target - 0.1,
              target - 0.01,
              target + 0.01,
              target + 0.1
            ];
            const table = displayMath(
              `\\begin{array}{c|cccc}x&${xValues.join("&")}\\\\f(x)&${yValues.map((value) => value.toFixed(2)).join("&")}\\end{array}`
            );
            return {
              prompt: `${table}표를 보고 ${inlineMath(
                `\\displaystyle\\lim_{x\\to ${a}}f(x)`
              )}를 추정하세요.`,
              inputMode: "short-answer",
              answer: target,
              solution: `${inlineMath(
                "x"
              )}가 ${inlineMath(
                String(a)
              )}의 양쪽에서 가까워질수록 ${inlineMath(
                "f(x)"
              )}는 ${inlineMath(
                String(target)
              )}에 가까워집니다.`,
              hintText: `표의 네 점을 좌표평면에 옮겼습니다. ${inlineMath(
                `x=${a}`
              )}의 양쪽 점들이 향하는 높이를 관찰하세요.`,
              visualization: {
                kind: "table-points",
                focusX: a,
                target,
                xValues,
                yValues
              },
              validityChecks: [
                {
                  name: "table-approaches-from-both-sides",
                  passed: xValues.some((value) => value < a) && xValues.some((value) => value > a) && yValues.every(
                    (value, index) => Math.abs(
                      Math.abs(value - target) - Math.abs(xValues[index] - a)
                    ) < 1e-9
                  ),
                  message: "표의 값이 목표점의 양쪽에서 같은 값으로 수렴하지 않습니다."
                }
              ]
            };
          }
        }
      ];
      module.exports = {
        key: "calculus-limit-meaning",
        requiredDistinctTypes: 5,
        problemTypes,
        isCorrectAnswer
      };
    }
  });

  // services/problemGenerators/calculus1/helpers.js
  var require_helpers = __commonJS({
    "services/problemGenerators/calculus1/helpers.js"(exports, module) {
      var {
        randomInteger,
        nonZeroInteger,
        isCorrectAnswer
      } = require_utils();
      function inlineMath(tex) {
        return `\\(${tex}\\)`;
      }
      function displayMath(tex) {
        return `\\[${tex}\\]`;
      }
      function signedNumber(value) {
        if (value === 0) return "";
        return value > 0 ? `+${value}` : `-${Math.abs(value)}`;
      }
      function xMinus(value) {
        if (value === 0) return "x";
        return value > 0 ? `x-${value}` : `x+${Math.abs(value)}`;
      }
      function linearExpression(slope, constant, variable = "x") {
        const variableTerm = slope === 1 ? variable : slope === -1 ? `-${variable}` : `${slope}${variable}`;
        return `${variableTerm}${signedNumber(constant)}`;
      }
      function quadraticExpression(quadratic, linear, constant, variable = "x") {
        const quadraticTerm = quadratic === 1 ? `${variable}^2` : quadratic === -1 ? `-${variable}^2` : `${quadratic}${variable}^2`;
        const linearTerm = linear === 0 ? "" : linear === 1 ? `+${variable}` : linear === -1 ? `-${variable}` : linear > 0 ? `+${linear}${variable}` : `-${Math.abs(linear)}${variable}`;
        return `${quadraticTerm}${linearTerm}${signedNumber(
          constant
        )}`;
      }
      function greatestCommonDivisor(first, second) {
        let a = Math.abs(first);
        let b = Math.abs(second);
        while (b) {
          [a, b] = [b, a % b];
        }
        return a || 1;
      }
      function fractionTex(numerator, denominator) {
        if (denominator === 0) {
          throw new Error("분모는 0일 수 없습니다.");
        }
        let normalizedNumerator = numerator;
        let normalizedDenominator = denominator;
        if (normalizedDenominator < 0) {
          normalizedNumerator *= -1;
          normalizedDenominator *= -1;
        }
        const divisor = greatestCommonDivisor(
          normalizedNumerator,
          normalizedDenominator
        );
        normalizedNumerator /= divisor;
        normalizedDenominator /= divisor;
        if (normalizedDenominator === 1) {
          return String(normalizedNumerator);
        }
        return `\\frac{${normalizedNumerator}}{${normalizedDenominator}}`;
      }
      function linearCombinationTex(terms) {
        return terms.filter(({ coefficient }) => coefficient !== 0).map(({ coefficient, expression }, index) => {
          const magnitude = Math.abs(coefficient);
          const coefficientText = magnitude === 1 ? "" : String(magnitude);
          const term = `${coefficientText}${expression}`;
          if (index === 0) {
            return coefficient < 0 ? `-${term}` : term;
          }
          return coefficient < 0 ? `-${term}` : `+${term}`;
        }).join("");
      }
      module.exports = {
        randomInteger,
        nonZeroInteger,
        isCorrectAnswer,
        inlineMath,
        displayMath,
        signedNumber,
        xMinus,
        linearExpression,
        quadraticExpression,
        fractionTex,
        linearCombinationTex
      };
    }
  });

  // services/problemGenerators/calculus1/limitPropertiesAndCalculation.js
  var require_limitPropertiesAndCalculation = __commonJS({
    "services/problemGenerators/calculus1/limitPropertiesAndCalculation.js"(exports, module) {
      var {
        randomInteger,
        nonZeroInteger,
        isCorrectAnswer,
        inlineMath,
        xMinus,
        linearExpression,
        quadraticExpression,
        fractionTex,
        linearCombinationTex
      } = require_helpers();
      var problemTypes = [
        {
          id: "sum-and-difference-law",
          label: "유형 1 · 합과 차의 극한",
          difficulty: 1,
          generate() {
            const fLimit = randomInteger(-5, 5);
            const gLimit = randomInteger(-5, 5);
            const fCoefficient = nonZeroInteger(-3, 3);
            const gCoefficient = nonZeroInteger(-3, 3);
            const expression = linearCombinationTex([
              {
                coefficient: fCoefficient,
                expression: "f(x)"
              },
              {
                coefficient: gCoefficient,
                expression: "g(x)"
              }
            ]);
            const answer = fCoefficient * fLimit + gCoefficient * gLimit;
            return {
              prompt: `${inlineMath(
                `\\displaystyle\\lim_{x\\to a}f(x)=${fLimit}`
              )}, ${inlineMath(
                `\\displaystyle\\lim_{x\\to a}g(x)=${gLimit}`
              )}일 때, ${inlineMath(
                `\\displaystyle\\lim_{x\\to a}\\{${expression}\\}`
              )}를 구하세요.`,
              inputMode: "short-answer",
              answer,
              solution: `합·차와 상수배의 극한 성질을 적용하면 ${inlineMath(
                `${fCoefficient}\\times(${fLimit})${gCoefficient < 0 ? "" : "+"}${gCoefficient}\\times(${gLimit})=${answer}`
              )}입니다.`,
              hintText: `1단계: ${inlineMath(
                `f(x)\\to ${fLimit},\\quad g(x)\\to ${gLimit}`
              )}로 바꿉니다.
2단계: 현재 식은 ${inlineMath(
                `${fCoefficient}(${fLimit})${gCoefficient < 0 ? "" : "+"}${gCoefficient}(${gLimit})`
              )}가 됩니다. 이제 마지막 정수 계산만 해보세요.`,
              visualization: null
            };
          }
        },
        {
          id: "product-law",
          label: "유형 2 · 곱의 극한",
          difficulty: 1,
          generate() {
            const fLimit = nonZeroInteger(-5, 5);
            const gLimit = nonZeroInteger(-5, 5);
            const answer = fLimit * gLimit;
            return {
              prompt: `${inlineMath(
                `\\displaystyle\\lim_{x\\to a}f(x)=${fLimit}`
              )}, ${inlineMath(
                `\\displaystyle\\lim_{x\\to a}g(x)=${gLimit}`
              )}일 때, ${inlineMath(
                "\\displaystyle\\lim_{x\\to a}f(x)g(x)"
              )}를 구하세요.`,
              inputMode: "short-answer",
              answer,
              solution: `곱의 극한은 각 극한값의 곱이므로 ${inlineMath(
                `(${fLimit})\\times(${gLimit})=${answer}`
              )}입니다.`,
              hintText: `곱의 극한은 각 극한값의 곱으로 바꿀 수 있습니다.
현재 숫자를 넣으면 ${inlineMath(
                `(${fLimit})\\times(${gLimit})`
              )}입니다. 부호부터 확인한 뒤 곱하세요.`,
              visualization: null
            };
          }
        },
        {
          id: "quotient-law",
          label: "유형 3 · 몫의 극한",
          difficulty: 2,
          generate() {
            const fLimit = nonZeroInteger(-6, 6);
            const gLimit = nonZeroInteger(-6, 6);
            const answer = fLimit / gLimit;
            const answerTex = fractionTex(
              fLimit,
              gLimit
            );
            return {
              prompt: `${inlineMath(
                `\\displaystyle\\lim_{x\\to a}f(x)=${fLimit}`
              )}, ${inlineMath(
                `\\displaystyle\\lim_{x\\to a}g(x)=${gLimit}`
              )}일 때, ${inlineMath(
                "\\displaystyle\\lim_{x\\to a}\\frac{f(x)}{g(x)}"
              )}를 구하세요.`,
              inputMode: "short-answer",
              answer,
              solution: `${inlineMath(
                `\\lim_{x\\to a}g(x)=${gLimit}\\ne0`
              )}이므로 몫의 성질을 적용할 수 있습니다. 정답은 ${inlineMath(answerTex)}입니다.`,
              hintText: `분모의 극한값은 ${inlineMath(
                String(gLimit)
              )}이므로 0이 아닙니다.
따라서 몫의 성질을 적용해 ${inlineMath(
                `\\frac{${fLimit}}{${gLimit}}`
              )}를 약분하면 됩니다.`,
              visualization: null,
              validityChecks: [
                {
                  name: "non-zero-limit-denominator",
                  passed: gLimit !== 0,
                  message: "몫의 극한에서 분모의 극한값은 0일 수 없습니다."
                }
              ]
            };
          }
        },
        {
          id: "power-and-polynomial-law",
          label: "유형 4 · 거듭제곱과 다항식",
          difficulty: 2,
          generate() {
            const fLimit = randomInteger(-3, 3);
            const quadratic = nonZeroInteger(-3, 3);
            const linear = randomInteger(-4, 4);
            const constant = randomInteger(-5, 5);
            const expression = quadraticExpression(
              quadratic,
              linear,
              constant,
              "f(x)"
            );
            const answer = quadratic * fLimit * fLimit + linear * fLimit + constant;
            return {
              prompt: `${inlineMath(
                `\\displaystyle\\lim_{x\\to a}f(x)=${fLimit}`
              )}일 때, ${inlineMath(
                `\\displaystyle\\lim_{x\\to a}\\{${expression}\\}`
              )}를 구하세요.`,
              inputMode: "short-answer",
              answer,
              solution: `거듭제곱, 합·차, 상수배의 극한 성질을 차례로 적용해 ${inlineMath(
                `${quadratic}(${fLimit})^2${linear < 0 ? "" : "+"}${linear}(${fLimit})${constant < 0 ? "" : "+"}${constant}=${answer}`
              )}을 얻습니다.`,
              hintText: `${inlineMath(
                `f(x)\\to ${fLimit}`
              )}이므로 식 안의 모든 ${inlineMath(
                "f(x)"
              )}를 ${inlineMath(`(${fLimit})`)}로 바꿉니다.
현재 계산식은 ${inlineMath(
                `${quadratic}(${fLimit})^2${linear < 0 ? "" : "+"}${linear}(${fLimit})${constant < 0 ? "" : "+"}${constant}`
              )}입니다. 제곱을 먼저 계산하세요.`,
              visualization: null
            };
          }
        },
        {
          id: "rational-direct-substitution",
          label: "유형 5 · 유리함수 직접 대입",
          difficulty: 1,
          generate() {
            const a = randomInteger(-3, 3);
            const numeratorSlope = nonZeroInteger(-4, 4);
            const numeratorConstant = randomInteger(-5, 5);
            const denominatorSlope = nonZeroInteger(-3, 3);
            let denominatorConstant = randomInteger(-5, 5);
            while (denominatorSlope * a + denominatorConstant === 0) {
              denominatorConstant = randomInteger(-5, 5);
            }
            const numeratorValue = numeratorSlope * a + numeratorConstant;
            const denominatorValue = denominatorSlope * a + denominatorConstant;
            const answer = numeratorValue / denominatorValue;
            const answerTex = fractionTex(
              numeratorValue,
              denominatorValue
            );
            return {
              prompt: `${inlineMath(
                `\\displaystyle\\lim_{x\\to ${a}}\\frac{${linearExpression(
                  numeratorSlope,
                  numeratorConstant
                )}}{${linearExpression(
                  denominatorSlope,
                  denominatorConstant
                )}}`
              )}의 값을 구하세요.`,
              inputMode: "short-answer",
              answer,
              solution: `분모에 ${inlineMath(`x=${a}`)}를 대입한 값이 ${inlineMath(String(denominatorValue))}로 0이 아니므로 직접 대입할 수 있습니다. 정답은 ${inlineMath(answerTex)}입니다.`,
              hintText: `${inlineMath(`x=${a}`)}를 넣으면 분자는 ${inlineMath(
                String(numeratorValue)
              )}, 분모는 ${inlineMath(
                String(denominatorValue)
              )}가 됩니다.
분모가 0이 아니므로 식을 변형하지 말고 ${inlineMath(
                `\\frac{${numeratorValue}}{${denominatorValue}}`
              )}를 정리하세요.`,
              visualization: null,
              validityChecks: [
                {
                  name: "non-zero-substitution-denominator",
                  passed: denominatorValue !== 0,
                  message: "직접 대입 문제의 분모가 0이 되었습니다."
                }
              ]
            };
          }
        },
        {
          id: "difference-of-squares",
          label: "유형 6 · 제곱의 차 약분",
          difficulty: 2,
          generate() {
            const a = nonZeroInteger(-6, 6);
            const answer = 2 * a;
            return {
              prompt: `${inlineMath(
                `\\displaystyle\\lim_{x\\to ${a}}\\frac{x^2-${a ** 2}}{${xMinus(a)}}`
              )}의 값을 구하세요.`,
              inputMode: "short-answer",
              answer,
              solution: `${inlineMath(
                `x^2-${a ** 2}=(${xMinus(a)})(x${a < 0 ? "" : "+"}${a})`
              )}로 인수분해한 뒤 공통 인자를 약분합니다. 남은 식에 ${inlineMath(`x=${a}`)}를 대입하면 ${inlineMath(String(answer))}입니다.`,
              hintText: `${inlineMath("A^2-B^2=(A-B)(A+B)")}를 이용해 분모와 같은 인자를 찾아보세요.`,
              visualization: {
                kind: "hole-linear",
                focusX: a,
                slope: 1,
                intercept: a
              }
            };
          }
        },
        {
          id: "expanded-factor-cancellation",
          label: "유형 7 · 이차식 인수분해",
          difficulty: 3,
          generate() {
            const a = nonZeroInteger(-4, 4);
            const slope = nonZeroInteger(-3, 3);
            const constant = randomInteger(-5, 5);
            const quadratic = slope;
            const linear = constant - slope * a;
            const expandedConstant = -a * constant;
            const numerator = quadraticExpression(
              quadratic,
              linear,
              expandedConstant
            );
            const answer = slope * a + constant;
            return {
              prompt: `${inlineMath(
                `\\displaystyle\\lim_{x\\to ${a}}\\frac{${numerator}}{${xMinus(a)}}`
              )}의 값을 구하세요.`,
              inputMode: "short-answer",
              answer,
              solution: `분자를 ${inlineMath(
                `(${xMinus(a)})(${linearExpression(
                  slope,
                  constant
                )})`
              )}로 인수분해합니다. 공통 인자를 약분한 뒤 ${inlineMath(`x=${a}`)}를 대입하면 정답은 ${inlineMath(String(answer))}입니다.`,
              hintText: `분자에 ${inlineMath(`x=${a}`)}를 대입하면 0입니다. 따라서 ${inlineMath(xMinus(a))}가 분자의 인수입니다.`,
              visualization: {
                kind: "hole-linear",
                focusX: a,
                slope,
                intercept: constant
              }
            };
          }
        },
        {
          id: "root-rationalization",
          label: "유형 8 · 무리식 유리화",
          difficulty: 3,
          generate() {
            const root = randomInteger(2, 6);
            const a = root ** 2;
            const answer = 1 / (2 * root);
            return {
              prompt: `${inlineMath(
                `\\displaystyle\\lim_{x\\to ${a}}\\frac{\\sqrt{x}-${root}}{x-${a}}`
              )}의 값을 구하세요.`,
              inputMode: "short-answer",
              answer,
              solution: `분자와 분모에 ${inlineMath(
                `\\sqrt{x}+${root}`
              )}를 이용해 유리화하면 ${inlineMath(
                `\\frac{1}{\\sqrt{x}+${root}}`
              )}이 됩니다. 따라서 정답은 ${inlineMath(
                `\\frac{1}{${2 * root}}`
              )}입니다.`,
              hintText: "분자의 켤레식을 곱하면 분자에 있던 제곱근의 차가 분모와 같은 인자로 바뀝니다.",
              visualization: {
                kind: "rationalized-root",
                focusX: a,
                root
              },
              validityChecks: [
                {
                  name: "perfect-square-focus",
                  passed: a === root ** 2 && root > 0,
                  message: "유리화 문제의 접근점과 제곱근 조건이 맞지 않습니다."
                }
              ]
            };
          }
        },
        {
          id: "parameter-for-finite-limit",
          label: "유형 9 · 극한값으로 매개변수 구하기",
          difficulty: 3,
          generate() {
            const a = nonZeroInteger(-4, 4);
            const parameter = randomInteger(-5, 5);
            const target = a + parameter;
            const linearCoefficient = a > 0 ? `(m-${a})x` : `(m+${Math.abs(a)})x`;
            const constantTerm = a > 0 ? `-${a}m` : `+${Math.abs(a)}m`;
            const numerator = `x^2+${linearCoefficient}${constantTerm}`;
            return {
              prompt: `${inlineMath(
                `\\displaystyle\\lim_{x\\to ${a}}\\frac{${numerator}}{${xMinus(a)}}=${target}`
              )}일 때, 상수 ${inlineMath("m")}의 값을 구하세요.`,
              inputMode: "short-answer",
              answer: parameter,
              solution: `분자는 ${inlineMath(
                `(${xMinus(a)})(x+m)`
              )}로 인수분해됩니다. 약분한 식의 극한은 ${inlineMath(`${a}+m=${target}`)}이므로 ${inlineMath(`m=${parameter}`)}입니다.`,
              hintText: `분자에서 ${inlineMath(xMinus(a))}를 인수로 묶은 뒤, 약분하고 남은 일차식의 극한을 이용하세요.`,
              visualization: {
                kind: "hole-linear",
                focusX: a,
                slope: 1,
                intercept: parameter
              }
            };
          }
        },
        {
          id: "infinity-leading-coefficients",
          label: "유형 10 · 무한대에서 최고차항 비교",
          difficulty: 3,
          generate() {
            const numeratorLeading = nonZeroInteger(-5, 5);
            const denominatorLeading = nonZeroInteger(-5, 5);
            const numerator = quadraticExpression(
              numeratorLeading,
              randomInteger(-5, 5),
              randomInteger(-5, 5)
            );
            const denominator = quadraticExpression(
              denominatorLeading,
              randomInteger(-5, 5),
              randomInteger(-5, 5)
            );
            const answer = numeratorLeading / denominatorLeading;
            const answerTex = fractionTex(
              numeratorLeading,
              denominatorLeading
            );
            return {
              prompt: `${inlineMath(
                `\\displaystyle\\lim_{x\\to\\infty}\\frac{${numerator}}{${denominator}}`
              )}의 값을 구하세요.`,
              inputMode: "short-answer",
              answer,
              solution: `분자와 분모를 ${inlineMath("x^2")}으로 나누면 낮은 차수의 항은 모두 0으로 갑니다. 따라서 정답은 최고차항 계수의 비 ${inlineMath(answerTex)}입니다.`,
              hintText: `분자와 분모의 최고차항은 각각 ${inlineMath(
                `${numeratorLeading}x^2`
              )}, ${inlineMath(
                `${denominatorLeading}x^2`
              )}입니다.
${inlineMath("x^2")}으로 나누면 낮은 차수의 항은 0으로 가므로 계수의 비 ${inlineMath(
                `\\frac{${numeratorLeading}}{${denominatorLeading}}`
              )}만 정리하면 됩니다.`,
              visualization: null,
              validityChecks: [
                {
                  name: "non-zero-leading-coefficients",
                  passed: numeratorLeading !== 0 && denominatorLeading !== 0,
                  message: "최고차항 계수는 0일 수 없습니다."
                }
              ]
            };
          }
        }
      ];
      module.exports = {
        key: "calculus-limit-properties-calculation",
        requiredDistinctTypes: 5,
        problemTypes,
        isCorrectAnswer
      };
    }
  });

  // services/problemGenerators/calculus1/functionContinuity.js
  var require_functionContinuity = __commonJS({
    "services/problemGenerators/calculus1/functionContinuity.js"(exports, module) {
      var {
        randomInteger,
        nonZeroInteger,
        isCorrectAnswer,
        inlineMath,
        displayMath,
        signedNumber,
        xMinus,
        linearExpression
      } = require_helpers();
      function yesNoChoices() {
        return [
          {
            key: "yes",
            text: "연속이다"
          },
          {
            key: "no",
            text: "연속이 아니다"
          }
        ];
      }
      function piecewiseDefinition(leftExpression, rightExpression, boundary, rightIncludesBoundary = true) {
        const leftCondition = rightIncludesBoundary ? `x<${boundary}` : `x\\le ${boundary}`;
        const rightCondition = rightIncludesBoundary ? `x\\ge ${boundary}` : `x>${boundary}`;
        return `f(x)=\\begin{cases}${leftExpression},&${leftCondition}\\\\${rightExpression},&${rightCondition}\\end{cases}`;
      }
      var problemTypes = [
        {
          id: "three-continuity-conditions",
          label: "유형 1 · 연속의 세 조건",
          difficulty: 1,
          generate() {
            const a = randomInteger(-4, 4);
            return {
              prompt: `함수 ${inlineMath("f(x)")}가 ${inlineMath(
                `x=${a}`
              )}에서 연속이기 위한 조건으로 옳은 것을 고르세요.`,
              inputMode: "multiple-choice",
              choices: [
                {
                  key: "all-three",
                  text: `${inlineMath(`f(${a})`)}가 정의되고, 극한이 존재하며, ${inlineMath(
                    `\\lim_{x\\to ${a}}f(x)=f(${a})`
                  )}이다.`
                },
                {
                  key: "point-only",
                  text: `${inlineMath(`f(${a})`)}의 값만 존재하면 된다.`
                },
                {
                  key: "limit-only",
                  text: `극한값만 존재하면 함수값과 달라도 된다.`
                },
                {
                  key: "one-side",
                  text: `좌극한과 함수값만 같으면 된다.`
                }
              ],
              answer: "all-three",
              solution: `점에서의 연속은 함수값의 존재, 양쪽 극한의 존재, 그리고 ${inlineMath(
                `\\lim_{x\\to ${a}}f(x)=f(${a})`
              )}라는 세 조건이 모두 필요합니다.`,
              hintText: `${inlineMath(`x=${a}`)}에서 다음 세 항목을 순서대로 확인하세요.
① ${inlineMath(`f(${a})`)}가 정의되는가
② 좌극한과 우극한이 같은가
③ 그 공통 극한값이 ${inlineMath(`f(${a})`)}와 같은가`,
              visualization: {
                kind: "polynomial",
                focusX: a,
                coefficients: {
                  quadratic: 1,
                  linear: -2 * a,
                  constant: a ** 2
                },
                note: "그래프가 이어지고, 접근하는 높이와 실제 점의 높이가 같은지 확인하세요."
              }
            };
          }
        },
        {
          id: "judge-from-limit-and-value",
          label: "유형 2 · 극한과 함수값으로 판정",
          difficulty: 2,
          generate() {
            const a = randomInteger(-3, 3);
            const limitValue = randomInteger(-4, 4);
            const caseIndex = randomInteger(0, 3);
            let leftLimit = limitValue;
            let rightLimit = limitValue;
            let pointValue = limitValue;
            let pointDefined = true;
            let answer = "yes";
            let reason = "좌극한, 우극한, 함수값이 모두 같은 값입니다.";
            let visualization = {
              kind: "polynomial",
              focusX: a,
              coefficients: {
                quadratic: 0,
                linear: 0,
                constant: limitValue
              }
            };
            if (caseIndex === 1) {
              rightLimit += nonZeroInteger(-3, 3);
              pointValue = randomInteger(-4, 4);
              answer = "no";
              reason = "좌극한과 우극한이 달라 극한이 존재하지 않습니다.";
              visualization = {
                kind: "one-sided-limits",
                focusX: a,
                leftLimit,
                rightLimit
              };
            } else if (caseIndex === 2) {
              pointValue += nonZeroInteger(-3, 3);
              answer = "no";
              reason = "극한값은 존재하지만 함수값과 다릅니다.";
              visualization = {
                kind: "limit-point-example",
                focusX: a,
                limitValue,
                pointValue
              };
            } else if (caseIndex === 3) {
              pointDefined = false;
              answer = "no";
              reason = "극한값이 존재하더라도 함수값이 정의되지 않았습니다.";
              visualization = {
                kind: "hole-linear",
                focusX: a,
                slope: 0,
                intercept: limitValue
              };
            }
            return {
              prompt: `${inlineMath(
                `\\lim_{x\\to ${a}^{-}}f(x)=${leftLimit}`
              )}, ${inlineMath(
                `\\lim_{x\\to ${a}^{+}}f(x)=${rightLimit}`
              )}이고, ` + (pointDefined ? `${inlineMath(
                `f(${a})=${pointValue}`
              )}입니다.` : `${inlineMath(
                `f(${a})`
              )}는 정의되지 않았습니다.`) + ` 함수 ${inlineMath("f(x)")}는 ${inlineMath(
                `x=${a}`
              )}에서 연속입니까?`,
              inputMode: "multiple-choice",
              choices: yesNoChoices(),
              answer,
              solution: `${reason} 따라서 ${inlineMath(
                `x=${a}`
              )}에서 ${answer === "yes" ? "연속입니다." : "연속이 아닙니다."}`,
              hintText: "좌극한과 우극한을 먼저 비교하고, 그 공통값이 실제 함수값과 같은지 확인하세요.",
              visualization
            };
          }
        },
        {
          id: "fill-removable-hole",
          label: "유형 3 · 구멍을 메우는 함수값",
          difficulty: 2,
          generate() {
            const a = nonZeroInteger(-5, 5);
            const answer = 2 * a;
            const definition = `f(x)=\\begin{cases}\\dfrac{x^2-${a ** 2}}{${xMinus(a)}},&x\\ne ${a}\\\\k,&x=${a}\\end{cases}`;
            return {
              prompt: `${displayMath(definition)}${inlineMath("f(x)")}가 ${inlineMath(
                `x=${a}`
              )}에서 연속이 되도록 하는 ${inlineMath("k")}를 구하세요.`,
              inputMode: "short-answer",
              answer,
              solution: `${inlineMath(`x\\ne ${a}`)}에서 식을 약분하면 ${inlineMath(`f(x)=x${a < 0 ? "" : "+"}${a}`)}입니다. 따라서 극한값 ${inlineMath(String(answer))}과 함수값 ${inlineMath("k")}가 같아야 하므로 ${inlineMath(`k=${answer}`)}입니다.`,
              hintText: "먼저 분자를 제곱의 차로 인수분해해 극한값을 구한 뒤, 그 값을 빈 점에 채우세요.",
              visualization: {
                kind: "hole-linear",
                focusX: a,
                slope: 1,
                intercept: a
              }
            };
          }
        },
        {
          id: "piecewise-intercept-parameter",
          label: "유형 4 · 조각함수의 상수항",
          difficulty: 3,
          generate() {
            const a = randomInteger(-3, 3);
            const leftSlope = nonZeroInteger(-3, 3);
            const leftConstant = randomInteger(-4, 4);
            const rightSlope = nonZeroInteger(-3, 3);
            const leftValue = leftSlope * a + leftConstant;
            const parameter = leftValue - rightSlope * a;
            const rightExpression = rightSlope === 1 ? "x+k" : rightSlope === -1 ? "-x+k" : `${rightSlope}x+k`;
            const definition = piecewiseDefinition(
              linearExpression(
                leftSlope,
                leftConstant
              ),
              rightExpression,
              a
            );
            return {
              prompt: `${displayMath(definition)}${inlineMath("f(x)")}가 ${inlineMath(
                `x=${a}`
              )}에서 연속이 되도록 하는 ${inlineMath("k")}를 구하세요.`,
              inputMode: "short-answer",
              answer: parameter,
              solution: `왼쪽 식의 극한은 ${inlineMath(
                String(leftValue)
              )}입니다. 오른쪽 식과 함수값도 같아야 하므로 ${inlineMath(
                `${rightSlope}\\times(${a})+k=${leftValue}`
              )}에서 ${inlineMath(
                `k=${parameter}`
              )}를 얻습니다.`,
              hintText: `${inlineMath(`x=${a}`)}를 왼쪽 식과 오른쪽 식에 각각 대입한 값이 같아지도록 식을 세우세요.`,
              visualization: {
                kind: "piecewise-linear",
                focusX: a,
                left: {
                  slope: leftSlope,
                  constant: leftConstant
                },
                right: {
                  slope: rightSlope,
                  constant: parameter
                }
              }
            };
          }
        },
        {
          id: "piecewise-slope-parameter",
          label: "유형 5 · 조각함수의 기울기",
          difficulty: 3,
          generate() {
            const a = nonZeroInteger(-4, 4);
            const leftSlope = nonZeroInteger(-3, 3);
            const leftConstant = randomInteger(-4, 4);
            const parameter = randomInteger(-4, 4);
            const leftValue = leftSlope * a + leftConstant;
            const rightConstant = leftValue - parameter * a;
            const rightExpression = `mx${signedNumber(rightConstant)}`;
            const definition = piecewiseDefinition(
              linearExpression(
                leftSlope,
                leftConstant
              ),
              rightExpression,
              a
            );
            return {
              prompt: `${displayMath(definition)}${inlineMath("f(x)")}가 ${inlineMath(
                `x=${a}`
              )}에서 연속이 되도록 하는 ${inlineMath("m")}을 구하세요.`,
              inputMode: "short-answer",
              answer: parameter,
              solution: `양쪽 식에 ${inlineMath(`x=${a}`)}를 대입한 값이 같아야 합니다. ${inlineMath(
                `${leftValue}=${a}m${signedNumber(
                  rightConstant
                )}`
              )}을 풀면 ${inlineMath(
                `m=${parameter}`
              )}입니다.`,
              hintText: "경계의 왼쪽 높이와 오른쪽 높이가 같아야 그래프가 끊기지 않습니다.",
              visualization: {
                kind: "piecewise-linear",
                focusX: a,
                left: {
                  slope: leftSlope,
                  constant: leftConstant
                },
                right: {
                  slope: parameter,
                  constant: rightConstant
                }
              }
            };
          }
        },
        {
          id: "rational-continuity-at-point",
          label: "유형 6 · 유리함수의 한 점 연속",
          difficulty: 2,
          generate() {
            const a = randomInteger(-4, 4);
            const isContinuous = Math.random() >= 0.5;
            const excludedPoint = isContinuous ? a + nonZeroInteger(-3, 3) : a;
            const numeratorConstant = randomInteger(-4, 4);
            return {
              prompt: `${inlineMath(
                `f(x)=\\dfrac{x${signedNumber(
                  numeratorConstant
                )}}{${xMinus(excludedPoint)}}`
              )}일 때, ${inlineMath("f(x)")}는 ${inlineMath(
                `x=${a}`
              )}에서 연속입니까?`,
              inputMode: "multiple-choice",
              choices: yesNoChoices(),
              answer: isContinuous ? "yes" : "no",
              solution: isContinuous ? `${inlineMath(`x=${a}`)}에서 분모는 0이 아니므로 유리함수는 그 점에서 연속입니다.` : `${inlineMath(`x=${a}`)}에서 분모가 0이 되어 함수값이 정의되지 않으므로 연속이 아닙니다.`,
              hintText: `유리함수는 분모가 0이 아닌 점에서 연속입니다.
${inlineMath(`x=${a}`)}를 분모에 넣으면 ${inlineMath(
                `(${a})-(${excludedPoint})=${a - excludedPoint}`
              )}입니다. 이 값이 0인지 판단하세요.`,
              visualization: {
                kind: "rational-continuity",
                focusX: a,
                pole: excludedPoint,
                numeratorConstant,
                note: isContinuous ? `표시한 x=${a}에서는 분모가 0이 아니므로 곡선이 이어집니다.` : `x=${excludedPoint}에서는 분모가 0이 되어 그래프가 끊깁니다.`
              },
              validityChecks: [
                {
                  name: "rational-domain-condition",
                  passed: isContinuous === (a !== excludedPoint),
                  message: "유리함수의 정의역과 연속 판정이 일치하지 않습니다."
                }
              ]
            };
          }
        },
        {
          id: "rational-continuity-interval",
          label: "유형 7 · 연속인 구간 찾기",
          difficulty: 2,
          generate() {
            const excludedPoint = randomInteger(-4, 4);
            return {
              prompt: `${inlineMath(
                `f(x)=\\dfrac{1}{${xMinus(excludedPoint)}}`
              )}가 구간 전체에서 연속인 것을 고르세요.`,
              inputMode: "multiple-choice",
              choices: [
                {
                  key: "safe",
                  text: inlineMath(
                    `[${excludedPoint + 1},${excludedPoint + 3}]`
                  )
                },
                {
                  key: "left-end",
                  text: inlineMath(
                    `[${excludedPoint - 2},${excludedPoint}]`
                  )
                },
                {
                  key: "middle",
                  text: inlineMath(
                    `[${excludedPoint - 1},${excludedPoint + 1}]`
                  )
                },
                {
                  key: "right-end",
                  text: inlineMath(
                    `[${excludedPoint},${excludedPoint + 2}]`
                  )
                }
              ],
              answer: "safe",
              solution: `이 함수는 분모가 0이 되는 ${inlineMath(
                `x=${excludedPoint}`
              )}에서만 불연속입니다. 이 점을 포함하지 않는 ${inlineMath(
                `[${excludedPoint + 1},${excludedPoint + 3}]`
              )}에서 연속입니다.`,
              hintText: `분모 ${inlineMath(
                xMinus(excludedPoint)
              )}가 0이 되는 곳은 ${inlineMath(
                `x=${excludedPoint}`
              )}입니다.
보기의 양 끝점도 포함하여 이 값을 전혀 포함하지 않는 구간을 찾으세요.`,
              visualization: {
                kind: "rational-continuity",
                focusX: excludedPoint,
                pole: excludedPoint,
                numeratorMode: "constant",
                numeratorValue: 1,
                safeInterval: [
                  excludedPoint + 1,
                  excludedPoint + 3
                ],
                note: "점선으로 표시된 분모의 영점을 포함하지 않는 구간을 찾으세요."
              },
              validityChecks: [
                {
                  name: "unique-safe-interval",
                  passed: !(excludedPoint >= excludedPoint + 1 && excludedPoint <= excludedPoint + 3) && excludedPoint >= excludedPoint - 2 && excludedPoint <= excludedPoint && excludedPoint >= excludedPoint - 1 && excludedPoint <= excludedPoint + 1 && excludedPoint >= excludedPoint && excludedPoint <= excludedPoint + 2,
                  message: "연속인 구간 보기에 정답이 하나로 결정되지 않습니다."
                }
              ]
            };
          }
        },
        {
          id: "endpoint-continuity",
          label: "유형 8 · 닫힌구간의 끝점",
          difficulty: 2,
          generate() {
            const a = randomInteger(-5, 0);
            const b = randomInteger(1, 6);
            return {
              prompt: `함수 ${inlineMath("f(x)")}가 ${inlineMath(
                `(${a},${b})`
              )}의 모든 점에서 연속이고, ${inlineMath(
                `\\lim_{x\\to ${a}^{+}}f(x)=f(${a})`
              )}, ${inlineMath(
                `\\lim_{x\\to ${b}^{-}}f(x)=f(${b})`
              )}입니다. 연속인 구간을 고르세요.`,
              inputMode: "multiple-choice",
              choices: [
                {
                  key: "closed",
                  text: inlineMath(`[${a},${b}]`)
                },
                {
                  key: "open",
                  text: inlineMath(`(${a},${b})`)
                },
                {
                  key: "left-open",
                  text: inlineMath(`(${a},${b}]`)
                },
                {
                  key: "right-open",
                  text: inlineMath(`[${a},${b})`)
                }
              ],
              answer: "closed",
              solution: `구간 내부에서 연속이고, 왼쪽 끝점에서는 우극한이, 오른쪽 끝점에서는 좌극한이 각각 함수값과 같습니다. 따라서 ${inlineMath(`[${a},${b}]`)}에서 연속입니다.`,
              hintText: `내부 ${inlineMath(
                `(${a},${b})`
              )}에서는 이미 연속입니다.
왼쪽 끝 ${inlineMath(`x=${a}`)}에서는 우극한을, 오른쪽 끝 ${inlineMath(`x=${b}`)}에서는 좌극한을 확인했으므로 두 끝점을 포함할 수 있는지 판단하세요.`,
              visualization: {
                kind: "continuous-interval",
                focusX: (a + b) / 2,
                left: a,
                right: b,
                leftValue: 1,
                midpoint: (a + b) / 2,
                midpointValue: -1,
                rightValue: 2,
                note: "구간 안의 곡선과 두 끝점이 모두 이어져 닫힌구간 전체가 연결됩니다."
              }
            };
          }
        },
        {
          id: "classify-discontinuity",
          label: "유형 9 · 불연속 유형 판별",
          difficulty: 2,
          generate() {
            const a = randomInteger(-3, 3);
            const limitValue = randomInteger(-4, 4);
            const caseIndex = randomInteger(0, 2);
            let rightLimit = limitValue;
            let pointValue = limitValue;
            let answer = "continuous";
            let visualization = {
              kind: "polynomial",
              focusX: a,
              coefficients: {
                quadratic: 0,
                linear: 0,
                constant: limitValue
              }
            };
            if (caseIndex === 1) {
              pointValue += nonZeroInteger(-3, 3);
              answer = "removable";
              visualization = {
                kind: "limit-point-example",
                focusX: a,
                limitValue,
                pointValue
              };
            } else if (caseIndex === 2) {
              rightLimit += nonZeroInteger(-3, 3);
              answer = "jump";
              visualization = {
                kind: "one-sided-limits",
                focusX: a,
                leftLimit: limitValue,
                rightLimit
              };
            }
            return {
              prompt: `${inlineMath(
                `\\lim_{x\\to ${a}^{-}}f(x)=${limitValue}`
              )}, ${inlineMath(
                `\\lim_{x\\to ${a}^{+}}f(x)=${rightLimit}`
              )}, ${inlineMath(
                `f(${a})=${pointValue}`
              )}일 때 ${inlineMath(`x=${a}`)}에서의 상태를 고르세요.`,
              inputMode: "multiple-choice",
              choices: [
                {
                  key: "continuous",
                  text: "연속"
                },
                {
                  key: "removable",
                  text: "제거 가능한 불연속"
                },
                {
                  key: "jump",
                  text: "점프 불연속"
                }
              ],
              answer,
              solution: answer === "continuous" ? "좌극한, 우극한, 함수값이 모두 같으므로 연속입니다." : answer === "removable" ? "양쪽 극한은 같지만 함수값만 다르므로 그 점의 값을 바꾸면 연속이 되는 제거 가능한 불연속입니다." : "좌극한과 우극한이 서로 달라 그래프가 뛰어오르는 점프 불연속입니다.",
              hintText: "먼저 양쪽 극한이 같은지 보고, 같다면 함수값까지 일치하는지 확인하세요.",
              visualization
            };
          }
        },
        {
          id: "continuity-from-table",
          label: "유형 10 · 표에서 연속 판정",
          difficulty: 2,
          generate() {
            const a = randomInteger(-2, 2);
            const target = randomInteger(-4, 4);
            const isContinuous = Math.random() >= 0.5;
            const pointValue = isContinuous ? target : target + nonZeroInteger(-3, 3);
            const xValues = [
              a - 0.1,
              a - 0.01,
              a,
              a + 0.01,
              a + 0.1
            ];
            const yValues = [
              target - 0.1,
              target - 0.01,
              pointValue,
              target + 0.01,
              target + 0.1
            ];
            const table = displayMath(
              `\\begin{array}{c|ccccc}x&${xValues.join("&")}\\\\f(x)&${yValues.map((value) => value.toFixed(2)).join("&")}\\end{array}`
            );
            return {
              prompt: `${table}표를 바탕으로 ${inlineMath("f(x)")}가 ${inlineMath(
                `x=${a}`
              )}에서 연속인지 판단하세요.`,
              inputMode: "multiple-choice",
              choices: yesNoChoices(),
              answer: isContinuous ? "yes" : "no",
              solution: `주변의 함수값은 양쪽에서 ${inlineMath(
                String(target)
              )}에 가까워지고, ${inlineMath(
                `f(${a})=${pointValue}`
              )}입니다. 따라서 ` + (isContinuous ? "극한값과 함수값이 같아 연속입니다." : "극한값과 함수값이 달라 연속이 아닙니다."),
              hintText: `${inlineMath(`x=${a}`)}인 열을 잠시 가리고 양쪽 값이 향하는 높이를 찾은 뒤, 가운데 함수값과 비교하세요.`,
              visualization: {
                kind: "limit-point-example",
                focusX: a,
                limitValue: target,
                pointValue
              }
            };
          }
        }
      ];
      module.exports = {
        key: "calculus-function-continuity",
        requiredDistinctTypes: 5,
        problemTypes,
        isCorrectAnswer
      };
    }
  });

  // services/problemGenerators/calculus1/continuousFunctionProperties.js
  var require_continuousFunctionProperties = __commonJS({
    "services/problemGenerators/calculus1/continuousFunctionProperties.js"(exports, module) {
      var {
        randomInteger,
        nonZeroInteger,
        isCorrectAnswer,
        inlineMath,
        displayMath,
        signedNumber,
        xMinus
      } = require_helpers();
      function guaranteedChoices() {
        return [
          {
            key: "guaranteed",
            text: "존재가 보장된다"
          },
          {
            key: "not-guaranteed",
            text: "존재가 보장되지 않는다"
          }
        ];
      }
      var problemTypes = [
        {
          id: "algebra-of-continuous-functions",
          label: "유형 1 · 연속함수의 사칙연산",
          difficulty: 1,
          generate() {
            const a = randomInteger(-4, 4);
            return {
              prompt: `두 함수 ${inlineMath("f(x)")}, ${inlineMath(
                "g(x)"
              )}가 모두 ${inlineMath(
                `x=${a}`
              )}에서 연속일 때, 옳은 설명을 고르세요.`,
              inputMode: "multiple-choice",
              choices: [
                {
                  key: "sum-product",
                  text: `${inlineMath("f(x)+g(x)")}와 ${inlineMath("f(x)g(x)")}는 모두 연속이다.`
                },
                {
                  key: "quotient-always",
                  text: `${inlineMath(
                    "\\dfrac{f(x)}{g(x)}"
                  )}는 ${inlineMath(`g(${a})=0`)}이어도 항상 연속이다.`
                },
                {
                  key: "difference-never",
                  text: `${inlineMath("f(x)-g(x)")}는 항상 불연속이다.`
                },
                {
                  key: "reciprocal-always",
                  text: `${inlineMath(
                    "\\dfrac{1}{f(x)}"
                  )}는 함수값과 관계없이 항상 연속이다.`
                }
              ],
              answer: "sum-product",
              solution: "연속함수의 합, 차, 곱은 연속입니다. 몫과 역수는 해당 점에서 분모가 0이 아니라는 조건이 추가로 필요합니다.",
              hintText: `${inlineMath(`x=${a}`)}에서 연속인 두 함수의 합·차·곱은 추가 조건 없이 연속입니다.
보기 중 분모가 생기는 몫이나 역수에는 분모의 함수값이 0이 아니라는 조건이 빠졌는지 확인하세요.`,
              visualization: {
                kind: "limit-law-combination",
                focusX: a,
                fLimit: 2,
                gLimit: -1,
                resultLimit: 1,
                note: "연속인 두 곡선은 같은 x에서 합·차·곱을 해도 끊기지 않습니다."
              }
            };
          }
        },
        {
          id: "quotient-continuity-condition",
          label: "유형 2 · 몫의 연속 조건",
          difficulty: 2,
          generate() {
            const a = randomInteger(-4, 4);
            const fValue = randomInteger(-5, 5);
            const denominatorIsZero = Math.random() >= 0.5;
            const gValue = denominatorIsZero ? 0 : nonZeroInteger(-5, 5);
            return {
              prompt: `${inlineMath("f(x)")}, ${inlineMath(
                "g(x)"
              )}가 ${inlineMath(`x=${a}`)}에서 연속이고 ${inlineMath(`f(${a})=${fValue}`)}, ${inlineMath(`g(${a})=${gValue}`)}입니다. ${inlineMath(
                `h(x)=\\dfrac{f(x)}{g(x)}`
              )}가 ${inlineMath(`x=${a}`)}에서 연속인지 판단하세요.`,
              inputMode: "multiple-choice",
              choices: [
                {
                  key: "continuous",
                  text: "연속이다"
                },
                {
                  key: "not-continuous",
                  text: "연속이 아니다"
                }
              ],
              answer: denominatorIsZero ? "not-continuous" : "continuous",
              solution: denominatorIsZero ? `${inlineMath(`g(${a})=0`)}이므로 몫이 그 점에서 정의되지 않아 연속이 아닙니다.` : `${inlineMath(`g(${a})=${gValue}\\ne0`)}이므로 연속함수의 몫도 그 점에서 연속입니다.`,
              hintText: `분자 ${inlineMath(
                `f(${a})=${fValue}`
              )}보다 분모를 먼저 봅니다.
현재 ${inlineMath(
                `g(${a})=${gValue}`
              )}이므로 이 값이 0인지 확인해 몫의 연속 성질을 적용할 수 있는지 판단하세요.`,
              visualization: {
                kind: "rational-continuity",
                focusX: a,
                pole: denominatorIsZero ? a : a + (a < 3 ? 2 : -2),
                numeratorConstant: fValue,
                note: denominatorIsZero ? "분모가 0인 표시점에서는 몫의 그래프가 정의되지 않습니다." : "표시점에서 분모가 0이 아니므로 몫의 그래프가 이어집니다."
              }
            };
          }
        },
        {
          id: "composition-continuity",
          label: "유형 3 · 합성함수의 연속",
          difficulty: 2,
          generate() {
            const a = randomInteger(-3, 3);
            const b = randomInteger(-4, 4);
            const value = randomInteger(-6, 6);
            return {
              prompt: `${inlineMath("g(x)")}가 ${inlineMath(
                `x=${a}`
              )}에서 연속이고 ${inlineMath(`g(${a})=${b}`)}, ${inlineMath("f(x)")}가 ${inlineMath(
                `x=${b}`
              )}에서 연속이며 ${inlineMath(`f(${b})=${value}`)}입니다. ${inlineMath(
                `\\displaystyle\\lim_{x\\to ${a}}f(g(x))`
              )}를 구하세요.`,
              inputMode: "short-answer",
              answer: value,
              solution: `연속성에 의해 ${inlineMath(
                `\\lim_{x\\to ${a}}g(x)=g(${a})=${b}`
              )}이고, 다시 ${inlineMath("f")}의 연속성을 적용하면 ${inlineMath(
                `\\lim_{x\\to ${a}}f(g(x))=f(${b})=${value}`
              )}입니다.`,
              hintText: `안쪽 함수부터 보면 연속성에 의해 ${inlineMath(
                `g(x)\\to g(${a})=${b}`
              )}입니다.
따라서 바깥 함수의 입력은 ${inlineMath(
                String(b)
              )}가 되고, 문제에 주어진 ${inlineMath(
                `f(${b})=${value}`
              )}를 이용할 수 있습니다.`,
              visualization: {
                kind: "continuous-interval",
                focusX: a,
                left: a - 2,
                right: a + 2,
                leftValue: value - 2,
                midpoint: a,
                midpointValue: value,
                rightValue: value + 2,
                target: value,
                note: "안쪽 함수가 b로 다가가면 바깥 연속함수의 값은 f(b)로 이어집니다."
              }
            };
          }
        },
        {
          id: "extreme-value-theorem",
          label: "유형 4 · 최대·최소 정리",
          difficulty: 1,
          generate() {
            const a = randomInteger(-5, -1);
            const b = randomInteger(1, 5);
            return {
              prompt: `함수 ${inlineMath("f(x)")}가 닫힌구간 ${inlineMath(
                `[${a},${b}]`
              )}에서 연속일 때 반드시 보장되는 것을 고르세요.`,
              inputMode: "multiple-choice",
              choices: [
                {
                  key: "both-extremes",
                  text: "최댓값과 최솟값을 모두 갖는다."
                },
                {
                  key: "increasing",
                  text: "구간 전체에서 증가한다."
                },
                {
                  key: "one-root",
                  text: "방정식 f(x)=0의 해를 정확히 하나 갖는다."
                },
                {
                  key: "endpoints",
                  text: "최댓값과 최솟값을 모두 끝점에서 갖는다."
                }
              ],
              answer: "both-extremes",
              solution: "닫힌구간에서 연속인 함수는 최대·최소 정리에 의해 그 구간에서 최댓값과 최솟값을 모두 갖습니다.",
              hintText: `조건은 “${inlineMath(
                `[${a},${b}]`
              )}라는 닫힌구간”과 “그 구간에서 연속”입니다.
최대·최소 정리가 정확히 보장하는 것은 값의 위치나 근의 개수가 아니라 최댓값과 최솟값의 존재입니다.`,
              visualization: {
                kind: "continuous-interval",
                focusX: (a + b) / 2,
                left: a,
                right: b,
                leftValue: 1,
                midpoint: (a + b) / 2,
                midpointValue: -2,
                rightValue: 2,
                note: "닫힌구간의 연속인 곡선에는 가장 높은 점과 가장 낮은 점이 모두 존재합니다."
              }
            };
          }
        },
        {
          id: "quadratic-extreme-value",
          label: "유형 5 · 닫힌구간의 최대·최소 계산",
          difficulty: 2,
          generate() {
            const vertexX = randomInteger(-3, 3);
            const vertexY = randomInteger(-4, 4);
            const leftDistance = randomInteger(1, 4);
            const rightDistance = randomInteger(1, 4);
            const intervalStart = vertexX - leftDistance;
            const intervalEnd = vertexX + rightDistance;
            const asksMaximum = Math.random() >= 0.5;
            const minimum = vertexY;
            const maximum = vertexY + Math.max(
              leftDistance ** 2,
              rightDistance ** 2
            );
            const answer = asksMaximum ? maximum : minimum;
            return {
              prompt: `${inlineMath(
                `f(x)=(${xMinus(vertexX)})^2${signedNumber(
                  vertexY
                )}`
              )}일 때, 닫힌구간 ${inlineMath(
                `[${intervalStart},${intervalEnd}]`
              )}에서의 ${asksMaximum ? "최댓값" : "최솟값"}을 구하세요.`,
              inputMode: "short-answer",
              answer,
              solution: `꼭짓점은 ${inlineMath(
                `(${vertexX},${vertexY})`
              )}이므로 최솟값은 ${inlineMath(
                String(minimum)
              )}입니다. 두 끝점의 함수값도 비교하면 최댓값은 ${inlineMath(String(maximum))}입니다. 따라서 물은 값은 ${inlineMath(String(answer))}입니다.`,
              hintText: "위로 열린 포물선이므로 꼭짓점과 닫힌구간의 두 끝점, 총 세 곳의 높이를 비교하세요.",
              visualization: {
                kind: "polynomial",
                focusX: vertexX,
                coefficients: {
                  quadratic: 1,
                  linear: -2 * vertexX,
                  constant: vertexX ** 2 + vertexY
                }
              }
            };
          }
        },
        {
          id: "intermediate-target-value",
          label: "유형 6 · 중간값의 존재 판정",
          difficulty: 2,
          generate() {
            const a = randomInteger(-5, -1);
            const b = randomInteger(1, 5);
            const firstValue = randomInteger(-6, 0);
            const secondValue = randomInteger(2, 8);
            const isBetween = Math.random() >= 0.5;
            const target = isBetween ? randomInteger(
              firstValue + 1,
              secondValue - 1
            ) : secondValue + randomInteger(1, 4);
            return {
              prompt: `${inlineMath("f(x)")}가 ${inlineMath(
                `[${a},${b}]`
              )}에서 연속이고, ${inlineMath(
                `f(${a})=${firstValue}`
              )}, ${inlineMath(
                `f(${b})=${secondValue}`
              )}입니다. ${inlineMath(
                `f(c)=${target}`
              )}인 ${inlineMath(`c\\in(${a},${b})`)}의 존재가 사잇값 정리로 보장됩니까?`,
              inputMode: "multiple-choice",
              choices: guaranteedChoices(),
              answer: isBetween ? "guaranteed" : "not-guaranteed",
              solution: isBetween ? `${inlineMath(String(target))}은 두 끝점의 함수값 ${inlineMath(String(firstValue))}과 ${inlineMath(
                String(secondValue)
              )} 사이에 있으므로 존재가 보장됩니다.` : `${inlineMath(String(target))}은 두 끝점의 함수값 사이에 있지 않으므로 사잇값 정리만으로는 존재를 보장할 수 없습니다.`,
              hintText: `두 끝점의 높이는 ${inlineMath(
                String(firstValue)
              )}와 ${inlineMath(
                String(secondValue)
              )}이고 목표 높이는 ${inlineMath(
                String(target)
              )}입니다.
${inlineMath(
                `${firstValue}<${target}<${secondValue}`
              )}가 성립하는지 그대로 비교하세요.`,
              visualization: {
                kind: "continuous-interval",
                focusX: (a + b) / 2,
                left: a,
                right: b,
                leftValue: firstValue,
                rightValue: secondValue,
                target,
                note: isBetween ? "목표 높이가 두 끝값 사이에 있어 연속인 곡선과 만납니다." : "목표 높이가 두 끝값 바깥에 있어 사잇값 정리만으로 교점을 보장할 수 없습니다."
              },
              validityChecks: [
                {
                  name: "intermediate-target-condition",
                  passed: isBetween ? firstValue < target && target < secondValue : target < firstValue || target > secondValue,
                  message: "목표값이 의도한 사잇값 범위와 맞지 않습니다."
                }
              ]
            };
          }
        },
        {
          id: "root-from-sign-change",
          label: "유형 7 · 부호 변화와 근의 존재",
          difficulty: 2,
          generate() {
            const a = randomInteger(-5, -1);
            const b = randomInteger(1, 5);
            const firstValue = -randomInteger(1, 6);
            const secondValue = randomInteger(1, 6);
            return {
              prompt: `${inlineMath("f(x)")}가 ${inlineMath(
                `[${a},${b}]`
              )}에서 연속이고 ${inlineMath(
                `f(${a})=${firstValue}`
              )}, ${inlineMath(
                `f(${b})=${secondValue}`
              )}일 때 반드시 옳은 것을 고르세요.`,
              inputMode: "multiple-choice",
              choices: [
                {
                  key: "root-exists",
                  text: `${inlineMath(`f(c)=0`)}인 ${inlineMath(`c\\in(${a},${b})`)}가 적어도 하나 존재한다.`
                },
                {
                  key: "one-root",
                  text: "근이 정확히 하나만 존재한다."
                },
                {
                  key: "no-root",
                  text: "구간 안에 근이 존재하지 않는다."
                },
                {
                  key: "endpoint-root",
                  text: "두 끝점 중 하나가 반드시 근이다."
                }
              ],
              answer: "root-exists",
              solution: `끝점의 함수값 부호가 서로 다르고 함수가 연속이므로, 사잇값 정리에 의해 ${inlineMath(
                `f(c)=0`
              )}인 점이 열린구간 안에 적어도 하나 존재합니다.`,
              hintText: `${inlineMath(
                `f(${a})=${firstValue}<0`
              )}이고 ${inlineMath(
                `f(${b})=${secondValue}>0`
              )}입니다.
연속인 그래프가 음수 높이에서 양수 높이로 이동하면 중간 높이 0을 적어도 한 번 지나야 합니다.`,
              visualization: {
                kind: "continuous-interval",
                focusX: (a + b) / 2,
                left: a,
                right: b,
                leftValue: firstValue,
                rightValue: secondValue,
                target: 0,
                note: "음수 높이에서 양수 높이로 이어지는 곡선은 x축을 적어도 한 번 지납니다."
              },
              validityChecks: [
                {
                  name: "opposite-endpoint-signs",
                  passed: firstValue * secondValue < 0,
                  message: "근의 존재 문제에서 끝점 함수값의 부호가 다르지 않습니다."
                }
              ]
            };
          }
        },
        {
          id: "polynomial-root-interval",
          label: "유형 8 · 다항방정식의 근이 있는 구간",
          difficulty: 3,
          generate() {
            const lower = randomInteger(1, 3);
            const lowerCube = lower ** 3;
            const upperCube = (lower + 1) ** 3;
            const constant = randomInteger(
              lowerCube + 1,
              upperCube - 1
            );
            return {
              prompt: `방정식 ${inlineMath(
                `x^3-${constant}=0`
              )}의 양의 실근이 있음을 사잇값 정리로 보일 수 있는 구간을 고르세요.`,
              inputMode: "multiple-choice",
              choices: [
                {
                  key: "correct",
                  text: inlineMath(
                    `[${lower},${lower + 1}]`
                  )
                },
                {
                  key: "right",
                  text: inlineMath(
                    `[${lower + 1},${lower + 2}]`
                  )
                },
                {
                  key: "left",
                  text: inlineMath(`[0,${lower}]`)
                },
                {
                  key: "negative",
                  text: inlineMath(`[-${lower},0]`)
                }
              ],
              answer: "correct",
              solution: `${inlineMath(
                `${lower ** 3}-${constant}<0`
              )}이고 ${inlineMath(
                `${(lower + 1) ** 3}-${constant}>0`
              )}입니다. 다항함수는 연속이므로 ${inlineMath(
                `[${lower},${lower + 1}]`
              )} 안에 근이 존재합니다.`,
              hintText: `${inlineMath(
                `f(x)=x^3-${constant}`
              )}로 놓습니다.
${inlineMath(
                `f(${lower})=${lower ** 3}-${constant}<0`
              )}, ${inlineMath(
                `f(${lower + 1})=${(lower + 1) ** 3}-${constant}>0`
              )}이므로 이 두 점을 양 끝으로 갖는 구간을 찾으세요.`,
              visualization: {
                kind: "continuous-interval",
                focusX: lower + 0.5,
                left: lower,
                right: lower + 1,
                coefficients: [
                  -constant,
                  0,
                  0,
                  1
                ],
                target: 0,
                note: "구간의 양 끝에서 함수값의 부호가 바뀌므로 그 사이에 x축과의 교점이 있습니다."
              },
              validityChecks: [
                {
                  name: "root-bracketing-interval",
                  passed: lowerCube < constant && constant < upperCube,
                  message: "선택한 구간이 다항방정식의 근을 끼우지 못합니다."
                }
              ]
            };
          }
        },
        {
          id: "bisection-step",
          label: "유형 9 · 사잇값 정리로 구간 좁히기",
          difficulty: 3,
          generate() {
            const a = randomInteger(-4, 0);
            const midpoint = a + 2;
            const b = a + 4;
            const rootInLeftHalf = Math.random() >= 0.5;
            const firstValue = -randomInteger(1, 6);
            const midpointValue = rootInLeftHalf ? randomInteger(1, 6) : -randomInteger(1, 6);
            const lastValue = randomInteger(1, 6);
            return {
              prompt: `${inlineMath("f(x)")}가 ${inlineMath(
                `[${a},${b}]`
              )}에서 연속이고 ${inlineMath(
                `f(${a})=${firstValue}`
              )}, ${inlineMath(
                `f(${midpoint})=${midpointValue}`
              )}, ${inlineMath(
                `f(${b})=${lastValue}`
              )}입니다. ${inlineMath(
                "f(x)=0"
              )}의 근이 있음을 보장하면서 구간을 절반으로 좁힌 것을 고르세요.`,
              inputMode: "multiple-choice",
              choices: [
                {
                  key: "left",
                  text: inlineMath(`[${a},${midpoint}]`)
                },
                {
                  key: "right",
                  text: inlineMath(`[${midpoint},${b}]`)
                },
                {
                  key: "outside-left",
                  text: inlineMath(
                    `[${a - 2},${a}]`
                  )
                },
                {
                  key: "outside-right",
                  text: inlineMath(
                    `[${b},${b + 2}]`
                  )
                }
              ],
              answer: rootInLeftHalf ? "left" : "right",
              solution: `함수값의 부호가 바뀌는 두 점은 ` + (rootInLeftHalf ? `${inlineMath(`x=${a}`)}와 ${inlineMath(
                `x=${midpoint}`
              )}` : `${inlineMath(
                `x=${midpoint}`
              )}와 ${inlineMath(`x=${b}`)}`) + `입니다. 따라서 ${inlineMath(
                rootInLeftHalf ? `[${a},${midpoint}]` : `[${midpoint},${b}]`
              )} 안에 근이 존재합니다.`,
              hintText: `왼쪽 절반의 끝값은 ${inlineMath(
                `${firstValue},\\ ${midpointValue}`
              )}, 오른쪽 절반의 끝값은 ${inlineMath(
                `${midpointValue},\\ ${lastValue}`
              )}입니다.
두 값의 부호가 서로 다른 쪽 구간에서만 근의 존재가 보장됩니다.`,
              visualization: {
                kind: "continuous-interval",
                focusX: midpoint,
                left: a,
                right: b,
                leftValue: firstValue,
                midpoint,
                midpointValue,
                rightValue: lastValue,
                target: 0,
                selectedInterval: rootInLeftHalf ? [a, midpoint] : [midpoint, b],
                note: "세 점 중 함수값의 부호가 바뀌는 이웃한 두 점을 새 구간으로 선택하세요."
              },
              validityChecks: [
                {
                  name: "single-bisection-sign-change",
                  passed: rootInLeftHalf ? firstValue * midpointValue < 0 && midpointValue * lastValue > 0 : firstValue * midpointValue > 0 && midpointValue * lastValue < 0,
                  message: "이분한 두 구간의 부호 변화 조건이 의도와 다릅니다."
                }
              ]
            };
          }
        },
        {
          id: "missing-ivt-hypothesis",
          label: "유형 10 · 사잇값 정리의 조건",
          difficulty: 2,
          generate() {
            const jumpX = randomInteger(-4, 4);
            const leftValue = -randomInteger(1, 5);
            const rightValue = randomInteger(1, 5);
            const intervalRadius = randomInteger(1, 4);
            const leftEndpoint = jumpX - intervalRadius;
            const rightEndpoint = jumpX + intervalRadius;
            const definition = `f(x)=\\begin{cases}${leftValue},&x<${jumpX}\\\\${rightValue},&x\\ge${jumpX}\\end{cases}`;
            return {
              prompt: `${displayMath(definition)}${inlineMath(
                `f(${leftEndpoint})=${leftValue}<0<f(${rightEndpoint})=${rightValue}`
              )}이지만 ${inlineMath("f(c)=0")}인 ${inlineMath(
                `c\\in(${leftEndpoint},${rightEndpoint})`
              )}는 없습니다. 사잇값 정리를 적용할 수 없는 이유를 고르세요.`,
              inputMode: "multiple-choice",
              choices: [
                {
                  key: "not-continuous",
                  text: `${inlineMath("f(x)")}가 ${inlineMath(
                    `[${leftEndpoint},${rightEndpoint}]`
                  )}에서 연속이 아니기 때문이다.`
                },
                {
                  key: "not-closed",
                  text: `${inlineMath(
                    `[${leftEndpoint},${rightEndpoint}]`
                  )}이 닫힌구간이 아니기 때문이다.`
                },
                {
                  key: "same-sign",
                  text: "두 끝점의 함수값 부호가 같기 때문이다."
                },
                {
                  key: "zero-endpoint",
                  text: "끝점 중 하나가 0이기 때문이다."
                }
              ],
              answer: "not-continuous",
              solution: `함수는 ${inlineMath(`x=${jumpX}`)}에서 ${leftValue}에서 ${rightValue}로 뛰어 올라 불연속입니다. 연속이라는 핵심 가정이 없으므로 중간 높이 0을 지나지 않아도 됩니다.`,
              hintText: `그래프가 ${leftValue}의 높이에서 ${rightValue}의 높이로 이동할 때 중간을 지나지 않고 점프하는 지점을 찾으세요.`,
              visualization: {
                kind: "one-sided-limits",
                focusX: jumpX,
                leftLimit: leftValue,
                rightLimit: rightValue
              }
            };
          }
        }
      ];
      module.exports = {
        key: "calculus-continuous-function-properties",
        requiredDistinctTypes: 5,
        problemTypes,
        isCorrectAnswer
      };
    }
  });

  // services/problemGenerators/calculus1/advancedCalculus.js
  var require_advancedCalculus = __commonJS({
    "services/problemGenerators/calculus1/advancedCalculus.js"(exports, module) {
      var {
        randomInteger,
        isCorrectAnswer,
        inlineMath,
        displayMath,
        signedNumber,
        xMinus,
        quadraticExpression,
        fractionTex
      } = require_helpers();
      function round4(value) {
        return Math.round(
          (Number(value) + Number.EPSILON) * 1e4
        ) / 1e4;
      }
      function choose(values) {
        return values[randomInteger(0, values.length - 1)];
      }
      function nonZero(min = -5, max = 5) {
        let value = 0;
        while (value === 0) {
          value = randomInteger(min, max);
        }
        return value;
      }
      function sa(prompt, answer, solution, hintText, visualization) {
        return {
          prompt,
          inputMode: "short-answer",
          answer: round4(answer),
          solution,
          hintText,
          visualization
        };
      }
      function mc(prompt, choices, answerIndex, solution, hintText, visualization) {
        const shuffled = choices.map(
          (text, index) => ({
            text,
            correct: index === answerIndex
          })
        );
        for (let index = shuffled.length - 1; index > 0; index -= 1) {
          const swapIndex = randomInteger(0, index);
          [shuffled[index], shuffled[swapIndex]] = [
            shuffled[swapIndex],
            shuffled[index]
          ];
        }
        const normalized = shuffled.map(
          (choice, index) => ({
            key: String.fromCharCode(65 + index),
            ...choice
          })
        );
        return {
          prompt,
          inputMode: "multiple-choice",
          choices: normalized.map(
            ({ key, text }) => ({ key, text })
          ),
          answer: normalized.find(
            (choice) => choice.correct
          ).key,
          solution,
          hintText,
          visualization
        };
      }
      function calculusVisual(kind, data = {}) {
        return {
          kind: `calculus-${kind}`,
          ...data
        };
      }
      function powerTerm(coefficient, exponent, variable = "x") {
        if (coefficient === 0) return "0";
        const magnitude = Math.abs(coefficient);
        const coefficientText = magnitude === 1 && exponent > 0 ? "" : String(magnitude);
        const variableText = exponent === 0 ? "" : exponent === 1 ? variable : `${variable}^{${exponent}}`;
        return `${coefficient < 0 ? "-" : ""}${coefficientText}${variableText}`;
      }
      function signedTerm(coefficient, exponent, variable = "x") {
        if (coefficient === 0) return "";
        const term = powerTerm(
          Math.abs(coefficient),
          exponent,
          variable
        );
        return coefficient > 0 ? `+${term}` : `-${term}`;
      }
      function derivativeCoefficientProblems() {
        const q = nonZero(1, 4);
        const l = nonZero(-5, 5);
        const c = randomInteger(-5, 5);
        const a = randomInteger(-3, 3);
        const b = a + randomInteger(1, 5);
        const cubic = nonZero(1, 3);
        const quadratic = nonZero(-4, 4);
        const fA = q * a ** 2 + l * a + c;
        const derivativeAtA = 2 * q * a + l;
        const averageRate = q * (a + b) + l;
        const definitionValue = 2 * a + 1;
        return [
          sa(`${inlineMath(`f(x)=${quadraticExpression(q, l, c)}`)}의 구간 [${a},${b}]에서 평균변화율은?`, averageRate, `평균변화율은 ${inlineMath(`\\frac{f(${b})-f(${a})}{${b}-${a}}=${averageRate}`)}입니다.`, "두 끝의 함수값 차를 x의 변화량으로 나누세요.", calculusVisual("secant", { q, l, c, a, b })),
          sa(`${inlineMath(`f(x)=${quadraticExpression(q, l, c)}`)}일 때 ${inlineMath(`f'(${a})`)}는?`, derivativeAtA, `차분몫 ${inlineMath(`\\frac{f(${a}+h)-f(${a})}{h}`)}을 정리하고 ${inlineMath(`h\\to0`)}으로 보내면 ${derivativeAtA}입니다.`, "도함수 공식을 먼저 쓰지 말고 미분계수의 정의에 직접 대입하세요.", calculusVisual("tangent", { q, l, c, point: a })),
          mc(`${inlineMath(`x=${a}`)}에서 미분계수를 나타내는 식은?`, [
            `${inlineMath(`\\lim_{h\\to0}\\frac{f(${a}+h)-f(${a})}{h}`)}`,
            `${inlineMath(`\\lim_{h\\to0}\\frac{f(${a})-f(h)}{${a}}`)}`,
            `${inlineMath(`\\frac{f(${a})}{${a}}`)}`,
            `${inlineMath(`\\lim_{x\\to${a}}f(x)`)}`
          ], 0, "미분계수는 한 점에서 차분몫의 극한입니다.", "분자는 함수값의 변화량, 분모는 x의 변화량이어야 합니다.", calculusVisual("definition", { point: a })),
          sa(`곡선 ${inlineMath(`y=${quadraticExpression(q, l, c)}`)} 위에서 ${inlineMath(`x=${a}`)}인 점의 접선 기울기는?`, derivativeAtA, `할선의 기울기를 나타내는 차분몫의 극한이 ${inlineMath(`f'(${a})=${derivativeAtA}`)}입니다.`, "접선 기울기를 미분계수의 정의로 바꾸어 계산하세요.", calculusVisual("tangent", { q, l, c, point: a })),
          sa(`${inlineMath(`\\lim_{h\\to0}\\frac{f(${a}+h)-f(${a})}{h}=${derivativeAtA}`)}일 때 ${inlineMath(`f'(${a})`)}는?`, derivativeAtA, "주어진 극한식 자체가 미분계수의 정의입니다.", "극한식에서 기준점과 함수값의 차를 읽으세요.", calculusVisual("definition", { point: a, slope: derivativeAtA })),
          sa(`${inlineMath(`f(x)=${l}x${signedNumber(c)}`)}의 모든 점에서 미분계수는?`, l, "일차함수의 접선은 함수 자신과 평행하므로 기울기는 항상 x의 계수입니다.", "일차함수의 기울기를 읽으세요.", calculusVisual("tangent", { q: 0, l, c, point: a })),
          sa(`상수함수 ${inlineMath(`f(x)=${c}`)}의 미분계수는?`, 0, "함수값의 변화량이 항상 0이므로 미분계수는 0입니다.", "수평선의 기울기를 생각하세요.", calculusVisual("tangent", { q: 0, l: 0, c, point: a })),
          sa(`${inlineMath(`f(x)=${quadraticExpression(q, l, c)}`)}에서 ${inlineMath(`h=0.1,0.01,0.001`)}로 줄인 차분몫이 가까워지는 값, 즉 ${inlineMath(`f'(${a})`)}는?`, derivativeAtA, `${inlineMath(`\\frac{f(${a}+h)-f(${a})}{h}`)}에서 h가 0으로 가까워질 때 남는 값은 ${derivativeAtA}입니다.`, "여러 할선 기울기의 공통 도착값을 읽으세요.", calculusVisual("secant", { q, l, c, a, b: a + 0.5 })),
          sa(`${inlineMath(`\\lim_{h\\to0}\\frac{(${a}+h)^2+(${a}+h)-(${a ** 2 + a})}{h}`)}의 값은?`, definitionValue, `${inlineMath(`f(x)=x^2+x`)}의 ${inlineMath(`x=${a}`)}에서의 미분계수이므로 ${definitionValue}입니다.`, "분자를 전개한 뒤 h를 약분하고 h를 0으로 보내세요.", calculusVisual("definition", { point: a, slope: definitionValue })),
          mc(`${inlineMath(`f'(${a})<0`)}이 뜻하는 그래프의 상태는?`, ["그 점에서 오른쪽으로 갈수록 내려간다.", "그 점에서 반드시 최솟값을 갖는다.", "그 점에서 함수값이 음수다.", "그 점에서 불연속이다."], 0, "미분계수의 부호는 접선의 기울기와 순간적인 증가·감소 방향을 나타냅니다.", "함수값의 부호가 아니라 접선 기울기의 부호를 읽으세요.", calculusVisual("definition", { point: a, slope: -Math.abs(derivativeAtA || 1) }))
        ];
      }
      function differentiabilityProblems() {
        const point = randomInteger(-4, 4);
        const slope = nonZero(-5, 5);
        const leftSlope = nonZero(-5, 5);
        const rightSlope = leftSlope + nonZero(1, 4);
        const value = randomInteger(-5, 5);
        return [
          mc(`${inlineMath(`x=${point}`)}에서 미분가능하면 반드시 참인 것은?`, ["그 점에서 연속이다.", "그 점에서 극대이다.", "함수값이 0이다.", "도함수가 양수이다."], 0, "미분가능한 함수는 그 점에서 반드시 연속입니다.", "미분가능성과 연속성의 한 방향 포함 관계를 기억하세요.", calculusVisual("differentiability", { point })),
          mc(`${inlineMath(`f(x)=|${xMinus(point)}|`)}는 ${inlineMath(`x=${point}`)}에서?`, ["연속이고 미분가능하다.", "연속이지만 미분가능하지 않다.", "불연속이지만 미분가능하다.", "함수값이 없다."], 1, "뾰족점에서 좌우 기울기가 -1과 1로 달라 미분가능하지 않습니다.", "그래프는 이어져 있어도 접선 기울기가 하나인지 확인하세요.", calculusVisual("cusp", { point })),
          sa(`${displayMath(`f(x)=\\begin{cases}${leftSlope}(${xMinus(point)})+${value},&x<${point}\\\\k(${xMinus(point)})+${value},&x\\ge${point}\\end{cases}`)}
${inlineMath(`x=${point}`)}에서 미분가능할 때 k는?`, leftSlope, "연속성은 이미 맞고 좌우 기울기가 같아야 하므로 k는 왼쪽 기울기와 같습니다.", "좌미분계수와 우미분계수를 같게 놓으세요.", calculusVisual("piecewise-slope", { point, leftSlope, value })),
          mc(`좌미분계수가 ${leftSlope}, 우미분계수가 ${rightSlope}인 함수는 그 점에서?`, ["미분가능하다.", "미분가능하지 않다.", "반드시 불연속이다.", "반드시 극소이다."], 1, "양쪽 미분계수가 다르면 하나의 미분계수가 존재하지 않습니다.", "좌우 기울기를 먼저 비교하세요.", calculusVisual("piecewise-slope", { leftSlope, rightSlope })),
          mc(`다항함수 ${inlineMath(`f(x)=${slope}x^3${signedNumber(value)}`)}에 대한 옳은 설명은?`, ["모든 실수에서 미분가능하다.", "x=0에서만 미분가능하다.", "항상 불연속이다.", "양수 구간에서만 연속이다."], 0, "다항함수는 모든 실수에서 연속이고 미분가능합니다.", "다항함수의 기본 성질을 사용하세요.", calculusVisual("smooth", { slope, value })),
          mc(`함수가 x=${point}에서 불연속이면 미분가능성은?`, ["반드시 미분가능하다.", "미분가능하지 않다.", "도함수가 0이다.", "좌미분계수만 존재한다."], 1, "미분가능이면 연속이어야 하므로 그 대우에 의해 불연속이면 미분불가능입니다.", "미분가능 ⇒ 연속의 대우를 사용하세요.", calculusVisual("discontinuity", { point })),
          sa(`${displayMath(`f(x)=\\begin{cases}${leftSlope}x+k,&x<${point}\\\\${leftSlope}x${signedNumber(value)},&x\\ge${point}\\end{cases}`)}
${inlineMath(`x=${point}`)}에서 연속이 되게 하는 k는?`, value, "양쪽 식의 x계수가 같으므로 상수항도 같아야 함수값과 극한이 일치합니다.", "경계점에서 두 식의 값을 같게 놓으세요.", calculusVisual("piecewise-value", { point, leftSlope })),
          mc(`x=${point}에서 연속이지만 좌우 접선 기울기가 다른 그래프의 특징은?`, ["그 점에서 미분가능하다.", "뾰족점이 생길 수 있다.", "함수값이 없다.", "극한이 존재하지 않는다."], 1, "연속이어도 뾰족점에서는 좌우 기울기가 달라 미분가능하지 않습니다.", "연속성과 매끄러움을 구분하세요.", calculusVisual("cusp", { point })),
          sa(`좌미분계수와 우미분계수가 모두 ${slope}일 때 그 점의 미분계수는?`, slope, "두 일방 미분계수가 같은 값으로 존재하므로 미분계수는 그 공통값입니다.", "두 값이 같으면 그 값을 그대로 씁니다.", calculusVisual("differentiability", { slope })),
          mc(`다음 중 연속이지만 ${inlineMath(`x=${point}`)}에서 미분가능하지 않은 함수는?`, [`${inlineMath(`|${xMinus(point)}|`)}`, `${inlineMath(`(${xMinus(point)})^2`)}`, `${inlineMath(`x${signedNumber(value)}`)}`, `${inlineMath(String(value))}`], 0, "절댓값 함수는 꼭짓점에서 좌우 기울기가 다릅니다.", "그래프에 뾰족점이 있는지 확인하세요.", calculusVisual("cusp", { point }))
        ];
      }
      function powerDerivativeProblems() {
        const n = randomInteger(2, 8);
        const coefficient = nonZero(-5, 5);
        const point = choose([-2, -1, 1, 2]);
        return [
          sa(`${inlineMath(`f(x)=x^{${n}}`)}일 때 ${inlineMath(`f'(${point})`)}는?`, n * point ** (n - 1), `${inlineMath(`f'(x)=${n}x^{${n - 1}}`)}입니다.`, "지수를 앞으로 내리고 지수를 1 줄이세요.", calculusVisual("power", { n, point })),
          sa(`${inlineMath(`(${coefficient}x^{${n}})'`)}의 x=${point}에서의 값은?`, coefficient * n * point ** (n - 1), `${inlineMath(`${coefficient * n}x^{${n - 1}}`)}에 x=${point}를 대입합니다.`, "상수배는 유지한 채 거듭제곱을 미분하세요.", calculusVisual("power", { coefficient, n, point })),
          mc(`${inlineMath(`(x^{${n}})'`)}와 같은 것은?`, [`${inlineMath(`${n}x^{${n - 1}}`)}`, `${inlineMath(`${n - 1}x^{${n}}`)}`, `${inlineMath(`x^{${n - 1}}`)}`, `${inlineMath(`${n}x^{${n}}`)}`], 0, "지수는 계수로 내려오고 1만큼 작아집니다.", "계수와 지수 변화 둘 다 확인하세요.", calculusVisual("power", { n })),
          sa(`${inlineMath(`f(x)=x^{${n}}`)}의 도함수에서 x의 지수는?`, n - 1, "미분하면 지수가 1 감소합니다.", "원래 지수에서 1을 빼세요.", calculusVisual("power", { n })),
          sa(`${inlineMath(`f'(x)=${n}x^{${n - 1}}`)}이고 ${inlineMath(`f(x)=x^m`)}일 때 m은?`, n, "거듭제곱함수의 미분 규칙에서 도함수의 계수는 원래 지수입니다.", "도함수 앞의 계수를 읽으세요.", calculusVisual("power", { n })),
          sa(`${inlineMath(`f(x)=x^{${n + 1}}`)}일 때 ${inlineMath(`f'(1)`)}은?`, n + 1, `${inlineMath(`f'(x)=${n + 1}x^{${n}}`)}이므로 x=1에서 ${n + 1}입니다.`, "1의 거듭제곱은 모두 1입니다.", calculusVisual("power", { n: n + 1, point: 1 })),
          sa(`${inlineMath(`f(x)=${coefficient}x^2`)}일 때 접선 기울기가 ${2 * coefficient * point}이 되는 x는?`, point, `${inlineMath(`f'(x)=${2 * coefficient}x`)}이므로 방정식을 풀면 x=${point}입니다.`, "도함수를 주어진 기울기와 같게 놓으세요.", calculusVisual("power", { coefficient, n: 2, point })),
          mc(`거듭제곱함수 미분의 올바른 순서는?`, ["지수를 계수로 내리고 지수를 1 줄인다.", "지수를 1 늘리고 그 수로 나눈다.", "계수만 제곱한다.", "지수만 0으로 만든다."], 0, "미분에서는 지수를 내린 뒤 1 줄입니다.", "적분 규칙과 혼동하지 마세요.", calculusVisual("power", { n })),
          sa(`${inlineMath(`\\frac{d}{dx}(${coefficient}x)`)}은?`, coefficient, `일차함수의 도함수는 x의 계수 ${coefficient}입니다.`, "일차함수의 기울기를 읽으세요.", calculusVisual("power", { coefficient, n: 1 })),
          sa(`${inlineMath(`\\frac{d}{dx}(${coefficient}x^{${n}}+${randomInteger(-5, 5)})`)}에서 최고차항의 계수는?`, coefficient * n, "상수항은 사라지고 최고차항의 계수에는 지수가 곱해집니다.", "최고차항만 미분해 계수를 보세요.", calculusVisual("power", { coefficient, n }))
        ];
      }
      function polynomialDerivativeProblems() {
        const a = nonZero(-4, 4);
        const b = nonZero(-6, 6);
        const c = randomInteger(-8, 8);
        const d = randomInteger(-8, 8);
        const point = choose([-2, -1, 0, 1, 2]);
        const derivativeAt = 3 * a * point ** 2 + 2 * b * point + c;
        return [
          sa(`${inlineMath(`f(x)=${powerTerm(a, 3)}${signedTerm(b, 2)}${signedTerm(c, 1)}${signedNumber(d)}`)}일 때 ${inlineMath(`f'(${point})`)}는?`, derivativeAt, "각 항을 미분한 뒤 x값을 대입합니다.", "상수항의 도함수는 0입니다.", calculusVisual("polynomial", { coefficients: [d, c, b, a], point })),
          sa(`${inlineMath(`(${powerTerm(a, 3)}${signedTerm(b, 2)})'`)}에서 x²의 계수는?`, 3 * a, "삼차항을 미분하면 계수에 3을 곱한 이차항이 됩니다.", "최고차항만 먼저 미분하세요.", calculusVisual("polynomial", { coefficients: [0, 0, b, a] })),
          sa(`${inlineMath(`f(x)=${quadraticExpression(a, b, c)}`)}의 도함수에서 상수항은?`, b, `${inlineMath(`f'(x)=${2 * a}x${signedNumber(b)}`)}입니다.`, "일차항을 미분하면 그 계수가 상수항이 됩니다.", calculusVisual("polynomial", { coefficients: [c, b, a] })),
          mc(`다항함수의 미분에 대한 옳은 설명은?`, ["각 항을 따로 미분해 더할 수 있다.", "합을 미분하면 항상 곱이 된다.", "상수항은 그대로 남는다.", "모든 계수는 사라진다."], 0, "미분은 합과 상수배에 대해 선형입니다.", "항별 미분이 가능한지 생각하세요.", calculusVisual("polynomial")),
          sa(`${inlineMath(`f(x)=${a}x^3${signedTerm(c, 1)}`)}일 때 ${inlineMath(`f'(0)`)}은?`, c, "삼차항의 도함수는 x=0에서 0이고 일차항의 계수만 남습니다.", "도함수를 구한 뒤 0을 대입하세요.", calculusVisual("polynomial", { coefficients: [0, c, 0, a], point: 0 })),
          sa(`${inlineMath(`f'(x)=${3 * a}x^2${signedTerm(2 * b, 1)}${signedNumber(c)}`)} 이고 f가 삼차함수일 때 f의 최고차항 계수는?`, a, "삼차항을 미분할 때 계수에 3이 곱해집니다.", "도함수의 x² 계수를 3으로 나누세요.", calculusVisual("polynomial", { coefficients: [d, c, b, a] })),
          sa(`${inlineMath(`g(x)=${quadraticExpression(a, b, c)}`)}일 때 ${inlineMath(`(2g)'(${point})`)}는?`, 2 * (2 * a * point + b), "상수배의 미분은 도함수에도 같은 상수배가 적용됩니다.", "먼저 g′을 구한 뒤 2를 곱하세요.", calculusVisual("polynomial", { coefficients: [2 * c, 2 * b, 2 * a], point })),
          sa(`${inlineMath(`f'(${point})=${derivativeAt}`)}일 때 ${inlineMath(`(-3f)'(${point})`)}는?`, -3 * derivativeAt, "상수배 -3은 미분 뒤에도 그대로 곱해집니다.", "주어진 미분계수에 -3을 곱하세요.", calculusVisual("polynomial", { point, slope: -3 * derivativeAt })),
          mc(`${inlineMath(`(${powerTerm(a, 2)}${signedNumber(c)})'`)}는?`, [`${inlineMath(powerTerm(2 * a, 1))}`, `${inlineMath(powerTerm(a, 1))}`, `${inlineMath(`${powerTerm(2 * a, 1)}+1`)}`, `${inlineMath(powerTerm(a, 2))}`], 0, "상수항은 사라지고 이차항은 일차항이 됩니다.", "각 항을 따로 미분하세요.", calculusVisual("polynomial", { coefficients: [c, 0, a] })),
          sa(`${inlineMath(`f(x)=${a}x^3${signedTerm(b, 2)}${signedTerm(c, 1)}${signedNumber(d)}`)}의 도함수 차수는?`, 2, "삼차다항함수의 최고차항을 미분하면 이차항이 됩니다.", "최고차항의 지수가 1 줄어듭니다.", calculusVisual("polynomial", { coefficients: [d, c, b, a] }))
        ];
      }
      function tangentProblems() {
        const q = nonZero(1, 4);
        const l = nonZero(-5, 5);
        const c = randomInteger(-6, 6);
        const point = randomInteger(-3, 3);
        const y = q * point ** 2 + l * point + c;
        const slope = 2 * q * point + l;
        const intercept = y - slope * point;
        return [
          sa(`곡선 ${inlineMath(`y=${quadraticExpression(q, l, c)}`)}의 x=${point}인 점에서 접선 기울기는?`, slope, `${inlineMath(`f'(x)=${2 * q}x${signedNumber(l)}`)}에 x=${point}를 대입합니다.`, "접선 기울기는 f′(a)입니다.", calculusVisual("tangent", { q, l, c, point })),
          sa(`곡선 ${inlineMath(`y=${quadraticExpression(q, l, c)}`)}의 x=${point}인 점에서 접선의 y절편은?`, intercept, `접점 (${point},${y})와 기울기 ${slope}를 이용하면 y=${slope}x${signedNumber(intercept)}입니다.`, "점-기울기식으로 접선을 만든 뒤 x=0을 대입하세요.", calculusVisual("tangent", { q, l, c, point })),
          sa(`기울기가 ${slope}이고 점 (${point},${y})를 지나는 직선의 y절편은?`, intercept, `${inlineMath(`y${signedNumber(-y)}=${slope}(${xMinus(point)})`)}를 정리합니다.`, `직선의 식 ${inlineMath("y=mx+b")}에 점을 대입해 상수항을 구하세요.`, calculusVisual("line", { point, y, slope })),
          mc(`곡선 y=f(x)의 x=${point}인 점에서 접선 방정식은?`, [
            `${inlineMath(`y-f(${point})=f'(${point})(${xMinus(point)})`)}`,
            `${inlineMath(`y=f(${point})x`)}`,
            `${inlineMath(`y-f'(${point})=f(${point})(${xMinus(point)})`)}`,
            `${inlineMath(`y=f(x)-f(${point})`)}`
          ], 0, "접점과 그 점에서의 미분계수를 점-기울기식에 넣습니다.", "직선이 지나야 하는 점과 기울기를 확인하세요.", calculusVisual("tangent", { point })),
          sa(`${inlineMath(`f(${point})=${y},\\;f'(${point})=${slope}`)}일 때 접선의 x=${point + 1}에서의 y값은?`, y + slope, "접점에서 x가 1만큼 변하면 접선 위 y는 기울기만큼 변합니다.", "접선식에 x=a+1을 넣으세요.", calculusVisual("tangent", { point, y, slope })),
          sa(`곡선 ${inlineMath(`y=${q}x^2`)}에서 접선 기울기가 ${2 * q * point}인 점의 x좌표는?`, point, `${inlineMath(`y'=${2 * q}x`)}를 주어진 기울기와 같게 놓습니다.`, "도함수=접선 기울기 방정식을 푸세요.", calculusVisual("tangent", { q, point })),
          sa(`곡선 ${inlineMath(`y=${quadraticExpression(q, l, c)}`)} 위 x=${point}인 접점의 y좌표는?`, y, "원함수에 접점의 x좌표를 대입합니다.", "도함수가 아니라 원함수에 대입하세요.", calculusVisual("tangent", { q, l, c, point })),
          mc(`접선의 방정식을 구할 때 필요하지 않은 것은?`, ["곡선 전체의 넓이", "접점의 x좌표", "접점의 함수값", "접점에서의 미분계수"], 0, "접선은 한 점과 그 점에서의 기울기로 결정됩니다.", "점-기울기식에 들어가는 정보를 떠올리세요.", calculusVisual("tangent", { point })),
          sa(`${inlineMath(`f'(${point})=${slope}`)}일 때 그 점에서 접선과 평행한 직선의 기울기는?`, slope, "평행한 두 직선의 기울기는 같습니다.", "접선 기울기는 f′(a)입니다.", calculusVisual("line", { slope })),
          sa(`접선 ${inlineMath(`y=${slope}x${signedNumber(intercept)}`)}이 곡선과 만나는 접점의 x좌표가 ${point}일 때 접점의 y좌표는?`, y, `접선식에 x=${point}를 대입하면 y=${y}입니다.`, "접점은 접선 위에도 있습니다.", calculusVisual("tangent", { point, y, slope }))
        ];
      }
      function meanValueProblems() {
        const a = randomInteger(-4, 1);
        const b = a + randomInteger(2, 6);
        const q = nonZero(1, 4);
        const l = nonZero(-4, 4);
        const c = randomInteger(-5, 5);
        const average = q * (a + b) + l;
        const meanPoint = (a + b) / 2;
        return [
          sa(`${inlineMath(`f(x)=${quadraticExpression(q, l, c)}`)}에서 [${a},${b}]의 평균변화율은?`, average, `${inlineMath(`\\frac{f(${b})-f(${a})}{${b}-${a}}=${average}`)}입니다.`, "두 끝점을 잇는 할선 기울기를 구하세요.", calculusVisual("mvt", { q, l, c, a, b })),
          sa(`위 함수에서 평균값 정리를 만족하는 c는? ${inlineMath(`f(x)=${quadraticExpression(q, l, c)},\\;[${a},${b}]`)}`, meanPoint, `${inlineMath(`f'(c)=${2 * q}c${signedNumber(l)}=${average}`)}를 풀면 c=${meanPoint}입니다.`, "도함수를 평균변화율과 같게 놓으세요.", calculusVisual("mvt", { q, l, c, a, b, meanPoint })),
          mc(`평균값 정리를 [${a},${b}]에서 적용하기 위한 조건은?`, ["닫힌구간에서 연속, 열린구간에서 미분가능", "닫힌구간에서만 미분가능", "양 끝 함수값이 같음", "도함수가 항상 0"], 0, "닫힌구간 연속과 열린구간 미분가능이 핵심 조건입니다.", "끝점에서는 미분가능까지 요구하지 않습니다.", calculusVisual("mvt", { a, b })),
          sa(`함수의 [${a},${b}] 평균변화율이 ${average}라면 평균값 정리가 보장하는 어떤 c에서의 f′(c)는?`, average, "평균값 정리는 순간변화율이 평균변화율과 같은 점의 존재를 보장합니다.", "주어진 평균변화율을 그대로 사용하세요.", calculusVisual("mvt", { a, b, average })),
          mc(`평균값 정리의 기하적 의미는?`, ["할선과 평행한 접선이 적어도 하나 존재한다.", "모든 접선이 서로 평행하다.", "그래프가 직선이다.", "함수값이 항상 양수다."], 0, "같은 기울기를 갖는 할선과 접선은 평행합니다.", "평균변화율과 순간변화율을 직선 기울기로 해석하세요.", calculusVisual("mvt", { a, b })),
          sa(`일차함수 ${inlineMath(`f(x)=${l}x${signedNumber(c)}`)}의 임의 구간에서 평균변화율은?`, l, "일차함수는 모든 구간의 할선 기울기가 함수의 기울기와 같습니다.", "x의 계수를 읽으세요.", calculusVisual("mvt", { l, c, a, b })),
          mc(`${inlineMath(`f(x)=|${xMinus(meanPoint)}|`)}에 [${a},${b}]에서 평균값 정리를 바로 적용할 수 없는 이유는?`, ["구간 안의 뾰족점에서 미분가능하지 않다.", "함수가 연속이 아니다.", "구간이 닫혀 있지 않다.", "함수값이 모두 같다."], 0, "절댓값 함수는 꼭짓점에서 미분가능하지 않습니다.", "열린구간 안의 미분가능성을 확인하세요.", calculusVisual("cusp", { point: meanPoint })),
          sa(`${inlineMath(`f(${a})=${c},\\;f(${b})=${c + average * (b - a)}`)}일 때 [${a},${b}]의 평균변화율은?`, average, "함수값의 차를 구간 길이로 나눕니다.", "분자는 f(b)-f(a)입니다.", calculusVisual("secant", { a, b })),
          mc(`평균값 정리가 보장하는 c의 위치는?`, [`${inlineMath(`(${a},${b})`)}`, `${inlineMath(`[${a},${b}]`)}의 바깥`, "항상 a", "항상 b"], 0, "c는 열린구간 (a,b) 안에 존재합니다.", "정리의 결론에서 c의 범위를 확인하세요.", calculusVisual("mvt", { a, b })),
          sa(`평균변화율이 ${average}이고 어떤 c에서 ${inlineMath(`f'(c)=k`)}라 할 때 평균값 정리의 결론에 따른 k는?`, average, "평균값 정리에서 f′(c)는 평균변화율과 같습니다.", "두 기울기를 같게 놓으세요.", calculusVisual("mvt", { average }))
        ];
      }
      function extremaProblems() {
        const r = randomInteger(1, 4);
        const scale = nonZero(1, 3);
        const vertexX = randomInteger(-4, 4);
        const constant = randomInteger(-5, 5);
        const vertexValue = constant;
        const cubicAtNegative = 2 * scale * r ** 3;
        const cubicAtPositive = -2 * scale * r ** 3;
        return [
          sa(`${inlineMath(`f(x)=${scale}(${xMinus(vertexX)})^2${signedNumber(constant)}`)}의 극소가 되는 x는?`, vertexX, "위로 열린 포물선의 꼭짓점에서 극소가 됩니다.", "꼭짓점형에서 x좌표를 읽으세요.", calculusVisual("extrema", { scale, vertexX, constant })),
          sa(`위 함수의 극솟값은? ${inlineMath(`f(x)=${scale}(${xMinus(vertexX)})^2${signedNumber(constant)}`)}`, vertexValue, "제곱항이 0일 때 함수값은 상수항입니다.", "꼭짓점의 y좌표를 읽으세요.", calculusVisual("extrema", { scale, vertexX, constant })),
          mc(`${inlineMath(`f'(x)>0`)}인 구간에서 f는?`, ["증가한다.", "감소한다.", "항상 0이다.", "불연속이다."], 0, "접선 기울기가 양수이면 x가 증가할수록 함수값이 증가합니다.", "도함수의 부호를 기울기로 해석하세요.", calculusVisual("sign-chart", { sign: 1 })),
          mc(`도함수의 부호가 +에서 -로 바뀌는 점은?`, ["극대점", "극소점", "항상 변곡점", "불연속점"], 0, "증가하다 감소하므로 봉우리인 극대가 됩니다.", "함수의 진행 방향 변화를 읽으세요.", calculusVisual("sign-chart", { signs: [1, -1] })),
          sa(`${inlineMath(`f'(x)=${scale}(x-${r})(x+${r})`)}의 임계점 중 양수인 것은?`, r, "도함수가 0이 되는 x는 ±r입니다.", "각 인자를 0으로 놓으세요.", calculusVisual("sign-chart", { roots: [-r, r], scale })),
          mc(`${inlineMath(`f'(x)=${scale > 0 ? "" : "-"}(x-${r})(x+${r})`)}에서 도함수의 부호가 바뀌는 지점의 개수는?`, ["2개", "1개", "0개", "무한히 많다"], 0, "서로 다른 두 단순근 ±r에서 부호가 각각 바뀝니다.", "도함수의 근과 중복도를 확인하세요.", calculusVisual("sign-chart", { roots: [-r, r], scale })),
          sa(`${inlineMath(`f(x)=${scale}x^3-${3 * scale * r ** 2}x`)}에서 x=-${r}일 때 함수값은?`, cubicAtNegative, "원함수에 x=-r을 대입합니다.", "극값의 위치를 찾은 뒤 원함수값을 계산하세요.", calculusVisual("extrema", { r, scale })),
          sa(`${inlineMath(`f(x)=${scale}x^3-${3 * scale * r ** 2}x`)}에서 x=${r}일 때 함수값은?`, cubicAtPositive, "원함수에 x=r을 대입합니다.", "도함수가 아니라 원함수에 대입하세요.", calculusVisual("extrema", { r, scale })),
          mc(`극값을 판정할 때 가장 직접적으로 필요한 것은?`, ["임계점 양쪽에서 도함수의 부호 변화", "함수식의 글자 수", "y절편만", "정의역의 길이만"], 0, "극대·극소는 임계점 주변의 증가·감소 변화로 판정합니다.", "도함수 부호표를 떠올리세요.", calculusVisual("sign-chart", { r })),
          sa(`${inlineMath(`f'(x)=2(${xMinus(vertexX)})`)}일 때 f가 감소하는 구간의 오른쪽 경계는?`, vertexX, `도함수는 ${inlineMath(`x<${vertexX}`)}에서 음수이므로 그 점까지 감소합니다.`, "도함수가 0보다 작은 부등식을 푸세요.", calculusVisual("sign-chart", { root: vertexX }))
        ];
      }
      function graphShapeProblems() {
        const r = randomInteger(1, 4);
        const scale = nonZero(1, 3);
        const shift = randomInteger(-4, 4);
        return [
          mc(`${inlineMath(`f'(x)=${scale > 0 ? "" : "-"}(${xMinus(shift)})`)}이고 ${scale > 0 ? "계수가 양수" : "계수가 음수"}일 때 f의 그래프는 x=${shift}에서?`, scale > 0 ? ["극소", "극대", "변화 없음", "불연속"] : ["극대", "극소", "변화 없음", "불연속"], 0, "도함수의 부호 변화로 꼭짓점의 종류를 판정합니다.", "임계점 좌우의 부호를 확인하세요.", calculusVisual("graph-shape", { shift, scale })),
          sa(`${inlineMath(`f(x)=${scale}(${xMinus(shift)})^2`)}의 대칭축은 x=?`, shift, `꼭짓점형 이차함수의 대칭축은 ${inlineMath(`x=${shift}`)}입니다.`, "제곱 안을 0으로 만드는 x를 찾으세요.", calculusVisual("graph-shape", { shift, scale })),
          mc(`삼차함수의 도함수가 서로 다른 두 실근을 가지면 가능한 그래프 모양은?`, ["극대와 극소를 각각 하나 가질 수 있다.", "항상 직선이다.", "극값이 절대 없다.", "정의역이 한 점이다."], 0, "도함수의 두 단순근에서 증가·감소가 바뀌면 두 극값이 생깁니다.", "임계점의 개수를 그래프 방향 전환과 연결하세요.", calculusVisual("graph-shape", { roots: [-r, r] })),
          sa(`${inlineMath(`f(x)=x^3-${3 * r ** 2}x`)}의 임계점 사이 구간 길이는?`, 2 * r, "도함수 3(x-r)(x+r)=0의 두 근은 -r,r입니다.", "두 임계점의 차를 구하세요.", calculusVisual("graph-shape", { roots: [-r, r] })),
          mc(`최고차항 계수가 양수인 삼차함수의 양 끝 방향은?`, ["왼쪽 아래, 오른쪽 위", "왼쪽 위, 오른쪽 아래", "양쪽 모두 위", "양쪽 모두 아래"], 0, "양의 삼차항은 x→-∞에서 -∞, x→∞에서 ∞입니다.", "최고차항만 보아 끝모양을 판단하세요.", calculusVisual("graph-shape", { degree: 3, leading: 1 })),
          mc(`최고차항 계수가 ${scale > 0 ? "양수" : "음수"}인 이차함수는?`, scale > 0 ? ["위로 열린다.", "아래로 열린다.", "항상 증가한다.", "직선이다."] : ["아래로 열린다.", "위로 열린다.", "항상 증가한다.", "직선이다."], 0, "이차항 계수의 부호가 포물선이 열리는 방향을 정합니다.", "최고차항 계수의 부호를 보세요.", calculusVisual("graph-shape", { degree: 2, leading: scale })),
          sa(`${inlineMath(`f'(x)=3(x-${r})(x+${r})`)}일 때 증가·감소 구간을 나누는 경계점의 개수는?`, 2, "도함수의 서로 다른 두 영점이 구간 경계가 됩니다.", "f′(x)=0의 실근 개수를 세세요.", calculusVisual("sign-chart", { roots: [-r, r] })),
          mc(`그래프 개형을 그릴 때 가장 먼저 확인할 정보로 적절한 것은?`, ["정의역과 절편, 끝모양", "정적분 상수만", "표본의 크기", "확률의 합"], 0, "그래프의 기본 위치와 전체 방향을 먼저 잡아야 합니다.", "미분 전에도 알 수 있는 정보를 찾으세요.", calculusVisual("graph-shape")),
          sa(`${inlineMath(`f(x)=(${xMinus(shift)})^2${signedNumber(r)}`)}의 꼭짓점 y좌표는?`, r, "제곱항이 0일 때 y=r입니다.", "꼭짓점형에서 상수항을 읽으세요.", calculusVisual("graph-shape", { shift, vertexY: r })),
          mc(`도함수가 모든 실수에서 양수인 함수의 그래프는?`, ["전체 구간에서 증가한다.", "전체 구간에서 감소한다.", "항상 x축 위다.", "항상 직선이다."], 0, "도함수 양수는 모든 점의 접선 기울기가 양수라는 뜻입니다.", "함수값의 부호와 기울기의 부호를 구분하세요.", calculusVisual("graph-shape", { derivativePositive: true }))
        ];
      }
      function equationInequalityProblems() {
        const shift = randomInteger(-5, 5);
        const minimum = randomInteger(-5, 5);
        const k = minimum + randomInteger(-3, 3);
        const r = randomInteger(1, 5);
        return [
          sa(`${inlineMath(`f(x)=(${xMinus(shift)})^2${signedNumber(minimum)}`)}의 최솟값은?`, minimum, "제곱항의 최솟값은 0입니다.", "꼭짓점의 y좌표를 읽으세요.", calculusVisual("equation", { shift, minimum })),
          mc(`${inlineMath(`(${xMinus(shift)})^2${signedNumber(minimum)}=${k}`)}의 실근 개수는?`, k > minimum ? ["2개", "1개", "0개", "무한히 많다"] : k === minimum ? ["1개", "2개", "0개", "무한히 많다"] : ["0개", "1개", "2개", "무한히 많다"], 0, `포물선의 최솟값 ${minimum}과 수평선 y=${k}를 비교합니다.`, "수평선과 그래프의 교점 수로 해석하세요.", calculusVisual("equation", { shift, minimum, k })),
          sa(`${inlineMath(`(${xMinus(shift)})^2\\ge${r ** 2}`)}의 경계 중 큰 값은?`, shift + r, `등호의 해는 ${inlineMath(`x=${shift}\\pm${r}`)}입니다.`, "제곱 부등식의 경계부터 구하세요.", calculusVisual("inequality", { shift, r })),
          sa(`${inlineMath(`(${xMinus(shift)})^2\\le${r ** 2}`)}의 해 구간 길이는?`, 2 * r, `해는 ${shift - r}≤x≤${shift + r}이므로 길이는 ${2 * r}입니다.`, "두 경계값의 차를 구하세요.", calculusVisual("inequality", { shift, r })),
          mc(`함수의 최솟값이 ${minimum}일 때 방정식 f(x)=${minimum - 1}의 실근은?`, ["없다.", "1개다.", "2개다.", "항상 3개다."], 0, "수평선이 그래프의 최솟값보다 아래에 있어 만나지 않습니다.", "함숫값의 가능한 범위를 확인하세요.", calculusVisual("equation", { minimum })),
          mc(`방정식 f(x)=k의 실근 개수를 그래프로 판단할 때 세는 것은?`, ["y=f(x)와 y=k의 교점", "f′(x)의 계수", "x축 눈금 수", "정의역의 글자 수"], 0, "방정식의 해는 두 그래프가 같은 y값을 갖는 x좌표입니다.", "등식을 두 그래프의 만남으로 바꾸세요.", calculusVisual("equation", { k })),
          sa(`${inlineMath(`f(x)=-(${xMinus(shift)})^2${signedNumber(minimum)}`)}의 최댓값은?`, minimum, "음의 제곱항은 0일 때 가장 큽니다.", "아래로 열린 포물선의 꼭짓점을 보세요.", calculusVisual("equation", { shift, maximum: minimum })),
          mc(`${inlineMath(`f'(x)=2(${xMinus(shift)})`)}일 때 f의 최솟값이 생기는 x는?`, [`${inlineMath(String(shift))}`, `${inlineMath(String(shift + 1))}`, `${inlineMath(String(shift - 1))}`, "존재하지 않음"], 0, `도함수가 음수에서 양수로 바뀌는 ${inlineMath(`x=${shift}`)}에서 극소입니다.`, "도함수가 0인 지점을 구하고 부호 변화를 보세요.", calculusVisual("sign-chart", { root: shift })),
          sa(`${inlineMath(`x^2-${2 * r}x+k`)}가 모든 실수 x에서 0 이상이 되기 위한 k의 최솟값은?`, r ** 2, `${inlineMath(`(x-${r})^2+k-${r ** 2}`)}의 최솟값이 0 이상이어야 합니다.`, "완전제곱식으로 바꾸어 최솟값을 구하세요.", calculusVisual("inequality", { r })),
          mc(`부등식 f(x)≥0의 해는 그래프에서?`, ["x축 위 또는 x축 위의 점에 해당하는 x", "y축 오른쪽의 모든 x", "도함수가 0인 점만", "그래프의 넓이"], 0, "함수값의 부호는 그래프가 x축보다 위인지 아래인지로 읽습니다.", "y=f(x)의 높이를 x축과 비교하세요.", calculusVisual("inequality"))
        ];
      }
      function motionProblems() {
        const a = nonZero(1, 4);
        const b = -randomInteger(1, 6);
        const c = randomInteger(-5, 5);
        const time = randomInteger(1, 5);
        const velocity = 2 * a * time + b;
        const acceleration = 2 * a;
        return [
          sa(`위치 ${inlineMath(`s(t)=${a}t^2${signedTerm(b, 1, "t")}${signedNumber(c)}`)}일 때 t=${time}의 속도는?`, velocity, `${inlineMath(`v(t)=s'(t)=${2 * a}t${signedNumber(b)}`)}입니다.`, "위치함수를 시간으로 한 번 미분하세요.", calculusVisual("motion", { a, b, c, time })),
          sa(`위 운동의 가속도는? ${inlineMath(`s(t)=${a}t^2${signedTerm(b, 1, "t")}${signedNumber(c)}`)}`, acceleration, `${inlineMath(`a(t)=s''(t)=${acceleration}`)}입니다.`, "위치함수를 두 번 미분하세요.", calculusVisual("motion", { a, b, c })),
          sa(`속도 ${inlineMath(`v(t)=${2 * a}t${signedNumber(b)}`)}일 때 t=${time}의 속력은?`, Math.abs(velocity), "속력은 속도의 절댓값입니다.", "방향을 나타내는 부호를 제거하세요.", calculusVisual("motion", { a, b, time })),
          sa(`위치 ${inlineMath(`s(t)=${a}t^2${signedTerm(b, 1, "t")}${signedNumber(c)}`)}에서 정지하는 시각이 양수라면 그 값은?`, round4(-b / (2 * a)), "v(t)=0을 풀어 정지 시각을 구합니다.", "위치함수를 미분한 뒤 속도를 0으로 놓으세요.", calculusVisual("motion", { a, b })),
          mc(`직선 운동에서 속도가 음수라는 뜻은?`, ["정한 양의 방향과 반대로 움직인다.", "반드시 느려진다.", "정지해 있다.", "가속도가 0이다."], 0, "속도의 부호는 운동 방향을 나타냅니다.", "속력과 속도를 구분하세요.", calculusVisual("motion")),
          mc(`속도와 가속도의 부호가 같을 때 물체의 속력은 일반적으로?`, ["증가한다.", "감소한다.", "항상 0이다.", "판단할 수 없다."], 0, "진행 방향과 같은 방향으로 가속되면 속력의 크기가 커집니다.", "속도 벡터와 가속도 방향을 비교하세요.", calculusVisual("motion", { sameSign: true })),
          sa(`속도 ${inlineMath(`v(t)=${a}t^2${signedTerm(b, 1, "t")}${signedNumber(c)}`)}일 때 t=${time}의 가속도는?`, 2 * a * time + b, `${inlineMath(`a(t)=v'(t)=${2 * a}t${signedNumber(b)}`)}입니다.`, "속도를 시간으로 미분하세요.", calculusVisual("motion", { a, b, c, time })),
          sa(`가속도가 일정하게 ${acceleration}이고 초기속도가 ${b}일 때 t=${time}의 속도는?`, acceleration * time + b, `${inlineMath(`v(t)=${b}+${acceleration}t`)}입니다.`, "초기속도에 가속도×시간을 더하세요.", calculusVisual("motion", { acceleration, initialVelocity: b, time })),
          mc(`위치·속도·가속도의 올바른 관계는?`, ["s를 미분하면 v, v를 미분하면 a", "s를 두 번 적분하면 v", "v를 미분하면 s", "a를 미분하면 v"], 0, "시간에 대한 미분 순서는 위치→속도→가속도입니다.", "변화율의 순서를 확인하세요.", calculusVisual("motion")),
          sa(`t=${time}에서 속도가 ${velocity}라면 그 순간 속력은?`, Math.abs(velocity), "속력은 속도의 크기이므로 절댓값을 취합니다.", "음수여도 이동의 빠르기는 양수입니다.", calculusVisual("motion", { time, velocity }))
        ];
      }
      function indefiniteIntegralProblems() {
        const n = randomInteger(1, 6);
        const coefficient = nonZero(-6, 6);
        const constant = randomInteger(-8, 8);
        return [
          sa(`${inlineMath(`\\int ${n + 1}x^{${n}}dx`)}에서 ${inlineMath(`x^{${n + 1}}`)}의 계수는?`, 1, `${inlineMath(`x^{${n + 1}}+C`)}입니다.`, "지수를 1 늘리고 새 지수로 나누세요.", calculusVisual("antiderivative", { n, coefficient: n + 1 })),
          sa(`${inlineMath(`\\int ${coefficient}dx`)}에서 x의 계수는?`, coefficient, `${inlineMath(`${coefficient}x+C`)}입니다.`, "상수함수의 원시함수는 일차함수입니다.", calculusVisual("antiderivative", { coefficient })),
          mc(`부정적분 결과에 +C를 붙이는 이유는?`, ["미분하면 모든 상수가 0이 되기 때문이다.", "적분값이 항상 양수이기 때문이다.", "x가 상수이기 때문이다.", "구간 길이를 나타내기 때문이다."], 0, "같은 도함수를 갖는 함수들은 상수만큼 차이 납니다.", "원시함수 하나가 아니라 전체 모음을 나타냅니다.", calculusVisual("antiderivative", { constant })),
          sa(`${inlineMath(`F'(x)=${coefficient}x`)}일 때 F의 x² 계수는?`, coefficient / 2, `${inlineMath(`F(x)=${fractionTex(coefficient, 2)}x^2+C`)}입니다.`, "x의 지수를 2로 늘리고 2로 나누세요.", calculusVisual("antiderivative", { coefficient, n: 1 })),
          sa(`${inlineMath(`F'(x)=0`)}이고 ${inlineMath(`F(${n})=${constant}`)}일 때 F(x)의 상수값은?`, constant, "도함수가 0인 함수는 모든 x에서 같은 상수값을 가집니다.", "변화가 없는 원시함수를 생각하세요.", calculusVisual("antiderivative", { coefficient: 0, constant })),
          mc(`${inlineMath(`\\int x^{${n}}dx`)}와 같은 것은?`, [
            `${inlineMath(`\\frac{x^{${n + 1}}}{${n + 1}}+C`)}`,
            `${inlineMath(`${n}x^{${n - 1}}+C`)}`,
            `${inlineMath(`x^{${n + 1}}+C`)}`,
            `${inlineMath(`\\frac{x^${n}}${n}+C`)}`
          ], 0, "지수를 1 늘리고 그 새 지수로 나눕니다.", "미분 공식과 반대 방향입니다.", calculusVisual("antiderivative", { n })),
          sa(`${inlineMath(`F(x)=${coefficient}x${signedNumber(constant)}`)}일 때 F′(x)는?`, coefficient, "일차함수를 미분하면 x의 계수만 남습니다.", "적분 결과를 미분해 검산하세요.", calculusVisual("antiderivative", { coefficient, constant })),
          sa(`${inlineMath(`\\int ${2 * coefficient}x\\,dx`)}의 x² 계수는?`, coefficient, `지수 1을 2로 늘린 뒤 계수 ${2 * coefficient}을 2로 나눕니다.`, "새 지수 2로 나누세요.", calculusVisual("antiderivative", { coefficient, n: 1 })),
          mc(`서로 다른 두 원시함수 F,G에 대해 항상 일정한 것은?`, ["F(x)-G(x)", "F(x)G(x)", "F(x)/G(x)", "F(x)+G(x)의 기울기"], 0, "같은 함수를 미분 결과로 갖는 원시함수들은 상수만큼 차이 납니다.", "두 함수의 도함수 차가 0임을 이용하세요.", calculusVisual("antiderivative")),
          sa(`${inlineMath(`\\int ${coefficient * (n + 1)}x^{${n}}dx`)}에서 최고차항 계수는?`, coefficient, `새 지수 ${n + 1}로 계수를 나누면 ${coefficient}이 됩니다.`, "적분 전 계수를 새 지수로 나누세요.", calculusVisual("antiderivative", { coefficient, n }))
        ];
      }
      function polynomialIntegralProblems() {
        const a = nonZero(-5, 5);
        const b = nonZero(-6, 6);
        const c = randomInteger(-8, 8);
        const n = randomInteger(1, 5);
        return [
          sa(`${inlineMath(`\\int ${a * 3}x^2dx`)}에서 x³의 계수는?`, a, "지수를 3으로 늘리고 계수를 3으로 나눕니다.", "새 지수로 나누세요.", calculusVisual("antiderivative", { coefficients: [0, 0, 3 * a] })),
          sa(`${inlineMath(`\\int (${2 * a}x${signedNumber(b)})dx`)}에서 x²의 계수는?`, a, "2a를 새 지수 2로 나눕니다.", "항별로 적분하세요.", calculusVisual("antiderivative", { coefficients: [b, 2 * a] })),
          sa(`${inlineMath(`\\int (${2 * a}x${signedNumber(b)})dx`)}에서 x의 계수는?`, b, `상수항 ${b}의 원시함수는 ${inlineMath(`${b}x`)}입니다.`, "상수항도 적분하면 x가 붙습니다.", calculusVisual("antiderivative", { coefficients: [b, 2 * a] })),
          mc(`다항함수의 부정적분에 대한 옳은 설명은?`, ["각 항을 따로 적분해 더할 수 있다.", "상수항은 항상 사라진다.", "지수는 1 줄어든다.", "적분상수는 필요 없다."], 0, "적분은 합과 상수배에 대해 선형입니다.", "미분과 적분의 지수 변화를 구분하세요.", calculusVisual("antiderivative")),
          sa(`${inlineMath(`\\int ${a * (n + 1)}x^${n}dx`)}의 최고차항 계수는?`, a, "지수를 1 늘리고 새 지수 n+1로 나눕니다.", "계수와 새 지수를 약분하세요.", calculusVisual("antiderivative", { a, n })),
          sa(`${inlineMath(`F'(x)=${3 * a}x^2${signedTerm(2 * b, 1)}${signedNumber(c)}`)}일 때 F의 x³ 계수는?`, a, "x²항을 적분하면 계수를 3으로 나눕니다.", "최고차항만 역으로 미분하세요.", calculusVisual("antiderivative", { coefficients: [c, 2 * b, 3 * a] })),
          sa(`${inlineMath(`F'(x)=${2 * a}x${signedNumber(b)}`)}이고 F(0)=${c}일 때 적분상수 C는?`, c, `${inlineMath(`F(x)=${a}x^2${signedTerm(b, 1)}+C`)}에서 x=0을 넣습니다.`, "초기조건을 원시함수에 대입하세요.", calculusVisual("antiderivative", { a, b, c })),
          sa(`${inlineMath(`\\int (${a * 2}x+${b * 3}x^2)dx`)}에서 x³의 계수는?`, b, "3b x²을 적분하면 b x³입니다.", "각 항을 따로 적분하세요.", calculusVisual("antiderivative", { a, b })),
          mc(`${inlineMath(`\\int (f(x)-g(x))dx`)}는?`, ["∫f(x)dx-∫g(x)dx", "∫f(x)dx·∫g(x)dx", "f′(x)-g′(x)", "항상 0"], 0, "차의 적분은 적분의 차입니다.", "적분의 선형성을 적용하세요.", calculusVisual("antiderivative")),
          sa(`${inlineMath(`\\int ${a * 4}x^3dx`)}에서 x⁴의 계수는?`, a, "새 지수 4로 계수 4a를 나눕니다.", "지수+1, 새 지수로 나눔 순서입니다.", calculusVisual("antiderivative", { a, n: 3 }))
        ];
      }
      function definiteIntegralConceptProblems() {
        const a = randomInteger(-5, 1);
        const b = a + randomInteger(2, 7);
        const c = randomInteger(a + 1, b - 1);
        const height = nonZero(-5, 5);
        const value1 = randomInteger(-10, 10);
        const value2 = randomInteger(-10, 10);
        return [
          sa(`${inlineMath(`\\int_{${a}}^{${b}}${height}\\,dx`)}는?`, height * (b - a), "상수함수의 부호 있는 넓이는 높이×구간 길이입니다.", "직사각형의 넓이로 생각하세요.", calculusVisual("definite", { a, b, height })),
          sa(`${inlineMath(`\\int_{${a}}^{${b}}f(x)dx=${value1}`)}일 때 ${inlineMath(`\\int_{${b}}^{${a}}f(x)dx`)}는?`, -value1, "적분 구간의 순서를 바꾸면 부호가 바뀝니다.", "윗끝과 아랫끝 교환은 -1을 곱합니다.", calculusVisual("definite", { a, b, value: value1 })),
          sa(`${inlineMath(`\\int_{${a}}^{${c}}f(x)dx=${value1},\\;\\int_{${c}}^{${b}}f(x)dx=${value2}`)}일 때 ${inlineMath(`\\int_{${a}}^{${b}}f(x)dx`)}는?`, value1 + value2, "인접한 구간의 정적분을 더합니다.", "구간의 덧셈성을 사용하세요.", calculusVisual("definite", { a, c, b })),
          sa(`${inlineMath(`\\int_{${a}}^{${a}}f(x)dx`)}는?`, 0, "구간 길이가 0이므로 누적량도 0입니다.", "시작점과 끝점이 같습니다.", calculusVisual("definite", { a, b: a })),
          mc(`함수가 x축 아래에 있는 구간의 정적분은?`, ["음수가 될 수 있다.", "항상 실제 넓이와 같다.", "항상 0이다.", "정의되지 않는다."], 0, "정적분은 x축 아래의 넓이를 음수로 셉니다.", "정적분은 부호 있는 넓이입니다.", calculusVisual("area", { belowAxis: true })),
          sa(`${inlineMath(`\\int_{${a}}^{${b}}f(x)dx=${value1}`)}일 때 ${inlineMath(`\\int_{${a}}^{${b}}2f(x)dx`)}는?`, 2 * value1, "상수배는 적분 밖으로 나올 수 있습니다.", "적분의 선형성을 사용하세요.", calculusVisual("definite", { a, b, value: value1 })),
          sa(`${inlineMath(`\\int_{${a}}^{${b}}f(x)dx=${value1},\\;\\int_{${a}}^{${b}}g(x)dx=${value2}`)}일 때 ${inlineMath(`\\int_{${a}}^{${b}}(f+g)dx`)}는?`, value1 + value2, "합의 적분은 적분의 합입니다.", "같은 구간의 두 값을 더하세요.", calculusVisual("definite", { a, b })),
          mc(`정적분을 직사각형 합의 극한으로 볼 때 분할을 촘촘하게 한다는 뜻은?`, ["각 작은 구간의 폭이 0에 가까워진다.", "함수값을 모두 0으로 만든다.", "구간을 없앤다.", "적분상수를 크게 한다."], 0, "리만합에서 최대 구간 폭이 0으로 가까워집니다.", "직사각형의 폭 변화를 생각하세요.", calculusVisual("riemann", { a, b })),
          sa(`폭이 ${b - a}, 높이가 ${Math.abs(height)}인 직사각형 모양의 함수가 x축 위에 있을 때 정적분은?`, Math.abs(height) * (b - a), "x축 위에서는 정적분과 실제 넓이가 같습니다.", "가로×세로를 계산하세요.", calculusVisual("area", { width: b - a, height: Math.abs(height) })),
          mc(`${inlineMath(`\\int_{${a}}^{${b}}f(x)dx`)}가 나타내는 것은?`, ["구간에서의 부호 있는 누적량", "항상 도형의 실제 넓이", "한 점의 함수값", "접선의 기울기"], 0, "정적분은 위쪽과 아래쪽을 부호와 함께 합한 값입니다.", "넓이와 부호 있는 넓이를 구분하세요.", calculusVisual("definite", { a, b }))
        ];
      }
      function fundamentalTheoremProblems() {
        const a = randomInteger(-3, 1);
        const b = a + randomInteger(2, 5);
        const coefficient = nonZero(-4, 4);
        const constant = randomInteger(-5, 5);
        const upperValue = coefficient * b ** 2 + constant * b;
        const lowerValue = coefficient * a ** 2 + constant * a;
        return [
          sa(`${inlineMath(`\\int_{${a}}^{${b}}${2 * coefficient}x\\,dx`)}는?`, coefficient * (b ** 2 - a ** 2), `${inlineMath(`[${coefficient}x^2]_{${a}}^{${b}}`)}로 계산합니다.`, "원시함수에 윗끝과 아랫끝을 대입해 빼세요.", calculusVisual("fundamental", { a, b, coefficient })),
          sa(`${inlineMath(`F(x)=${coefficient}x^2${signedTerm(constant, 1)}`)}일 때 ${inlineMath(`F(${b})-F(${a})`)}는?`, upperValue - lowerValue, "각 끝값을 계산해 윗값에서 아랫값을 뺍니다.", "대입 순서를 바꾸지 마세요.", calculusVisual("fundamental", { a, b, coefficient, constant })),
          mc(`${inlineMath(`F'(x)=f(x)`)}일 때 정적분 공식은?`, [
            `${inlineMath(`\\int_a^b f(x)dx=F(b)-F(a)`)}`,
            `${inlineMath(`\\int_a^b f(x)dx=F(a)-F(b)`)}`,
            `${inlineMath(`\\int_a^b f(x)dx=f(b)-f(a)`)}`,
            `${inlineMath(`\\int_a^b f(x)dx=F(a)+F(b)`)}`
          ], 0, "원시함수의 윗끝값에서 아랫끝값을 뺍니다.", "F와 f를 구분하세요.", calculusVisual("fundamental", { a, b })),
          sa(`${inlineMath(`\\int_{${a}}^{${b}}${constant}\\,dx`)}를 원시함수로 계산한 값은?`, constant * (b - a), `원시함수 ${constant}x의 끝값 차입니다.`, "상수의 원시함수에 양 끝을 대입하세요.", calculusVisual("fundamental", { a, b, constant })),
          sa(`${inlineMath(`\\int_{${a}}^{${b}}(${2 * coefficient}x${signedNumber(constant)})dx`)}는?`, coefficient * (b ** 2 - a ** 2) + constant * (b - a), "원시함수의 끝값 차를 계산합니다.", "항별로 원시함수를 구하세요.", calculusVisual("fundamental", { a, b, coefficient, constant })),
          mc(`정적분 계산에서 적분상수 C가 사라지는 이유는?`, ["F(b)+C와 F(a)+C의 차에서 소거된다.", "C가 항상 0이기 때문이다.", "구간 길이가 0이기 때문이다.", "미분을 하지 않기 때문이다."], 0, "같은 상수가 양 끝값 차에서 서로 없어집니다.", "끝값 차에 +C를 직접 써보세요.", calculusVisual("fundamental")),
          sa(`${inlineMath(`\\int_{0}^{${Math.abs(b) + 1}}${2 * coefficient}x\\,dx`)}는?`, coefficient * (Math.abs(b) + 1) ** 2, `원시함수 ${inlineMath(`${coefficient}x^2`)}에 양 끝을 대입합니다.`, "아랫끝 0에서의 값은 0입니다.", calculusVisual("fundamental", { a: 0, b: Math.abs(b) + 1, coefficient })),
          sa(`${inlineMath(`\\int_{${a}}^{${b}}f(x)dx=${upperValue - lowerValue}`)}이고 F(a)=${lowerValue}일 때 F(b)는?`, upperValue, "정적분=F(b)-F(a)이므로 F(b)=정적분+F(a)입니다.", "끝값 관계를 F(b)에 대해 푸세요.", calculusVisual("fundamental", { a, b })),
          mc(`정적분을 원시함수의 끝값 차로 계산하게 해 주는 핵심 연결은?`, ["미적분의 기본정리", "피타고라스 정리", "덧셈정리", "큰 수의 법칙"], 0, "미적분의 기본정리가 미분과 적분을 연결합니다.", "변화율과 누적량의 관계를 떠올리세요.", calculusVisual("fundamental")),
          sa(`${inlineMath(`F(${b})=${upperValue},\\;F(${a})=${lowerValue}`)}이고 F′=f일 때 ${inlineMath(`\\int_{${a}}^{${b}}f(x)dx`)}는?`, upperValue - lowerValue, "윗끝 원시함수값에서 아랫끝 원시함수값을 뺍니다.", "F(b)-F(a)를 계산하세요.", calculusVisual("fundamental", { a, b }))
        ];
      }
      function areaProblems() {
        const width = randomInteger(2, 7);
        const height = randomInteger(1, 6);
        const left = randomInteger(-4, 1);
        const right = left + width;
        const scale = randomInteger(1, 4);
        const root = randomInteger(1, 4);
        const parabolaArea = 4 / 3 * scale * root ** 3;
        return [
          sa(`구간 [${left},${right}]에서 함수 y=${height}와 x축 사이의 넓이는?`, width * height, "직사각형의 가로×세로입니다.", "함수가 x축 위에 있으므로 정적분과 넓이가 같습니다.", calculusVisual("area", { left, right, height })),
          sa(`구간 [${left},${right}]에서 함수 y=-${height}와 x축 사이의 실제 넓이는?`, width * height, "정적분은 음수지만 실제 넓이는 절댓값을 취합니다.", "x축 아래 영역도 넓이는 양수입니다.", calculusVisual("area", { left, right, height: -height })),
          sa(`${inlineMath(`y=${scale * 2}x`)}와 x축, x=${width}로 둘러싸인 삼각형의 넓이는?`, scale * width ** 2, `밑변 ${width}, 높이 ${2 * scale * width}인 삼각형 넓이입니다.`, "1/2×밑변×높이를 사용하세요.", calculusVisual("area", { slope: 2 * scale, left: 0, right: width })),
          sa(`${inlineMath(`y=${scale}(${root ** 2}-x^2)`)}와 x축 사이에서 -${root}≤x≤${root}인 넓이는?`, round4(parabolaArea), `${inlineMath(`\\int_{-${root}}^{${root}}${scale}(${root ** 2}-x^2)dx=${round4(parabolaArea)}`)}입니다.`, `짝함수의 대칭을 이용해 0부터 ${root}까지 적분한 값의 2배를 구하세요.`, calculusVisual("area", { scale, roots: [-root, root] })),
          mc(`두 곡선 사이 넓이를 구하는 기본 적분식은?`, ["∫(위 함수-아래 함수)dx", "∫(아래 함수-위 함수)dx를 그대로 사용", "두 함수의 곱", "두 도함수의 합"], 0, "각 구간에서 위 함수값에서 아래 함수값을 빼야 넓이가 양수가 됩니다.", "그래프의 위아래를 먼저 판정하세요.", calculusVisual("area")),
          sa(`두 곡선의 차가 구간 [${left},${right}]에서 항상 ${height}일 때 두 곡선 사이 넓이는?`, width * height, "세로 간격이 일정한 직사각형 영역입니다.", "함수 차×구간 길이입니다.", calculusVisual("area", { left, right, gap: height })),
          mc(`두 곡선의 위아래가 바뀌는 지점에서 해야 할 일은?`, ["적분 구간을 나누고 각 구간에서 위-아래를 다시 정한다.", "그 지점을 무시한다.", "전체 적분에 -1만 곱한다.", "도함수를 적분하지 않는다."], 0, "교점은 함수 차의 부호가 바뀔 수 있는 경계입니다.", "절댓값 적분을 구간별로 계산하세요.", calculusVisual("area", { crossing: true })),
          sa(`${inlineMath(`\\int_{${left}}^{${right}}f(x)dx=-${width * height}`)}이고 f≤0일 때 그래프와 x축 사이의 넓이는?`, width * height, "함수가 x축 아래에 있으므로 실제 넓이는 정적분의 절댓값입니다.", "음의 정적분에 -를 붙이세요.", calculusVisual("area", { left, right, integral: -width * height })),
          sa(`밑변 길이가 ${width}, 높이가 ${height}인 삼각형 영역의 넓이는?`, width * height / 2, "삼각형 넓이는 1/2×밑변×높이입니다.", "선형함수 아래 넓이를 기하적으로 보세요.", calculusVisual("area", { width, height, triangle: true })),
          mc(`정적분값과 실제 넓이가 항상 같지 않은 이유는?`, ["x축 아래 영역을 정적분은 음수로 세기 때문이다.", "넓이는 음수가 될 수 있기 때문이다.", "정적분에는 구간이 없기 때문이다.", "함수는 항상 불연속이기 때문이다."], 0, "정적분은 부호 있는 누적량이고 넓이는 음수가 아닙니다.", "x축 아래 영역을 비교하세요.", calculusVisual("area", { belowAxis: true }))
        ];
      }
      function velocityDistanceProblems() {
        const zero = randomInteger(1, 5);
        const scale = randomInteger(1, 4);
        const end = zero + randomInteger(1, 5);
        const initialPosition = randomInteger(-10, 10);
        const displacement = scale / 2 * (end ** 2 - 2 * zero * end);
        const distance = scale / 2 * zero ** 2 + scale / 2 * (end - zero) ** 2;
        return [
          sa(`속도 ${inlineMath(`v(t)=${scale}(t-${zero})`)}일 때 t=${zero}에서 속도는?`, 0, `${inlineMath(`v(${zero})=0`)}이므로 그 순간 정지합니다.`, "속도식에 시간을 대입하세요.", calculusVisual("velocity-area", { zero, scale })),
          sa(`속도 ${inlineMath(`v(t)=${scale}(t-${zero})`)}일 때 0≤t≤${end}의 변위는?`, round4(displacement), `${inlineMath(`\\int_0^{${end}}${scale}(t-${zero})dt=${round4(displacement)}`)}입니다.`, "변위는 속도의 부호 있는 적분입니다.", calculusVisual("velocity-area", { zero, scale, end })),
          sa(`같은 운동에서 0≤t≤${end}의 이동거리는?`, round4(distance), `${inlineMath(`t=${zero}`)}에서 방향이 바뀌므로 음의 넓이와 양의 넓이의 크기를 더합니다.`, "속도가 0인 시각에서 구간을 나누어 속력의 넓이를 더하세요.", calculusVisual("velocity-area", { zero, scale, end, absolute: true })),
          sa(`초기 위치가 ${initialPosition}이고 변위가 ${round4(displacement)}일 때 마지막 위치는?`, round4(initialPosition + displacement), "마지막 위치=초기 위치+변위입니다.", "이동거리 대신 부호 있는 변위를 더하세요.", calculusVisual("velocity-area", { initialPosition, displacement })),
          mc(`속도를 적분해 얻는 것은?`, ["변위", "항상 이동거리", "가속도", "속력의 최댓값"], 0, "속도의 부호 있는 넓이는 위치의 변화량인 변위입니다.", "위치와 속도의 미분·적분 관계를 떠올리세요.", calculusVisual("velocity-area")),
          mc(`이동거리를 구할 때 적분해야 하는 것은?`, ["|v(t)|", "v′(t)", "s′′(t)만", "v(t)의 부호를 무시한 원시함수"], 0, "방향과 관계없이 이동한 길이를 더하려면 속력 |v|를 적분합니다.", "음의 속도 구간도 양의 길이로 세세요.", calculusVisual("velocity-area", { absolute: true })),
          sa(`0≤t≤${zero}에서 속도가 항상 -${scale}일 때 이동거리는?`, scale * zero, `속력은 ${scale}이고 시간은 ${zero}이므로 거리=속력×시간입니다.`, "음의 부호는 방향일 뿐 거리에는 절댓값을 씁니다.", calculusVisual("velocity-area", { velocity: -scale, end: zero })),
          sa(`0≤t≤${end}에서 속도가 항상 ${scale}일 때 변위는?`, scale * end, "일정한 속도의 변위는 속도×시간입니다.", "속도 그래프 아래 직사각형 넓이입니다.", calculusVisual("velocity-area", { velocity: scale, end })),
          mc(`변위가 0인데 이동거리는 양수일 수 있는 상황은?`, ["출발점에서 움직였다가 다시 돌아온 경우", "전혀 움직이지 않은 경우만", "속도가 항상 양수인 경우", "시간이 0인 경우"], 0, "서로 반대 방향의 변위가 상쇄되어도 이동한 길이는 남습니다.", "부호 있는 합과 절댓값 합을 비교하세요.", calculusVisual("velocity-area", { returnTrip: true })),
          sa(`위치 변화량이 ${round4(displacement)}이고 초기 위치가 ${initialPosition}일 때 최종 위치는?`, round4(initialPosition + displacement), "초기 위치에 변위를 더합니다.", "변위에는 방향을 나타내는 부호가 포함됩니다.", calculusVisual("velocity-area", { initialPosition, displacement }))
        ];
      }
      var definitions = [
        ["differentiation", "calculus-1-02-01", "미분계수", derivativeCoefficientProblems],
        ["differentiation", "calculus-1-02-02", "미분가능성과 연속성", differentiabilityProblems],
        ["differentiation", "calculus-1-02-03", "거듭제곱함수의 도함수", powerDerivativeProblems],
        ["differentiation", "calculus-1-02-04", "다항함수의 미분법", polynomialDerivativeProblems],
        ["differentiation", "calculus-1-02-05", "접선의 방정식", tangentProblems],
        ["differentiation", "calculus-1-02-06", "평균값 정리", meanValueProblems],
        ["differentiation", "calculus-1-02-07", "함수의 증가·감소와 극값", extremaProblems],
        ["differentiation", "calculus-1-02-08", "함수 그래프의 개형", graphShapeProblems],
        ["differentiation", "calculus-1-02-09", "미분과 방정식·부등식", equationInequalityProblems],
        ["differentiation", "calculus-1-02-10", "속도와 가속도", motionProblems],
        ["integration", "calculus-1-03-01", "부정적분", indefiniteIntegralProblems],
        ["integration", "calculus-1-03-02", "다항함수의 부정적분", polynomialIntegralProblems],
        ["integration", "calculus-1-03-03", "정적분의 개념과 성질", definiteIntegralConceptProblems],
        ["integration", "calculus-1-03-04", "부정적분과 정적분의 관계", fundamentalTheoremProblems],
        ["integration", "calculus-1-03-05", "정적분과 넓이", areaProblems],
        ["integration", "calculus-1-03-06", "적분과 속도·거리", velocityDistanceProblems]
      ];
      var generators = definitions.map(
        ([unitId, conceptId, title, buildProblems]) => ({
          key: conceptId,
          courseId: "calculus-1",
          unitId,
          conceptId,
          requiredDistinctTypes: 5,
          problemTypes: Array.from(
            { length: 10 },
            (_, index) => ({
              id: `${conceptId}-type-${String(
                index + 1
              ).padStart(2, "0")}`,
              label: `유형 ${index + 1} · ${title}`,
              difficulty: index < 3 ? 1 : index < 7 ? 2 : 3,
              generate() {
                const generated = buildProblems()[index];
                if (!generated) {
                  throw new Error(
                    `${conceptId}의 ${index + 1}번 문제 유형이 없습니다.`
                  );
                }
                return {
                  ...generated,
                  validityChecks: [
                    {
                      name: "calculus-answer",
                      passed: generated.answer !== void 0 && generated.answer !== null && String(
                        generated.answer
                      ).trim() !== "",
                      message: "정답이 비어 있습니다."
                    }
                  ]
                };
              }
            })
          ),
          isCorrectAnswer
        })
      );
      var generatorMap = new Map(
        generators.map((generator) => [
          [
            generator.courseId,
            generator.unitId,
            generator.conceptId
          ].join("/"),
          generator
        ])
      );
      module.exports = {
        generators,
        generatorMap
      };
    }
  });

  // services/problemGenerators/algebra/helpers.js
  var require_helpers2 = __commonJS({
    "services/problemGenerators/algebra/helpers.js"(exports, module) {
      var {
        randomInteger,
        nonZeroInteger,
        isCorrectAnswer
      } = require_utils();
      var {
        formatAlgebraMathText
      } = require_mathTextService();
      function round4(value) {
        return Number(Number(value).toFixed(4));
      }
      function iterate(firstTerm, step, targetIndex) {
        let value = firstTerm;
        for (let index = 1; index < targetIndex; index += 1) {
          value = step(value, index);
        }
        return value;
      }
      var GRAPH_CONCEPT_IDS = /* @__PURE__ */ new Set([
        "algebra-01-04",
        "algebra-01-06",
        "algebra-01-07",
        "algebra-01-08",
        "algebra-02-02",
        "algebra-03-01",
        "algebra-03-02",
        "algebra-03-03",
        "algebra-03-06"
      ]);
      function normalizeGraphPrompt(value) {
        const subscriptDigits = {
          "₀": "0",
          "₁": "1",
          "₂": "2",
          "₃": "3",
          "₄": "4",
          "₅": "5",
          "₆": "6",
          "₇": "7",
          "₈": "8",
          "₉": "9"
        };
        return String(value || "").replace(/−/g, "-").replace(/[₀-₉]/g, (digit) => subscriptDigits[digit]).replace(/\s+/g, " ").trim();
      }
      function matchedNumber(text, pattern, fallback = null) {
        const match = text.match(pattern);
        const value = match ? Number(match[1]) : Number.NaN;
        return Number.isFinite(value) ? value : fallback;
      }
      function finiteAnswer(generated, fallback = null) {
        const value = Number(generated.answer);
        return Number.isFinite(value) ? value : fallback;
      }
      function expLogVisualization({
        conceptId,
        typeId,
        generated,
        text
      }) {
        const fractionBase = matchedNumber(
          text,
          /\(1\/(\d+(?:\.\d+)?)\)\^/
        );
        const logBase = matchedNumber(text, /log_(\d+(?:\.\d+)?)/);
        const exponentialBase = matchedNumber(
          text,
          /(?:^|[=\s])(\d+(?:\.\d+)?)\^\(?x/
        );
        const base = fractionBase ? 1 / fractionBase : logBase || exponentialBase || 2;
        const answer = finiteAnswer(generated);
        const isLog = text.includes("log");
        const isInverse = typeId === "inverse-relation" || typeId === "symmetry-yx" || typeId === "log-inverse";
        const functionType = isInverse ? "both" : isLog ? "log" : "exp";
        const minusShift = matchedNumber(
          text,
          /log_[^( ]+\s*\(x\s*-\s*(-?\d+(?:\.\d+)?)/
        );
        const plusShift = matchedNumber(
          text,
          /log_[^( ]+\s*\(x\s*\+\s*(\d+(?:\.\d+)?)/
        );
        const shiftX = minusShift !== null ? minusShift : plusShift !== null ? -plusShift : 0;
        const expShift = matchedNumber(
          text,
          /\^x\s*\+\s*(-?\d+(?:\.\d+)?)/
        );
        const expMinusShift = matchedNumber(
          text,
          /\^x\s*-\s*(\d+(?:\.\d+)?)/
        );
        const exponentOffset = matchedNumber(
          text,
          /\^\(x\s*\+\s*(-?\d+(?:\.\d+)?)\)/
        ) ?? 0;
        const shiftY = expShift !== null ? expShift : expMinusShift !== null ? -expMinusShift : 0;
        let focusX = functionType === "log" ? shiftX + 1 : 0;
        let targetY = null;
        let inequality = null;
        const functionInput = matchedNumber(
          text,
          /[fg]\((-?\d+(?:\.\d+)?)\)/
        );
        const interval = text.match(
          /(-?\d+(?:\.\d+)?)≤x≤(-?\d+(?:\.\d+)?)/
        );
        const point = text.match(
          /\((-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)\)/
        );
        const logArgument = matchedNumber(
          text,
          /log_\d+(?:\.\d+)?\s+(\d+(?:\.\d+)?)/
        );
        if (functionInput !== null) {
          focusX = functionInput;
        } else if (interval) {
          const left = Number(interval[1]);
          const right = Number(interval[2]);
          const asksMaximum = text.includes("최댓값") || text.includes("최대");
          focusX = asksMaximum ? right : left;
        } else if (point) {
          focusX = Number(point[1]);
        } else if ([
          "exp-equation",
          "exp-equation-base",
          "exp-inequality",
          "exp-eq-two",
          "exp-solve"
        ].includes(typeId) && answer !== null) {
          focusX = answer;
        } else if (typeId === "exp-sub" && answer !== null) {
          focusX = Math.log(Math.max(answer, 1e-4)) / Math.log(base);
        } else if ([
          "log-eq-def",
          "log-equation",
          "log-inequality",
          "log-eq-two"
        ].includes(typeId) && answer !== null) {
          focusX = answer;
        } else if (logArgument !== null) {
          focusX = logArgument;
        } else if (typeId === "compound-growth") {
          focusX = matchedNumber(text, /(\d+)기간/, 1);
        } else if (typeId === "log-scale") {
          focusX = matchedNumber(
            text,
            /x=(-?\d+(?:\.\d+)?)/,
            shiftX + 1
          );
        }
        if ([
          "exp-equation",
          "exp-equation-base",
          "exp-inequality",
          "exp-eq-two",
          "exp-solve"
        ].includes(typeId)) {
          targetY = base ** (focusX + exponentOffset) + shiftY;
        } else if (typeId === "exp-sub") {
          targetY = answer;
        } else if ([
          "log-eq-def",
          "log-equation",
          "log-inequality",
          "log-eq-two"
        ].includes(typeId)) {
          const argument = Math.max(1e-4, focusX - shiftX);
          targetY = Math.log(argument) / Math.log(base);
        }
        if (typeId.includes("inequality")) {
          if (text.includes(">")) inequality = "greater";
          if (text.includes("<")) inequality = "less";
        }
        return {
          kind: "algebra-exp-log",
          conceptId,
          typeId,
          functionType,
          base,
          shiftX,
          shiftY,
          exponentOffset,
          focusX,
          targetY,
          inequality,
          focusFunction: isLog ? "log" : "exp",
          reflectY: typeId === "reflect-exp",
          showInverseLine: isInverse,
          note: inequality ? "교점의 양쪽에서 두 그래프의 높이를 비교하세요." : isInverse ? "지수함수와 로그함수의 대응점은 y=x에 대해 대칭입니다." : "표시한 점과 점근선을 문제의 식과 함께 확인하세요."
        };
      }
      function trigVisualization({
        conceptId,
        typeId,
        generated,
        text
      }) {
        const functionName = text.match(/\b(sin|cos|tan)\b/)?.[1] || "sin";
        const quadrant = matchedNumber(text, /제(\d)사분면/);
        const degree = matchedNumber(
          text,
          /(?:sin|cos|tan)\s*(\d+(?:\.\d+)?)°/
        );
        const amplitude = matchedNumber(text, /y=(-?\d+(?:\.\d+)?)sin/, 1);
        const frequency = matchedNumber(text, /sin\((\d+(?:\.\d+)?)x\)/, 1);
        const verticalShift = matchedNumber(
          text,
          /sin x\s*\+\s*(-?\d+(?:\.\d+)?)/,
          0
        );
        const answer = finiteAnswer(generated);
        let focusDegree = degree !== null ? degree : quadrant !== null ? [45, 135, 225, 315][quadrant - 1] : 90;
        if (typeId === "simple-equation" && answer !== null) {
          focusDegree = answer;
        } else if (typeId === "graph-min") {
          focusDegree = 270 / frequency;
        } else if (typeId === "graph-max") {
          focusDegree = 90 / frequency;
        }
        return {
          kind: "algebra-trig",
          conceptId,
          typeId,
          functionName,
          amplitude,
          frequency,
          verticalShift,
          focusDegree,
          note: typeId === "quadrant-sign" ? "표시점이 어느 사분면에 있는지 보고 좌표의 부호를 확인하세요." : "표시한 각에서 그래프의 높이가 삼각함수 값입니다."
        };
      }
      function sequenceBasicsValues(typeId, text, answer) {
        let count = Math.max(
          6,
          matchedNumber(text, /a_(\d+)/, 6)
        );
        count = Math.min(10, count);
        let evaluate = (n) => 2 * n + 1;
        const linear = text.match(
          /a_n=(-?\d+(?:\.\d+)?)n\+(-?\d+(?:\.\d+)?)/
        );
        if (linear) {
          const coefficient = Number(linear[1]);
          const constant = Number(linear[2]);
          evaluate = (n) => coefficient * n + constant;
        } else if (text.includes("a_n=n²")) {
          evaluate = (n) => n * n;
        } else if (text.includes("a_n=n(n+1)")) {
          evaluate = (n) => n * (n + 1);
        } else if (text.includes("(-1)ⁿ") || text.includes("(−1)ⁿ")) {
          evaluate = (n) => (n % 2 ? -1 : 1) * n;
        } else if (text.includes("a_n=2ⁿ")) {
          evaluate = (n) => 2 ** n;
        } else if (typeId === "an-from-Sn") {
          evaluate = (n) => 2 * n - 1;
        } else if (typeId === "next-term-pattern") {
          const listed = text.match(/수열\s+([^.]*)\.\.\./)?.[1]?.match(/-?\d+(?:\.\d+)?/g)?.map(Number);
          if (Array.isArray(listed) && listed.length >= 3) {
            return [
              ...listed.slice(0, 4),
              answer
            ].filter(Number.isFinite);
          }
        }
        return Array.from(
          { length: count },
          (_, index) => evaluate(index + 1)
        );
      }
      function arithmeticValues(typeId, text, answer) {
        let first = matchedNumber(text, /첫째항 (-?\d+(?:\.\d+)?)/);
        let difference = matchedNumber(text, /공차 (-?\d+(?:\.\d+)?)/);
        let count = Math.max(
          6,
          matchedNumber(text, /제(\d+)항/, 6),
          matchedNumber(text, /a_(\d+)/, 6)
        );
        const firstTwo = text.match(
          /a1=(-?\d+(?:\.\d+)?), a2=(-?\d+(?:\.\d+)?)/
        );
        const twoTerms = text.match(
          /a_(\d+)=(-?\d+(?:\.\d+)?), a_(\d+)=(-?\d+(?:\.\d+)?)/
        );
        const endpoints = text.match(
          /첫째항 (-?\d+(?:\.\d+)?), 제(\d+)항 (-?\d+(?:\.\d+)?)/
        );
        const knownTerm = text.match(
          /공차 (-?\d+(?:\.\d+)?) 인 등차수열에서 a_(\d+)=(-?\d+(?:\.\d+)?)/
        );
        const three = text.match(
          /등차항이 (-?\d+(?:\.\d+)?), (-?\d+(?:\.\d+)?), (-?\d+(?:\.\d+)?)/
        );
        const mean = text.match(
          /세 수 (-?\d+(?:\.\d+)?), x, (-?\d+(?:\.\d+)?)/
        );
        if (firstTwo) {
          first = Number(firstTwo[1]);
          difference = Number(firstTwo[2]) - first;
        } else if (twoTerms) {
          const firstIndex = Number(twoTerms[1]);
          const firstValue = Number(twoTerms[2]);
          const secondIndex = Number(twoTerms[3]);
          const secondValue = Number(twoTerms[4]);
          difference = (secondValue - firstValue) / (secondIndex - firstIndex);
          first = firstValue - (firstIndex - 1) * difference;
          count = Math.max(count, secondIndex);
        } else if (endpoints) {
          first = Number(endpoints[1]);
          count = Number(endpoints[2]);
          difference = (Number(endpoints[3]) - first) / Math.max(1, count - 1);
        } else if (knownTerm) {
          difference = Number(knownTerm[1]);
          count = Math.max(count, Number(knownTerm[2]));
          first = Number(knownTerm[3]) - (Number(knownTerm[2]) - 1) * difference;
        } else if (three) {
          return [
            Number(three[1]),
            Number(three[2]),
            Number(three[3])
          ];
        } else if (mean) {
          return [
            Number(mean[1]),
            answer,
            Number(mean[2])
          ];
        }
        first = first ?? 2;
        difference = difference ?? 2;
        count = Math.min(10, count);
        return Array.from(
          { length: count },
          (_, index) => first + index * difference
        );
      }
      function geometricValues(typeId, text, answer) {
        let first = matchedNumber(text, /첫째항 (-?\d+(?:\.\d+)?)/);
        let ratio = matchedNumber(text, /공비 (-?\d+(?:\.\d+)?)/);
        let count = Math.max(
          6,
          matchedNumber(text, /제(\d+)항/, 6),
          matchedNumber(text, /a_(\d+)/, 6)
        );
        const firstTwo = text.match(
          /a1=(-?\d+(?:\.\d+)?), a2=(-?\d+(?:\.\d+)?)/
        );
        const thirdTerm = text.match(
          /a1=(-?\d+(?:\.\d+)?), a3=(-?\d+(?:\.\d+)?)/
        );
        const knownTerm = text.match(
          /공비 (-?\d+(?:\.\d+)?) 인 등비수열에서 a_(\d+)=(-?\d+(?:\.\d+)?)/
        );
        const secondTerm = text.match(
          /공비 (-?\d+(?:\.\d+)?) 인 등비수열에서 a2=(-?\d+(?:\.\d+)?)/
        );
        const three = text.match(
          /등비항이 (-?\d+(?:\.\d+)?), (-?\d+(?:\.\d+)?), (-?\d+(?:\.\d+)?)/
        );
        const mean = text.match(
          /세 양수 1, x, (\d+(?:\.\d+)?)/
        );
        if (firstTwo) {
          first = Number(firstTwo[1]);
          ratio = Number(firstTwo[2]) / first;
        } else if (thirdTerm) {
          first = Number(thirdTerm[1]);
          ratio = Math.sqrt(
            Number(thirdTerm[2]) / first
          );
        } else if (knownTerm) {
          ratio = Number(knownTerm[1]);
          count = Math.max(count, Number(knownTerm[2]));
          first = Number(knownTerm[3]) / ratio ** (Number(knownTerm[2]) - 1);
        } else if (secondTerm) {
          ratio = Number(secondTerm[1]);
          first = Number(secondTerm[2]) / ratio;
        } else if (three) {
          return [
            Number(three[1]),
            Number(three[2]),
            Number(three[3])
          ];
        } else if (mean) {
          return [1, answer, Number(mean[1])];
        }
        first = first ?? 1;
        ratio = ratio ?? 2;
        count = Math.min(9, count);
        return Array.from(
          { length: count },
          (_, index) => first * ratio ** index
        );
      }
      function recursiveValues(typeId, text) {
        const first = matchedNumber(text, /a1=(-?\d+(?:\.\d+)?)/, 1);
        const second = matchedNumber(text, /a2=(-?\d+(?:\.\d+)?)/);
        const targetIndices = Array.from(
          text.matchAll(/a(\d+)/g),
          (match) => Number(match[1])
        );
        const count = Math.min(
          9,
          Math.max(6, ...targetIndices)
        );
        const values = [first];
        if (typeId === "rec-fib") {
          values.push(second ?? 1);
          while (values.length < count) {
            values.push(
              values[values.length - 1] + values[values.length - 2]
            );
          }
          return values;
        }
        const additive = matchedNumber(
          text,
          /a_\{n\+1\}=a_n\+(-?\d+(?:\.\d+)?)/
        );
        const multiplier = matchedNumber(
          text,
          /a_\{n\+1\}=(-?\d+(?:\.\d+)?)·?a_n/
        );
        while (values.length < count) {
          const n = values.length;
          const previous = values[values.length - 1];
          let next;
          if (typeId === "rec-add-n") {
            next = previous + 2 * n;
          } else if (typeId === "rec-affine") {
            next = 2 * previous + 1;
          } else if (typeId === "rec-half") {
            next = previous / 2;
          } else if (typeId === "rec-add-nsq") {
            next = previous + n * n;
          } else if (typeId === "rec-known-two") {
            next = values.length === 1 && second !== null ? second : previous + ((second ?? first + 1) - first);
          } else if (multiplier !== null) {
            next = previous * multiplier;
          } else {
            next = previous + (additive ?? 2);
          }
          values.push(next);
        }
        return values;
      }
      function sequenceVisualization({
        conceptId,
        typeId,
        generated,
        text
      }) {
        const answer = finiteAnswer(generated);
        let values;
        if (conceptId === "algebra-03-01") {
          values = sequenceBasicsValues(typeId, text, answer);
        } else if (conceptId === "algebra-03-02") {
          values = arithmeticValues(typeId, text, answer);
        } else if (conceptId === "algebra-03-03") {
          values = geometricValues(typeId, text, answer);
        } else {
          values = recursiveValues(typeId, text);
        }
        const explicitIndices = Array.from(
          text.matchAll(/a_?(\d+)/g),
          (match) => Number(match[1])
        ).filter(Number.isFinite);
        const requestedIndex = explicitIndices.length ? Math.max(...explicitIndices) : values.length;
        return {
          kind: "algebra-sequence",
          conceptId,
          typeId,
          values: values.map(Number).filter(Number.isFinite).slice(0, 10),
          focusIndex: Math.min(
            values.length,
            Math.max(1, requestedIndex)
          ),
          note: conceptId === "algebra-03-02" ? "점 사이의 세로 변화량이 일정한지 확인하세요." : conceptId === "algebra-03-03" ? "앞 항에서 다음 항으로 갈 때의 비율을 확인하세요." : conceptId === "algebra-03-06" ? "앞 항에서 같은 규칙을 적용해 다음 항을 만듭니다." : "수열은 자연수 위치에 찍힌 점들의 모임입니다."
        };
      }
      function buildAlgebraGraphVisualization({
        conceptId,
        typeId,
        generated
      }) {
        if (!GRAPH_CONCEPT_IDS.has(conceptId)) {
          return {
            kind: "algebra-concept",
            conceptId,
            typeId
          };
        }
        const text = normalizeGraphPrompt(
          generated.prompt
        );
        if (conceptId.startsWith("algebra-01-")) {
          return expLogVisualization({
            conceptId,
            typeId,
            generated,
            text
          });
        }
        if (conceptId === "algebra-02-02") {
          return trigVisualization({
            conceptId,
            typeId,
            generated,
            text
          });
        }
        return sequenceVisualization({
          conceptId,
          typeId,
          generated,
          text
        });
      }
      function createAlgebraProblemType(problemType, { conceptId, conceptTitle }) {
        return {
          ...problemType,
          generate() {
            const generated = problemType.generate();
            const typeTitle = problemType.label.replace(
              /^유형\s*\d+\s*·\s*/,
              ""
            );
            return {
              ...generated,
              prompt: formatAlgebraMathText(
                generated.prompt
              ),
              solution: formatAlgebraMathText(
                generated.solution
              ),
              choices: Array.isArray(
                generated.choices
              ) ? generated.choices.map(
                (choice) => ({
                  ...choice,
                  text: formatAlgebraMathText(
                    choice.text
                  )
                })
              ) : generated.choices,
              hintText: formatAlgebraMathText(
                generated.hintText || (generated.inputMode === "multiple-choice" ? `${conceptTitle}의 정의와 조건을 먼저 확인한 뒤 각 선택지를 비교해보세요.` : `문제에 주어진 수와 기호를 ${typeTitle}의 관계식에 표시한 뒤, 한 줄에 한 단계씩 정리해보세요.`)
              ),
              visualization: generated.visualization || {
                ...buildAlgebraGraphVisualization({
                  conceptId,
                  typeId: problemType.id,
                  generated
                }),
                difficulty: problemType.difficulty || 1
              },
              validityChecks: [
                ...generated.validityChecks || [],
                {
                  name: "algebra-generated-answer",
                  passed: generated.answer !== void 0 && generated.answer !== null && String(generated.answer).trim() !== "",
                  message: "생성된 문제의 정답이 비어 있습니다."
                }
              ]
            };
          }
        };
      }
      module.exports = {
        randomInteger,
        nonZeroInteger,
        round4,
        iterate,
        isCorrectAnswer,
        buildAlgebraGraphVisualization,
        createAlgebraProblemType
      };
    }
  });

  // services/problemGenerators/algebra/powersAndRoots.js
  var require_powersAndRoots = __commonJS({
    "services/problemGenerators/algebra/powersAndRoots.js"(exports, module) {
      var {
        randomInteger,
        nonZeroInteger,
        round4,
        isCorrectAnswer,
        createAlgebraProblemType
      } = require_helpers2();
      var problemTypes = [
        {
          id: "nth-root-value",
          label: "유형 1 · 거듭제곱근의 값",
          difficulty: 1,
          generate() {
            const b = randomInteger(2, 5), n = randomInteger(2, 3), v = b ** n;
            return {
              prompt: `${n}제곱근 ${v} 의 값(양의 실수)을 구하세요.`,
              inputMode: "short-answer",
              answer: b,
              solution: `${v}=${b}^${n} 이므로 값은 ${b}.`
            };
          }
        },
        {
          id: "root-product",
          label: "유형 2 · 거듭제곱근의 곱",
          difficulty: 2,
          generate() {
            const m = randomInteger(2, 6), k = randomInteger(2, 6);
            return {
              prompt: `√${m * m} × √${k * k} 의 값을 구하세요.`,
              inputMode: "short-answer",
              answer: m * k,
              solution: `√${m * m}=${m}, √${k * k}=${k} → ${m}×${k}=${m * k}.`
            };
          }
        },
        {
          id: "root-quotient",
          label: "유형 3 · 거듭제곱근의 나눗셈",
          difficulty: 2,
          generate() {
            const m = randomInteger(2, 6), k = randomInteger(2, 5), a = (m * k) ** 2, b = k * k;
            return {
              prompt: `√${a} ÷ √${b} 의 값을 구하세요.`,
              inputMode: "short-answer",
              answer: m,
              solution: `√${a}/√${b}=√(${a}/${b})=√${m * m}=${m}.`
            };
          }
        },
        {
          id: "root-power",
          label: "유형 4 · 거듭제곱근의 거듭제곱",
          difficulty: 2,
          generate() {
            const b = randomInteger(2, 4), m = randomInteger(2, 3), a = b ** 3;
            return {
              prompt: `(∛${a})^${m} 의 값을 구하세요.`,
              inputMode: "short-answer",
              answer: b ** m,
              solution: `∛${a}=${b} 이므로 ${b}^${m}=${b ** m}.`
            };
          }
        },
        {
          id: "root-of-root",
          label: "유형 5 · 이중근호",
          difficulty: 3,
          generate() {
            const b = randomInteger(2, 3), a = b ** 6;
            return {
              prompt: `√(∛${a}) 의 값을 구하세요.`,
              inputMode: "short-answer",
              answer: b,
              solution: `√(∛${a})=${a}^(1/6)=${b}.`
            };
          }
        },
        {
          id: "exp-to-root",
          label: "유형 6 · 지수↔거듭제곱근",
          difficulty: 1,
          generate() {
            const b = randomInteger(2, 5), n = randomInteger(2, 3), a = b ** n;
            return {
              prompt: `${a}^(1/${n}) 의 값을 구하세요.`,
              inputMode: "short-answer",
              answer: b,
              solution: `${a}^(1/${n})=${n}제곱근 ${a}=${b}.`
            };
          }
        },
        {
          id: "count-real-roots",
          label: "유형 7 · 실수인 거듭제곱근의 개수",
          difficulty: 2,
          generate() {
            const n = randomInteger(2, 5), even = n % 2 === 0;
            return {
              prompt: `양수 a 의 실수인 ${n}제곱근의 개수를 구하세요.`,
              inputMode: "short-answer",
              answer: even ? 2 : 1,
              solution: even ? `n이 짝수이고 a>0이면 실수인 거듭제곱근은 2개.` : `n이 홀수이면 실수인 거듭제곱근은 1개.`
            };
          }
        },
        {
          id: "root-compare",
          label: "유형 8 · 거듭제곱근의 대소",
          difficulty: 2,
          generate() {
            const a = randomInteger(2, 5);
            return {
              prompt: `a=${a}(>1) 일 때 √a 와 ∛a 중 더 큰 값은?`,
              inputMode: "multiple-choice",
              choices: [{ key: "sqrt", text: "√a" }, { key: "cbrt", text: "∛a" }],
              answer: "sqrt",
              solution: `a>1이면 지수 1/2 > 1/3 이므로 √a가 더 큽니다.`
            };
          }
        },
        {
          id: "cube-root",
          label: "유형 9 · 세제곱근 계산",
          difficulty: 1,
          generate() {
            const b = randomInteger(2, 6), a = b ** 3;
            return {
              prompt: `∛${a} 의 값을 구하세요.`,
              inputMode: "short-answer",
              answer: b,
              solution: `${b}³=${a} 이므로 ∛${a}=${b}.`
            };
          }
        },
        {
          id: "root-combined",
          label: "유형 10 · 거듭제곱근 종합",
          difficulty: 3,
          generate() {
            const a = randomInteger(2, 4), b = randomInteger(2, 4);
            return {
              prompt: `∛(${a}³ × ${b}³) 의 값을 구하세요.`,
              inputMode: "short-answer",
              answer: a * b,
              solution: `∛(${a}³×${b}³)=${a}×${b}=${a * b}.`
            };
          }
        }
      ].map(
        (problemType) => createAlgebraProblemType(problemType, {
          conceptId: "algebra-01-01",
          conceptTitle: "거듭제곱과 거듭제곱근"
        })
      );
      module.exports = {
        key: "algebra-powers-and-roots",
        requiredDistinctTypes: 5,
        problemTypes,
        isCorrectAnswer
      };
    }
  });

  // services/problemGenerators/algebra/rationalAndRealExponents.js
  var require_rationalAndRealExponents = __commonJS({
    "services/problemGenerators/algebra/rationalAndRealExponents.js"(exports, module) {
      var {
        randomInteger,
        nonZeroInteger,
        round4,
        isCorrectAnswer,
        createAlgebraProblemType
      } = require_helpers2();
      var problemTypes = [
        {
          id: "rational-exp",
          label: "유형 1 · 유리수 지수의 값",
          difficulty: 2,
          generate() {
            const b = randomInteger(2, 3), n = randomInteger(2, 3), m = randomInteger(1, 2), a = b ** n;
            return {
              prompt: `${a}^(${m}/${n}) 의 값을 구하세요.`,
              inputMode: "short-answer",
              answer: b ** m,
              solution: `${a}=${b}^${n} → (${b}^${n})^(${m}/${n})=${b}^${m}=${b ** m}.`
            };
          }
        },
        {
          id: "negative-exp",
          label: "유형 2 · 음의 지수",
          difficulty: 1,
          generate() {
            const b = randomInteger(2, 5), n = randomInteger(1, 3);
            return {
              prompt: `${b}^(−${n}) 의 값을 구하세요. (소수로 입력)`,
              inputMode: "short-answer",
              answer: 1 / b ** n,
              solution: `${b}^(−${n})=1/${b ** n}=${(1 / b ** n).toFixed(4)}.`
            };
          }
        },
        {
          id: "rational-notation",
          label: "유형 3 · 유리수 지수 ↔ 근호 표현",
          difficulty: 2,
          generate() {
            const p = randomInteger(2, 3), q = randomInteger(2, 3);
            return {
              prompt: `a^(${p}/${q}) 를 근호로 바르게 나타낸 것은?`,
              inputMode: "multiple-choice",
              choices: [{ key: "ok", text: `${q}제곱근 (a^${p})` }, { key: "no", text: `${p}제곱근 (a^${q})` }],
              answer: "ok",
              solution: `a^(m/n)=n제곱근(a^m) 이므로 ${q}제곱근(a^${p}).`
            };
          }
        },
        {
          id: "product-rational",
          label: "유형 4 · 유리수 지수의 곱",
          difficulty: 2,
          generate() {
            const b = randomInteger(2, 4), a = b ** 2;
            return {
              prompt: `${a}^(1/2) × ${a}^(1/2) 의 값을 구하세요.`,
              inputMode: "short-answer",
              answer: a,
              solution: `지수를 더하면 ${a}^1=${a}.`
            };
          }
        },
        {
          id: "power-of-power",
          label: "유형 5 · 유리수 지수의 거듭제곱",
          difficulty: 2,
          generate() {
            const b = randomInteger(2, 3), a = b ** 2;
            return {
              prompt: `(${a}^(1/2))^4 의 값을 구하세요.`,
              inputMode: "short-answer",
              answer: a ** 2,
              solution: `지수를 곱하면 ${a}^2=${a ** 2}.`
            };
          }
        },
        {
          id: "eighth",
          label: "유형 6 · 유리수 지수 계산",
          difficulty: 2,
          generate() {
            const b = randomInteger(2, 3), n = randomInteger(2, 3), a = b ** n, m = randomInteger(2, 3);
            return {
              prompt: `${a}^(${m}/${n}) 의 값을 구하세요.`,
              inputMode: "short-answer",
              answer: b ** m,
              solution: `(${b}^${n})^(${m}/${n})=${b}^${m}=${b ** m}.`
            };
          }
        },
        {
          id: "reciprocal-neg",
          label: "유형 7 · (1/a)^(−n)",
          difficulty: 2,
          generate() {
            const a = randomInteger(2, 4), n = randomInteger(1, 3);
            return {
              prompt: `(1/${a})^(−${n}) 의 값을 구하세요.`,
              inputMode: "short-answer",
              answer: a ** n,
              solution: `(1/${a})^(−${n})=${a}^${n}=${a ** n}.`
            };
          }
        },
        {
          id: "compare-rational",
          label: "유형 8 · 유리수 지수 대소",
          difficulty: 2,
          generate() {
            const a = randomInteger(2, 4);
            return {
              prompt: `a=${a}(>1) 일 때 a^(2/3) 와 a^(1/2) 중 큰 값은?`,
              inputMode: "multiple-choice",
              choices: [{ key: "a", text: "a^(2/3)" }, { key: "b", text: "a^(1/2)" }],
              answer: "a",
              solution: `2/3 > 1/2 이고 밑>1 이므로 a^(2/3)가 큽니다.`
            };
          }
        },
        {
          id: "zero-exp",
          label: "유형 9 · 지수 0",
          difficulty: 1,
          generate() {
            const a = nonZeroInteger(2, 9);
            return {
              prompt: `${a}^0 의 값을 구하세요.`,
              inputMode: "short-answer",
              answer: 1,
              solution: `0이 아닌 수의 0제곱은 항상 1.`
            };
          }
        },
        {
          id: "root-exp-mix",
          label: "유형 10 · 근호·지수 혼합",
          difficulty: 3,
          generate() {
            const b = randomInteger(2, 3), a = b ** 6;
            return {
              prompt: `${a}^(1/6) × ${a}^(1/3) 의 값을 구하세요.`,
              inputMode: "short-answer",
              answer: b ** 3,
              solution: `지수합 1/6+1/3=1/2 → ${a}^(1/2)=${b ** 3}.`
            };
          }
        }
      ].map(
        (problemType) => createAlgebraProblemType(problemType, {
          conceptId: "algebra-01-02",
          conceptTitle: "유리수·실수 지수로의 확장"
        })
      );
      module.exports = {
        key: "algebra-rational-and-real-exponents",
        requiredDistinctTypes: 5,
        problemTypes,
        isCorrectAnswer
      };
    }
  });

  // services/problemGenerators/algebra/exponentLaws.js
  var require_exponentLaws = __commonJS({
    "services/problemGenerators/algebra/exponentLaws.js"(exports, module) {
      var {
        randomInteger,
        nonZeroInteger,
        round4,
        isCorrectAnswer,
        createAlgebraProblemType
      } = require_helpers2();
      var problemTypes = [
        {
          id: "law-mult",
          label: "유형 1 · 지수의 곱셈법칙",
          difficulty: 1,
          generate() {
            const b = randomInteger(2, 5), m = randomInteger(2, 5), n = randomInteger(2, 5);
            return {
              prompt: `${b}^${m} × ${b}^${n} = ${b}^k 일 때 k 를 구하세요.`,
              inputMode: "short-answer",
              answer: m + n,
              solution: `지수를 더함: ${m}+${n}=${m + n}.`
            };
          }
        },
        {
          id: "law-div",
          label: "유형 2 · 지수의 나눗셈법칙",
          difficulty: 1,
          generate() {
            const b = randomInteger(2, 5), m = randomInteger(4, 8), n = randomInteger(1, 3);
            return {
              prompt: `${b}^${m} ÷ ${b}^${n} = ${b}^k 일 때 k 를 구하세요.`,
              inputMode: "short-answer",
              answer: m - n,
              solution: `지수를 뺌: ${m}−${n}=${m - n}.`
            };
          }
        },
        {
          id: "law-power",
          label: "유형 3 · 지수의 거듭제곱법칙",
          difficulty: 1,
          generate() {
            const b = randomInteger(2, 4), m = randomInteger(2, 4), n = randomInteger(2, 4);
            return {
              prompt: `(${b}^${m})^${n} = ${b}^k 일 때 k 를 구하세요.`,
              inputMode: "short-answer",
              answer: m * n,
              solution: `지수를 곱함: ${m}×${n}=${m * n}.`
            };
          }
        },
        {
          id: "law-product-base",
          label: "유형 4 · 곱의 거듭제곱",
          difficulty: 2,
          generate() {
            const a = randomInteger(2, 3), b = randomInteger(2, 3), n = randomInteger(2, 3);
            return {
              prompt: `(${a}×${b})^${n} 의 값을 구하세요.`,
              inputMode: "short-answer",
              answer: (a * b) ** n,
              solution: `(${a}×${b})^${n}=${a}^${n}×${b}^${n}=${(a * b) ** n}.`
            };
          }
        },
        {
          id: "law-value",
          label: "유형 5 · 지수법칙 값 계산",
          difficulty: 2,
          generate() {
            const b = randomInteger(2, 3), m = randomInteger(1, 3), n = randomInteger(1, 3);
            return {
              prompt: `${b}^${m} × ${b}^${n} 의 값을 구하세요.`,
              inputMode: "short-answer",
              answer: b ** (m + n),
              solution: `${b}^${m + n}=${b ** (m + n)}.`
            };
          }
        },
        {
          id: "law-neg-combine",
          label: "유형 6 · 음의 지수 포함 계산",
          difficulty: 2,
          generate() {
            const b = randomInteger(2, 4), m = randomInteger(3, 6), n = randomInteger(1, 2);
            return {
              prompt: `${b}^${m} × ${b}^(−${n}) 의 값을 구하세요.`,
              inputMode: "short-answer",
              answer: b ** (m - n),
              solution: `지수합 ${m}−${n}=${m - n} → ${b ** (m - n)}.`
            };
          }
        },
        {
          id: "law-frac-exp",
          label: "유형 7 · 지수법칙과 유리수 지수",
          difficulty: 2,
          generate() {
            const b = randomInteger(2, 3), a = b ** 2;
            return {
              prompt: `${a}^(3/2) 의 값을 구하세요.`,
              inputMode: "short-answer",
              answer: b ** 3,
              solution: `(${b}^2)^(3/2)=${b}^3=${b ** 3}.`
            };
          }
        },
        {
          id: "law-simplify-exp",
          label: "유형 8 · 지수 간단히(지수 구하기)",
          difficulty: 2,
          generate() {
            const b = randomInteger(2, 4), m = randomInteger(2, 4), n = randomInteger(2, 4), p = randomInteger(1, 3);
            return {
              prompt: `(${b}^${m})^${n} ÷ ${b}^${p} = ${b}^k 일 때 k 를 구하세요.`,
              inputMode: "short-answer",
              answer: m * n - p,
              solution: `${m}×${n}−${p}=${m * n - p}.`
            };
          }
        },
        {
          id: "law-base-swap",
          label: "유형 9 · 밑이 거듭제곱인 경우",
          difficulty: 3,
          generate() {
            const n = randomInteger(2, 4);
            return {
              prompt: `4^${n} = 2^k 일 때 k 를 구하세요.`,
              inputMode: "short-answer",
              answer: 2 * n,
              solution: `4=2² 이므로 4^${n}=2^(2×${n})=2^${2 * n}.`
            };
          }
        },
        {
          id: "law-mixed-value",
          label: "유형 10 · 지수법칙 종합",
          difficulty: 3,
          generate() {
            const b = randomInteger(2, 3);
            return {
              prompt: `${b}² × ${b}³ ÷ ${b} 의 값을 구하세요.`,
              inputMode: "short-answer",
              answer: b ** 4,
              solution: `지수합 2+3−1=4 → ${b}^4=${b ** 4}.`
            };
          }
        }
      ].map(
        (problemType) => createAlgebraProblemType(problemType, {
          conceptId: "algebra-01-03",
          conceptTitle: "지수법칙"
        })
      );
      module.exports = {
        key: "algebra-exponent-laws",
        requiredDistinctTypes: 5,
        problemTypes,
        isCorrectAnswer
      };
    }
  });

  // services/problemGenerators/algebra/logarithmDefinitionAndProperties.js
  var require_logarithmDefinitionAndProperties = __commonJS({
    "services/problemGenerators/algebra/logarithmDefinitionAndProperties.js"(exports, module) {
      var {
        randomInteger,
        nonZeroInteger,
        round4,
        isCorrectAnswer,
        createAlgebraProblemType
      } = require_helpers2();
      var problemTypes = [
        {
          id: "log-def",
          label: "유형 1 · 로그의 정의",
          difficulty: 1,
          generate() {
            const a = randomInteger(2, 5), k = randomInteger(1, 4);
            return {
              prompt: `log_${a} ${a ** k} 의 값을 구하세요.`,
              inputMode: "short-answer",
              answer: k,
              solution: `${a}^${k}=${a ** k} → ${k}.`
            };
          }
        },
        {
          id: "log-eq-def",
          label: "유형 2 · 로그의 정의(진수 구하기)",
          difficulty: 1,
          generate() {
            const a = randomInteger(2, 4), k = randomInteger(1, 4);
            return {
              prompt: `log_${a} x = ${k} 일 때 x 를 구하세요.`,
              inputMode: "short-answer",
              answer: a ** k,
              solution: `x=${a}^${k}=${a ** k}.`
            };
          }
        },
        {
          id: "log-sum",
          label: "유형 3 · 로그의 합",
          difficulty: 2,
          generate() {
            const a = randomInteger(2, 3), m = randomInteger(1, 3), n = randomInteger(1, 3);
            return {
              prompt: `log_${a} ${a ** m} + log_${a} ${a ** n} 의 값을 구하세요.`,
              inputMode: "short-answer",
              answer: m + n,
              solution: `곱의 로그=합 → ${m}+${n}=${m + n}.`
            };
          }
        },
        {
          id: "log-diff",
          label: "유형 4 · 로그의 차",
          difficulty: 2,
          generate() {
            const a = randomInteger(2, 3), m = randomInteger(3, 5), n = randomInteger(1, 2);
            return {
              prompt: `log_${a} ${a ** m} − log_${a} ${a ** n} 의 값을 구하세요.`,
              inputMode: "short-answer",
              answer: m - n,
              solution: `나눗셈의 로그=차 → ${m}−${n}=${m - n}.`
            };
          }
        },
        {
          id: "log-power",
          label: "유형 5 · 로그와 지수(계수)",
          difficulty: 2,
          generate() {
            const a = randomInteger(2, 4), k = randomInteger(2, 4), p = randomInteger(2, 3);
            return {
              prompt: `log_${a} (${a ** k})^${p} 의 값을 구하세요.`,
              inputMode: "short-answer",
              answer: k * p,
              solution: `진수의 지수는 앞으로: ${p}×${k}=${k * p}.`
            };
          }
        },
        {
          id: "log-one-zero",
          label: "유형 6 · 로그의 기본값",
          difficulty: 1,
          generate() {
            const a = randomInteger(2, 9), one = Math.random() < 0.5;
            return {
              prompt: `log_${a} ${one ? 1 : a} 의 값을 구하세요.`,
              inputMode: "short-answer",
              answer: one ? 0 : 1,
              solution: one ? `log_a 1 = 0.` : `log_a a = 1.`
            };
          }
        },
        {
          id: "change-base",
          label: "유형 7 · 밑변환",
          difficulty: 3,
          generate() {
            const s = randomInteger(1, 3);
            let t = randomInteger(1, 4);
            while (t === s) t = randomInteger(1, 4);
            return {
              prompt: `log_${2 ** s} ${2 ** t} 의 값을 구하세요. (소수 가능)`,
              inputMode: "short-answer",
              answer: t / s,
              solution: `밑을 2로: (${t})/(${s})=${(t / s).toFixed(4)}.`
            };
          }
        },
        {
          id: "log-value-combo",
          label: "유형 8 · 로그 성질 종합",
          difficulty: 3,
          generate() {
            const a = randomInteger(2, 3), m = randomInteger(1, 3), n = randomInteger(1, 3);
            return {
              prompt: `log_${a} ${a ** m} + log_${a} ${a ** n} − log_${a} ${a} 의 값을 구하세요.`,
              inputMode: "short-answer",
              answer: m + n - 1,
              solution: `${m}+${n}−1=${m + n - 1}.`
            };
          }
        },
        {
          id: "log-inverse",
          label: "유형 9 · 로그와 지수의 역관계",
          difficulty: 3,
          generate() {
            const a = randomInteger(2, 3), k = randomInteger(1, 3);
            return {
              prompt: `${a}^(log_${a} ${a ** k}) 의 값을 구하세요.`,
              inputMode: "short-answer",
              answer: a ** k,
              solution: `log_${a} ${a ** k}=${k} → ${a}^${k}=${a ** k}.`
            };
          }
        },
        {
          id: "log-domain",
          label: "유형 10 · 로그의 정의 조건",
          difficulty: 2,
          generate() {
            const shift = randomInteger(-4, 4);
            const inside = shift === 0 ? "x" : shift > 0 ? `x-${shift}` : `x+${Math.abs(shift)}`;
            return {
              prompt: `log_a(${inside}) 가 정의되기 위한 x 의 조건은?`,
              inputMode: "multiple-choice",
              choices: [
                {
                  key: "positive",
                  text: `x > ${shift}`
                },
                {
                  key: "nonnegative",
                  text: `x ≥ ${shift}`
                },
                {
                  key: "opposite",
                  text: `x < ${shift}`
                }
              ],
              answer: "positive",
              solution: `진수는 양수여야 하므로 ${inside}>0, 즉 x>${shift}.`
            };
          }
        }
      ].map(
        (problemType) => createAlgebraProblemType(problemType, {
          conceptId: "algebra-01-04",
          conceptTitle: "로그의 뜻과 성질"
        })
      );
      module.exports = {
        key: "algebra-logarithm-definition-and-properties",
        requiredDistinctTypes: 5,
        problemTypes,
        isCorrectAnswer
      };
    }
  });

  // services/problemGenerators/algebra/commonLogarithmApplications.js
  var require_commonLogarithmApplications = __commonJS({
    "services/problemGenerators/algebra/commonLogarithmApplications.js"(exports, module) {
      var {
        randomInteger,
        nonZeroInteger,
        round4,
        isCorrectAnswer,
        createAlgebraProblemType
      } = require_helpers2();
      var problemTypes = [
        {
          id: "common-def",
          label: "유형 1 · 상용로그의 값",
          difficulty: 1,
          generate() {
            const k = randomInteger(0, 5);
            return {
              prompt: `log 10^${k} 의 값을 구하세요. (밑 10)`,
              inputMode: "short-answer",
              answer: k,
              solution: `log 10^${k}=${k}.`
            };
          }
        },
        {
          id: "characteristic",
          label: "유형 2 · 지표",
          difficulty: 2,
          generate() {
            const k = randomInteger(1, 6);
            return {
              prompt: `10^${k} ≤ N < 10^${k + 1} 인 자연수 N 에 대한 log N 의 지표를 구하세요.`,
              inputMode: "short-answer",
              answer: k,
              solution: `지표=${k}.`
            };
          }
        },
        {
          id: "digits",
          label: "유형 3 · 자릿수",
          difficulty: 2,
          generate() {
            const k = randomInteger(1, 7);
            return {
              prompt: `log N 의 지표가 ${k} 인 자연수 N 의 자릿수를 구하세요.`,
              inputMode: "short-answer",
              answer: k + 1,
              solution: `자릿수=지표+1=${k + 1}.`
            };
          }
        },
        {
          id: "leading-zeros",
          label: "유형 4 · 소수 부분의 위치",
          difficulty: 3,
          generate() {
            const k = randomInteger(1, 5);
            return {
              prompt: `양수 N 의 log N 의 지표가 −${k} 일 때, N 은 소수점 아래 몇째 자리에서 처음으로 0이 아닌 숫자가 나오나요?`,
              inputMode: "short-answer",
              answer: k,
              solution: `지표 −${k} 이면 소수 ${k}째 자리에서 처음 유효숫자 등장.`
            };
          }
        },
        {
          id: "log-power-common",
          label: "유형 5 · 상용로그의 거듭제곱 계산",
          difficulty: 1,
          generate() {
            const a = randomInteger(1, 4), k = randomInteger(1, 4);
            return {
              prompt: `log 10^${a} + log 10^${k} 의 값을 구하세요.`,
              inputMode: "short-answer",
              answer: a + k,
              solution: `${a}+${k}=${a + k}.`
            };
          }
        },
        {
          id: "sound-model",
          label: "유형 6 · 상용로그 활용(모델)",
          difficulty: 2,
          generate() {
            const k = randomInteger(1, 4);
            return {
              prompt: `어떤 양이 L = 10·log(10^${k}) 로 주어질 때 L 의 값을 구하세요.`,
              inputMode: "short-answer",
              answer: 10 * k,
              solution: `log(10^${k})=${k} → L=10×${k}=${10 * k}.`
            };
          }
        },
        {
          id: "compare-common",
          label: "유형 7 · 상용로그 대소",
          difficulty: 2,
          generate() {
            let a = randomInteger(1, 5), b = randomInteger(1, 5);
            while (a === b) b = randomInteger(1, 5);
            return {
              prompt: `log 10^${a} 와 log 10^${b} 중 더 큰 값은?`,
              inputMode: "multiple-choice",
              choices: [{ key: "a", text: `log 10^${a}` }, { key: "b", text: `log 10^${b}` }],
              answer: a > b ? "a" : "b",
              solution: `지수가 큰 쪽이 큽니다.`
            };
          }
        },
        {
          id: "digits-power",
          label: "유형 8 · 10의 거듭제곱 자릿수",
          difficulty: 2,
          generate() {
            const k = randomInteger(1, 6);
            return {
              prompt: `10^${k} 은 몇 자리 자연수인가요?`,
              inputMode: "short-answer",
              answer: k + 1,
              solution: `10^${k} 은 ${k + 1}자리.`
            };
          }
        },
        {
          id: "log-add-common",
          label: "유형 9 · 상용로그의 합",
          difficulty: 2,
          generate() {
            const variants = [
              { left: 2, right: 5, power: 1 },
              { left: 4, right: 25, power: 2 },
              { left: 8, right: 125, power: 3 },
              { left: 20, right: 5, power: 2 },
              { left: 40, right: 25, power: 3 }
            ];
            const variant = variants[randomInteger(0, variants.length - 1)];
            return {
              prompt: `log ${variant.left} + log ${variant.right} 의 값을 구하세요.`,
              inputMode: "short-answer",
              answer: variant.power,
              solution: `log ${variant.left}+log ${variant.right}=log(${variant.left}×${variant.right})=log 10^${variant.power}=${variant.power}.`
            };
          }
        },
        {
          id: "log-value-known",
          label: "유형 10 · 주어진 로그값 활용",
          difficulty: 3,
          generate() {
            const n = randomInteger(2, 5);
            return {
              prompt: `log 2 = 0.3010 일 때 log 2^${n} 의 값을 구하세요. (소수)`,
              inputMode: "short-answer",
              answer: Number((0.301 * n).toFixed(4)),
              solution: `log 2^${n}=${n}×0.3010=${(0.301 * n).toFixed(4)}.`
            };
          }
        }
      ].map(
        (problemType) => createAlgebraProblemType(problemType, {
          conceptId: "algebra-01-05",
          conceptTitle: "상용로그의 활용"
        })
      );
      module.exports = {
        key: "algebra-common-logarithm-applications",
        requiredDistinctTypes: 5,
        problemTypes,
        isCorrectAnswer
      };
    }
  });

  // services/problemGenerators/algebra/exponentialAndLogarithmicFunctions.js
  var require_exponentialAndLogarithmicFunctions = __commonJS({
    "services/problemGenerators/algebra/exponentialAndLogarithmicFunctions.js"(exports, module) {
      var {
        randomInteger,
        nonZeroInteger,
        round4,
        isCorrectAnswer,
        createAlgebraProblemType
      } = require_helpers2();
      var problemTypes = [
        {
          id: "exp-eval",
          label: "유형 1 · 지수함수의 함숫값",
          difficulty: 1,
          generate() {
            const a = randomInteger(2, 4), x = randomInteger(0, 3);
            return {
              prompt: `f(x)=${a}^x 일 때 f(${x}) 를 구하세요.`,
              inputMode: "short-answer",
              answer: a ** x,
              solution: `${a}^${x}=${a ** x}.`
            };
          }
        },
        {
          id: "log-eval",
          label: "유형 2 · 로그함수의 함숫값",
          difficulty: 1,
          generate() {
            const a = randomInteger(2, 4), k = randomInteger(1, 3);
            return {
              prompt: `g(x)=log_${a} x 일 때 g(${a ** k}) 를 구하세요.`,
              inputMode: "short-answer",
              answer: k,
              solution: `log_${a} ${a ** k}=${k}.`
            };
          }
        },
        {
          id: "exp-through-point",
          label: "유형 3 · 지수함수가 지나는 점",
          difficulty: 2,
          generate() {
            const a = randomInteger(2, 4);
            return {
              prompt: `y=${a}^x 는 항상 점 (0, k) 를 지납니다. k 를 구하세요.`,
              inputMode: "short-answer",
              answer: 1,
              solution: `${a}^0=1 → (0,1).`
            };
          }
        },
        {
          id: "log-through-point",
          label: "유형 4 · 로그함수가 지나는 점",
          difficulty: 2,
          generate() {
            const a = randomInteger(2, 4);
            return {
              prompt: `y=log_${a} x 는 항상 점 (k, 0) 를 지납니다. k 를 구하세요.`,
              inputMode: "short-answer",
              answer: 1,
              solution: `log_${a} 1=0 → (1,0).`
            };
          }
        },
        {
          id: "inverse-relation",
          label: "유형 5 · 역함수 관계",
          difficulty: 2,
          generate() {
            const a = randomInteger(2, 4);
            return {
              prompt: `y=${a}^x 의 역함수는?`,
              inputMode: "multiple-choice",
              choices: [{ key: "log", text: `y=log_${a} x` }, { key: "exp", text: `y=${a}^(−x)` }],
              answer: "log",
              solution: `지수함수의 역함수는 같은 밑의 로그함수.`
            };
          }
        },
        {
          id: "exp-negative-x",
          label: "유형 6 · 지수함수 f(−x)",
          difficulty: 2,
          generate() {
            const a = randomInteger(2, 4), x = randomInteger(1, 3);
            return {
              prompt: `f(x)=${a}^x 일 때 f(−${x}) 를 구하세요. (소수)`,
              inputMode: "short-answer",
              answer: 1 / a ** x,
              solution: `${a}^(−${x})=1/${a ** x}=${(1 / a ** x).toFixed(4)}.`
            };
          }
        },
        {
          id: "domain-log",
          label: "유형 7 · 로그함수의 정의역",
          difficulty: 2,
          generate() {
            const shift = randomInteger(-3, 3);
            const inside = shift === 0 ? "x" : shift > 0 ? `x-${shift}` : `x+${Math.abs(shift)}`;
            return {
              prompt: `로그함수 y=log_a(${inside}) 의 정의역은?`,
              inputMode: "multiple-choice",
              choices: [
                {
                  key: "correct",
                  text: `x > ${shift}`
                },
                {
                  key: "opposite",
                  text: `x < ${shift}`
                },
                {
                  key: "all",
                  text: "모든 실수"
                }
              ],
              answer: "correct",
              solution: `진수 ${inside}>0 이어야 하므로 x>${shift}.`
            };
          }
        },
        {
          id: "range-exp",
          label: "유형 8 · 지수함수의 치역",
          difficulty: 2,
          generate() {
            const base = randomInteger(2, 5);
            const shift = randomInteger(-3, 3);
            const shiftedTerm = shift === 0 ? "" : shift > 0 ? `+${shift}` : `${shift}`;
            return {
              prompt: `지수함수 y=${base}^x${shiftedTerm} 의 치역은?`,
              inputMode: "multiple-choice",
              choices: [
                {
                  key: "correct",
                  text: `y > ${shift}`
                },
                {
                  key: "opposite",
                  text: `y < ${shift}`
                },
                {
                  key: "all",
                  text: "모든 실수"
                }
              ],
              answer: "correct",
              solution: `${base}^x>0 이므로 y=${base}^x${shiftedTerm}>${shift}.`
            };
          }
        },
        {
          id: "monotonic",
          label: "유형 9 · 증가·감소 판정",
          difficulty: 2,
          generate() {
            const inc = Math.random() < 0.5;
            const a = inc ? randomInteger(2, 4) : 0;
            return {
              prompt: `y=${inc ? a : "(1/2)"}^x (밑 ${inc ? ">1" : "<1"}) 는 증가함수입니까?`,
              inputMode: "multiple-choice",
              choices: [{ key: "inc", text: "증가함수" }, { key: "dec", text: "감소함수" }],
              answer: inc ? "inc" : "dec",
              solution: inc ? `밑>1이면 증가함수.` : `밑<1이면 감소함수.`
            };
          }
        },
        {
          id: "exp-solve",
          label: "유형 10 · 함숫값으로 x 찾기",
          difficulty: 2,
          generate() {
            const a = randomInteger(2, 4), k = randomInteger(1, 3);
            return {
              prompt: `f(x)=${a}^x, f(x)=${a ** k} 일 때 x 를 구하세요.`,
              inputMode: "short-answer",
              answer: k,
              solution: `${a}^x=${a ** k} → x=${k}.`
            };
          }
        }
      ].map(
        (problemType) => createAlgebraProblemType(problemType, {
          conceptId: "algebra-01-06",
          conceptTitle: "지수함수와 로그함수의 뜻"
        })
      );
      module.exports = {
        key: "algebra-exponential-and-logarithmic-functions",
        requiredDistinctTypes: 5,
        problemTypes,
        isCorrectAnswer
      };
    }
  });

  // services/problemGenerators/algebra/exponentialAndLogarithmicGraphs.js
  var require_exponentialAndLogarithmicGraphs = __commonJS({
    "services/problemGenerators/algebra/exponentialAndLogarithmicGraphs.js"(exports, module) {
      var {
        randomInteger,
        nonZeroInteger,
        round4,
        isCorrectAnswer,
        createAlgebraProblemType
      } = require_helpers2();
      var problemTypes = [
        {
          id: "exp-shift-point",
          label: "유형 1 · 지수함수 평행이동 점",
          difficulty: 2,
          generate() {
            const a = randomInteger(2, 3), c = randomInteger(1, 4);
            return {
              prompt: `y=${a}^x + ${c} 의 그래프가 지나는 점 (0, k) 의 k 를 구하세요.`,
              inputMode: "short-answer",
              answer: 1 + c,
              solution: `${a}^0+${c}=1+${c}=${1 + c}.`
            };
          }
        },
        {
          id: "asymptote-exp",
          label: "유형 2 · 지수함수의 점근선",
          difficulty: 2,
          generate() {
            const c = randomInteger(-3, 3);
            return {
              prompt: `y=2^x + ${c} 의 점근선 y=k 의 k 를 구하세요.`,
              inputMode: "short-answer",
              answer: c,
              solution: `수평점근선은 y=${c}.`
            };
          }
        },
        {
          id: "asymptote-log",
          label: "유형 3 · 로그함수의 점근선",
          difficulty: 2,
          generate() {
            const c = randomInteger(-3, 3);
            return {
              prompt: `y=log_2 (x − ${c}) 의 수직점근선 x=k 의 k 를 구하세요.`,
              inputMode: "short-answer",
              answer: c,
              solution: `진수>0: x>${c} → 점근선 x=${c}.`
            };
          }
        },
        {
          id: "symmetry-yx",
          label: "유형 4 · y=x 대칭(역함수 그래프)",
          difficulty: 2,
          generate() {
            const a = randomInteger(2, 4), p = randomInteger(1, 3);
            return {
              prompt: `y=${a}^x 위의 점 (${p}, ${a ** p}) 을 y=x 에 대칭시킨 점의 x좌표를 구하세요.`,
              inputMode: "short-answer",
              answer: a ** p,
              solution: `(p,q)→(q,p): x좌표=${a ** p}.`
            };
          }
        },
        {
          id: "exp-max-interval",
          label: "유형 5 · 구간에서의 최댓값(지수)",
          difficulty: 2,
          generate() {
            const a = randomInteger(2, 3), b = randomInteger(2, 3);
            return {
              prompt: `0≤x≤${b} 에서 y=${a}^x 의 최댓값을 구하세요.`,
              inputMode: "short-answer",
              answer: a ** b,
              solution: `증가함수이므로 x=${b}에서 최대: ${a ** b}.`
            };
          }
        },
        {
          id: "log-max-interval",
          label: "유형 6 · 구간에서의 최댓값(로그)",
          difficulty: 2,
          generate() {
            const a = randomInteger(2, 3), k = randomInteger(2, 3);
            return {
              prompt: `1≤x≤${a ** k} 에서 y=log_${a} x 의 최댓값을 구하세요.`,
              inputMode: "short-answer",
              answer: k,
              solution: `증가함수이므로 x=${a ** k}에서 최대: ${k}.`
            };
          }
        },
        {
          id: "reflect-exp",
          label: "유형 7 · y축 대칭",
          difficulty: 2,
          generate() {
            const a = randomInteger(2, 4);
            return {
              prompt: `y=${a}^x 를 y축에 대칭시킨 그래프의 식은?`,
              inputMode: "multiple-choice",
              choices: [{ key: "negx", text: `y=${a}^(−x)` }, { key: "neg", text: `y=−${a}^x` }],
              answer: "negx",
              solution: `y축 대칭은 x→−x → y=${a}^(−x).`
            };
          }
        },
        {
          id: "graph-increasing",
          label: "유형 8 · 그래프의 증가/감소",
          difficulty: 1,
          generate() {
            const big = Math.random() < 0.5;
            const a = big ? randomInteger(2, 5) : 0;
            return {
              prompt: `y=${big ? a : "(1/3)"}^x 의 그래프는 증가/감소 중 무엇인가요?`,
              inputMode: "multiple-choice",
              choices: [{ key: "inc", text: "증가" }, { key: "dec", text: "감소" }],
              answer: big ? "inc" : "dec",
              solution: big ? `밑>1 → 증가.` : `밑<1 → 감소.`
            };
          }
        },
        {
          id: "log-min-interval",
          label: "유형 9 · 구간에서의 최솟값(로그)",
          difficulty: 2,
          generate() {
            const a = randomInteger(2, 3);
            return {
              prompt: `${a}≤x≤${a ** 3} 에서 y=log_${a} x 의 최솟값을 구하세요.`,
              inputMode: "short-answer",
              answer: 1,
              solution: `증가함수이므로 x=${a}에서 최소: log_${a} ${a}=1.`
            };
          }
        },
        {
          id: "exp-min-interval",
          label: "유형 10 · 구간에서의 최솟값(지수)",
          difficulty: 2,
          generate() {
            const a = randomInteger(2, 3), b = randomInteger(2, 3);
            return {
              prompt: `0≤x≤${b} 에서 y=${a}^x 의 최솟값을 구하세요.`,
              inputMode: "short-answer",
              answer: 1,
              solution: `증가함수이므로 x=0에서 최소: ${a}^0=1.`
            };
          }
        }
      ].map(
        (problemType) => createAlgebraProblemType(problemType, {
          conceptId: "algebra-01-07",
          conceptTitle: "지수함수와 로그함수의 그래프"
        })
      );
      module.exports = {
        key: "algebra-exponential-and-logarithmic-graphs",
        requiredDistinctTypes: 5,
        problemTypes,
        isCorrectAnswer
      };
    }
  });

  // services/problemGenerators/algebra/exponentialAndLogarithmicApplications.js
  var require_exponentialAndLogarithmicApplications = __commonJS({
    "services/problemGenerators/algebra/exponentialAndLogarithmicApplications.js"(exports, module) {
      var {
        randomInteger,
        nonZeroInteger,
        round4,
        isCorrectAnswer,
        createAlgebraProblemType
      } = require_helpers2();
      var problemTypes = [
        {
          id: "exp-equation",
          label: "유형 1 · 지수방정식(밑 같게)",
          difficulty: 2,
          generate() {
            const a = randomInteger(2, 4), k = randomInteger(1, 4);
            return {
              prompt: `${a}^x = ${a ** k} 의 해 x 를 구하세요.`,
              inputMode: "short-answer",
              answer: k,
              solution: `밑이 같으므로 x=${k}.`
            };
          }
        },
        {
          id: "exp-equation-base",
          label: "유형 2 · 지수방정식(밑 변형)",
          difficulty: 3,
          generate() {
            const n = randomInteger(1, 3);
            const k = randomInteger(1, 3) * 2;
            return {
              prompt: `4^x = 2^${k} 의 해 x 를 구하세요.`,
              inputMode: "short-answer",
              answer: k / 2,
              solution: `4=2² → 2^(2x)=2^${k} → x=${k / 2}.`
            };
          }
        },
        {
          id: "log-equation",
          label: "유형 3 · 로그방정식",
          difficulty: 2,
          generate() {
            const a = randomInteger(2, 4), k = randomInteger(1, 4);
            return {
              prompt: `log_${a} x = ${k} 의 해 x 를 구하세요.`,
              inputMode: "short-answer",
              answer: a ** k,
              solution: `x=${a}^${k}=${a ** k}.`
            };
          }
        },
        {
          id: "exp-inequality",
          label: "유형 4 · 지수부등식(밑>1)",
          difficulty: 3,
          generate() {
            const a = randomInteger(2, 4), k = randomInteger(1, 4);
            return {
              prompt: `${a}^x > ${a ** k} (밑>1) 의 해는 x > m 입니다. m 을 구하세요.`,
              inputMode: "short-answer",
              answer: k,
              solution: `밑>1이므로 부등호 방향 유지: x>${k}.`
            };
          }
        },
        {
          id: "log-inequality",
          label: "유형 5 · 로그부등식",
          difficulty: 3,
          generate() {
            const a = randomInteger(2, 4), k = randomInteger(1, 3);
            return {
              prompt: `log_${a} x < ${k} (진수>0) 의 해는 0 < x < m 입니다. m 을 구하세요.`,
              inputMode: "short-answer",
              answer: a ** k,
              solution: `밑>1: x<${a ** k}, 진수조건 x>0 → 0<x<${a ** k}.`
            };
          }
        },
        {
          id: "exp-sub",
          label: "유형 6 · 치환(지수)",
          difficulty: 3,
          generate() {
            const t = randomInteger(2, 4);
            return {
              prompt: `2^x = ${2 ** t} 을 t=2^x 로 치환할 때 t 의 값을 구하세요.`,
              inputMode: "short-answer",
              answer: 2 ** t,
              solution: `t=2^x=${2 ** t}.`
            };
          }
        },
        {
          id: "compound-growth",
          label: "유형 7 · 지수 성장 모델",
          difficulty: 2,
          generate() {
            const a = randomInteger(2, 3), n = randomInteger(1, 4);
            return {
              prompt: `초기값 1이 매 기간 ${a}배로 늘 때 ${n}기간 후의 값을 구하세요.`,
              inputMode: "short-answer",
              answer: a ** n,
              solution: `${a}^${n}=${a ** n}.`
            };
          }
        },
        {
          id: "log-scale",
          label: "유형 8 · 로그 척도 활용",
          difficulty: 2,
          generate() {
            const a = randomInteger(2, 4), k = randomInteger(1, 3);
            return {
              prompt: `M = log_${a} x, x=${a ** k} 일 때 M 을 구하세요.`,
              inputMode: "short-answer",
              answer: k,
              solution: `M=log_${a} ${a ** k}=${k}.`
            };
          }
        },
        {
          id: "exp-eq-two",
          label: "유형 9 · 지수방정식(공통밑 정리)",
          difficulty: 3,
          generate() {
            const a = randomInteger(2, 3), m = randomInteger(2, 4);
            return {
              prompt: `${a}^(x+1) = ${a ** m} 의 해 x 를 구하세요.`,
              inputMode: "short-answer",
              answer: m - 1,
              solution: `x+1=${m} → x=${m - 1}.`
            };
          }
        },
        {
          id: "log-eq-two",
          label: "유형 10 · 로그방정식(진수 정리)",
          difficulty: 3,
          generate() {
            const a = randomInteger(2, 3), k = randomInteger(1, 3), c = randomInteger(1, 4);
            return {
              prompt: `log_${a} (x − ${c}) = ${k} 의 해 x 를 구하세요.`,
              inputMode: "short-answer",
              answer: a ** k + c,
              solution: `x−${c}=${a}^${k}=${a ** k} → x=${a ** k + c}.`
            };
          }
        }
      ].map(
        (problemType) => createAlgebraProblemType(problemType, {
          conceptId: "algebra-01-08",
          conceptTitle: "지수함수와 로그함수의 활용"
        })
      );
      module.exports = {
        key: "algebra-exponential-and-logarithmic-applications",
        requiredDistinctTypes: 5,
        problemTypes,
        isCorrectAnswer
      };
    }
  });

  // services/problemGenerators/algebra/generalAnglesAndRadians.js
  var require_generalAnglesAndRadians = __commonJS({
    "services/problemGenerators/algebra/generalAnglesAndRadians.js"(exports, module) {
      var {
        randomInteger,
        nonZeroInteger,
        round4,
        isCorrectAnswer,
        createAlgebraProblemType
      } = require_helpers2();
      var problemTypes = [
        {
          id: "rad-to-deg",
          label: "유형 1 · 호도법 → 육십분법",
          difficulty: 1,
          generate() {
            const k = [2, 3, 4, 6][randomInteger(0, 3)];
            return {
              prompt: `π/${k} (라디안)을 도(°)로 나타내세요.`,
              inputMode: "short-answer",
              answer: 180 / k,
              solution: `π=180° 이므로 π/${k}=${180 / k}°.`
            };
          }
        },
        {
          id: "deg-to-rad",
          label: "유형 2 · 육십분법 → 호도법",
          difficulty: 1,
          generate() {
            const d = [30, 45, 60, 90, 180][randomInteger(0, 4)];
            const k = 180 / d;
            return {
              prompt: `${d}° 를 π/k 꼴의 호도법으로 나타낼 때 k 를 구하세요.`,
              inputMode: "short-answer",
              answer: k,
              solution: `${d}° = ${d}π/180 = π/${k}.`
            };
          }
        },
        {
          id: "coterminal",
          label: "유형 3 · 동경이 같은 각",
          difficulty: 2,
          generate() {
            const base = randomInteger(0, 350);
            const n = randomInteger(1, 3);
            const ang = base + 360 * n;
            return {
              prompt: `${ang}° 와 동경이 같은 각 중 0°≤θ<360° 인 θ 를 구하세요.`,
              inputMode: "short-answer",
              answer: base,
              solution: `${ang}°−360°×${n}=${base}°.`
            };
          }
        },
        {
          id: "arc-length",
          label: "유형 4 · 부채꼴의 호의 길이",
          difficulty: 1,
          generate() {
            const r = randomInteger(2, 8), t = randomInteger(1, 4);
            return {
              prompt: `반지름 ${r}, 중심각 ${t}(라디안)인 부채꼴의 호의 길이 l 을 구하세요.`,
              inputMode: "short-answer",
              answer: r * t,
              solution: `l=rθ=${r}×${t}=${r * t}.`
            };
          }
        },
        {
          id: "sector-area",
          label: "유형 5 · 부채꼴의 넓이",
          difficulty: 2,
          generate() {
            const r = 2 * randomInteger(1, 4), t = randomInteger(1, 4);
            return {
              prompt: `반지름 ${r}, 중심각 ${t}(라디안)인 부채꼴의 넓이 S 를 구하세요.`,
              inputMode: "short-answer",
              answer: 0.5 * r * r * t,
              solution: `S=½r²θ=½×${r}²×${t}=${0.5 * r * r * t}.`
            };
          }
        },
        {
          id: "sector-area-arc",
          label: "유형 6 · 호의 길이로 넓이",
          difficulty: 2,
          generate() {
            const r = 2 * randomInteger(1, 4), l = randomInteger(2, 8);
            return {
              prompt: `반지름 ${r}, 호의 길이 ${l} 인 부채꼴의 넓이 S 를 구하세요.`,
              inputMode: "short-answer",
              answer: 0.5 * r * l,
              solution: `S=½rl=½×${r}×${l}=${0.5 * r * l}.`
            };
          }
        },
        {
          id: "central-angle",
          label: "유형 7 · 중심각 구하기(θ=l/r)",
          difficulty: 2,
          generate() {
            const r = randomInteger(2, 6), t = randomInteger(1, 5), l = r * t;
            return {
              prompt: `반지름 ${r}, 호의 길이 ${l} 인 부채꼴의 중심각(라디안)을 구하세요.`,
              inputMode: "short-answer",
              answer: t,
              solution: `θ=l/r=${l}/${r}=${t}.`
            };
          }
        },
        {
          id: "quadrant-of-angle",
          label: "유형 8 · 각의 사분면",
          difficulty: 2,
          generate() {
            const q = randomInteger(1, 4);
            const ang = (q - 1) * 90 + randomInteger(10, 80);
            return {
              prompt: `${ang}° 는 제몇 사분면의 각인가요?`,
              inputMode: "multiple-choice",
              choices: [{ key: "1", text: "제1사분면" }, { key: "2", text: "제2사분면" }, { key: "3", text: "제3사분면" }, { key: "4", text: "제4사분면" }],
              answer: String(q),
              solution: `${ang}° 는 제${q}사분면.`
            };
          }
        },
        {
          id: "perimeter",
          label: "유형 9 · 부채꼴의 둘레",
          difficulty: 2,
          generate() {
            const r = randomInteger(2, 6), t = randomInteger(1, 4), l = r * t;
            return {
              prompt: `반지름 ${r}, 중심각 ${t}(라디안)인 부채꼴의 둘레를 구하세요.`,
              inputMode: "short-answer",
              answer: 2 * r + l,
              solution: `둘레=2r+l=2×${r}+${l}=${2 * r + l}.`
            };
          }
        },
        {
          id: "angle-from-area",
          label: "유형 10 · 넓이로 중심각",
          difficulty: 3,
          generate() {
            const r = 2 * randomInteger(1, 3), t = randomInteger(1, 4), S = 0.5 * r * r * t;
            return {
              prompt: `반지름 ${r}, 넓이 ${S} 인 부채꼴의 중심각(라디안)을 구하세요.`,
              inputMode: "short-answer",
              answer: t,
              solution: `θ=2S/r²=2×${S}/${r}²=${t}.`
            };
          }
        }
      ].map(
        (problemType) => createAlgebraProblemType(problemType, {
          conceptId: "algebra-02-01",
          conceptTitle: "일반각과 호도법"
        })
      );
      module.exports = {
        key: "algebra-general-angles-and-radians",
        requiredDistinctTypes: 5,
        problemTypes,
        isCorrectAnswer
      };
    }
  });

  // services/problemGenerators/algebra/trigonometricFunctionsAndGraphs.js
  var require_trigonometricFunctionsAndGraphs = __commonJS({
    "services/problemGenerators/algebra/trigonometricFunctionsAndGraphs.js"(exports, module) {
      var {
        randomInteger,
        nonZeroInteger,
        round4,
        isCorrectAnswer,
        createAlgebraProblemType
      } = require_helpers2();
      var problemTypes = [
        {
          id: "special-value",
          label: "유형 1 · 특수각의 삼각함수 값",
          difficulty: 2,
          generate() {
            const table = [["sin", 30, 0.5], ["sin", 90, 1], ["sin", 0, 0], ["cos", 0, 1], ["cos", 60, 0.5], ["cos", 90, 0], ["tan", 45, 1], ["tan", 0, 0]];
            const [f, d, v] = table[randomInteger(0, table.length - 1)];
            return {
              prompt: `${f} ${d}° 의 값을 구하세요. (소수/정수)`,
              inputMode: "short-answer",
              answer: v,
              solution: `${f}${d}°=${v}.`
            };
          }
        },
        {
          id: "quadrant-sign",
          label: "유형 2 · 삼각함수의 부호",
          difficulty: 2,
          generate() {
            const q = randomInteger(1, 4);
            const f = ["sin", "cos", "tan"][randomInteger(0, 2)];
            const s = { sin: [1, 1, -1, -1], cos: [1, -1, -1, 1], tan: [1, -1, 1, -1] }[f][q - 1] > 0;
            return {
              prompt: `θ가 제${q}사분면의 각일 때 ${f}θ 의 부호는?`,
              inputMode: "multiple-choice",
              choices: [{ key: "p", text: "양수(+)" }, { key: "n", text: "음수(−)" }],
              answer: s ? "p" : "n",
              solution: `제${q}사분면에서 ${f}θ 는 ${s ? "양" : "음"}수.`
            };
          }
        },
        {
          id: "identity-cos",
          label: "유형 3 · 삼각함수의 기본 관계",
          difficulty: 2,
          generate() {
            const T = [[3, 4, 5], [5, 12, 13], [8, 15, 17]][randomInteger(0, 2)];
            return {
              prompt: `제1사분면 각 θ에서 sinθ=${T[0]}/${T[2]} 일 때 cosθ 를 구하세요. (소수)`,
              inputMode: "short-answer",
              answer: T[1] / T[2],
              solution: `cosθ=${T[1]}/${T[2]}=${(T[1] / T[2]).toFixed(4)}.`
            };
          }
        },
        {
          id: "tan-from-triple",
          label: "유형 4 · 삼각함수 사이의 관계",
          difficulty: 2,
          generate() {
            const T = [[3, 4, 5], [5, 12, 13], [8, 15, 17]][randomInteger(0, 2)];
            return {
              prompt: `제1사분면 각 θ에서 sinθ=${T[0]}/${T[2]}, cosθ=${T[1]}/${T[2]} 일 때 tanθ 를 구하세요. (소수)`,
              inputMode: "short-answer",
              answer: T[0] / T[1],
              solution: `tanθ=${T[0]}/${T[1]}=${(T[0] / T[1]).toFixed(4)}.`
            };
          }
        },
        {
          id: "graph-max",
          label: "유형 5 · 그래프의 최댓값",
          difficulty: 2,
          generate() {
            const A = randomInteger(2, 5), c = randomInteger(-3, 3);
            return {
              prompt: `y=${A}sin x + ${c} 의 최댓값을 구하세요.`,
              inputMode: "short-answer",
              answer: A + c,
              solution: `최댓값=${A}×1+${c}=${A + c}.`
            };
          }
        },
        {
          id: "graph-min",
          label: "유형 6 · 그래프의 최솟값",
          difficulty: 2,
          generate() {
            const A = randomInteger(2, 5), c = randomInteger(-3, 3);
            return {
              prompt: `y=${A}sin x + ${c} 의 최솟값을 구하세요.`,
              inputMode: "short-answer",
              answer: -A + c,
              solution: `최솟값=${A}×(−1)+${c}=${-A + c}.`
            };
          }
        },
        {
          id: "period",
          label: "유형 7 · 주기",
          difficulty: 2,
          generate() {
            const b = randomInteger(2, 6);
            return {
              prompt: `y=sin(${b}x) 의 주기는 2π/k 입니다. k 를 구하세요.`,
              inputMode: "short-answer",
              answer: b,
              solution: `주기=2π/${b} 이므로 k=${b}.`
            };
          }
        },
        {
          id: "amplitude",
          label: "유형 8 · 진폭",
          difficulty: 1,
          generate() {
            const A = nonZeroInteger(-5, 5);
            return {
              prompt: `y=${A}sin x 의 진폭을 구하세요.`,
              inputMode: "short-answer",
              answer: Math.abs(A),
              solution: `진폭=|${A}|=${Math.abs(A)}.`
            };
          }
        },
        {
          id: "transform-value",
          label: "유형 9 · 여러 각의 삼각함수",
          difficulty: 3,
          generate() {
            const table = [[150, "sin", 0.5], [120, "sin", Math.round(Math.sin(Math.PI * 120 / 180) * 1e3) / 1e3], [180, "cos", -1], [90, "cos", 0]];
            const pick = [[150, 0.5, "sin(180°−30°)=sin30°"], [0, 0, "sin0°"], [180, 0, "sin180°=0"]][randomInteger(0, 2)];
            return {
              prompt: `sin ${pick[0]}° 의 값을 구하세요.`,
              inputMode: "short-answer",
              answer: pick[1],
              solution: `${pick[2]}=${pick[1]}.`
            };
          }
        },
        {
          id: "simple-equation",
          label: "유형 10 · 간단한 삼각방정식",
          difficulty: 2,
          generate() {
            const cases = [["sin", 1, 90], ["cos", 1, 0], ["sin", 0, 0], ["cos", 0, 90]];
            const c = cases[randomInteger(0, cases.length - 1)];
            return {
              prompt: `0°≤x≤90° 에서 ${c[0]} x = ${c[1]} 을 만족하는 x(°) 를 구하세요.`,
              inputMode: "short-answer",
              answer: c[2],
              solution: `${c[0]}${c[2]}°=${c[1]} → x=${c[2]}°.`
            };
          }
        }
      ].map(
        (problemType) => createAlgebraProblemType(problemType, {
          conceptId: "algebra-02-02",
          conceptTitle: "삼각함수와 그래프"
        })
      );
      module.exports = {
        key: "algebra-trigonometric-functions-and-graphs",
        requiredDistinctTypes: 5,
        problemTypes,
        isCorrectAnswer
      };
    }
  });

  // services/problemGenerators/algebra/sineAndCosineLaws.js
  var require_sineAndCosineLaws = __commonJS({
    "services/problemGenerators/algebra/sineAndCosineLaws.js"(exports, module) {
      var {
        randomInteger,
        nonZeroInteger,
        round4,
        isCorrectAnswer,
        createAlgebraProblemType
      } = require_helpers2();
      var problemTypes = [
        {
          id: "law-sines-b",
          label: "유형 1 · 사인법칙(변 b)",
          difficulty: 2,
          generate() {
            const a = randomInteger(2, 8);
            return {
              prompt: `삼각형 ABC에서 A=30°, B=90°, a=${a} 일 때 b 를 구하세요.`,
              inputMode: "short-answer",
              answer: 2 * a,
              solution: `b=a·sinB/sinA=${a}×1÷(1/2)=${2 * a}.`
            };
          }
        },
        {
          id: "law-sines-a",
          label: "유형 2 · 사인법칙(변 a)",
          difficulty: 2,
          generate() {
            const b = randomInteger(2, 8);
            return {
              prompt: `삼각형 ABC에서 A=90°, B=30°, b=${b} 일 때 a 를 구하세요.`,
              inputMode: "short-answer",
              answer: 2 * b,
              solution: `a=b·sinA/sinB=${b}×1÷(1/2)=${2 * b}.`
            };
          }
        },
        {
          id: "circumradius",
          label: "유형 3 · 외접원의 반지름 R",
          difficulty: 3,
          generate() {
            const a = randomInteger(2, 8);
            return {
              prompt: `삼각형 ABC에서 A=30°, a=${a} 일 때 외접원의 반지름 R 을 구하세요.`,
              inputMode: "short-answer",
              answer: a,
              solution: `2R=a/sinA=${a}÷(1/2)=${2 * a} → R=${a}.`
            };
          }
        },
        {
          id: "cosines-60",
          label: "유형 4 · 코사인법칙(A=60°)",
          difficulty: 3,
          generate() {
            const b = randomInteger(2, 7), c = randomInteger(2, 7);
            return {
              prompt: `삼각형에서 b=${b}, c=${c}, A=60° 일 때 a² 을 구하세요.`,
              inputMode: "short-answer",
              answer: b * b + c * c - b * c,
              solution: `a²=b²+c²−2bc·cos60°=${b}²+${c}²−${b}×${c}=${b * b + c * c - b * c}.`
            };
          }
        },
        {
          id: "cosines-90",
          label: "유형 5 · 코사인법칙(A=90°, 피타고라스)",
          difficulty: 2,
          generate() {
            const b = randomInteger(2, 7), c = randomInteger(2, 7);
            return {
              prompt: `삼각형에서 b=${b}, c=${c}, A=90° 일 때 a² 을 구하세요.`,
              inputMode: "short-answer",
              answer: b * b + c * c,
              solution: `cos90°=0 이므로 a²=b²+c²=${b * b + c * c}.`
            };
          }
        },
        {
          id: "cosines-120",
          label: "유형 6 · 코사인법칙(A=120°)",
          difficulty: 3,
          generate() {
            const b = randomInteger(2, 7), c = randomInteger(2, 7);
            return {
              prompt: `삼각형에서 b=${b}, c=${c}, A=120° 일 때 a² 을 구하세요.`,
              inputMode: "short-answer",
              answer: b * b + c * c + b * c,
              solution: `cos120°=−½ 이므로 a²=b²+c²+bc=${b * b + c * c + b * c}.`
            };
          }
        },
        {
          id: "area-30",
          label: "유형 7 · 삼각형 넓이(C=30°)",
          difficulty: 2,
          generate() {
            const a = 2 * randomInteger(1, 5), b = 2 * randomInteger(1, 5);
            return {
              prompt: `두 변 a=${a}, b=${b}, 끼인각 C=30° 인 삼각형의 넓이를 구하세요.`,
              inputMode: "short-answer",
              answer: a * b / 4,
              solution: `S=½ab·sin30°=½×${a}×${b}×½=${a * b / 4}.`
            };
          }
        },
        {
          id: "area-90",
          label: "유형 8 · 삼각형 넓이(C=90°)",
          difficulty: 1,
          generate() {
            const a = randomInteger(2, 8), b = randomInteger(2, 8);
            return {
              prompt: `두 변 a=${a}, b=${b}, 끼인각 C=90° 인 삼각형의 넓이를 구하세요.`,
              inputMode: "short-answer",
              answer: a * b / 2,
              solution: `S=½ab·sin90°=½×${a}×${b}=${a * b / 2}.`
            };
          }
        },
        {
          id: "area-150",
          label: "유형 9 · 삼각형 넓이(C=150°)",
          difficulty: 3,
          generate() {
            const a = 2 * randomInteger(1, 5), b = 2 * randomInteger(1, 5);
            return {
              prompt: `두 변 a=${a}, b=${b}, 끼인각 C=150° 인 삼각형의 넓이를 구하세요.`,
              inputMode: "short-answer",
              answer: a * b / 4,
              solution: `sin150°=½ → S=½ab×½=${a * b / 4}.`
            };
          }
        },
        {
          id: "cos-from-sides",
          label: "유형 10 · 세 변으로 코사인값 구하기",
          difficulty: 3,
          generate() {
            const T = [[4, 5, 6], [2, 3, 4], [3, 5, 7], [5, 6, 7]][randomInteger(0, 3)];
            const [a, b, c] = T;
            const cosA = (b * b + c * c - a * a) / (2 * b * c);
            return {
              prompt: `세 변이 a=${a}, b=${b}, c=${c} 인 삼각형에서 cosA 를 구하세요. (소수)`,
              inputMode: "short-answer",
              answer: Number(cosA.toFixed(4)),
              solution: `cosA=(b²+c²−a²)/(2bc)=(${b * b}+${c * c}−${a * a})/${2 * b * c}=${cosA.toFixed(4)}.`
            };
          }
        }
      ].map(
        (problemType) => createAlgebraProblemType(problemType, {
          conceptId: "algebra-02-03",
          conceptTitle: "사인법칙과 코사인법칙"
        })
      );
      module.exports = {
        key: "algebra-sine-and-cosine-laws",
        requiredDistinctTypes: 5,
        problemTypes,
        isCorrectAnswer
      };
    }
  });

  // services/problemGenerators/algebra/sequenceBasics.js
  var require_sequenceBasics = __commonJS({
    "services/problemGenerators/algebra/sequenceBasics.js"(exports, module) {
      var {
        randomInteger,
        nonZeroInteger,
        round4,
        isCorrectAnswer,
        createAlgebraProblemType
      } = require_helpers2();
      var problemTypes = [
        {
          id: "nth-term-linear",
          label: "유형 1 · 일반항 대입(일차)",
          difficulty: 1,
          generate() {
            const p = nonZeroInteger(-4, 4), q = randomInteger(-5, 5), n = randomInteger(2, 9);
            return {
              prompt: `수열의 일반항이 a_n=${p}n+${q} 일 때 a_${n} 을 구하세요.`,
              inputMode: "short-answer",
              answer: p * n + q,
              solution: `a_${n}=${p}×${n}+${q}=${p * n + q}.`
            };
          }
        },
        {
          id: "nth-term-square",
          label: "유형 2 · 일반항 대입(제곱)",
          difficulty: 1,
          generate() {
            const n = randomInteger(2, 8);
            return {
              prompt: `a_n=n² 일 때 a_${n} 을 구하세요.`,
              inputMode: "short-answer",
              answer: n * n,
              solution: `a_${n}=${n}²=${n * n}.`
            };
          }
        },
        {
          id: "first-term",
          label: "유형 3 · 첫째항 구하기",
          difficulty: 1,
          generate() {
            const p = nonZeroInteger(-4, 4), q = randomInteger(-5, 5);
            return {
              prompt: `a_n=${p}n+${q} 인 수열의 첫째항 a₁ 을 구하세요.`,
              inputMode: "short-answer",
              answer: p + q,
              solution: `a₁=${p}+${q}=${p + q}.`
            };
          }
        },
        {
          id: "nth-term-product",
          label: "유형 4 · 일반항 n(n+1)",
          difficulty: 2,
          generate() {
            const n = randomInteger(2, 7);
            return {
              prompt: `a_n=n(n+1) 일 때 a_${n} 을 구하세요.`,
              inputMode: "short-answer",
              answer: n * (n + 1),
              solution: `a_${n}=${n}×${n + 1}=${n * (n + 1)}.`
            };
          }
        },
        {
          id: "term-index",
          label: "유형 5 · 항 번호 찾기",
          difficulty: 2,
          generate() {
            const p = randomInteger(2, 5), q = randomInteger(-3, 3), n = randomInteger(3, 10), v = p * n + q;
            return {
              prompt: `a_n=${p}n+${q} 일 때 a_n=${v} 를 만족하는 n 을 구하세요.`,
              inputMode: "short-answer",
              answer: n,
              solution: `${p}n+${q}=${v} → n=${n}.`
            };
          }
        },
        {
          id: "alternating",
          label: "유형 6 · 교대수열",
          difficulty: 2,
          generate() {
            const n = randomInteger(2, 8);
            const v = (n % 2 === 0 ? 1 : -1) * n;
            return {
              prompt: `a_n=(−1)ⁿ·n 일 때 a_${n} 을 구하세요.`,
              inputMode: "short-answer",
              answer: v,
              solution: `(−1)^${n}×${n}=${v}.`
            };
          }
        },
        {
          id: "power-term",
          label: "유형 7 · 일반항 2ⁿ",
          difficulty: 2,
          generate() {
            const n = randomInteger(2, 8);
            return {
              prompt: `a_n=2ⁿ 일 때 a_${n} 을 구하세요.`,
              inputMode: "short-answer",
              answer: 2 ** n,
              solution: `2^${n}=${2 ** n}.`
            };
          }
        },
        {
          id: "next-term-pattern",
          label: "유형 8 · 규칙 찾아 다음 항",
          difficulty: 1,
          generate() {
            const a1 = randomInteger(1, 5), d = randomInteger(2, 5);
            const seq = [a1, a1 + d, a1 + 2 * d, a1 + 3 * d];
            return {
              prompt: `수열 ${seq[0]}, ${seq[1]}, ${seq[2]}, ${seq[3]}, ... 의 다음 항을 구하세요.`,
              inputMode: "short-answer",
              answer: a1 + 4 * d,
              solution: `공차 ${d}씩 증가 → ${a1 + 4 * d}.`
            };
          }
        },
        {
          id: "an-from-Sn",
          label: "유형 9 · S_n − S_{n-1} = a_n",
          difficulty: 3,
          generate() {
            const n = randomInteger(2, 7);
            const S = (k) => k * k;
            return {
              prompt: `수열의 부분합이 S_n=n² 일 때 a_${n} 을 구하세요. (단 n≥2, a_n=S_n−S_{n−1})`,
              inputMode: "short-answer",
              answer: S(n) - S(n - 1),
              solution: `a_${n}=S_${n}−S_${n - 1}=${S(n)}−${S(n - 1)}=${S(n) - S(n - 1)}.`
            };
          }
        },
        {
          id: "nth-term-value",
          label: "유형 10 · 일반항의 값 계산",
          difficulty: 1,
          generate() {
            const A = nonZeroInteger(-5, 5), B = randomInteger(-5, 5), n = randomInteger(2, 9);
            return {
              prompt: `a_n=${A}n+${B} 일 때 a_${n} 을 구하세요.`,
              inputMode: "short-answer",
              answer: A * n + B,
              solution: `${A}×${n}+${B}=${A * n + B}.`
            };
          }
        }
      ].map(
        (problemType) => createAlgebraProblemType(problemType, {
          conceptId: "algebra-03-01",
          conceptTitle: "수열의 뜻"
        })
      );
      module.exports = {
        key: "algebra-sequence-basics",
        requiredDistinctTypes: 5,
        problemTypes,
        isCorrectAnswer
      };
    }
  });

  // services/problemGenerators/algebra/arithmeticSequences.js
  var require_arithmeticSequences = __commonJS({
    "services/problemGenerators/algebra/arithmeticSequences.js"(exports, module) {
      var {
        randomInteger,
        nonZeroInteger,
        round4,
        isCorrectAnswer,
        createAlgebraProblemType
      } = require_helpers2();
      var problemTypes = [
        {
          id: "arith-nth",
          label: "유형 1 · 등차수열 일반항",
          difficulty: 1,
          generate() {
            const a1 = randomInteger(-5, 5), d = nonZeroInteger(-4, 4), n = randomInteger(3, 10);
            return {
              prompt: `첫째항 ${a1}, 공차 ${d} 인 등차수열의 a_${n} 을 구하세요.`,
              inputMode: "short-answer",
              answer: a1 + (n - 1) * d,
              solution: `a_n=a₁+(n−1)d=${a1}+${n - 1}×${d}=${a1 + (n - 1) * d}.`
            };
          }
        },
        {
          id: "arith-common-diff",
          label: "유형 2 · 공차 구하기",
          difficulty: 1,
          generate() {
            const a1 = randomInteger(-4, 4), d = nonZeroInteger(-4, 4);
            return {
              prompt: `등차수열의 a₁=${a1}, a₂=${a1 + d} 일 때 공차 d 를 구하세요.`,
              inputMode: "short-answer",
              answer: d,
              solution: `d=a₂−a₁=${a1 + d}−${a1}=${d}.`
            };
          }
        },
        {
          id: "arith-sum",
          label: "유형 3 · 등차수열의 합",
          difficulty: 2,
          generate() {
            const a1 = randomInteger(-3, 5), d = nonZeroInteger(-3, 3), n = randomInteger(3, 10);
            let s = 0;
            for (let k = 0; k < n; k++) s += a1 + k * d;
            return {
              prompt: `첫째항 ${a1}, 공차 ${d} 인 등차수열의 첫째항부터 제${n}항까지의 합 S_${n} 을 구하세요.`,
              inputMode: "short-answer",
              answer: s,
              solution: `S_n=n(2a₁+(n−1)d)/2=${s}.`
            };
          }
        },
        {
          id: "arith-first-from",
          label: "유형 4 · 특정항으로 첫째항",
          difficulty: 2,
          generate() {
            const a1 = randomInteger(-4, 4), d = nonZeroInteger(-3, 3), n = randomInteger(3, 8), an = a1 + (n - 1) * d;
            return {
              prompt: `공차 ${d} 인 등차수열에서 a_${n}=${an} 일 때 첫째항 a₁ 을 구하세요.`,
              inputMode: "short-answer",
              answer: a1,
              solution: `a₁=a_${n}−(${n}−1)×${d}=${an}−${(n - 1) * d}=${a1}.`
            };
          }
        },
        {
          id: "arith-d-from-two",
          label: "유형 5 · 두 항으로 공차",
          difficulty: 3,
          generate() {
            const a1 = randomInteger(-4, 4), d = nonZeroInteger(-3, 3), m = randomInteger(2, 4), n = m + randomInteger(2, 4);
            return {
              prompt: `등차수열에서 a_${m}=${a1 + (m - 1) * d}, a_${n}=${a1 + (n - 1) * d} 일 때 공차 d 를 구하세요.`,
              inputMode: "short-answer",
              answer: d,
              solution: `d=(a_${n}−a_${m})/(${n}−${m})=${d}.`
            };
          }
        },
        {
          id: "arith-mean",
          label: "유형 6 · 등차중항",
          difficulty: 1,
          generate() {
            const a = randomInteger(-6, 6), c = a + 2 * nonZeroInteger(1, 5);
            return {
              prompt: `세 수 ${a}, x, ${c} 가 등차수열을 이룰 때 x 를 구하세요.`,
              inputMode: "short-answer",
              answer: (a + c) / 2,
              solution: `x=(${a}+${c})/2=${(a + c) / 2}.`
            };
          }
        },
        {
          id: "arith-sum-endpoints",
          label: "유형 7 · 합(첫째항·끝항)",
          difficulty: 2,
          generate() {
            const a1 = randomInteger(1, 5), d = randomInteger(1, 4), n = randomInteger(4, 10), an = a1 + (n - 1) * d;
            return {
              prompt: `첫째항 ${a1}, 제${n}항 ${an} 인 등차수열의 첫째항부터 제${n}항까지의 합을 구하세요.`,
              inputMode: "short-answer",
              answer: n * (a1 + an) / 2,
              solution: `S=n(a₁+a_n)/2=${n}×(${a1}+${an})/2=${n * (a1 + an) / 2}.`
            };
          }
        },
        {
          id: "arith-index",
          label: "유형 8 · 항 번호 찾기",
          difficulty: 2,
          generate() {
            const a1 = randomInteger(-3, 3), d = nonZeroInteger(1, 4), n = randomInteger(3, 10), an = a1 + (n - 1) * d;
            return {
              prompt: `첫째항 ${a1}, 공차 ${d} 인 등차수열에서 ${an} 은 제몇 항인가요?`,
              inputMode: "short-answer",
              answer: n,
              solution: `a₁+(n−1)d=${an} → n=${n}.`
            };
          }
        },
        {
          id: "arith-partial",
          label: "유형 9 · 부분합 계산",
          difficulty: 2,
          generate() {
            const a1 = randomInteger(1, 4), d = randomInteger(1, 3), n = randomInteger(3, 8);
            let s = 0;
            for (let k = 0; k < n; k++) s += a1 + k * d;
            return {
              prompt: `첫째항 ${a1}, 공차 ${d} 인 등차수열의 처음 ${n}개 항의 합을 구하세요.`,
              inputMode: "short-answer",
              answer: s,
              solution: `합=${s}.`
            };
          }
        },
        {
          id: "arith-three",
          label: "유형 10 · 등차 세 수",
          difficulty: 2,
          generate() {
            const m = randomInteger(2, 8), d = nonZeroInteger(1, 4);
            return {
              prompt: `연속된 세 등차항이 ${m - d}, ${m}, ${m + d} 일 때 가운데 항을 확인하고 세 항의 합을 구하세요.`,
              inputMode: "short-answer",
              answer: 3 * m,
              solution: `세 항의 합=3×(가운데 항)=3×${m}=${3 * m}.`
            };
          }
        }
      ].map(
        (problemType) => createAlgebraProblemType(problemType, {
          conceptId: "algebra-03-02",
          conceptTitle: "등차수열"
        })
      );
      module.exports = {
        key: "algebra-arithmetic-sequences",
        requiredDistinctTypes: 5,
        problemTypes,
        isCorrectAnswer
      };
    }
  });

  // services/problemGenerators/algebra/geometricSequences.js
  var require_geometricSequences = __commonJS({
    "services/problemGenerators/algebra/geometricSequences.js"(exports, module) {
      var {
        randomInteger,
        nonZeroInteger,
        round4,
        isCorrectAnswer,
        createAlgebraProblemType
      } = require_helpers2();
      var problemTypes = [
        {
          id: "geo-nth",
          label: "유형 1 · 등비수열 일반항",
          difficulty: 2,
          generate() {
            const a1 = randomInteger(1, 4), r = randomInteger(2, 3), n = randomInteger(2, 5);
            return {
              prompt: `첫째항 ${a1}, 공비 ${r} 인 등비수열의 a_${n} 을 구하세요.`,
              inputMode: "short-answer",
              answer: a1 * r ** (n - 1),
              solution: `a_n=a₁r^(n−1)=${a1}×${r}^${n - 1}=${a1 * r ** (n - 1)}.`
            };
          }
        },
        {
          id: "geo-ratio",
          label: "유형 2 · 공비 구하기",
          difficulty: 1,
          generate() {
            const a1 = randomInteger(1, 4), r = randomInteger(2, 4);
            return {
              prompt: `등비수열의 a₁=${a1}, a₂=${a1 * r} 일 때 공비 r 을 구하세요.`,
              inputMode: "short-answer",
              answer: r,
              solution: `r=a₂/a₁=${a1 * r}/${a1}=${r}.`
            };
          }
        },
        {
          id: "geo-sum",
          label: "유형 3 · 등비수열의 합",
          difficulty: 2,
          generate() {
            const a1 = randomInteger(1, 4), r = 2, n = randomInteger(2, 6);
            let s = 0;
            for (let k = 0; k < n; k++) s += a1 * r ** k;
            return {
              prompt: `첫째항 ${a1}, 공비 ${r} 인 등비수열의 첫째항부터 제${n}항까지의 합을 구하세요.`,
              inputMode: "short-answer",
              answer: s,
              solution: `S_n=a₁(rⁿ−1)/(r−1)=${s}.`
            };
          }
        },
        {
          id: "geo-mean",
          label: "유형 4 · 등비중항",
          difficulty: 2,
          generate() {
            const b = randomInteger(2, 6);
            const a = randomInteger(1, 4);
            const c = b * b / a;
            const aa = 1;
            const bb = randomInteger(2, 6);
            return {
              prompt: `세 양수 1, x, ${bb * bb} 가 등비수열을 이룰 때 양수 x 를 구하세요.`,
              inputMode: "short-answer",
              answer: bb,
              solution: `x²=1×${bb * bb} → x=${bb}.`
            };
          }
        },
        {
          id: "geo-term-from",
          label: "유형 5 · 특정항으로 첫째항",
          difficulty: 3,
          generate() {
            const a1 = randomInteger(1, 4), r = randomInteger(2, 3), n = randomInteger(2, 4), an = a1 * r ** (n - 1);
            return {
              prompt: `공비 ${r} 인 등비수열에서 a_${n}=${an} 일 때 첫째항 a₁ 을 구하세요.`,
              inputMode: "short-answer",
              answer: a1,
              solution: `a₁=a_${n}/r^(${n}−1)=${an}/${r ** (n - 1)}=${a1}.`
            };
          }
        },
        {
          id: "geo-ratio-two",
          label: "유형 6 · 두 항으로 공비",
          difficulty: 3,
          generate() {
            const a1 = randomInteger(1, 3), r = randomInteger(2, 3);
            return {
              prompt: `등비수열에서 a₁=${a1}, a₃=${a1 * r * r} 일 때 공비 r(양수) 을 구하세요.`,
              inputMode: "short-answer",
              answer: r,
              solution: `r²=a₃/a₁=${r * r} → r=${r}.`
            };
          }
        },
        {
          id: "geo-sum-r3",
          label: "유형 7 · 등비합(공비 3)",
          difficulty: 2,
          generate() {
            const a1 = randomInteger(1, 3), r = 3, n = randomInteger(2, 5);
            let s = 0;
            for (let k = 0; k < n; k++) s += a1 * r ** k;
            return {
              prompt: `첫째항 ${a1}, 공비 ${r} 인 등비수열의 처음 ${n}개 항의 합을 구하세요.`,
              inputMode: "short-answer",
              answer: s,
              solution: `합=${s}.`
            };
          }
        },
        {
          id: "geo-index",
          label: "유형 8 · 항 번호 찾기",
          difficulty: 3,
          generate() {
            const a1 = randomInteger(1, 3), r = 2, n = randomInteger(2, 6), an = a1 * r ** (n - 1);
            return {
              prompt: `첫째항 ${a1}, 공비 ${r} 인 등비수열에서 ${an} 은 제몇 항인가요?`,
              inputMode: "short-answer",
              answer: n,
              solution: `a₁·2^(n−1)=${an} → n=${n}.`
            };
          }
        },
        {
          id: "geo-three",
          label: "유형 9 · 등비 세 수의 곱",
          difficulty: 2,
          generate() {
            const m = randomInteger(2, 5), r = randomInteger(2, 3);
            return {
              prompt: `연속된 세 등비항이 ${m}, ${m * r}, ${m * r * r} 일 때 가운데 항을 구하세요.`,
              inputMode: "short-answer",
              answer: m * r,
              solution: `가운데 항=${m}×${r}=${m * r}.`
            };
          }
        },
        {
          id: "geo-first",
          label: "유형 10 · 공비와 항으로 첫째항",
          difficulty: 2,
          generate() {
            const a1 = randomInteger(1, 4), r = randomInteger(2, 3), a2 = a1 * r;
            return {
              prompt: `공비 ${r} 인 등비수열에서 a₂=${a2} 일 때 첫째항 a₁ 을 구하세요.`,
              inputMode: "short-answer",
              answer: a1,
              solution: `a₁=a₂/r=${a2}/${r}=${a1}.`
            };
          }
        }
      ].map(
        (problemType) => createAlgebraProblemType(problemType, {
          conceptId: "algebra-03-03",
          conceptTitle: "등비수열"
        })
      );
      module.exports = {
        key: "algebra-geometric-sequences",
        requiredDistinctTypes: 5,
        problemTypes,
        isCorrectAnswer
      };
    }
  });

  // services/problemGenerators/algebra/sigmaDefinitionAndProperties.js
  var require_sigmaDefinitionAndProperties = __commonJS({
    "services/problemGenerators/algebra/sigmaDefinitionAndProperties.js"(exports, module) {
      var {
        randomInteger,
        nonZeroInteger,
        round4,
        isCorrectAnswer,
        createAlgebraProblemType
      } = require_helpers2();
      var problemTypes = [
        {
          id: "sigma-k",
          label: "유형 1 · Σk",
          difficulty: 1,
          generate() {
            const n = randomInteger(3, 12);
            let s = 0;
            for (let k = 1; k <= n; k++) s += k;
            return { prompt: `Σ_{k=1}^{${n}} k 를 구하세요.`, inputMode: "short-answer", answer: s, solution: `n(n+1)/2=${s}.` };
          }
        },
        {
          id: "sigma-k2",
          label: "유형 2 · Σk²",
          difficulty: 2,
          generate() {
            const n = randomInteger(3, 9);
            let s = 0;
            for (let k = 1; k <= n; k++) s += k * k;
            return { prompt: `Σ_{k=1}^{${n}} k² 를 구하세요.`, inputMode: "short-answer", answer: s, solution: `n(n+1)(2n+1)/6=${s}.` };
          }
        },
        {
          id: "sigma-k3",
          label: "유형 3 · Σk³",
          difficulty: 2,
          generate() {
            const n = randomInteger(2, 6);
            let s = 0;
            for (let k = 1; k <= n; k++) s += k ** 3;
            return { prompt: `Σ_{k=1}^{${n}} k³ 를 구하세요.`, inputMode: "short-answer", answer: s, solution: `{n(n+1)/2}²=${s}.` };
          }
        },
        {
          id: "sigma-const",
          label: "유형 4 · Σ 상수",
          difficulty: 1,
          generate() {
            const n = randomInteger(3, 10), c = nonZeroInteger(-5, 5);
            return { prompt: `Σ_{k=1}^{${n}} ${c} 를 구하세요.`, inputMode: "short-answer", answer: c * n, solution: `${c}×${n}=${c * n}.` };
          }
        },
        {
          id: "sigma-linear",
          label: "유형 5 · 시그마의 선형성",
          difficulty: 2,
          generate() {
            const n = randomInteger(3, 8), a = randomInteger(2, 4), b = randomInteger(-3, 3);
            let s = 0;
            for (let k = 1; k <= n; k++) s += a * k + b;
            return { prompt: `Σ_{k=1}^{${n}} (${a}k + ${b}) 를 구하세요.`, inputMode: "short-answer", answer: s, solution: `${a}Σk+Σ${b}=${s}.` };
          }
        },
        {
          id: "sigma-quad",
          label: "유형 6 · Σ(k²+k)",
          difficulty: 2,
          generate() {
            const n = randomInteger(3, 8);
            let s = 0;
            for (let k = 1; k <= n; k++) s += k * k + k;
            return { prompt: `Σ_{k=1}^{${n}} (k² + k) 를 구하세요.`, inputMode: "short-answer", answer: s, solution: `Σk²+Σk=${s}.` };
          }
        },
        {
          id: "sigma-odd",
          label: "유형 7 · Σ(2k−1)=n²",
          difficulty: 2,
          generate() {
            const n = randomInteger(3, 10);
            let s = 0;
            for (let k = 1; k <= n; k++) s += 2 * k - 1;
            return { prompt: `Σ_{k=1}^{${n}} (2k−1) 를 구하세요.`, inputMode: "short-answer", answer: s, solution: `홀수의 합=n²=${s}.` };
          }
        },
        {
          id: "sigma-product",
          label: "유형 8 · Σk(k+1)",
          difficulty: 3,
          generate() {
            const n = randomInteger(3, 7);
            let s = 0;
            for (let k = 1; k <= n; k++) s += k * (k + 1);
            return { prompt: `Σ_{k=1}^{${n}} k(k+1) 를 구하세요.`, inputMode: "short-answer", answer: s, solution: `Σk²+Σk=${s}.` };
          }
        },
        {
          id: "sigma-shift",
          label: "유형 9 · Σ(k+상수)",
          difficulty: 2,
          generate() {
            const n = randomInteger(3, 9), c = randomInteger(1, 5);
            let s = 0;
            for (let k = 1; k <= n; k++) s += k + c;
            return { prompt: `Σ_{k=1}^{${n}} (k + ${c}) 를 구하세요.`, inputMode: "short-answer", answer: s, solution: `Σk + ${c}n = ${s}.` };
          }
        },
        {
          id: "sigma-geo",
          label: "유형 10 · Σ 2ᵏ",
          difficulty: 3,
          generate() {
            const n = randomInteger(2, 8);
            let s = 0;
            for (let k = 1; k <= n; k++) s += 2 ** k;
            return { prompt: `Σ_{k=1}^{${n}} 2ᵏ 를 구하세요.`, inputMode: "short-answer", answer: s, solution: `2^(n+1)−2=${s}.` };
          }
        }
      ].map(
        (problemType) => createAlgebraProblemType(problemType, {
          conceptId: "algebra-03-04",
          conceptTitle: "시그마(Σ)의 뜻과 성질"
        })
      );
      module.exports = {
        key: "algebra-sigma-definition-and-properties",
        requiredDistinctTypes: 5,
        problemTypes,
        isCorrectAnswer
      };
    }
  });

  // services/problemGenerators/algebra/sumsOfVariousSequences.js
  var require_sumsOfVariousSequences = __commonJS({
    "services/problemGenerators/algebra/sumsOfVariousSequences.js"(exports, module) {
      var {
        randomInteger,
        nonZeroInteger,
        round4,
        isCorrectAnswer,
        createAlgebraProblemType
      } = require_helpers2();
      var problemTypes = [
        {
          id: "tele-1",
          label: "유형 1 · Σ1/(k(k+1))",
          difficulty: 3,
          generate() {
            const n = randomInteger(3, 9);
            let s = 0;
            for (let k = 1; k <= n; k++) s += 1 / (k * (k + 1));
            return { prompt: `Σ_{k=1}^{${n}} 1/(k(k+1)) 를 구하세요. (소수)`, inputMode: "short-answer", answer: round4(s), solution: `1−1/${n + 1}=${round4(s)}.` };
          }
        },
        {
          id: "tele-2",
          label: "유형 2 · Σ1/((2k−1)(2k+1))",
          difficulty: 3,
          generate() {
            const n = randomInteger(3, 8);
            let s = 0;
            for (let k = 1; k <= n; k++) s += 1 / ((2 * k - 1) * (2 * k + 1));
            return { prompt: `Σ_{k=1}^{${n}} 1/((2k−1)(2k+1)) 를 구하세요. (소수)`, inputMode: "short-answer", answer: round4(s), solution: `½(1−1/${2 * n + 1})=${round4(s)}.` };
          }
        },
        {
          id: "tele-3",
          label: "유형 3 · Σ1/(k(k+2))",
          difficulty: 3,
          generate() {
            const n = randomInteger(3, 8);
            let s = 0;
            for (let k = 1; k <= n; k++) s += 1 / (k * (k + 2));
            return { prompt: `Σ_{k=1}^{${n}} 1/(k(k+2)) 를 구하세요. (소수)`, inputMode: "short-answer", answer: round4(s), solution: `부분분수로 망원합=${round4(s)}.` };
          }
        },
        {
          id: "sum-kk1-closed",
          label: "유형 4 · Σk(k+1)의 값",
          difficulty: 2,
          generate() {
            const n = randomInteger(3, 7);
            let s = 0;
            for (let k = 1; k <= n; k++) s += k * (k + 1);
            return { prompt: `Σ_{k=1}^{${n}} k(k+1) 를 구하세요.`, inputMode: "short-answer", answer: s, solution: `n(n+1)(n+2)/3=${s}.` };
          }
        },
        {
          id: "sum-2k1",
          label: "유형 5 · Σ(2k+1)",
          difficulty: 2,
          generate() {
            const n = randomInteger(3, 9);
            let s = 0;
            for (let k = 1; k <= n; k++) s += 2 * k + 1;
            return { prompt: `Σ_{k=1}^{${n}} (2k+1) 를 구하세요.`, inputMode: "short-answer", answer: s, solution: `n²+2n=${s}.` };
          }
        },
        {
          id: "sum-partial-terms",
          label: "유형 6 · 부분합의 차",
          difficulty: 3,
          generate() {
            const n = randomInteger(3, 7);
            let s = 0;
            for (let k = 1; k <= n; k++) s += k * k;
            return { prompt: `Σ_{k=1}^{${n}} k² 의 값을 구하세요.`, inputMode: "short-answer", answer: s, solution: `n(n+1)(2n+1)/6=${s}.` };
          }
        },
        {
          id: "sum-arith-geo-mix",
          label: "유형 7 · Σ(3k−2)",
          difficulty: 2,
          generate() {
            const n = randomInteger(3, 9);
            let s = 0;
            for (let k = 1; k <= n; k++) s += 3 * k - 2;
            return { prompt: `Σ_{k=1}^{${n}} (3k−2) 를 구하세요.`, inputMode: "short-answer", answer: s, solution: `3Σk−2n=${s}.` };
          }
        },
        {
          id: "sum-square-diff",
          label: "유형 8 · Σ(k²−1)",
          difficulty: 2,
          generate() {
            const n = randomInteger(3, 8);
            let s = 0;
            for (let k = 1; k <= n; k++) s += k * k - 1;
            return { prompt: `Σ_{k=1}^{${n}} (k²−1) 를 구하세요.`, inputMode: "short-answer", answer: s, solution: `Σk²−n=${s}.` };
          }
        },
        {
          id: "sum-tele-frac",
          label: "유형 9 · Σ(1/k − 1/(k+1))",
          difficulty: 3,
          generate() {
            const n = randomInteger(3, 9);
            const s = 1 - 1 / (n + 1);
            return { prompt: `Σ_{k=1}^{${n}} (1/k − 1/(k+1)) 를 구하세요. (소수)`, inputMode: "short-answer", answer: round4(s), solution: `망원합=1−1/${n + 1}=${round4(s)}.` };
          }
        },
        {
          id: "sum-cubes-value",
          label: "유형 10 · Σk³ 값",
          difficulty: 2,
          generate() {
            const n = randomInteger(2, 6);
            let s = 0;
            for (let k = 1; k <= n; k++) s += k ** 3;
            return { prompt: `Σ_{k=1}^{${n}} k³ 를 구하세요.`, inputMode: "short-answer", answer: s, solution: `{n(n+1)/2}²=${s}.` };
          }
        }
      ].map(
        (problemType) => createAlgebraProblemType(problemType, {
          conceptId: "algebra-03-05",
          conceptTitle: "여러 가지 수열의 합"
        })
      );
      module.exports = {
        key: "algebra-sums-of-various-sequences",
        requiredDistinctTypes: 5,
        problemTypes,
        isCorrectAnswer
      };
    }
  });

  // services/problemGenerators/algebra/recursiveSequences.js
  var require_recursiveSequences = __commonJS({
    "services/problemGenerators/algebra/recursiveSequences.js"(exports, module) {
      var {
        randomInteger,
        nonZeroInteger,
        round4,
        iterate,
        isCorrectAnswer,
        createAlgebraProblemType
      } = require_helpers2();
      var problemTypes = [
        {
          id: "rec-add",
          label: "유형 1 · a_{n+1}=a_n+d",
          difficulty: 1,
          generate() {
            const a1 = randomInteger(1, 6), d = nonZeroInteger(-3, 4);
            const a3 = iterate(a1, (a) => a + d, 3);
            return { prompt: `a₁=${a1}, a_{n+1}=a_n+${d} 일 때 a₃ 을 구하세요.`, inputMode: "short-answer", answer: a3, solution: `a₂=${a1 + d}, a₃=${a3}.` };
          }
        },
        {
          id: "rec-mult",
          label: "유형 2 · a_{n+1}=r·a_n",
          difficulty: 2,
          generate() {
            const a1 = randomInteger(1, 4), r = randomInteger(2, 3);
            const a3 = iterate(a1, (a) => a * r, 3);
            return { prompt: `a₁=${a1}, a_{n+1}=${r}·a_n 일 때 a₃ 을 구하세요.`, inputMode: "short-answer", answer: a3, solution: `a₂=${a1 * r}, a₃=${a3}.` };
          }
        },
        {
          id: "rec-add-n",
          label: "유형 3 · a_{n+1}=a_n+2n",
          difficulty: 2,
          generate() {
            const a1 = randomInteger(1, 5);
            const a4 = iterate(a1, (a, n) => a + 2 * n, 4);
            return { prompt: `a₁=${a1}, a_{n+1}=a_n+2n 일 때 a₄ 를 구하세요.`, inputMode: "short-answer", answer: a4, solution: `순서대로 계산하면 a₄=${a4}.` };
          }
        },
        {
          id: "rec-affine",
          label: "유형 4 · a_{n+1}=2a_n+1",
          difficulty: 2,
          generate() {
            const a1 = randomInteger(1, 4);
            const a3 = iterate(a1, (a) => 2 * a + 1, 3);
            return { prompt: `a₁=${a1}, a_{n+1}=2a_n+1 일 때 a₃ 을 구하세요.`, inputMode: "short-answer", answer: a3, solution: `a₂=${2 * a1 + 1}, a₃=${a3}.` };
          }
        },
        {
          id: "rec-fib",
          label: "유형 5 · a_{n+2}=a_{n+1}+a_n",
          difficulty: 3,
          generate() {
            const a1 = randomInteger(1, 4), a2 = randomInteger(1, 5);
            const a4 = a1 + a2 + a2;
            return { prompt: `a₁=${a1}, a₂=${a2}, a_{n+2}=a_{n+1}+a_n 일 때 a₄ 를 구하세요.`, inputMode: "short-answer", answer: a4, solution: `a₃=${a1 + a2}, a₄=${a4}.` };
          }
        },
        {
          id: "rec-add5",
          label: "유형 6 · 다섯째항 구하기",
          difficulty: 2,
          generate() {
            const a1 = randomInteger(1, 5), d = nonZeroInteger(1, 4);
            const a5 = iterate(a1, (a) => a + d, 5);
            return { prompt: `a₁=${a1}, a_{n+1}=a_n+${d} 일 때 a₅ 를 구하세요.`, inputMode: "short-answer", answer: a5, solution: `a₅=${a5}.` };
          }
        },
        {
          id: "rec-known-two",
          label: "유형 7 · 두 항 주어진 등차형",
          difficulty: 2,
          generate() {
            const a1 = randomInteger(1, 5), d = nonZeroInteger(1, 4);
            const a4 = iterate(a1, (a) => a + d, 4);
            return { prompt: `a₁=${a1}, a₂=${a1 + d}, 공차가 일정할 때 a₄ 를 구하세요.`, inputMode: "short-answer", answer: a4, solution: `공차 ${d} → a₄=${a4}.` };
          }
        },
        {
          id: "rec-half",
          label: "유형 8 · a_{n+1}=a_n/2",
          difficulty: 2,
          generate() {
            const a1 = 8 * randomInteger(1, 3);
            const a3 = iterate(a1, (a) => a / 2, 3);
            return { prompt: `a₁=${a1}, a_{n+1}=a_n/2 일 때 a₃ 을 구하세요.`, inputMode: "short-answer", answer: a3, solution: `a₂=${a1 / 2}, a₃=${a3}.` };
          }
        },
        {
          id: "rec-add-nsq",
          label: "유형 9 · a_{n+1}=a_n+n²",
          difficulty: 3,
          generate() {
            const a1 = randomInteger(1, 4);
            const a3 = iterate(a1, (a, n) => a + n * n, 3);
            return { prompt: `a₁=${a1}, a_{n+1}=a_n+n² 일 때 a₃ 을 구하세요.`, inputMode: "short-answer", answer: a3, solution: `a₂=${a1 + 1}, a₃=${a3}.` };
          }
        },
        {
          id: "rec-triple",
          label: "유형 10 · a_{n+1}=3a_n",
          difficulty: 2,
          generate() {
            const a1 = randomInteger(1, 3);
            const a4 = iterate(a1, (a) => 3 * a, 4);
            return { prompt: `a₁=${a1}, a_{n+1}=3a_n 일 때 a₄ 를 구하세요.`, inputMode: "short-answer", answer: a4, solution: `a₄=${a4}.` };
          }
        }
      ].map(
        (problemType) => createAlgebraProblemType(problemType, {
          conceptId: "algebra-03-06",
          conceptTitle: "수열의 귀납적 정의"
        })
      );
      module.exports = {
        key: "algebra-recursive-sequences",
        requiredDistinctTypes: 5,
        problemTypes,
        isCorrectAnswer
      };
    }
  });

  // services/problemGenerators/algebra/mathematicalInduction.js
  var require_mathematicalInduction = __commonJS({
    "services/problemGenerators/algebra/mathematicalInduction.js"(exports, module) {
      var {
        randomInteger,
        nonZeroInteger,
        round4,
        isCorrectAnswer,
        createAlgebraProblemType
      } = require_helpers2();
      var problemTypes = [
        {
          id: "domino-idea",
          label: "유형 1 · 귀납법의 원리(도미노)",
          difficulty: 1,
          generate() {
            const start = randomInteger(1, 4);
            return {
              prompt: `P(${start})가 참이고, k≥${start}에서 P(k)가 참이면 P(k+1)도 참임을 보였습니다. 결론은?`,
              inputMode: "multiple-choice",
              choices: [
                {
                  key: "all",
                  text: `모든 자연수 n≥${start}에서 P(n)이 참`
                },
                {
                  key: "some",
                  text: `n=${start}에서만 P(n)이 참`
                }
              ],
              answer: "all",
              solution: `기초 단계 P(${start})와 귀납 단계가 모두 성립하므로 모든 자연수 n≥${start}에서 P(n)이 참입니다.`
            };
          }
        },
        {
          id: "base-check-sum",
          label: "유형 2 · n=1 확인(합)",
          difficulty: 1,
          generate() {
            const variants = [
              "1+2+…+n=n(n+1)/2",
              "1+3+…+(2n-1)=n²",
              "1²+2²+…+n²=n(n+1)(2n+1)/6"
            ];
            const statement = variants[randomInteger(0, variants.length - 1)];
            return {
              prompt: `등식 ${statement}의 기초 단계에서 n=1일 때 좌변의 값을 구하세요.`,
              inputMode: "short-answer",
              answer: 1,
              solution: `n=1이면 좌변에는 첫 번째 항 1만 남으므로 값은 1입니다.`
            };
          }
        },
        {
          id: "hypothesis-step",
          label: "유형 3 · 가정 단계 개념",
          difficulty: 2,
          generate() {
            const statement = Math.random() < 0.5 ? "1+2+…+n=n(n+1)/2" : "1+3+…+(2n-1)=n²";
            return {
              prompt: `명제 P(n): ${statement}을 귀납법으로 증명할 때 귀납 가정은?`,
              inputMode: "multiple-choice",
              choices: [
                {
                  key: "ind",
                  text: `P(k)가 참이라고 가정한다.`
                },
                {
                  key: "base",
                  text: `P(k+1)가 참이라고 먼저 가정한다.`
                }
              ],
              answer: "ind",
              solution: `귀납 단계에서는 P(k)가 참이라고 가정하고 P(k+1)을 증명합니다.`
            };
          }
        },
        {
          id: "verify-kplus1",
          label: "유형 4 · n=k+1 좌변 값",
          difficulty: 2,
          generate() {
            const k = randomInteger(2, 6);
            let s = 0;
            for (let i = 1; i <= k + 1; i++) s += i;
            return { prompt: `1+2+…+n 에서 n=${k + 1} 일 때의 합을 구하세요.`, inputMode: "short-answer", answer: s, solution: `${k + 1}(${k + 2})/2=${s}.` };
          }
        },
        {
          id: "sum-formula-value",
          label: "유형 5 · 등식 P(n) 좌변 값",
          difficulty: 1,
          generate() {
            const n = randomInteger(3, 8);
            let s = 0;
            for (let i = 1; i <= n; i++) s += i;
            return { prompt: `1+2+…+${n} 의 값을 구하세요.`, inputMode: "short-answer", answer: s, solution: `${n}(${n + 1})/2=${s}.` };
          }
        },
        {
          id: "odd-sum-value",
          label: "유형 6 · 홀수합 P(n)=n²",
          difficulty: 2,
          generate() {
            const n = randomInteger(3, 9);
            return { prompt: `1+3+5+…+(2×${n}−1) 의 값을 구하세요.`, inputMode: "short-answer", answer: n * n, solution: `홀수 ${n}개의 합=${n}²=${n * n}.` };
          }
        },
        {
          id: "step-order",
          label: "유형 7 · 증명 단계 순서",
          difficulty: 2,
          generate() {
            const start = randomInteger(1, 4);
            return {
              prompt: `n≥${start}에서 명제 P(n)을 귀납법으로 증명할 때 올바른 순서는?`,
              inputMode: "multiple-choice",
              choices: [
                {
                  key: "ok",
                  text: `① P(${start}) 확인 → ② P(k) 가정 → ③ P(k+1) 증명`
                },
                {
                  key: "no",
                  text: `① P(k+1) 가정 → ② P(${start}) 생략`
                }
              ],
              answer: "ok",
              solution: `기초 단계 P(${start})를 확인한 뒤 귀납 가정과 P(k+1)의 증명 순서로 진행합니다.`
            };
          }
        },
        {
          id: "base-holds",
          label: "유형 8 · 기초단계 성립 판정",
          difficulty: 1,
          generate() {
            const offset = Math.random() < 0.5 ? 0 : 1;
            return {
              prompt: `등식 1+2+…+n=n(n+1)/2+${offset}에서 n=1일 때 좌변과 우변이 같습니까?`,
              inputMode: "multiple-choice",
              choices: [
                {
                  key: "y",
                  text: "같다(기초 단계 성립)"
                },
                {
                  key: "n",
                  text: "다르다(기초 단계 불성립)"
                }
              ],
              answer: offset === 0 ? "y" : "n",
              solution: `n=1일 때 좌변은 1, 우변은 ${1 + offset}이므로 ${offset === 0 ? "같습니다." : "다릅니다."}`
            };
          }
        },
        {
          id: "inequality-min",
          label: "유형 9 · 부등식 2ⁿ>n² 최소 n",
          difficulty: 3,
          generate() {
            const powers = [
              { exponent: 1, answer: 1 },
              { exponent: 2, answer: 5 },
              { exponent: 3, answer: 10 }
            ];
            const variant = powers[randomInteger(0, powers.length - 1)];
            return {
              prompt: `n≥m인 모든 자연수에서 2ⁿ>n^${variant.exponent}이 성립하기 시작하는 최소 자연수 m을 구하세요.`,
              inputMode: "short-answer",
              answer: variant.answer,
              solution: `작은 자연수부터 비교하면 n=${variant.answer}부터 2ⁿ>n^${variant.exponent}이 계속 성립합니다.`
            };
          }
        },
        {
          id: "odd-sum-check",
          label: "유형 10 · 홀수합 확인",
          difficulty: 2,
          generate() {
            const n = randomInteger(2, 7);
            let s = 0;
            for (let i = 1; i <= n; i++) s += 2 * i - 1;
            return { prompt: `1+3+…+(2×${n}−1) 이 ${n}² 과 같은지 확인하기 위해 좌변을 계산하세요.`, inputMode: "short-answer", answer: s, solution: `좌변=${s}=${n}².` };
          }
        }
      ].map(
        (problemType) => createAlgebraProblemType(problemType, {
          conceptId: "algebra-03-07",
          conceptTitle: "수학적 귀납법"
        })
      );
      module.exports = {
        key: "algebra-mathematical-induction",
        requiredDistinctTypes: 5,
        problemTypes,
        isCorrectAnswer
      };
    }
  });

  // services/problemGenerators/probabilityStatistics/helpers.js
  var require_helpers3 = __commonJS({
    "services/problemGenerators/probabilityStatistics/helpers.js"(exports, module) {
      var {
        randomInteger,
        isCorrectAnswer
      } = require_utils();
      var {
        formatAlgebraMathText
      } = require_mathTextService();
      function inlineMath(tex) {
        return `\\(${tex}\\)`;
      }
      function displayMath(tex) {
        return `\\[${tex}\\]`;
      }
      function factorial(n) {
        let value = 1;
        for (let index = 2; index <= n; index += 1) {
          value *= index;
        }
        return value;
      }
      function combination(n, r) {
        if (r < 0 || r > n) return 0;
        const k = Math.min(r, n - r);
        let value = 1;
        for (let index = 1; index <= k; index += 1) {
          value = value * (n - k + index) / index;
        }
        return Math.round(value);
      }
      function permutation(n, r) {
        return factorial(n) / factorial(n - r);
      }
      function gcd(a, b) {
        let left = Math.abs(Math.round(a));
        let right = Math.abs(Math.round(b));
        while (right) {
          [left, right] = [right, left % right];
        }
        return left || 1;
      }
      function fractionText(numerator, denominator) {
        const divisor = gcd(numerator, denominator);
        const n = numerator / divisor;
        const d = denominator / divisor;
        return d === 1 ? String(n) : `\\frac{${n}}{${d}}`;
      }
      function round4(value) {
        return Math.round(value * 1e4) / 1e4;
      }
      function shortAnswer({
        prompt,
        answer,
        solution,
        hintText,
        visualization
      }) {
        return {
          prompt,
          inputMode: "short-answer",
          answer: round4(answer),
          solution,
          hintText,
          visualization
        };
      }
      function multipleChoice({
        prompt,
        choices,
        answerIndex,
        solution,
        hintText,
        visualization
      }) {
        const shuffledChoices = choices.map(
          (text, index) => ({
            text,
            correct: index === answerIndex
          })
        );
        for (let index = shuffledChoices.length - 1; index > 0; index -= 1) {
          const swapIndex = randomInteger(0, index);
          [
            shuffledChoices[index],
            shuffledChoices[swapIndex]
          ] = [
            shuffledChoices[swapIndex],
            shuffledChoices[index]
          ];
        }
        const normalizedChoices = shuffledChoices.map(
          (choice, index) => ({
            key: String.fromCharCode(65 + index),
            text: choice.text,
            correct: choice.correct
          })
        );
        const correctChoice = normalizedChoices.find(
          (choice) => choice.correct
        );
        return {
          prompt,
          inputMode: "multiple-choice",
          choices: normalizedChoices.map(
            ({ key, text }) => ({ key, text })
          ),
          answer: correctChoice.key,
          solution,
          hintText,
          visualization
        };
      }
      function createProblemTypes({
        conceptId,
        conceptTitle,
        labels,
        buildProblems
      }) {
        return labels.map((label, index) => ({
          id: `${conceptId}-type-${String(index + 1).padStart(2, "0")}`,
          label: `유형 ${index + 1} · ${label}`,
          difficulty: index < 3 ? 1 : index < 7 ? 2 : 3,
          generate() {
            const problems = buildProblems();
            const generated = problems[index];
            if (!generated) {
              throw new Error(
                `${conceptTitle}의 ${index + 1}번 문제 유형이 없습니다.`
              );
            }
            return {
              ...generated,
              prompt: formatAlgebraMathText(
                generated.prompt
              ),
              solution: formatAlgebraMathText(
                generated.solution
              ),
              choices: Array.isArray(
                generated.choices
              ) ? generated.choices.map((choice) => ({
                ...choice,
                text: formatAlgebraMathText(
                  choice.text
                )
              })) : generated.choices,
              hintText: formatAlgebraMathText(
                generated.hintText || `${conceptTitle}의 정의를 먼저 쓰고, 문제에 주어진 수를 한 단계씩 대입해보세요.`
              ),
              visualization: generated.visualization || {
                kind: "probability-concept",
                conceptId,
                typeIndex: index
              },
              validityChecks: [
                ...generated.validityChecks || [],
                {
                  name: "probability-statistics-answer",
                  passed: generated.answer !== void 0 && generated.answer !== null && String(generated.answer).trim() !== "",
                  message: "정답이 비어 있습니다."
                }
              ]
            };
          }
        }));
      }
      module.exports = {
        randomInteger,
        inlineMath,
        displayMath,
        factorial,
        combination,
        permutation,
        fractionText,
        round4,
        shortAnswer,
        multipleChoice,
        createProblemTypes,
        isCorrectAnswer
      };
    }
  });

  // services/problemGenerators/probabilityStatistics/generators.js
  var require_generators2 = __commonJS({
    "services/problemGenerators/probabilityStatistics/generators.js"(exports, module) {
      var {
        randomInteger,
        inlineMath,
        factorial,
        combination,
        permutation,
        fractionText,
        round4,
        shortAnswer,
        multipleChoice,
        createProblemTypes,
        isCorrectAnswer
      } = require_helpers3();
      function probability(numerator, denominator) {
        return round4(numerator / denominator);
      }
      function binomialProbability(n, p, k) {
        return round4(
          combination(n, k) * p ** k * (1 - p) ** (n - k)
        );
      }
      function normalCdf(z) {
        const sign = z < 0 ? -1 : 1;
        const x = Math.abs(z) / Math.sqrt(2);
        const t = 1 / (1 + 0.3275911 * x);
        const coefficients = [
          0.254829592,
          -0.284496736,
          1.421413741,
          -1.453152027,
          1.061405429
        ];
        let polynomial = coefficients[4];
        for (let index = 3; index >= 0; index -= 1) {
          polynomial = polynomial * t + coefficients[index];
        }
        const erf = sign * (1 - polynomial * t * Math.exp(-x * x));
        return (1 + erf) / 2;
      }
      function sa(prompt, answer, solution, hintText, visualization) {
        return shortAnswer({
          prompt,
          answer,
          solution,
          hintText,
          visualization
        });
      }
      function mc(prompt, choices, answerIndex, solution, hintText, visualization) {
        return multipleChoice({
          prompt,
          choices,
          answerIndex,
          solution,
          hintText,
          visualization
        });
      }
      function countingVisual(data = {}) {
        return { kind: "probability-counting", ...data };
      }
      function vennVisual(data = {}) {
        return { kind: "probability-venn", ...data };
      }
      function treeVisual(data = {}) {
        return { kind: "probability-tree", ...data };
      }
      function distributionVisual(data = {}) {
        return { kind: "probability-distribution", ...data };
      }
      function binomialVisual(data = {}) {
        return { kind: "probability-binomial", ...data };
      }
      function normalVisual(data = {}) {
        return { kind: "probability-normal", ...data };
      }
      function samplingVisual(data = {}) {
        return { kind: "probability-sampling", ...data };
      }
      function confidenceVisual(data = {}) {
        return { kind: "probability-confidence", ...data };
      }
      var definitions = [
        {
          conceptId: "probability-statistics-01-01",
          unitId: "counting",
          key: "probstat-repeated-multiset-permutation",
          title: "중복순열과 같은 것이 있는 순열",
          labels: [
            "중복순열",
            "비밀번호 만들기",
            "같은 것이 있는 순열",
            "문자 배열",
            "원순열과 구별",
            "특정 기호 포함",
            "자리 제한",
            "같은 수 묶기",
            "두 종류의 중복",
            "종합 배열"
          ],
          buildProblems() {
            const n = randomInteger(2, 5);
            const r = randomInteger(2, 5);
            const a = randomInteger(2, 4);
            const b = randomInteger(2, 4);
            const total = a + b;
            const repeated = n ** r;
            const multiset = factorial(total) / (factorial(a) * factorial(b));
            const uniqueCount = randomInteger(2, 4);
            const duplicateCount = randomInteger(2, 3);
            const letterTotal = uniqueCount + duplicateCount;
            const letterArrangement = factorial(letterTotal) / factorial(duplicateCount);
            const circleCount = randomInteger(4, 7);
            const circleArrangement = factorial(circleCount - 1);
            const thirdGroup = randomInteger(2, 3);
            const threeGroupTotal = total + thirdGroup;
            const threeGroupArrangement = factorial(threeGroupTotal) / (factorial(a) * factorial(b) * factorial(thirdGroup));
            return [
              sa(`${n}개의 문자를 중복을 허용하여 ${r}자리로 나열하는 경우의 수를 구하세요.`, repeated, `각 자리마다 ${n}가지이므로 ${inlineMath(`${n}^{${r}}=${repeated}`)}입니다.`, "선택한 뒤에도 다음 자리의 선택지 수가 줄지 않습니다.", countingVisual({ mode: "repeated", choices: n, slots: r })),
              sa(`숫자 ${n}개로 중복 가능한 ${r}자리 비밀번호를 만드는 경우의 수는?`, repeated, `${r}개 자리에 각각 ${n}가지가 들어가므로 ${repeated}가지입니다.`, "자리별 선택지 수를 곱하세요.", countingVisual({ mode: "repeated", choices: n, slots: r })),
              sa(`A가 ${a}개, B가 ${b}개인 ${total}개 문자를 모두 나열하는 경우의 수를 구하세요.`, multiset, `${inlineMath(`\\frac{${total}!}{${a}!${b}!}=${multiset}`)}입니다.`, "모두 다르다고 센 뒤 A끼리, B끼리의 자리바꿈을 나눕니다.", countingVisual({ mode: "multiset", groups: [a, b] })),
              sa(`같은 문자 A가 ${duplicateCount}개이고 서로 다른 문자가 ${uniqueCount}개일 때, ${letterTotal}개 문자를 모두 나열하는 방법의 수는?`, letterArrangement, `${inlineMath(`\\frac{${letterTotal}!}{${duplicateCount}!}=${letterArrangement}`)}입니다.`, "같은 A끼리의 자리바꿈은 새로운 배열을 만들지 않습니다.", countingVisual({ mode: "multiset", groups: [duplicateCount, ...Array(uniqueCount).fill(1)] })),
              mc(`서로 다른 ${circleCount}개를 원형으로 배열하는 경우의 수는?`, [`${circleCount}!`, `${circleCount}^2`, `${circleCount - 1}!`, `${circleCount}!/2!`], 2, `회전하여 같은 배열을 하나로 보므로 (${circleCount}-1)!=${circleArrangement}입니다.`, "원순열은 중복순열과 다른 기준으로 중복을 제거합니다.", countingVisual({ mode: "circle", slots: circleCount })),
              sa(`0과 1로 만든 ${r}자리 문자열 중 1이 적어도 한 번 나오는 문자열 수는?`, 2 ** r - 1, `전체 ${inlineMath(`2^{${r}}`)}개에서 0만 있는 한 가지를 뺍니다.`, "여사건인 '1이 한 번도 없음'을 먼저 세세요.", countingVisual({ mode: "repeated", choices: 2, slots: r })),
              sa(`${n}개의 숫자를 중복 허용하여 만든 ${r + 1}자리 문자열 중 첫 자리가 고정된 경우의 수는?`, n ** r, `첫 자리는 고정되고 나머지 ${r}자리는 각각 ${n}가지이므로 ${inlineMath(`${n}^{${r}}=${n ** r}`)}입니다.`, "고정된 자리는 선택지 곱에서 제외합니다.", countingVisual({ mode: "repeated", choices: n, slots: r })),
              sa(`같은 빨간 공 ${a}개와 같은 파란 공 ${b}개를 일렬로 놓는 방법의 수는?`, multiset, `${total}자리 중 빨간 공의 자리 ${a}개를 고르면 ${inlineMath(`\\binom{${total}}{${a}}=${multiset}`)}입니다.`, "빨간 공의 자리만 정하면 나머지는 자동으로 파란 공입니다.", countingVisual({ mode: "multiset", groups: [a, b] })),
              sa(`A ${a}개, B ${b}개, C ${thirdGroup}개를 모두 나열하는 경우의 수는?`, threeGroupArrangement, `${inlineMath(`\\frac{${threeGroupTotal}!}{${a}!${b}!${thirdGroup}!}=${threeGroupArrangement}`)}입니다.`, "각 종류 안에서 생기는 중복을 모두 나눕니다.", countingVisual({ mode: "multiset", groups: [a, b, thirdGroup] })),
              sa(`같은 문자 A ${a}개, N ${b}개와 서로 다른 문자 1개를 모두 나열하는 방법의 수는?`, factorial(total + 1) / (factorial(a) * factorial(b)), `전체 ${total + 1}개 중 A끼리와 N끼리의 중복을 나누면 ${inlineMath(`\\frac{${total + 1}!}{${a}!${b}!}`)}입니다.`, "같은 문자가 몇 개씩 있는지 먼저 표시하세요.", countingVisual({ mode: "multiset", groups: [a, b, 1] }))
            ];
          }
        },
        {
          conceptId: "probability-statistics-01-02",
          unitId: "counting",
          key: "probstat-repeated-combination",
          title: "중복조합",
          labels: [
            "중복조합 공식",
            "사탕 고르기",
            "음이 아닌 해",
            "적어도 하나",
            "종류별 선택",
            "별과 막대",
            "상한이 있는 선택",
            "양의 정수해",
            "두 조건 결합",
            "종합 중복조합"
          ],
          buildProblems() {
            const n = randomInteger(3, 6);
            const r = randomInteger(2, 5);
            const value = combination(n + r - 1, r);
            const boundedItems = randomInteger(4, 8);
            const boundedValue = 2 * boundedItems + 1;
            const positiveSum = randomInteger(6, 11);
            const positiveValue = combination(positiveSum - 1, 2);
            const requiredItems = randomInteger(4, 8);
            const requiredValue = combination(
              n + requiredItems - 2,
              requiredItems - 1
            );
            const drinkTypes = randomInteger(4, 7);
            const drinkCount = randomInteger(3, 6);
            const drinkValue = combination(
              drinkTypes + drinkCount - 1,
              drinkCount
            );
            return [
              sa(`${n}종류에서 중복을 허용하여 ${r}개를 고르는 방법의 수는?`, value, `${inlineMath(`{}_{${n}}H_{${r}}=\\binom{${n + r - 1}}{${r}}=${value}`)}입니다.`, "중복조합을 조합으로 바꿀 때 n+r-1을 사용합니다.", countingVisual({ mode: "stars-bars", groups: n, items: r })),
              sa(`서로 다른 맛 ${n}종류의 사탕을 중복 가능하게 ${r}개 고르는 방법의 수는?`, value, `맛별 개수의 합이 ${r}인 음이 아닌 정수해와 같아 ${value}가지입니다.`, "사탕을 별, 맛 사이 경계를 막대로 생각하세요.", countingVisual({ mode: "stars-bars", groups: n, items: r })),
              sa(`${inlineMath(`x_1+x_2+x_3=${r}`)}의 음이 아닌 정수해의 개수는?`, combination(r + 2, 2), `${inlineMath(`\\binom{${r + 2}}{2}`)}입니다.`, "별 r개와 막대 2개를 배열합니다.", countingVisual({ mode: "stars-bars", groups: 3, items: r })),
              sa(`${inlineMath(`x_1+x_2+x_3=${r + 3}`)}에서 각 ${inlineMath("x_i\\ge1")}인 정수해의 개수는?`, combination(r + 2, 2), `각 변수에 1씩 먼저 주면 남은 합이 ${r}이므로 ${inlineMath(`\\binom{${r + 2}}2`)}입니다.`, "최솟값을 먼저 배정한 뒤 음이 아닌 해로 바꾸세요.", countingVisual({ mode: "stars-bars", groups: 3, items: r })),
              sa(`빵 ${n}종류를 합하여 ${r}개 사되, 어떤 종류도 사지 않아도 될 때 경우의 수는?`, value, `중복조합 ${inlineMath(`{}_${n}H_${r}`)}이므로 ${value}가지입니다.`, "순서는 중요하지 않고 같은 종류를 여러 번 고를 수 있습니다.", countingVisual({ mode: "stars-bars", groups: n, items: r })),
              mc(`별과 막대에서 종류가 ${n}개이면 필요한 막대 수는?`, [`${n - 1}개`, `${n}개`, `${n + 1}개`, "선택 개수와 같다"], 0, `${n}개 구역을 만들려면 막대는 ${n - 1}개입니다.`, "종류 수보다 막대가 하나 적습니다.", countingVisual({ mode: "stars-bars", groups: n, items: r })),
              sa(`세 종류에서 중복을 허용해 ${boundedItems}개를 고르되 첫 종류는 최대 1개인 경우의 수는?`, boundedValue, `첫 종류가 0개일 때 ${boundedItems + 1}가지, 1개일 때 ${boundedItems}가지이므로 ${boundedValue}가지입니다.`, "상한에 따라 첫 종류의 개수를 0,1로 나누세요.", countingVisual({ mode: "stars-bars", groups: 3, items: boundedItems })),
              sa(`${inlineMath(`x+y+z=${positiveSum}`)}의 양의 정수해 개수는?`, positiveValue, `각 변수에 1씩 주면 남은 합은 ${positiveSum - 3}, 따라서 ${inlineMath(`\\binom{${positiveSum - 1}}2=${positiveValue}`)}입니다.`, "양의 조건을 제거하려면 각 변수에서 1을 빼세요.", countingVisual({ mode: "stars-bars", groups: 3, items: positiveSum - 3 })),
              sa(`${n}종류의 과일을 ${requiredItems}개 고르되 첫 종류를 적어도 1개 고르는 방법의 수는?`, requiredValue, `첫 종류 1개를 먼저 고른 뒤 ${n}종류에서 ${requiredItems - 1}개를 중복조합하므로 ${inlineMath(`\\binom{${n + requiredItems - 2}}{${requiredItems - 1}}=${requiredValue}`)}입니다.`, "필수 개수를 먼저 배정하세요.", countingVisual({ mode: "stars-bars", groups: n, items: requiredItems - 1 })),
              sa(`${drinkTypes}종류의 음료를 중복 허용하여 ${drinkCount}개 고르는 방법의 수는?`, drinkValue, `${inlineMath(`{}_${drinkTypes}H_${drinkCount}=\\binom{${drinkTypes + drinkCount - 1}}{${drinkCount}}=${drinkValue}`)}입니다.`, "종류 수와 선택 개수를 별과 막대로 바꿔보세요.", countingVisual({ mode: "stars-bars", groups: drinkTypes, items: drinkCount }))
            ];
          }
        },
        {
          conceptId: "probability-statistics-01-03",
          unitId: "counting",
          key: "probstat-binomial-theorem",
          title: "이항정리",
          labels: [
            "일반항",
            "특정 항의 계수",
            "상수항",
            "계수의 합",
            "홀수항 계수",
            "파스칼 삼각형",
            "이항계수 대칭",
            "두 항의 부호",
            "중앙항",
            "종합 전개"
          ],
          buildProblems() {
            const n = randomInteger(4, 8);
            const k = randomInteger(1, n - 1);
            const coefficient = randomInteger(2, 4);
            const constant = randomInteger(2, 4);
            const power = randomInteger(3, 6);
            const evenPower = 2 * randomInteger(2, 5);
            const signPower = randomInteger(4, 7);
            const signConstant = randomInteger(2, 4);
            const targetPower = randomInteger(
              1,
              signPower - 1
            );
            const signCoefficient = combination(signPower, targetPower) * (-signConstant) ** (signPower - targetPower);
            const squareCoefficient = combination(power, 2) * coefficient ** 2 * (-1) ** (power - 2);
            return [
              mc(`${inlineMath(`(a+b)^{${n}}`)}의 일반항으로 옳은 것은?`, [inlineMath(`\\binom{${n}}r a^{${n}-r}b^r`), inlineMath(`\\binom{${n}}r a^r b^r`), inlineMath(`${n}a^{${n}-r}b^r`), inlineMath(`a^{${n}}+b^{${n}}`)], 0, "b를 r번 고른 항의 계수는 이항계수이고 a의 지수는 n-r입니다.", "각 인수에서 b를 고르는 위치 r개를 선택합니다.", countingVisual({ mode: "pascal", row: n })),
              sa(`${inlineMath(`(x+1)^{${n}}`)}에서 ${inlineMath(`x^{${n - k}}`)}의 계수를 구하세요.`, combination(n, k), `계수는 ${inlineMath(`\\binom{${n}}{${k}}=${combination(n, k)}`)}입니다.`, "1을 k번 고르는 항을 찾으세요.", countingVisual({ mode: "pascal", row: n, focus: k })),
              sa(`${inlineMath(`(${coefficient}x+${constant})^${power}`)}의 상수항을 구하세요.`, constant ** power, `x가 들어 있는 항을 한 번도 고르지 않을 때 상수항은 ${inlineMath(`${constant}^${power}=${constant ** power}`)}입니다.`, "상수항은 x의 지수가 0인 항입니다.", countingVisual({ mode: "pascal", row: power, focus: power })),
              sa(`${inlineMath(`(2x+3)^{${n}}`)}의 모든 계수의 합을 구하세요.`, 5 ** n, `${inlineMath("x=1")}을 대입하면 ${inlineMath(`5^{${n}}=${5 ** n}`)}입니다.`, "계수의 합은 다항식에 x=1을 대입한 값입니다.", countingVisual({ mode: "pascal", row: n })),
              sa(`${inlineMath(`(1+x)^${evenPower}`)}에서 홀수차항 계수의 합을 구하세요.`, 2 ** (evenPower - 1), `${inlineMath(`\\frac{2^${evenPower}-0^${evenPower}}2=${2 ** (evenPower - 1)}`)}입니다.`, "P(1)과 P(-1)을 빼면 홀수차항만 두 배로 남습니다.", countingVisual({ mode: "pascal", row: evenPower })),
              sa(`파스칼의 삼각형에서 ${n}번째 행(0번째 행부터 시작)의 계수 합은?`, 2 ** n, `이항계수 합은 ${inlineMath(`2^${n}=${2 ** n}`)}입니다.`, `행의 계수는 ${inlineMath(`(1+1)^${n}`)}의 전개계수입니다.`, countingVisual({ mode: "pascal", row: n })),
              mc(`${inlineMath(`\\binom{${n}}{${k}}`)}와 항상 같은 것은?`, [inlineMath(`\\binom{${n}}{${n - k}}`), inlineMath(`\\binom{${n - 1}}{${k}}`), inlineMath(`\\binom{${k}}{${n}}`), inlineMath(`${n - k}`)], 0, "고른 것과 고르지 않은 것을 바꾸어 세면 같은 값입니다.", "이항계수의 대칭성을 떠올리세요.", countingVisual({ mode: "pascal", row: n, focus: k })),
              sa(`${inlineMath(`(x-${signConstant})^${signPower}`)}에서 ${inlineMath(`x^${targetPower}`)}의 계수를 구하세요.`, signCoefficient, `${inlineMath(`\\binom{${signPower}}{${targetPower}}(-${signConstant})^{${signPower - targetPower}}=${signCoefficient}`)}입니다.`, `x를 ${targetPower}번 고르고 상수항의 부호도 함께 계산하세요.`, countingVisual({ mode: "pascal", row: signPower, focus: signPower - targetPower })),
              sa(`${inlineMath(`(x+1)^${evenPower}`)}의 중앙항 계수를 구하세요.`, combination(evenPower, evenPower / 2), `중앙항은 r=${evenPower / 2}이므로 ${inlineMath(`\\binom{${evenPower}}{${evenPower / 2}}=${combination(evenPower, evenPower / 2)}`)}입니다.`, "지수가 짝수이면 가운데 이항계수 하나가 중앙에 있습니다.", countingVisual({ mode: "pascal", row: evenPower, focus: evenPower / 2 })),
              sa(`${inlineMath(`(${coefficient}x-1)^${power}`)}에서 ${inlineMath("x^2")}의 계수를 구하세요.`, squareCoefficient, `${inlineMath(`\\binom{${power}}2${coefficient}^2(-1)^{${power - 2}}=${squareCoefficient}`)}입니다.`, `${coefficient}x를 두 번, -1을 ${power - 2}번 고릅니다.`, countingVisual({ mode: "pascal", row: power, focus: power - 2 }))
            ];
          }
        },
        {
          conceptId: "probability-statistics-02-01",
          unitId: "probability",
          key: "probstat-basic-probability",
          title: "확률의 개념과 기본 성질",
          labels: [
            "수학적 확률",
            "상대도수",
            "확률의 범위",
            "전체사건",
            "공사건",
            "주사위",
            "동전",
            "표본공간",
            "공정성",
            "종합 확률"
          ],
          buildProblems() {
            const favorable = randomInteger(1, 5);
            const total = randomInteger(favorable + 1, 12);
            const trialUnit = randomInteger(2, 8);
            const trials = trialUnit * 50;
            const successes = randomInteger(
              trialUnit * 10,
              trialUnit * 40
            );
            const dieThreshold = randomInteger(2, 5);
            const coinTosses = randomInteger(2, 5);
            const spinnerSides = randomInteger(4, 10);
            const cardMultiplier = randomInteger(2, 5);
            const cardTotal = randomInteger(
              2,
              4
            ) * cardMultiplier;
            const multipleCount = Math.floor(
              cardTotal / cardMultiplier
            );
            return [
              sa(`동일하게 일어날 가능성이 있는 ${total}개 결과 중 원하는 결과가 ${favorable}개일 때 확률을 소수로 구하세요.`, probability(favorable, total), `${inlineMath(`P(A)=\\frac{${favorable}}{${total}}=${round4(favorable / total)}`)}입니다.`, "유리한 경우의 수를 전체 경우의 수로 나눕니다.", vennVisual({ total, a: favorable })),
              sa(`어떤 실험을 ${trials}번 시행해 사건 A가 ${successes}번 일어났을 때 상대도수는?`, round4(successes / trials), `${inlineMath(`\\frac{${successes}}{${trials}}=${round4(successes / trials)}`)}입니다.`, "발생 횟수를 시행 횟수로 나누세요.", distributionVisual({ values: [successes / trials, 1 - successes / trials], labels: ["A", "A 아님"] })),
              mc("사건 A의 확률로 가능한 값은?", ["-0.2", "0.65", "1.4", "2"], 1, "확률은 항상 0 이상 1 이하입니다.", "확률의 범위를 확인하세요.", vennVisual({ a: 0.65 })),
              mc("표본공간 전체인 사건 S의 확률 P(S)는?", ["0", "1", "표본점 수", "항상 1보다 크다"], 1, "반드시 일어나는 전체사건의 확률은 1입니다.", "모든 결과를 포함하는 사건입니다.", vennVisual({ total: 1, a: 1 })),
              mc("절대로 일어나지 않는 공사건의 확률은?", ["0", "1", "-1", "정할 수 없다"], 0, "공사건에는 유리한 결과가 없으므로 확률은 0입니다.", "유리한 경우의 수가 0개입니다.", vennVisual({ total: 1, a: 0 })),
              sa(`공정한 주사위를 한 번 던져 ${dieThreshold} 이하의 눈이 나올 확률을 소수로 구하세요.`, round4(dieThreshold / 6), `${dieThreshold}가지 눈이 유리하므로 ${inlineMath(`\\frac{${dieThreshold}}6=${round4(dieThreshold / 6)}`)}입니다.`, `표본공간 {1,2,3,4,5,6}에서 ${dieThreshold} 이하를 표시하세요.`, vennVisual({ total: 6, a: dieThreshold })),
              sa(`공정한 동전을 ${coinTosses}번 던져 앞면이 정확히 한 번 나올 확률은?`, round4(coinTosses / 2 ** coinTosses), `앞면의 위치를 ${coinTosses}곳 중 하나 고르므로 ${inlineMath(`\\frac{${coinTosses}}{2^${coinTosses}}=${round4(coinTosses / 2 ** coinTosses)}`)}입니다.`, "앞면이 나오는 위치를 고르고 전체 결과 수로 나누세요.", treeVisual({ levels: coinTosses, probability: 0.5 })),
              sa(`${spinnerSides}칸이 같은 크기로 나뉜 공정한 회전판을 한 번 돌리는 실험의 표본공간 원소 수는?`, spinnerSides, `가능한 칸은 모두 ${spinnerSides}개입니다.`, "가능한 결과를 빠짐없이 나열하세요.", vennVisual({ total: spinnerSides, a: 0 })),
              mc("모든 결과가 같은 가능성을 가질 때 사용할 수 있는 확률 정의는?", ["수학적 확률", "조건부확률", "표본평균", "표준편차"], 0, "동등 가능성이 확보되면 경우의 수 비로 수학적 확률을 구합니다.", "전체 결과가 같은 가능성인지가 핵심입니다.", vennVisual({ total: 8, a: 3 })),
              sa(`1부터 ${cardTotal}까지 적힌 카드 중 한 장을 뽑아 ${cardMultiplier}의 배수가 나올 확률을 소수로 구하세요.`, round4(multipleCount / cardTotal), `유리한 카드는 ${multipleCount}장이므로 ${inlineMath(`\\frac{${multipleCount}}{${cardTotal}}=${round4(multipleCount / cardTotal)}`)}입니다.`, "유리한 카드를 먼저 나열하세요.", vennVisual({ total: cardTotal, a: multipleCount }))
            ];
          }
        },
        {
          conceptId: "probability-statistics-02-02",
          unitId: "probability",
          key: "probstat-addition-rule",
          title: "확률의 덧셈정리",
          labels: [
            "합사건",
            "교집합 빼기",
            "배반사건",
            "두 조건",
            "벤다이어그램",
            "주사위 합사건",
            "카드 합사건",
            "확률 역산",
            "세 영역 읽기",
            "종합 덧셈정리"
          ],
          buildProblems() {
            const aOnly = randomInteger(1, 3) / 10;
            const bOnly = randomInteger(1, 3) / 10;
            const intersection = randomInteger(1, 2) / 10;
            const pa = round4(aOnly + intersection);
            const pb = round4(bOnly + intersection);
            const union = round4(pa + pb - intersection);
            const disjointA = randomInteger(2, 5) / 10;
            const disjointB = randomInteger(1, 9 - disjointA * 10) / 10;
            const contextTotal = randomInteger(8, 10) * 10;
            const contextA = randomInteger(20, 35);
            const contextB = randomInteger(15, 30);
            const contextBoth = randomInteger(
              5,
              Math.min(contextA, contextB, 10)
            );
            const cardTotal = randomInteger(8, 15);
            const cardA = randomInteger(2, cardTotal - 4);
            const cardB = randomInteger(2, cardTotal - cardA);
            const cardBoth = randomInteger(
              1,
              Math.min(cardA, cardB)
            );
            return [
              sa(`P(A)=${pa}, P(B)=${pb}, P(A∩B)=${intersection}일 때 P(A∪B)는?`, union, `${inlineMath(`P(A\\cup B)=${pa}+${pb}-${intersection}=${union}`)}입니다.`, "겹치는 부분은 두 번 더해졌으므로 한 번 뺍니다.", vennVisual({ a: pa, b: pb, intersection })),
              sa(`P(A)=${pa}, P(B)=${pb}, P(A∩B)=${intersection}일 때 P(A∪B)는?`, union, `${pa}+${pb}-${intersection}=${union}입니다.`, "A와 B의 겹침을 빼세요.", vennVisual({ a: pa, b: pb, intersection })),
              sa(`A와 B가 배반이고 P(A)=${disjointA}, P(B)=${disjointB}일 때 P(A∪B)는?`, round4(disjointA + disjointB), `배반이면 교집합 확률이 0이므로 ${disjointA}+${disjointB}=${round4(disjointA + disjointB)}입니다.`, "배반사건은 겹치는 영역이 없습니다.", vennVisual({ a: disjointA, b: disjointB, intersection: 0 })),
              sa(`${contextTotal}명 중 A에 속한 학생이 ${contextA}명, B에 속한 학생이 ${contextB}명이고 둘 다 속한 학생이 ${contextBoth}명일 때 적어도 하나에 속할 확률은?`, round4((contextA + contextB - contextBoth) / contextTotal), `합집합 인원은 ${contextA}+${contextB}-${contextBoth}=${contextA + contextB - contextBoth}명이므로 확률은 ${round4((contextA + contextB - contextBoth) / contextTotal)}입니다.`, "둘 다 속한 학생은 한 번만 세어야 합니다.", vennVisual({ total: contextTotal, a: contextA, b: contextB, intersection: contextBoth })),
              mc("P(A∪B)를 나타내는 식은?", ["P(A)+P(B)", "P(A)+P(B)-P(A∩B)", "P(A)P(B)", "1-P(A)"], 1, "덧셈정리는 교집합을 한 번 뺍니다.", "벤다이어그램에서 겹침이 몇 번 세어졌는지 보세요.", vennVisual({ a: 0.5, b: 0.4, intersection: 0.2 })),
              sa(`전체 ${cardTotal}개의 같은 가능성 결과에서 A가 ${cardA}개, B가 ${cardB}개, 두 사건에 모두 속한 결과가 ${cardBoth}개일 때 합사건의 확률은?`, round4((cardA + cardB - cardBoth) / cardTotal), `유리한 결과는 ${cardA}+${cardB}-${cardBoth}=${cardA + cardB - cardBoth}개입니다.`, "교집합에 속한 결과는 한 번만 셉니다.", vennVisual({ total: cardTotal, a: cardA, b: cardB, intersection: cardBoth })),
              sa(`1부터 ${cardTotal}까지의 카드에서 사건 A에 ${cardA}장, 사건 B에 ${cardB}장, 두 사건에 모두 ${cardBoth}장이 속할 때 A 또는 B인 카드를 뽑을 확률은?`, round4((cardA + cardB - cardBoth) / cardTotal), `${inlineMath(`\\frac{${cardA}+${cardB}-${cardBoth}}{${cardTotal}}=${round4((cardA + cardB - cardBoth) / cardTotal)}`)}입니다.`, "겹치는 카드는 한 번만 셉니다.", vennVisual({ total: cardTotal, a: cardA, b: cardB, intersection: cardBoth })),
              sa(`P(A∪B)=${union}, P(A)=${pa}, P(B)=${pb}일 때 P(A∩B)는?`, intersection, `P(A∩B)=${pa}+${pb}-${union}=${intersection}입니다.`, "덧셈정리를 교집합에 대해 정리하세요.", vennVisual({ a: pa, b: pb, intersection })),
              sa(`A만의 확률이 ${aOnly}, B만의 확률이 ${bOnly}, 교집합 확률이 ${intersection}일 때 P(A∪B)는?`, union, `서로 겹치지 않는 세 영역을 더해 ${union}입니다.`, "A만, 겹침, B만을 각각 한 번씩 더하세요.", vennVisual({ aOnly, bOnly, intersection })),
              sa(`P(A)=${pa}, P(B)=${pb}이고 P(A∪B)=${union}일 때 P(A∩B)는?`, intersection, `${pa}+${pb}-${union}=${intersection}입니다.`, "합사건 식을 교집합 확률에 대해 풀어보세요.", vennVisual({ a: pa, b: pb, intersection }))
            ];
          }
        },
        {
          conceptId: "probability-statistics-02-03",
          unitId: "probability",
          key: "probstat-complement",
          title: "여사건의 확률",
          labels: [
            "여사건 공식",
            "적어도 하나",
            "한 번도 없음",
            "최대 조건",
            "주사위 반복",
            "불량품",
            "생일 조건",
            "합격 확률",
            "범위의 여사건",
            "종합 여사건"
          ],
          buildProblems() {
            const p = randomInteger(1, 8) / 10;
            const repeatedP = randomInteger(1, 7) / 10;
            const repeatedN = randomInteger(2, 6);
            const threshold = randomInteger(2, 5);
            const dieRepeats = randomInteger(2, 5);
            const defectRate = randomInteger(1, 8) / 100;
            const productCount = randomInteger(3, 8);
            const passProbability = randomInteger(55, 90) / 100;
            const cardMultiple = randomInteger(2, 6);
            const cardTotal = cardMultiple * randomInteger(3, 6);
            const notProbability = randomInteger(1, 8) / 10;
            return [
              sa(`P(A)=${p}일 때 P(Aᶜ)는?`, round4(1 - p), `${inlineMath(`P(A^c)=1-${p}=${round4(1 - p)}`)}입니다.`, "사건과 여사건은 표본공간 전체를 나눕니다.", vennVisual({ a: p, complement: true })),
              sa(`성공 확률이 ${repeatedP}인 시행을 ${repeatedN}번 독립적으로 할 때 적어도 한 번 성공할 확률은?`, round4(1 - (1 - repeatedP) ** repeatedN), `한 번도 성공하지 않을 확률 ${inlineMath(`(1-${repeatedP})^${repeatedN}`)}을 1에서 빼면 ${round4(1 - (1 - repeatedP) ** repeatedN)}입니다.`, "'적어도 한 번'의 여사건은 '한 번도 없음'입니다.", treeVisual({ levels: repeatedN, probability: repeatedP, complement: true })),
              sa(`앞면 확률이 ${repeatedP}인 동전을 ${repeatedN}번 던져 앞면이 한 번도 안 나올 확률은?`, round4((1 - repeatedP) ** repeatedN), `${inlineMath(`(1-${repeatedP})^${repeatedN}=${round4((1 - repeatedP) ** repeatedN)}`)}입니다.`, "모든 시행에서 앞면이 나오지 않아야 합니다.", treeVisual({ levels: repeatedN, probability: repeatedP })),
              sa(`주사위를 ${repeatedN}번 던져 나온 눈이 모두 ${threshold} 이하일 확률은?`, round4((threshold / 6) ** repeatedN), `${inlineMath(`(${threshold}/6)^${repeatedN}=${round4((threshold / 6) ** repeatedN)}`)}입니다.`, `각 시행에서 허용되는 눈은 1부터 ${threshold}까지입니다.`, treeVisual({ levels: repeatedN, probability: threshold / 6 })),
              sa(`주사위를 ${dieRepeats}번 던져 6이 적어도 한 번 나올 확률을 소수로 구하세요.`, round4(1 - (5 / 6) ** dieRepeats), `${inlineMath(`1-(5/6)^${dieRepeats}=${round4(1 - (5 / 6) ** dieRepeats)}`)}입니다.`, "6이 한 번도 나오지 않는 경우를 빼세요.", treeVisual({ levels: dieRepeats, probability: 1 / 6, complement: true })),
              sa(`불량률이 ${defectRate}인 제품 ${productCount}개가 독립일 때 적어도 하나가 불량일 확률을 소수로 구하세요.`, round4(1 - (1 - defectRate) ** productCount), `${inlineMath(`1-(1-${defectRate})^${productCount}=${round4(1 - (1 - defectRate) ** productCount)}`)}입니다.`, "모두 정상일 확률의 여사건입니다.", treeVisual({ levels: productCount, probability: defectRate, complement: true })),
              mc("'적어도 두 사람이 같은 생일'의 여사건은?", ["모두 생일이 다르다", "모두 생일이 같다", "정확히 두 명만 같다", "한 명만 생일이 있다"], 0, "같은 생일 쌍이 하나도 없다는 것은 모두 다르다는 뜻입니다.", "적어도 하나의 충돌이 없다고 바꿔 말하세요.", vennVisual({ complement: true })),
              sa(`시험에 합격할 확률이 ${passProbability}일 때 불합격할 확률은?`, round4(1 - passProbability), `1-${passProbability}=${round4(1 - passProbability)}입니다.`, "합격과 불합격은 서로 여사건입니다.", vennVisual({ a: passProbability, complement: true })),
              sa(`1부터 ${cardTotal} 카드 중 ${cardMultiple}의 배수가 아닌 카드를 뽑을 확률은?`, round4(1 - 1 / cardMultiple), `${cardMultiple}의 배수는 ${cardTotal / cardMultiple}개이므로 ${inlineMath(`1-\\frac{${cardTotal / cardMultiple}}{${cardTotal}}=${round4(1 - 1 / cardMultiple)}`)}입니다.`, `먼저 ${cardMultiple}의 배수 확률을 구하세요.`, vennVisual({ total: cardTotal, a: cardTotal / cardMultiple, complement: true })),
              sa(`어떤 사건이 일어나지 않을 확률이 ${notProbability}일 때 그 사건이 일어날 확률은?`, round4(1 - notProbability), `1-${notProbability}=${round4(1 - notProbability)}입니다.`, "사건과 여사건의 확률 합은 1입니다.", vennVisual({ a: 1 - notProbability, complement: true }))
            ];
          }
        },
        {
          conceptId: "probability-statistics-02-04",
          unitId: "probability",
          key: "probstat-conditional-probability",
          title: "조건부확률",
          labels: [
            "조건부확률 공식",
            "표본공간 축소",
            "표에서 계산",
            "카드 조건",
            "주사위 조건",
            "검사 결과",
            "조건 역산",
            "나무도표",
            "인과 오해",
            "종합 조건부확률"
          ],
          buildProblems() {
            const conditionProbability = randomInteger(3, 8) / 10;
            const withinRatio = randomInteger(2, 8) / 10;
            const jointProbability = round4(
              conditionProbability * withinRatio
            );
            const conditionCount = randomInteger(2, 8) * 10;
            const jointCount = randomInteger(
              1,
              conditionCount / 10 - 1
            ) * 10;
            const groupCount = randomInteger(15, 40);
            const favorableCount = randomInteger(
              3,
              groupCount - 2
            );
            const dieConditionCount = randomInteger(3, 6);
            const prevalence = randomInteger(1, 4) / 10;
            const sensitivity = randomInteger(6, 9) / 10;
            const firstPath = randomInteger(2, 7) / 10;
            const secondPath = randomInteger(2, 8) / 10;
            return [
              sa(`P(A∩B)=${jointProbability}, P(B)=${conditionProbability}일 때 P(A|B)는?`, withinRatio, `${inlineMath(`P(A|B)=${jointProbability}/${conditionProbability}=${withinRatio}`)}입니다.`, "조건 B가 새 표본공간의 전체가 됩니다.", vennVisual({ b: conditionProbability, intersection: jointProbability, conditional: "B" })),
              sa(`${conditionCount + randomInteger(10, 50)}명 중 조건 B에 속한 학생이 ${conditionCount}명이고, 그중 ${jointCount}명이 사건 A에 속한다. B라는 조건에서 A일 확률은?`, round4(jointCount / conditionCount), `조건에 맞는 ${conditionCount}명만 남기고 ${inlineMath(`\\frac{${jointCount}}{${conditionCount}}=${round4(jointCount / conditionCount)}`)}입니다.`, "전체 인원이 아니라 조건 집단의 인원이 분모입니다.", vennVisual({ b: conditionCount, intersection: jointCount, conditional: "B" })),
              sa(`한 집단 ${groupCount}명 중 특정 활동을 좋아하는 사람이 ${favorableCount}명일 때, 이 집단에 속한다는 조건에서 활동을 좋아할 확률은?`, round4(favorableCount / groupCount), `${inlineMath(`\\frac{${favorableCount}}{${groupCount}}=${round4(favorableCount / groupCount)}`)}입니다.`, "조건 집단 안에서의 비율을 구하세요.", vennVisual({ b: groupCount, intersection: favorableCount, conditional: "B" })),
              sa(`조건 B에 해당하는 카드가 ${conditionCount}장이고 그중 사건 A에도 속하는 카드가 ${jointCount}장일 때 P(A|B)는?`, round4(jointCount / conditionCount), `${inlineMath(`\\frac{${jointCount}}{${conditionCount}}=${round4(jointCount / conditionCount)}`)}입니다.`, "조건 B의 카드만 남겨 새 표본공간을 만드세요.", vennVisual({ b: conditionCount, intersection: jointCount, conditional: "B" })),
              sa(`조건을 만족하는 주사위 결과가 ${dieConditionCount}개이고 그중 사건 A에 속하는 결과가 2개일 때 조건부확률을 구하세요.`, round4(2 / dieConditionCount), `${inlineMath(`\\frac2{${dieConditionCount}}=${round4(2 / dieConditionCount)}`)}입니다.`, "조건을 만족하는 눈부터 나열하세요.", vennVisual({ b: dieConditionCount, intersection: 2, conditional: "B" })),
              sa(`질병 유병률이 ${prevalence}이고, 환자가 양성일 확률이 ${sensitivity}일 때 환자이면서 양성일 확률은?`, round4(prevalence * sensitivity), `${prevalence}×${sensitivity}=${round4(prevalence * sensitivity)}입니다.`, "P(환자∩양성)=P(환자)P(양성|환자)입니다.", treeVisual({ first: prevalence, conditional: sensitivity })),
              sa(`P(A|B)=${withinRatio}, P(B)=${conditionProbability}일 때 P(A∩B)는?`, jointProbability, `${withinRatio}×${conditionProbability}=${jointProbability}입니다.`, "조건부확률 공식을 교집합에 대해 정리하세요.", vennVisual({ b: conditionProbability, intersection: jointProbability, conditional: "B" })),
              sa(`첫 상자 선택 확률이 ${firstPath}이고, 그 상자에서 빨간 공을 뽑을 조건부확률이 ${secondPath}일 때 그 경로의 확률은?`, round4(firstPath * secondPath), `나무의 한 경로는 ${firstPath}×${secondPath}=${round4(firstPath * secondPath)}입니다.`, "한 경로의 가지 확률을 곱하세요.", treeVisual({ first: firstPath, conditional: secondPath })),
              mc("P(A|B)가 크다는 사실만으로 말할 수 없는 것은?", ["B인 경우 A의 비율이 크다", "B가 A의 원인이다", "표본공간이 B로 줄었다", "P(A∩B)/P(B)로 계산한다"], 1, "조건부확률은 연관을 나타내지만 인과관계를 자동으로 뜻하지 않습니다.", "시간 순서나 원인을 확률식만으로 단정할 수 없습니다.", vennVisual({ conditional: "B" })),
              sa(`P(A∩B)=${jointProbability}, P(B)=${conditionProbability}일 때 P(A|B)는?`, withinRatio, `${jointProbability}/${conditionProbability}=${withinRatio}입니다.`, "이번에는 B가 조건이므로 분모가 P(B)입니다.", vennVisual({ b: conditionProbability, intersection: jointProbability, conditional: "B" }))
            ];
          }
        },
        {
          conceptId: "probability-statistics-02-05",
          unitId: "probability",
          key: "probstat-independence",
          title: "사건의 독립과 종속",
          labels: [
            "독립 판정",
            "조건부확률 판정",
            "종속 판정",
            "동전 시행",
            "비복원 추출",
            "복원 추출",
            "독립의 곱",
            "배반과 독립",
            "표 자료 판정",
            "종합 독립성"
          ],
          buildProblems() {
            const independentA = randomInteger(2, 7) / 10;
            const independentB = randomInteger(2, 7) / 10;
            const independentIntersection = round4(independentA * independentB);
            const independentUnion = round4(
              independentA + independentB - independentIntersection
            );
            return [
              mc("P(A)=0.4, P(B)=0.5, P(A∩B)=0.2일 때 두 사건의 관계는?", ["독립", "종속", "배반", "판단 불가"], 0, "0.4×0.5=0.2이므로 독립입니다.", "교집합 확률과 두 확률의 곱을 비교하세요.", vennVisual({ a: 0.4, b: 0.5, intersection: 0.2 })),
              mc("P(A|B)=P(A)이고 P(B)>0일 때 A와 B의 관계는?", ["독립", "종속", "배반", "여사건"], 0, "B가 일어나도 A의 확률이 바뀌지 않으므로 독립입니다.", "조건이 정보를 주었을 때 확률이 변하는지 보세요.", vennVisual({ independent: true })),
              mc("P(A)=0.5, P(B)=0.4, P(A∩B)=0.3일 때 두 사건의 관계는?", ["독립", "종속", "배반", "여사건"], 1, "0.5×0.4=0.2이지만 교집합은 0.3이므로 종속입니다.", "독립이라면 교집합은 곱과 같아야 합니다.", vennVisual({ a: 0.5, b: 0.4, intersection: 0.3 })),
              mc("공정한 동전을 두 번 던질 때 첫 번째가 앞면인 사건과 두 번째가 앞면인 사건의 관계는?", ["독립", "종속", "배반", "같은 사건"], 0, "첫 시행 결과는 둘째 시행의 확률을 바꾸지 않습니다.", "서로 다른 독립 시행입니다.", treeVisual({ levels: 2, probability: 0.5 })),
              mc("주머니에서 공을 비복원으로 두 번 뽑을 때 첫 결과와 둘째 결과는 일반적으로?", ["독립", "종속", "배반", "여사건"], 1, "첫 공을 빼면 주머니 구성이 바뀌므로 둘째 확률이 변합니다.", "첫 시행 뒤 전체 개수가 줄어듭니다.", treeVisual({ withoutReplacement: true })),
              mc("공을 뽑고 다시 넣은 뒤 두 번째 공을 뽑으면 두 시행은?", ["독립", "종속", "배반", "불가능"], 0, "복원하면 주머니 구성이 원래대로 돌아와 확률이 변하지 않습니다.", "두 번째 시행 전에 상태가 복구됩니다.", treeVisual({ replacement: true })),
              sa(`독립인 A, B에 대해 P(A)=${independentA}, P(B)=${independentB}일 때 P(A∩B)는?`, independentIntersection, `독립이므로 ${independentA}×${independentB}=${independentIntersection}입니다.`, "독립 사건의 교집합 확률은 곱입니다.", vennVisual({ a: independentA, b: independentB, intersection: independentIntersection })),
              mc("확률이 모두 양수인 두 배반사건은 독립인가?", ["항상 독립", "독립이 아니다", "항상 같은 사건", "판단 불가"], 1, "배반이면 교집합은 0이지만 확률의 곱은 양수라 같지 않습니다.", "배반과 독립은 서로 다른 개념입니다.", vennVisual({ intersection: 0 })),
              mc("전체 100명 중 A 40명, B 50명, 둘 다 20명일 때 A와 B는?", ["독립", "종속", "배반", "여사건"], 0, "P(A∩B)=0.2이고 P(A)P(B)=0.4×0.5=0.2입니다.", "빈도를 확률로 바꿔 곱과 비교하세요.", vennVisual({ total: 100, a: 40, b: 50, intersection: 20 })),
              sa(`독립인 A와 B에 대해 P(A∪B)=${independentUnion}, P(A)=${independentA}, P(B)=${independentB}일 때 P(A∩B)는?`, independentIntersection, `독립이므로 ${independentA}×${independentB}=${independentIntersection}이고 덧셈정리와도 일치합니다.`, "독립 조건을 먼저 사용하세요.", vennVisual({ a: independentA, b: independentB, intersection: independentIntersection }))
            ];
          }
        },
        {
          conceptId: "probability-statistics-02-06",
          unitId: "probability",
          key: "probstat-multiplication-rule",
          title: "확률의 곱셈정리",
          labels: [
            "곱셈정리",
            "연속 추출",
            "나무 경로",
            "독립 시행",
            "비복원",
            "두 경로 합",
            "조건부확률 활용",
            "세 단계 경로",
            "역산",
            "종합 곱셈정리"
          ],
          buildProblems() {
            const first = randomInteger(2, 8) / 10;
            const conditional = randomInteger(2, 8) / 10;
            const pathProbability = round4(
              first * conditional
            );
            const red = randomInteger(3, 7);
            const blue = randomInteger(2, 6);
            const ballTotal = red + blue;
            const branchA = randomInteger(2, 6) / 10;
            const successA = randomInteger(2, 8) / 10;
            const successB = randomInteger(2, 8) / 10;
            const threePath = [
              randomInteger(2, 8) / 10,
              randomInteger(2, 8) / 10,
              randomInteger(2, 8) / 10
            ];
            const tosses = randomInteger(2, 5);
            return [
              sa(`P(A)=${first}, P(B|A)=${conditional}일 때 P(A∩B)는?`, pathProbability, `${first}×${conditional}=${pathProbability}입니다.`, "첫 사건 확률과 그 뒤 조건부확률을 곱합니다.", treeVisual({ first, conditional })),
              sa(`빨간 공 ${red}개, 파란 공 ${blue}개에서 비복원으로 빨간 공을 연속 두 번 뽑을 확률은?`, round4(red / ballTotal * ((red - 1) / (ballTotal - 1))), `${inlineMath(`\\frac{${red}}{${ballTotal}}\\times\\frac{${red - 1}}{${ballTotal - 1}}=${round4(red / ballTotal * ((red - 1) / (ballTotal - 1)))}`)}입니다.`, "첫 빨간 공을 뽑은 뒤 빨간 공과 전체 공이 모두 하나씩 줄어듭니다.", treeVisual({ withoutReplacement: true, first: red / ballTotal, conditional: (red - 1) / (ballTotal - 1) })),
              sa(`나무도표에서 한 경로의 가지 확률이 ${first}와 ${conditional}일 때 경로 확률은?`, pathProbability, `${first}×${conditional}=${pathProbability}입니다.`, "한 경로에서는 가지를 곱합니다.", treeVisual({ first, conditional })),
              sa(`성공확률 ${conditional}인 독립 시행을 ${tosses}번 모두 성공할 확률은?`, round4(conditional ** tosses), `${inlineMath(`${conditional}^${tosses}=${round4(conditional ** tosses)}`)}입니다.`, "독립 시행의 같은 경로 확률을 곱하세요.", treeVisual({ levels: tosses, probability: conditional })),
              sa(`${ballTotal}개 중 불량품 ${blue}개를 비복원으로 두 개 뽑아 모두 불량일 확률을 소수로 구하세요.`, round4(blue / ballTotal * ((blue - 1) / (ballTotal - 1))), `${inlineMath(`\\frac{${blue}}{${ballTotal}}\\times\\frac{${blue - 1}}{${ballTotal - 1}}=${round4(blue / ballTotal * ((blue - 1) / (ballTotal - 1)))}`)}입니다.`, "첫 불량품을 뽑은 뒤 남은 불량품은 하나 줄어듭니다.", treeVisual({ withoutReplacement: true, first: blue / ballTotal, conditional: (blue - 1) / (ballTotal - 1) })),
              sa(`상자 A를 고를 확률이 ${branchA}, A에서 성공할 확률이 ${successA}, 상자 B에서 성공할 확률이 ${successB}일 때 전체 성공확률은?`, round4(branchA * successA + (1 - branchA) * successB), `두 성공 경로를 더해 ${inlineMath(`${branchA}\\cdot${successA}+${round4(1 - branchA)}\\cdot${successB}=${round4(branchA * successA + (1 - branchA) * successB)}`)}입니다.`, "경로 안에서는 곱하고, 서로 다른 경로끼리는 더합니다.", treeVisual({ paths: [[branchA, successA], [1 - branchA, successB]] })),
              sa(`P(A∩B)=${pathProbability}, P(A)=${first}일 때 P(B|A)는?`, conditional, `${pathProbability}/${first}=${conditional}입니다.`, "곱셈정리를 조건부확률에 대해 정리하세요.", treeVisual({ first, conditional })),
              sa(`세 단계 경로의 확률이 각각 ${threePath.join(", ")}일 때 전체 경로 확률은?`, round4(threePath.reduce((value, item) => value * item, 1)), `${threePath.join("×")}=${round4(threePath.reduce((value, item) => value * item, 1))}입니다.`, "같은 경로에 놓인 모든 가지를 곱합니다.", treeVisual({ path: threePath })),
              sa(`P(A∩B)=${pathProbability}, P(B|A)=${conditional}일 때 P(A)는?`, first, `P(A)=${pathProbability}/${conditional}=${first}입니다.`, "P(A∩B)=P(A)P(B|A)를 사용하세요.", treeVisual({ first, conditional })),
              sa(`공정한 동전을 ${tosses}번 던져 미리 정한 한 가지 순서로 나올 확률은?`, round4((1 / 2) ** tosses), `${inlineMath(`(1/2)^${tosses}=${round4((1 / 2) ** tosses)}`)}입니다.`, "정해진 한 경로의 가지 확률을 모두 곱합니다.", treeVisual({ path: Array(tosses).fill(0.5) }))
            ];
          }
        },
        {
          conceptId: "probability-statistics-03-01",
          unitId: "statistics",
          key: "probstat-random-variable",
          title: "확률변수와 확률분포",
          labels: [
            "확률변수 뜻",
            "분포표 완성",
            "확률의 합",
            "함숫값 확률",
            "누적확률",
            "주사위 확률변수",
            "동전 확률변수",
            "미지 확률",
            "분포 판정",
            "종합 분포"
          ],
          buildProblems() {
            const p1 = randomInteger(1, 3) / 10;
            const p2 = randomInteger(
              1,
              8 - Math.round(p1 * 10)
            ) / 10;
            const p3 = round4(1 - p1 - p2);
            const dieFocus = randomInteger(1, 6);
            const coinTosses = randomInteger(2, 5);
            const coinHeads = randomInteger(
              1,
              coinTosses - 1
            );
            const weight = randomInteger(2, 5);
            const symmetricValue = randomInteger(1, 5);
            const symmetricProbability = randomInteger(1, 4) / 10;
            return [
              mc("확률변수 X에 대한 설명으로 옳은 것은?", ["표본공간의 결과를 수에 대응시키는 함수", "항상 연속인 함수", "확률 그 자체", "표본의 개수"], 0, "확률변수는 각 결과를 실수값에 대응시키는 함수입니다.", "결과를 숫자로 바꾸는 규칙이라고 생각하세요.", distributionVisual({ values: [0, 1, 2], probabilities: [0.2, 0.5, 0.3] })),
              sa(`P(X=0)=${p1}, P(X=1)=${p2}일 때 P(X=2)는?`, p3, `확률의 합이 1이므로 1-${p1}-${p2}=${p3}입니다.`, "분포표의 모든 확률을 더하면 1입니다.", distributionVisual({ values: [0, 1, 2], probabilities: [p1, p2, p3] })),
              sa(`X가 1,2,3을 각각 확률 ${p1}, ${p2}, ${p3}으로 가질 때 확률의 합은?`, 1, `${p1}+${p2}+${p3}=1입니다.`, "완전한 확률분포의 막대 높이 합을 보세요.", distributionVisual({ values: [1, 2, 3], probabilities: [p1, p2, p3] })),
              sa(`P(X=1)=${p1}, P(X=2)=${p2}, P(X=3)=${p3}일 때 P(X≥2)는?`, round4(p2 + p3), `${p2}+${p3}=${round4(p2 + p3)}입니다.`, "조건을 만족하는 막대의 확률만 더하세요.", distributionVisual({ values: [1, 2, 3], probabilities: [p1, p2, p3], focusFrom: 2 })),
              sa(`P(X=1)=${p1}, P(X=2)=${p2}, P(X=3)=${p3}일 때 P(X≤2)는?`, round4(p1 + p2), `${p1}+${p2}=${round4(p1 + p2)}입니다.`, "2 이하의 막대를 모두 더합니다.", distributionVisual({ values: [1, 2, 3], probabilities: [p1, p2, p3], focusTo: 2 })),
              sa(`주사위를 한 번 던져 X를 나온 눈이라 할 때 P(X=${dieFocus})는?`, probability(1, 6), "각 눈은 동일하게 1/6입니다.", `X=${dieFocus}에 해당하는 표본점은 하나입니다.`, distributionVisual({ values: [1, 2, 3, 4, 5, 6], probabilities: Array(6).fill(1 / 6), focus: dieFocus })),
              sa(`동전을 ${coinTosses}번 던져 X를 앞면 수라 할 때 P(X=${coinHeads})는?`, binomialProbability(coinTosses, 0.5, coinHeads), `${inlineMath(`\\binom{${coinTosses}}{${coinHeads}}(0.5)^${coinTosses}=${binomialProbability(coinTosses, 0.5, coinHeads)}`)}입니다.`, `X=${coinHeads}이 되는 앞면 위치를 고르세요.`, distributionVisual({ values: Array.from({ length: coinTosses + 1 }, (_, index) => index), probabilities: Array.from({ length: coinTosses + 1 }, (_, index) => binomialProbability(coinTosses, 0.5, index)), focus: coinHeads })),
              sa(`P(X=0)=a, P(X=1)=${weight}a, P(X=2)=a일 때 a는?`, round4(1 / (weight + 2)), `a+${weight}a+a=1이므로 a=${round4(1 / (weight + 2))}입니다.`, "모든 확률의 합이 1이라는 식을 세우세요.", distributionVisual({ values: [0, 1, 2], probabilities: [1 / (weight + 2), weight / (weight + 2), 1 / (weight + 2)] })),
              mc("확률분포가 될 수 없는 것은?", ["0.2, 0.3, 0.5", "0.1, 0.1, 0.8", "-0.1, 0.5, 0.6", "0, 0.4, 0.6"], 2, "확률은 음수가 될 수 없습니다.", "각 값의 범위와 전체 합을 모두 확인하세요.", distributionVisual({ values: [0, 1, 2], probabilities: [-0.1, 0.5, 0.6] })),
              sa(`X의 값이 -${symmetricValue},0,${symmetricValue}이고 확률이 각각 ${symmetricProbability},${round4(1 - 2 * symmetricProbability)},${symmetricProbability}일 때 P(|X|=${symmetricValue})는?`, round4(2 * symmetricProbability), `양 끝 확률을 더해 ${round4(2 * symmetricProbability)}입니다.`, `|X|=${symmetricValue}가 되는 두 막대를 고르세요.`, distributionVisual({ values: [-symmetricValue, 0, symmetricValue], probabilities: [symmetricProbability, 1 - 2 * symmetricProbability, symmetricProbability], focusValues: [-symmetricValue, symmetricValue] }))
            ];
          }
        },
        {
          conceptId: "probability-statistics-03-02",
          unitId: "statistics",
          key: "probstat-expectation-deviation",
          title: "이산확률변수의 기댓값과 표준편차",
          labels: [
            "기댓값",
            "분산",
            "표준편차",
            "선형변환 평균",
            "선형변환 분산",
            "공정한 게임",
            "미지 확률 평균",
            "편차 제곱",
            "두 점 분포",
            "종합 통계량"
          ],
          buildProblems() {
            const highValue = randomInteger(2, 6);
            const values = [0, 1, highValue];
            const firstProbability = randomInteger(1, 3) / 10;
            const secondProbability = randomInteger(2, 5) / 10;
            const thirdProbability = round4(
              1 - firstProbability - secondProbability
            );
            const probabilities = [
              firstProbability,
              secondProbability,
              thirdProbability
            ];
            const mean = round4(
              values.reduce(
                (sum, value, index) => sum + value * probabilities[index],
                0
              )
            );
            const variance = round4(
              values.reduce(
                (sum, value, index) => sum + (value - mean) ** 2 * probabilities[index],
                0
              )
            );
            const standardDeviation = randomInteger(1, 4);
            const baseMean = randomInteger(1, 6);
            const scale = randomInteger(2, 4);
            const shift = randomInteger(-3, 6);
            const baseVariance = randomInteger(1, 6);
            const win = randomInteger(5, 15) * 100;
            const loss = randomInteger(1, 8) * 100;
            const twoPointHigh = randomInteger(2, 8);
            const highProbability = randomInteger(2, 8) / 10;
            const deviationMean = randomInteger(-2, 5);
            const deviationValue = deviationMean + randomInteger(2, 6);
            const low = randomInteger(-3, 3);
            const high = low + 2 * randomInteger(1, 5);
            const midpoint = (low + high) / 2;
            const twoPointVariance = ((high - low) / 2) ** 2;
            return [
              sa(`X가 ${values.join(",")}를 확률 ${probabilities.join(",")}로 가질 때 E(X)는?`, mean, `각 값에 확률을 곱해 더하면 ${mean}입니다.`, "각 값에 그 확률을 곱해 모두 더하세요.", distributionVisual({ values, probabilities, mean })),
              sa(`X가 ${values.join(",")}를 확률 ${probabilities.join(",")}로 가질 때 V(X)를 구하세요.`, variance, `평균 ${mean}을 기준으로 편차 제곱을 가중평균하면 ${variance}입니다.`, "E(X²)-[E(X)]²을 계산하세요.", distributionVisual({ values, probabilities, mean, variance })),
              sa(`V(X)=${standardDeviation ** 2}일 때 표준편차 σ(X)는?`, standardDeviation, `표준편차는 분산의 양의 제곱근이므로 ${standardDeviation}입니다.`, "표준편차는 음수가 아닙니다.", distributionVisual({ variance: standardDeviation ** 2 })),
              sa(`E(X)=${baseMean}일 때 E(${scale}X${shift >= 0 ? `+${shift}` : shift})는?`, scale * baseMean + shift, `E(${scale}X${shift >= 0 ? `+${shift}` : shift})=${scale}E(X)${shift >= 0 ? `+${shift}` : shift}=${scale * baseMean + shift}입니다.`, "평균에는 곱과 더하기가 모두 반영됩니다.", distributionVisual({ mean: baseMean, transformedMean: scale * baseMean + shift })),
              sa(`V(X)=${baseVariance}일 때 V(${scale}X${shift >= 0 ? `+${shift}` : shift})는?`, scale ** 2 * baseVariance, `상수 이동은 분산을 바꾸지 않고 배율의 제곱을 곱하므로 ${scale}²×${baseVariance}=${scale ** 2 * baseVariance}입니다.`, `분산에는 ${scale}이 아니라 ${scale}²이 곱해집니다.`, distributionVisual({ variance: baseVariance, transformedVariance: scale ** 2 * baseVariance })),
              sa(`50% 확률로 ${win}원을 얻고 50% 확률로 ${loss}원을 잃는 게임의 기대수익은?`, (win - loss) / 2, `${win}×0.5+(-${loss})×0.5=${(win - loss) / 2}원입니다.`, "손실은 음수로 넣으세요.", distributionVisual({ values: [-loss, win], probabilities: [0.5, 0.5], mean: (win - loss) / 2 })),
              sa(`X가 0과 ${twoPointHigh}를 확률 p, 1-p로 갖고 E(X)=${round4(twoPointHigh * (1 - highProbability))}일 때 p는?`, highProbability, `${twoPointHigh}(1-p)=${round4(twoPointHigh * (1 - highProbability))}이므로 p=${highProbability}입니다.`, "기댓값 식을 p에 대해 푸세요.", distributionVisual({ values: [0, twoPointHigh], probabilities: [highProbability, 1 - highProbability], mean: twoPointHigh * (1 - highProbability) })),
              sa(`평균이 ${deviationMean}일 때 값 ${deviationValue}의 편차 제곱은?`, (deviationValue - deviationMean) ** 2, `(${deviationValue}-${deviationMean})²=${(deviationValue - deviationMean) ** 2}입니다.`, "값에서 평균을 뺀 뒤 제곱합니다.", distributionVisual({ values: [deviationMean, deviationValue], mean: deviationMean, focus: deviationValue })),
              sa(`X가 ${low}와 ${high}를 같은 확률로 가질 때 E(X)는?`, midpoint, `(${low}+${high})/2=${midpoint}입니다.`, "같은 확률인 두 점의 무게중심은 가운데입니다.", distributionVisual({ values: [low, high], probabilities: [0.5, 0.5], mean: midpoint })),
              sa(`X가 ${low}와 ${high}를 같은 확률로 가질 때 V(X)는?`, twoPointVariance, `평균 ${midpoint}에서 두 값까지의 거리는 ${(high - low) / 2}이므로 분산은 ${twoPointVariance}입니다.`, "각 편차 제곱을 확률로 가중평균하세요.", distributionVisual({ values: [low, high], probabilities: [0.5, 0.5], mean: midpoint, variance: twoPointVariance }))
            ];
          }
        },
        {
          conceptId: "probability-statistics-03-03",
          unitId: "statistics",
          key: "probstat-binomial-distribution",
          title: "이항분포",
          labels: [
            "이항확률",
            "정확히 k번",
            "한 번도 성공하지 않음",
            "적어도 한 번",
            "평균",
            "분산",
            "표준편차",
            "최빈값 관찰",
            "확률 비교",
            "종합 이항분포"
          ],
          buildProblems() {
            const n = randomInteger(4, 7);
            const p = [0.2, 0.3, 0.4, 0.5][randomInteger(0, 3)];
            const k = randomInteger(1, n - 1);
            const standardDeviation = randomInteger(1, 4);
            const standardDeviationN = 4 * standardDeviation ** 2;
            const defectN = randomInteger(5, 10);
            const defectP = [0.1, 0.2, 0.3][randomInteger(0, 2)];
            const defectK = randomInteger(
              1,
              Math.min(2, defectN - 1)
            );
            const probs = Array.from(
              { length: n + 1 },
              (_, index) => binomialProbability(n, p, index)
            );
            return [
              sa(`${inlineMath(`X\\sim B(${n},${p})`)}일 때 P(X=${k})를 소수로 구하세요.`, binomialProbability(n, p, k), `${inlineMath(`\\binom{${n}}{${k}}${p}^{${k}}(1-${p})^{${n - k}}`)}입니다.`, "성공 위치를 고르는 이항계수와 한 경로의 확률을 곱하세요.", binomialVisual({ n, p, probabilities: probs, focus: k })),
              sa(`성공확률 ${p}인 시행을 ${n}번 하여 정확히 ${k}번 성공할 확률은?`, binomialProbability(n, p, k), `${inlineMath(`\\binom{${n}}{${k}}${p}^{${k}}(1-${p})^{${n - k}}=${binomialProbability(n, p, k)}`)}입니다.`, `성공 ${k}번의 위치를 고르는 경우의 수를 포함하세요.`, binomialVisual({ n, p, focus: k })),
              sa(`${inlineMath(`X\\sim B(${n},${p})`)}일 때 P(X=0)는?`, round4((1 - p) ** n), `${inlineMath(`(1-${p})^{${n}}`)}입니다.`, "모든 시행이 실패하는 한 경로입니다.", binomialVisual({ n, p, probabilities: probs, focus: 0 })),
              sa(`성공확률 ${p}인 시행을 ${n}번 하여 적어도 한 번 성공할 확률은?`, round4(1 - (1 - p) ** n), `${inlineMath(`1-(1-${p})^{${n}}=${round4(1 - (1 - p) ** n)}`)}입니다.`, "X≥1의 여사건은 X=0입니다.", binomialVisual({ n, p, focusFrom: 1 })),
              sa(`${inlineMath(`X\\sim B(${n},${p})`)}의 평균을 구하세요.`, round4(n * p), `${inlineMath(`E(X)=np=${n}\\times${p}=${round4(n * p)}`)}입니다.`, "시행 횟수와 성공확률을 곱하세요.", binomialVisual({ n, p, mean: n * p })),
              sa(`${inlineMath(`X\\sim B(${n},${p})`)}의 분산을 구하세요.`, round4(n * p * (1 - p)), `${inlineMath(`V(X)=np(1-p)=${round4(n * p * (1 - p))}`)}입니다.`, "q=1-p를 먼저 구하세요.", binomialVisual({ n, p, mean: n * p })),
              sa(`${inlineMath(`X\\sim B(${standardDeviationN},0.5)`)}의 표준편차를 구하세요.`, standardDeviation, `${inlineMath(`\\sqrt{${standardDeviationN}\\cdot0.5\\cdot0.5}=${standardDeviation}`)}입니다.`, "분산 npq의 양의 제곱근입니다.", binomialVisual({ n: standardDeviationN, p: 0.5, mean: standardDeviationN / 2 })),
              mc("B(10,0.5)의 분포에서 중심에 가장 가까운 값은?", ["0", "2", "5", "10"], 2, "평균 np=5이고 대칭분포의 중심도 5입니다.", "p=0.5이면 분포가 중앙을 기준으로 대칭입니다.", binomialVisual({ n: 10, p: 0.5, mean: 5 })),
              mc("B(6,0.5)에서 P(X=2)와 P(X=4)의 관계는?", ["P(X=2)>P(X=4)", "같다", "P(X=2)<P(X=4)", "둘 다 0"], 1, "p=0.5인 분포는 n/2를 중심으로 대칭입니다.", "2와 4는 중심 3에서 같은 거리입니다.", binomialVisual({ n: 6, p: 0.5, focusValues: [2, 4] })),
              sa(`불량률 ${defectP}인 제품 ${defectN}개 중 정확히 ${defectK}개가 불량일 확률을 소수로 구하세요.`, binomialProbability(defectN, defectP, defectK), `${inlineMath(`\\binom{${defectN}}{${defectK}}${defectP}^{${defectK}}(1-${defectP})^{${defectN - defectK}}=${binomialProbability(defectN, defectP, defectK)}`)}입니다.`, `불량품 ${defectK}개의 위치를 고르는 경우의 수를 포함하세요.`, binomialVisual({ n: defectN, p: defectP, focus: defectK }))
            ];
          }
        },
        {
          conceptId: "probability-statistics-03-04",
          unitId: "statistics",
          key: "probstat-normal-binomial",
          title: "정규분포와 이항분포의 관계",
          labels: [
            "정규분포 대칭",
            "표준화",
            "구간확률",
            "평균 이동",
            "표준편차 변화",
            "이항분포 근사",
            "연속성 수정",
            "68% 규칙",
            "꼬리확률",
            "종합 정규분포"
          ],
          buildProblems() {
            const mean = randomInteger(5, 20) * 5;
            const sd = randomInteger(2, 10);
            const z = [0.5, 1, 1.5, 2][randomInteger(0, 3)];
            const focus = round4(mean + z * sd);
            const intervalZ = [0.5, 1, 1.5][randomInteger(0, 2)];
            const binomialN = randomInteger(5, 20) * 10;
            const binomialP = [0.2, 0.3, 0.4, 0.5, 0.6, 0.7][randomInteger(0, 5)];
            const binomialMean = binomialN * binomialP;
            const binomialSd = Math.sqrt(
              binomialN * binomialP * (1 - binomialP)
            );
            const continuityBoundary = randomInteger(
              Math.max(0, Math.floor(binomialMean - binomialSd)),
              Math.ceil(binomialMean + binomialSd)
            );
            const tailZ = [0.5, 1, 1.5, 2][randomInteger(0, 3)];
            const intervalMean = randomInteger(3, 15) * 5;
            const intervalSd = randomInteger(2, 8);
            return [
              sa(`정규분포 ${inlineMath(`N(${mean},${sd ** 2})`)}에서 평균보다 작은 값이 나올 확률은?`, 0.5, "정규분포는 평균을 중심으로 대칭이므로 왼쪽 넓이는 0.5입니다.", "평균을 지나는 세로선이 넓이를 반으로 나눕니다.", normalVisual({ mean, sd, shadeTo: mean })),
              sa(`${inlineMath(`X\\sim N(${mean},${sd ** 2})`)}에서 X=${focus}의 표준점수 z는?`, z, `표준편차는 ${sd}이므로 z=(${focus}-${mean})/${sd}=${z}입니다.`, "두 번째 모수는 분산이므로 먼저 제곱근을 구하세요.", normalVisual({ mean, sd, focus })),
              sa(`표준정규분포에서 P(-${intervalZ}≤Z≤${intervalZ})를 소수로 구하세요.`, round4(normalCdf(intervalZ) - normalCdf(-intervalZ)), `표준정규 누적확률의 차는 ${round4(normalCdf(intervalZ) - normalCdf(-intervalZ))}입니다.`, "양쪽 경계의 누적확률 차를 구하세요.", normalVisual({ mean: 0, sd: 1, shadeFrom: -intervalZ, shadeTo: intervalZ })),
              mc("정규분포의 평균이 커지면 그래프는 어떻게 변하는가?", ["오른쪽으로 이동", "폭만 넓어짐", "왼쪽으로 이동", "높이만 2배"], 0, "평균은 곡선의 중심 위치를 결정합니다.", "모양은 그대로이고 중심 좌표만 바뀝니다.", normalVisual({ mean: 2, sd: 1 })),
              mc("평균이 같고 표준편차가 커지면 정규곡선은?", ["더 좁고 높아진다", "더 넓고 낮아진다", "오른쪽 이동", "변하지 않는다"], 1, "전체 넓이는 1이므로 폭이 넓어지면 높이는 낮아집니다.", "표준편차는 자료가 중심에서 퍼진 정도입니다.", normalVisual({ mean: 0, sd: 2 })),
              sa(`${inlineMath(`X\\sim B(${binomialN},${binomialP})`)}를 정규근사할 때 근사 정규분포의 평균은?`, binomialMean, `np=${binomialN}×${binomialP}=${binomialMean}입니다.`, "이항분포와 근사 정규분포는 평균을 맞춥니다.", normalVisual({ mean: binomialMean, sd: binomialSd, binomial: true })),
              sa(`${inlineMath(`X\\sim B(${binomialN},${binomialP})`)}를 정규근사할 때 P(X≤${continuityBoundary})는 연속성 수정 후 어떤 경계까지 보는가?`, continuityBoundary + 0.5, `이산값 ${continuityBoundary}까지 포함하므로 연속 구간은 ${continuityBoundary + 0.5}까지입니다.`, "막대 하나의 폭을 1로 보고 오른쪽 경계를 사용하세요.", normalVisual({ mean: binomialMean, sd: binomialSd, shadeTo: continuityBoundary + 0.5, binomial: true })),
              sa(`정규분포 ${inlineMath(`N(${mean},${sd ** 2})`)}에서 평균±1표준편차 안에 들어갈 확률을 근사값으로 구하세요.`, round4(normalCdf(1) - normalCdf(-1)), "약 0.6827, 즉 68.27%입니다.", "분포의 평균과 표준편차가 달라도 표준화하면 -1부터 1까지입니다.", normalVisual({ mean, sd, shadeFrom: mean - sd, shadeTo: mean + sd })),
              sa(`표준정규분포에서 P(Z≥${tailZ})를 소수로 구하세요.`, round4(1 - normalCdf(tailZ)), `1-Φ(${tailZ})≈${round4(1 - normalCdf(tailZ))}입니다.`, "오른쪽 꼬리는 전체 1에서 왼쪽 누적확률을 뺍니다.", normalVisual({ mean: 0, sd: 1, shadeFrom: tailZ })),
              sa(`${inlineMath(`X\\sim N(${intervalMean},${intervalSd ** 2})`)}일 때 P(${intervalMean - intervalSd}≤X≤${intervalMean + intervalSd})를 소수로 구하세요.`, round4(normalCdf(1) - normalCdf(-1)), `표준편차는 ${intervalSd}이므로 두 경계의 z는 -1,1이고 확률은 약 0.6827입니다.`, `분산 ${intervalSd ** 2}의 제곱근이 표준편차 ${intervalSd}입니다.`, normalVisual({ mean: intervalMean, sd: intervalSd, shadeFrom: intervalMean - intervalSd, shadeTo: intervalMean + intervalSd }))
            ];
          }
        },
        {
          conceptId: "probability-statistics-03-05",
          unitId: "statistics",
          key: "probstat-population-sampling",
          title: "모집단과 표본추출",
          labels: [
            "모집단",
            "표본",
            "전수조사",
            "임의추출",
            "편향 판정",
            "층화추출",
            "군집추출",
            "표본 크기",
            "복원추출",
            "종합 표본설계"
          ],
          buildProblems() {
            return [
              mc("전국 고등학생의 평균 수면시간을 조사할 때 모집단은?", ["조사한 100명", "전국의 모든 고등학생", "조사원", "수면시간 평균"], 1, "알고 싶은 대상 전체가 모집단입니다.", "연구 결과를 적용하려는 전체 대상을 찾으세요.", samplingVisual({ population: 100, sample: 12 })),
              mc("전국 고등학생 중 무작위로 고른 500명은?", ["모수", "표본", "모집단", "확률변수"], 1, "모집단에서 실제 조사한 일부가 표본입니다.", "전체에서 선택된 일부 집단입니다.", samplingVisual({ population: 100, sample: 20 })),
              mc("모든 구성원을 조사하는 방법은?", ["표본조사", "전수조사", "층화추출", "계통추출"], 1, "모집단 전체를 빠짐없이 조사하면 전수조사입니다.", "일부가 아닌 전체를 조사합니다.", samplingVisual({ population: 60, sample: 60 })),
              mc("단순임의추출의 핵심 조건은?", ["편한 사람만 선택", "각 표본이 같은 선택 가능성", "항상 10명 선택", "남학생만 선택"], 1, "각 가능한 표본이 같은 기회를 갖도록 무작위화합니다.", "선택 가능성의 공정성을 확인하세요.", samplingVisual({ population: 80, sample: 10, random: true })),
              mc("학교 급식 만족도를 조사하면서 급식실 앞의 만족한 학생만 조사하면?", ["대표성이 높다", "선택 편향이 생길 수 있다", "전수조사다", "표본오차가 0이다"], 1, "응답자가 모집단을 고르게 대표하지 못할 수 있습니다.", "누가 조사에서 빠졌는지 생각하세요.", samplingVisual({ population: 80, sample: 10, biased: true })),
              mc("학년별 비율에 맞춰 각 학년에서 무작위로 뽑는 방법은?", ["층화추출", "군집추출", "편의추출", "전수조사"], 0, "모집단을 중요한 특성별 층으로 나눈 뒤 각 층에서 뽑습니다.", "각 학년을 하나의 층으로 봅니다.", samplingVisual({ strata: [30, 30, 40], sample: 15 })),
              mc("무작위로 몇 개 학급을 골라 그 학급 학생 전원을 조사하는 방법은?", ["층화추출", "군집추출", "계통추출", "복원추출"], 1, "자연스럽게 묶인 집단을 골라 집단 전체를 조사하는 군집추출입니다.", "개인이 아니라 학급 단위로 선택합니다.", samplingVisual({ clusters: 8, selectedClusters: 2 })),
              mc("일반적으로 같은 조건에서 표본 크기가 커지면?", ["표본오차가 줄어드는 경향", "편향이 자동으로 사라짐", "모집단이 작아짐", "모수가 변함"], 0, "표본 변동은 줄어들지만 잘못된 추출 방식의 편향이 자동으로 없어지는 것은 아닙니다.", "무작위 오차와 체계적 편향을 구분하세요.", samplingVisual({ population: 100, sample: 35 })),
              mc("뽑은 대상을 다시 모집단에 넣고 다음 대상을 뽑는 것은?", ["비복원추출", "복원추출", "층화추출", "군집추출"], 1, "매번 뽑은 대상을 되돌려 모집단 구성이 유지됩니다.", "다음 추출 전에 원래 상태로 돌아갑니다.", samplingVisual({ replacement: true })),
              mc("성별과 학년 비율을 모두 반영하고 싶을 때 가장 적절한 방법은?", ["편의추출", "관련 층을 만든 층화추출", "한 학급만 조사", "자원자만 조사"], 1, "중요한 하위집단을 층으로 나누고 비율에 맞게 무작위 추출합니다.", "대표해야 할 특성을 추출 설계에 포함하세요.", samplingVisual({ strata: [25, 25, 25, 25], sample: 20 }))
            ];
          }
        },
        {
          conceptId: "probability-statistics-03-06",
          unitId: "statistics",
          key: "probstat-sample-statistics",
          title: "표본통계량과 모수의 관계",
          labels: [
            "모수 판정",
            "통계량 판정",
            "표본평균의 평균",
            "표본평균 표준편차",
            "표본 크기 효과",
            "불편성",
            "표집분포",
            "표본비율",
            "표준오차",
            "종합 관계"
          ],
          buildProblems() {
            const populationMean = randomInteger(4, 20) * 5;
            const sampleRoot = randomInteger(3, 10);
            const sampleSize = sampleRoot ** 2;
            const standardError = randomInteger(1, 5);
            const populationSd = sampleRoot * standardError;
            const populationProportion = randomInteger(2, 8) / 10;
            const proportionRoot = randomInteger(5, 20);
            const proportionSampleSize = proportionRoot ** 2;
            const targetRoot = randomInteger(3, 10);
            const targetStandardError = randomInteger(1, 4);
            const targetPopulationSd = targetRoot * targetStandardError;
            return [
              mc("모집단 전체의 평균 μ는?", ["모수", "통계량", "표본", "사건"], 0, "모집단의 특성을 나타내는 고정된 수이므로 모수입니다.", "모집단 전체의 값인지 표본에서 계산한 값인지 구분하세요.", samplingVisual({ populationMean: 50 })),
              mc("한 표본에서 계산한 평균 x̄는?", ["모수", "통계량", "모집단", "확률"], 1, "표본 자료로부터 계산한 값이므로 통계량입니다.", "표본이 바뀌면 값도 바뀔 수 있습니다.", samplingVisual({ sampleMeans: [48, 51, 50, 52] })),
              sa(`모평균 μ=${populationMean}일 때 표본평균 X̄의 평균 E(X̄)는?`, populationMean, "표본평균의 기대값은 모평균과 같습니다.", "표본평균은 모평균의 불편추정량입니다.", samplingVisual({ populationMean, samplingMean: populationMean })),
              sa(`모표준편차 σ=${populationSd}, 표본크기 n=${sampleSize}일 때 표본평균의 표준편차는?`, standardError, `${inlineMath(`\\sigma/\\sqrt n=${populationSd}/${sampleRoot}=${standardError}`)}입니다.`, "표본평균의 표준오차는 σ/√n입니다.", samplingVisual({ populationSd, sampleSize, standardError })),
              mc("표본 크기를 4배로 하면 표본평균의 표준오차는?", ["4배", "2배", "1/2배", "변하지 않음"], 2, "표준오차는 1/√n에 비례하므로 4배 표본에서 절반입니다.", "제곱근 관계를 사용하세요.", samplingVisual({ sampleSizes: [25, 100] })),
              mc("E(X̄)=μ가 뜻하는 것은?", ["항상 X̄=μ", "표본평균이 모평균의 불편추정량", "표본오차가 0", "모집단이 정규분포"], 1, "여러 표본평균의 장기적인 중심이 모평균이라는 뜻입니다.", "한 번의 표본값과 표집분포의 평균을 구분하세요.", samplingVisual({ populationMean: 50, sampleMeans: [46, 49, 51, 54] })),
              mc("같은 크기의 표본을 반복해서 뽑아 얻은 X̄들의 분포는?", ["모집단", "표집분포", "조건부확률", "이항계수"], 1, "통계량이 반복 표집에서 만드는 확률분포입니다.", "분포를 이루는 값이 원자료인지 통계량인지 보세요.", samplingVisual({ sampleMeans: [47, 49, 50, 50, 51, 53] })),
              sa(`모비율 p=${populationProportion}일 때 표본비율 p̂의 평균은?`, populationProportion, `E(p̂)=p=${populationProportion}입니다.`, "표본비율도 모비율의 불편추정량입니다.", samplingVisual({ populationProportion, samplingMean: populationProportion })),
              sa(`p=${populationProportion}, n=${proportionSampleSize}일 때 표본비율의 표준편차는?`, round4(Math.sqrt(populationProportion * (1 - populationProportion) / proportionSampleSize)), `${inlineMath(`\\sqrt{${populationProportion}\\cdot${round4(1 - populationProportion)}/${proportionSampleSize}}\\approx${round4(Math.sqrt(populationProportion * (1 - populationProportion) / proportionSampleSize))}`)}입니다.`, "표본비율의 표준오차 공식 √(p(1-p)/n)을 사용하세요.", samplingVisual({ populationProportion, sampleSize: proportionSampleSize, standardError: Math.sqrt(populationProportion * (1 - populationProportion) / proportionSampleSize) })),
              sa(`모표준편차가 ${targetPopulationSd}일 때 표본평균의 표준오차를 ${targetStandardError}로 만들기 위한 표본크기 n은?`, targetRoot ** 2, `${inlineMath(`${targetPopulationSd}/\\sqrt n=${targetStandardError}`)}에서 √n=${targetRoot}, n=${targetRoot ** 2}입니다.`, "표준오차 식을 n에 대해 푸세요.", samplingVisual({ populationSd: targetPopulationSd, sampleSize: targetRoot ** 2, standardError: targetStandardError }))
            ];
          }
        },
        {
          conceptId: "probability-statistics-03-07",
          unitId: "statistics",
          key: "probstat-estimation",
          title: "모평균과 모비율의 추정",
          labels: [
            "모평균 신뢰구간",
            "오차한계",
            "표본 크기 효과",
            "신뢰수준 효과",
            "구간 해석",
            "모비율 신뢰구간",
            "표준오차",
            "하한과 상한",
            "필요 표본크기",
            "종합 추정"
          ],
          buildProblems() {
            const meanCenter = randomInteger(5, 20) * 5;
            const meanRoot = randomInteger(5, 12);
            const meanSampleSize = meanRoot ** 2;
            const meanSd = randomInteger(5, 15);
            const meanMargin = round4(
              1.96 * meanSd / meanRoot
            );
            const intervalCenter = randomInteger(5, 25) * 4;
            const intervalMargin = randomInteger(1, 8);
            const estimateProportion = randomInteger(2, 8) / 10;
            const estimateRoot = randomInteger(10, 25);
            const estimateSampleSize = estimateRoot ** 2;
            const proportionStandardError = Math.sqrt(
              estimateProportion * (1 - estimateProportion) / estimateSampleSize
            );
            const lowerCenter = randomInteger(10, 30) * 3;
            const lowerMargin = randomInteger(1, 8);
            const requiredRoot = randomInteger(4, 12);
            const requiredMargin = randomInteger(1, 5);
            const requiredSd = requiredRoot * requiredMargin / 2;
            const upperCenter = randomInteger(8, 30) * 3;
            const upperRoot = randomInteger(4, 12);
            const upperSd = randomInteger(2, 10);
            const upperMargin = round4(2 * upperSd / upperRoot);
            return [
              sa(`x̄=${meanCenter}, σ=${meanSd}, n=${meanSampleSize}일 때 95% 모평균 신뢰구간의 오차한계(1.96 사용)는?`, meanMargin, `${inlineMath(`1.96\\cdot${meanSd}/\\sqrt{${meanSampleSize}}=${meanMargin}`)}입니다.`, "임계값×표준오차를 계산하세요.", confidenceVisual({ center: meanCenter, margin: meanMargin })),
              sa(`추정값이 ${intervalCenter}이고 오차한계가 ${intervalMargin}일 때 신뢰구간의 길이는?`, 2 * intervalMargin, `하한 ${intervalCenter - intervalMargin}, 상한 ${intervalCenter + intervalMargin}이므로 전체 길이는 오차한계의 두 배인 ${2 * intervalMargin}입니다.`, "오차한계는 중심에서 한쪽 끝까지의 거리입니다.", confidenceVisual({ center: intervalCenter, margin: intervalMargin })),
              mc("다른 조건이 같을 때 표본 크기가 커지면 신뢰구간은?", ["넓어진다", "좁아진다", "중심이 0이 된다", "항상 같다"], 1, "표준오차가 1/√n에 따라 작아져 구간이 좁아집니다.", "표본 크기와 표준오차의 관계를 보세요.", confidenceVisual({ intervals: [[50, 4], [50, 2]] })),
              mc("다른 조건이 같을 때 신뢰수준을 높이면 신뢰구간은?", ["좁아진다", "넓어진다", "사라진다", "중심만 이동"], 1, "더 높은 포착률을 원하면 더 넓은 구간이 필요합니다.", "신뢰수준과 정밀도 사이의 교환관계입니다.", confidenceVisual({ intervals: [[50, 2], [50, 3]] })),
              mc("95% 신뢰구간 [48,52]의 올바른 해석에 가장 가까운 것은?", ["모평균이 반드시 50이다", "같은 절차를 반복하면 약 95%의 구간이 모평균을 포함한다", "자료의 95%가 48~52다", "표본평균이 95% 확률로 변한다"], 1, "신뢰수준은 반복되는 구간 생성 절차의 장기적 포함률입니다.", "모수는 고정되고 구간이 표본마다 달라집니다.", confidenceVisual({ center: 50, margin: 2 })),
              sa(`표본비율 p̂=${estimateProportion}, n=${estimateSampleSize}일 때 95% 모비율 신뢰구간의 오차한계를 소수로 구하세요. (1.96 사용)`, round4(1.96 * proportionStandardError), `${inlineMath(`1.96\\sqrt{${estimateProportion}\\cdot${round4(1 - estimateProportion)}/${estimateSampleSize}}\\approx${round4(1.96 * proportionStandardError)}`)}입니다.`, "표본비율 표준오차에 1.96을 곱하세요.", confidenceVisual({ center: estimateProportion, margin: 1.96 * proportionStandardError })),
              sa(`p̂=${estimateProportion}, n=${estimateSampleSize}일 때 표본비율의 표준오차를 구하세요.`, round4(proportionStandardError), `${inlineMath(`\\sqrt{${estimateProportion}\\cdot${round4(1 - estimateProportion)}/${estimateSampleSize}}\\approx${round4(proportionStandardError)}`)}입니다.`, "√(p̂(1-p̂)/n)을 사용하세요.", confidenceVisual({ center: estimateProportion, margin: proportionStandardError })),
              sa(`중심이 ${lowerCenter}이고 오차한계가 ${lowerMargin}인 신뢰구간의 하한은?`, lowerCenter - lowerMargin, `${lowerCenter}-${lowerMargin}=${lowerCenter - lowerMargin}입니다.`, "중심에서 오차한계를 빼세요.", confidenceVisual({ center: lowerCenter, margin: lowerMargin })),
              sa(`σ=${requiredSd}, 오차한계 ${requiredMargin}, 95% 임계값을 2로 근사할 때 필요한 표본크기 n은?`, requiredRoot ** 2, `${inlineMath(`2\\cdot${requiredSd}/\\sqrt n=${requiredMargin}`)}에서 √n=${requiredRoot}, n=${requiredRoot ** 2}입니다.`, "오차한계 공식을 n에 대해 정리하세요.", confidenceVisual({ center: 0, margin: requiredMargin, sampleSize: requiredRoot ** 2 })),
              sa(`x̄=${upperCenter}, σ=${upperSd}, n=${upperRoot ** 2}일 때 95% 모평균 신뢰구간의 상한을 구하세요. (임계값 2 사용)`, round4(upperCenter + upperMargin), `오차한계는 ${inlineMath(`2\\cdot${upperSd}/${upperRoot}=${upperMargin}`)}이므로 상한은 ${round4(upperCenter + upperMargin)}입니다.`, "먼저 표준오차, 다음 오차한계, 마지막 상한 순서입니다.", confidenceVisual({ center: upperCenter, margin: upperMargin }))
            ];
          }
        }
      ];
      var generators = definitions.map((definition) => ({
        key: definition.key,
        courseId: "probability-statistics",
        unitId: definition.unitId,
        conceptId: definition.conceptId,
        requiredDistinctTypes: 5,
        problemTypes: createProblemTypes({
          conceptId: definition.conceptId,
          conceptTitle: definition.title,
          labels: definition.labels,
          buildProblems: definition.buildProblems
        }),
        isCorrectAnswer
      }));
      var generatorMap = new Map(
        generators.map((generator) => [
          [
            generator.courseId,
            generator.unitId,
            generator.conceptId
          ].join("/"),
          generator
        ])
      );
      module.exports = {
        definitions,
        generators,
        generatorMap
      };
    }
  });

  // services/problemGenerators/index.js
  var require_problemGenerators = __commonJS({
    "services/problemGenerators/index.js"(exports, module) {
      var functionLimit = require_functionLimit();
      var limitPropertiesAndCalculation = require_limitPropertiesAndCalculation();
      var functionContinuity = require_functionContinuity();
      var continuousFunctionProperties = require_continuousFunctionProperties();
      var {
        generatorMap: advancedCalculusGeneratorMap
      } = require_advancedCalculus();
      var powersAndRoots = require_powersAndRoots();
      var rationalAndRealExponents = require_rationalAndRealExponents();
      var exponentLaws = require_exponentLaws();
      var logarithmDefinitionAndProperties = require_logarithmDefinitionAndProperties();
      var commonLogarithmApplications = require_commonLogarithmApplications();
      var exponentialAndLogarithmicFunctions = require_exponentialAndLogarithmicFunctions();
      var exponentialAndLogarithmicGraphs = require_exponentialAndLogarithmicGraphs();
      var exponentialAndLogarithmicApplications = require_exponentialAndLogarithmicApplications();
      var generalAnglesAndRadians = require_generalAnglesAndRadians();
      var trigonometricFunctionsAndGraphs = require_trigonometricFunctionsAndGraphs();
      var sineAndCosineLaws = require_sineAndCosineLaws();
      var sequenceBasics = require_sequenceBasics();
      var arithmeticSequences = require_arithmeticSequences();
      var geometricSequences = require_geometricSequences();
      var sigmaDefinitionAndProperties = require_sigmaDefinitionAndProperties();
      var sumsOfVariousSequences = require_sumsOfVariousSequences();
      var recursiveSequences = require_recursiveSequences();
      var mathematicalInduction = require_mathematicalInduction();
      var {
        generatorMap: probabilityStatisticsGeneratorMap
      } = require_generators2();
      var {
        generatorMap: commonMathGeneratorMap
      } = require_generators();
      var generatorRegistry = new Map([
        [
          [
            "calculus-1",
            "limits-and-continuity",
            "calculus-1-01-01"
          ].join("/"),
          functionLimit
        ],
        [
          [
            "calculus-1",
            "limits-and-continuity",
            "calculus-1-01-02"
          ].join("/"),
          limitPropertiesAndCalculation
        ],
        [
          [
            "calculus-1",
            "limits-and-continuity",
            "calculus-1-01-03"
          ].join("/"),
          functionContinuity
        ],
        [
          [
            "calculus-1",
            "limits-and-continuity",
            "calculus-1-01-04"
          ].join("/"),
          continuousFunctionProperties
        ],
        ...advancedCalculusGeneratorMap.entries(),
        [
          [
            "algebra",
            "exponential-logarithmic-functions",
            "algebra-01-01"
          ].join("/"),
          powersAndRoots
        ],
        [
          [
            "algebra",
            "exponential-logarithmic-functions",
            "algebra-01-02"
          ].join("/"),
          rationalAndRealExponents
        ],
        [
          [
            "algebra",
            "exponential-logarithmic-functions",
            "algebra-01-03"
          ].join("/"),
          exponentLaws
        ],
        [
          [
            "algebra",
            "exponential-logarithmic-functions",
            "algebra-01-04"
          ].join("/"),
          logarithmDefinitionAndProperties
        ],
        [
          [
            "algebra",
            "exponential-logarithmic-functions",
            "algebra-01-05"
          ].join("/"),
          commonLogarithmApplications
        ],
        [
          [
            "algebra",
            "exponential-logarithmic-functions",
            "algebra-01-06"
          ].join("/"),
          exponentialAndLogarithmicFunctions
        ],
        [
          [
            "algebra",
            "exponential-logarithmic-functions",
            "algebra-01-07"
          ].join("/"),
          exponentialAndLogarithmicGraphs
        ],
        [
          [
            "algebra",
            "exponential-logarithmic-functions",
            "algebra-01-08"
          ].join("/"),
          exponentialAndLogarithmicApplications
        ],
        [
          [
            "algebra",
            "trigonometric-functions",
            "algebra-02-01"
          ].join("/"),
          generalAnglesAndRadians
        ],
        [
          [
            "algebra",
            "trigonometric-functions",
            "algebra-02-02"
          ].join("/"),
          trigonometricFunctionsAndGraphs
        ],
        [
          [
            "algebra",
            "trigonometric-functions",
            "algebra-02-03"
          ].join("/"),
          sineAndCosineLaws
        ],
        [
          [
            "algebra",
            "sequences",
            "algebra-03-01"
          ].join("/"),
          sequenceBasics
        ],
        [
          [
            "algebra",
            "sequences",
            "algebra-03-02"
          ].join("/"),
          arithmeticSequences
        ],
        [
          [
            "algebra",
            "sequences",
            "algebra-03-03"
          ].join("/"),
          geometricSequences
        ],
        [
          [
            "algebra",
            "sequences",
            "algebra-03-04"
          ].join("/"),
          sigmaDefinitionAndProperties
        ],
        [
          [
            "algebra",
            "sequences",
            "algebra-03-05"
          ].join("/"),
          sumsOfVariousSequences
        ],
        [
          [
            "algebra",
            "sequences",
            "algebra-03-06"
          ].join("/"),
          recursiveSequences
        ],
        [
          [
            "algebra",
            "sequences",
            "algebra-03-07"
          ].join("/"),
          mathematicalInduction
        ],
        ...probabilityStatisticsGeneratorMap.entries(),
        ...commonMathGeneratorMap.entries()
      ]);
      function getProblemGenerator({
        courseId,
        unitId,
        conceptId
      }) {
        return generatorRegistry.get(
          [courseId, unitId, conceptId].join("/")
        ) || null;
      }
      function listProblemGeneratorRegistrations() {
        return [...generatorRegistry.entries()].map(
          ([registryKey, generator]) => {
            const [courseId, unitId, conceptId] = registryKey.split("/");
            const cachedModule = Object.values(__require.cache).find(
              (entry) => entry?.exports === generator
            );
            return {
              registryKey,
              courseId,
              unitId,
              conceptId,
              generator,
              sourceFile: cachedModule?.filename || ""
            };
          }
        );
      }
      module.exports = {
        getProblemGenerator,
        listProblemGeneratorRegistrations
      };
    }
  });

  // ../../../tmp/matths-web-reference-0907/ios-webgen-entry.cjs
  var require_ios_webgen_entry = __commonJS({
    "../../../tmp/matths-web-reference-0907/ios-webgen-entry.cjs"() {
      var templates = require_assessmentTemplates();
      var { getProblemGenerator } = require_problemGenerators();
      var { generateValidProblem } = require_utils();
      function tryGenerate(generate) {
        for (let attempt = 0; attempt < 40; attempt++) {
          try {
            const p = generate();
            if (p?.prompt && p.answer !== void 0 && p.answer !== null && String(p.answer).length) return p;
          } catch {
          }
        }
        return null;
      }
      var present = (p) => ({
        prompt: p.prompt,
        choices: Array.isArray(p.choices) && p.choices.length ? p.choices : null,
        answer: String(p.answer),
        solution: p.solution || "",
        hintText: p.hintText || "",
        visualization: p.visualization || null
      });
      globalThis.MatthsWebGen = {
        drawAdvanced(courseId, unitId, learned, count) {
          const config = (templates.unitConfigs || []).find((x) => x.courseId === courseId && x.unitId === unitId);
          if (!config) return [];
          const learnedSet = new Set(learned || []);
          const eligible = config.advancedTemplates.filter((t) => !learnedSet.size || (t.stages || []).some((s) => (s.requiredConceptIds || []).every((id) => learnedSet.has(id))) || (t.requiredConceptIds || []).every((id) => learnedSet.has(id)));
          const pool = eligible.length ? eligible : config.advancedTemplates;
          const output = [], used = /* @__PURE__ */ new Set();
          for (let tries = 0; output.length < count && tries < count * 8; tries++) {
            const t = pool[Math.floor(Math.random() * pool.length)];
            if (!t || used.has(t.id) && used.size < pool.length) continue;
            let generate = t.generate;
            for (const s of t.stages || []) if ((s.requiredConceptIds || []).every((id) => learnedSet.has(id))) generate = s.generate;
            const p = tryGenerate(generate);
            if (!p) continue;
            used.add(t.id);
            output.push({ ...present(p), templateId: t.id, title: t.title || "", estimatedMinutes: t.estimatedMinutes || 8, sourcePattern: t.sourcePattern || "" });
          }
          return output;
        },
        conceptGeneratorInfo(courseId, unitId, conceptId) {
          const g = getProblemGenerator({ courseId, unitId, conceptId });
          return g ? {
            key: g.key,
            requiredDistinctTypes: g.requiredDistinctTypes || 5,
            types: (g.problemTypes || []).map((t) => ({ id: t.id, label: t.label || "", difficulty: t.difficulty || 1 }))
          } : null;
        },
        generateLocal(courseId, unitId, conceptId, typeId, count) {
          const g = getProblemGenerator({ courseId, unitId, conceptId });
          const types = (g?.problemTypes || []).filter((t) => !typeId || t.id === typeId);
          if (!types.length) return [];
          const output = [];
          for (let tries = 0; output.length < count && tries < count * 6; tries++) {
            const t = types[Math.floor(Math.random() * types.length)], p = tryGenerate(t.generate);
            if (p) output.push({ ...present(p), typeId: t.id, label: t.label || "", difficulty: t.difficulty || 1 });
          }
          return output;
        }
      };
    }
  });
  require_ios_webgen_entry();
})();
