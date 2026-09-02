//  SheetAnalysis.swift
//  Matths
//
//  Pro 시험지 분석 결과 모델 — sheet-grader/skill/SKILL.md 의 최종 템플릿과 1:1.
//  서버가 그 JSON 을 주면 이 모델로 디코드해서 그대로 렌더한다.
//
//  아래 demo 데이터는 지어낸 것이 아니라 **실물 고3 모의고사 2쪽을 실제로 분석한
//  골든 예시**(sheet-grader/skill/golden/*.json)를 옮긴 것이다.
//  스킬 파이프라인이 도달해야 하는 품질 기준이기도 하다.

import SwiftUI

enum AnalysisStatus: String {
    case correct         = "correct"          // 완답
    case selfCorrected   = "self-corrected"   // 스스로 고쳐 완답
    case calcSlip        = "calc-slip"        // 계산 실수
    case conceptError    = "concept-error"    // 개념 오류
    case strategyStuck   = "strategy-stuck"   // 전략 부재로 중단
    case blank           = "blank"            // 미착수
    /// 판독이 불확실해 **채점을 보류**한 상태.
    /// 맞은 학생을 틀렸다고 모는 것보다 "모르겠다" 고 말하는 편이 낫다.
    case unknown         = "unknown"

    var label: String {
        switch self {
        case .correct:       return "완답"
        case .selfCorrected: return "완답 · 자기 교정"
        case .calcSlip:      return "계산 실수"
        case .conceptError:  return "개념 오류"
        case .strategyStuck: return "전략 막힘"
        case .blank:         return "미착수"
        case .unknown:       return "판정 보류"
        }
    }

    var color: Color {
        switch self {
        case .correct, .selfCorrected: return Tokens.success
        case .calcSlip:                return Tokens.warning
        case .conceptError, .strategyStuck: return Tokens.primary
        case .blank:                   return Tokens.text4
        case .unknown:                 return Tokens.warning
        }
    }

    var icon: String {
        switch self {
        case .correct:       return "checkmark"
        case .selfCorrected: return "checkmark.seal"
        case .calcSlip:      return "plusminus"
        case .conceptError:  return "questionmark"
        case .strategyStuck: return "signpost.right"
        case .blank:         return "minus"
        case .unknown:       return "questionmark.circle"
        }
    }
}

struct ProblemAnalysisItem: Identifiable {
    let no: Int
    let points: Int
    let topic: String
    let typeKey: ProblemType?     // 생성기 유형과 연결 — 유사 문제 재출제용. nil 이면 준비 중
    let status: AnalysisStatus
    let studentAnswer: String
    let didWell: [String]         // "여기까지 잘했다"
    let stuckAt: String?          // "여기서 막혔다"
    let errorWhy: String?         // 왜 그렇게 판정했는가
    let errorFix: String?         // 학생이 쓴 것에서 출발하는 교정 방향
    let coachNote: String
    /// AI 가 읽은 발문 (요약). 화면에 함께 보여 준다 —
    /// 판독이 틀렸을 때 학생이 **그 자리에서 알아챌 수 있어야** 한다.
    var statementRead: String? = nil
    /// 발문 판독이 불확실한가 (재확인 패스에서 두 판독이 어긋남).
    /// true 면 화면은 정오 판정을 **단정하지 않는다.**
    var statementUncertain: Bool = false

    var id: Int { no }
}

#if DEBUG
/// 내부 UI 회귀용 실물 시험지 2쪽 골든 예시. 정식 바이너리에는 컴파일하지 않는다.
enum SheetAnalysisDemo {
    static let pages: [(title: String, items: [ProblemAnalysisItem])] = [
        ("3쪽 · 8~10번", [
            ProblemAnalysisItem(
                no: 8, points: 3, topic: "로그의 성질", typeKey: .logEq,
                status: .correct, studentAnswer: "③ 3/2 (정답)",
                didWell: [
                    "(log3)²−(log2)² 합차 인수분해로 관문 통과",
                    "log₆10 밑변환으로 log6 소거 구조를 보고 들어감",
                    "10^(log 3/2) = 3/2 역연산 마무리",
                ],
                stuckAt: nil, errorWhy: nil, errorFix: nil,
                coachNote: "흠잡을 데가 없다. 합차 → 밑변환 → 소거, 출제 의도를 순서대로 밟았다."
            ),
            ProblemAnalysisItem(
                no: 9, points: 4, topic: "속도와 거리 · 정적분", typeKey: .integral,
                status: .selfCorrected, studentAnswer: "③ 116 (정답)",
                didWell: [
                    "'위치가 0' 을 ∫₀ᵃv = 0 으로 정확히 번역, a = 3 도출",
                    "속도 부호 변화(t=2)를 잡고 |v| 적분을 ∫₀² − ∫₂⁶ 로 분할",
                    "상한을 3 으로 잘못 잡았다가 스스로 지우고 2a = 6 재확인 — 이 검산이 4점을 지켰다",
                ],
                stuckAt: nil,
                errorWhy: "−216+108 을 한 줄에서 −109 로 옮겨 적었으나 다음 줄에서 바로잡혀 결과에 전파 안 됨",
                errorFix: "감점 없음. 큰 수 옮길 때 한 번씩 소리 내 확인하는 습관이면 충분",
                coachNote: "상한 실수를 스스로 잡아낸 게 이 페이지에서 제일 잘한 일이다."
            ),
            ProblemAnalysisItem(
                no: 10, points: 4, topic: "주기 수열의 합", typeKey: .seqBlockSum,
                status: .conceptError, studentAnswer: "미기입 (정답 ⑤ 29)",
                didWell: [
                    "첫 관찰이 정답 루트였다: [10, 10, −19] 블록 묶음 → 블록 합 1 → S₃ₙ = n",
                ],
                stuckAt: "블록 관찰을 버리고 등차수열 합 공식으로 갈아탄 지점",
                errorWhy: "이 수열은 주기 수열이지 등차가 아니다. 조건 확인 없이 등차 합 공식을 적용해 n = −3 모순이 나왔고 거기서 중단",
                errorFix: "본인이 그린 블록 그림으로 돌아가면 된다: S₃ₙ = n, n = 3k+2 에서 Sₙ = k+20 → k = 9 → n = 29",
                coachNote: "공식이 그림을 이긴 게 아니라 그림을 믿지 못한 게 패인이다. 공식 앞에서 '이거 등차 맞나?' 한 줄만 검문해라. 모순(n = −3)이 나오면 공식이 아니라 가정을 의심해라."
            ),
        ]),
        ("8쪽 · 21~22번", [
            ProblemAnalysisItem(
                no: 21, points: 4, topic: "조건 분기 점화식", typeKey: nil,
                status: .blank, studentAnswer: "미기입",
                didWell: [],
                stuckAt: "착수 흔적 없음 — 지면의 곡선 낙서는 전부 22번의 삼차함수 개형",
                errorWhy: nil,
                errorFix: "a₉ = 2 에서 거꾸로 올라가는 역추적 유형은 시작만 해도 반은 온다",
                coachNote: "빈칸은 분석할 것도 없다. 시작 안 한 이유가 시간인지 회피인지부터 확인하자."
            ),
            ProblemAnalysisItem(
                no: 22, points: 4, topic: "절댓값 삼차함수 미분가능", typeKey: .extremum,
                status: .strategyStuck, studentAnswer: "미기입",
                didWell: [
                    "x = 0 연속 조건 |f(0)|−8 = −f(0) 을 정확히 세워 f(0) = 4 도출",
                    "최고차항 부호(a < 0) 케이스 분리 시도 — 방향 자체는 옳다",
                ],
                stuckAt: "f(0) = 4 이후. 미분가능 조건을 식으로 세우지 못하고 개형 스케치만 십수 회 반복하다 중단",
                errorWhy: "이 문제는 그림이 아니라 등식 두 개에서 풀린다: x=0 좌우 도함수 일치, x=2 에서 |2x²−8| 꺾임 상쇄. 스케치는 후보를 줄일 뿐 답을 만들지 못한다",
                errorFix: "절차 고정: 꺾일 수 있는 점 나열 → 각 점의 연속·좌우도함수 등식 → 연립. 그림은 마지막에 근 고를 때만",
                coachNote: "f(0) = 4 까지는 맞는 길이었다. 다음에 필요했던 건 그림 열두 장이 아니라 등식 두 줄이었다."
            ),
        ]),
    ]

    /// 약한 유형 중 생성기가 지원하는 것 — "유사 모의고사" 버튼의 입력
    static var weakGeneratorTypes: [ProblemType] {
        pages.flatMap(\.items)
            .filter { [.conceptError, .strategyStuck, .calcSlip].contains($0.status) }
            .compactMap(\.typeKey)
    }
}
#endif
