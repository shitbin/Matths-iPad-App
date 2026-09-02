import Foundation

// CoachEngine 은 GeneratedProblem 에서 typeKey · typeName · isMultipleChoice
// 세 가지만 읽는다. 문제 생성기 전체(MathAnswer·ProblemGenerator)를 끌고 오면
// 코치 계약과 무관한 이유로 이 테스트가 깨지므로, 그 세 가지만 흉내 낸다.
struct GeneratedProblem {
    let typeKey: String
    let typeName: String
    var choices: [String]? = nil

    var isMultipleChoice: Bool { choices != nil }
}

private let logProblem = GeneratedProblem(
    typeKey: "alg-log-equation", typeName: "로그방정식")
private let choiceProblem = GeneratedProblem(
    typeKey: "prob-conditional", typeName: "조건부확률",
    choices: ["1/2", "1/3", "1/4", "1/5"])

private func lines(_ g: CoachGuidance) -> String {
    "\(g.observation) \(g.reason) \(g.nextAction)"
}

/// 코치가 말해도 되는 것은 이번 시도에서 확인된 값과 실제로 남은 기록뿐이다.
/// 원인 추정은 최종 답 하나로 확정할 수 없으므로 문장에 들어가면 안 된다.
private let speculation = [
    "것 같", "같아요", "헷갈", "실수", "놓쳤", "때문에", "아마", "보입니다",
]

@main
struct CoachGuidanceCases {
    static func main() {
        observationQuotesThisAttempt()
        repeatedAnswerIsNamedAsFact()
        spiceChangesToneOnly()
        correctAnswerUsesThisAttempt()
        multipleChoiceUsesTheNumberOnScreen()
        silentStaysSilent()
        streakStillSoftens()
        guidanceIsDeterministic()
        labelsHaveOneOwner()
        print("Coach guidance evidence contract passed")
    }

    // 관찰은 이번에 제출한 값을 그대로 인용한다.
    static func observationQuotesThisAttempt() {
        var coach = CoachEngine()
        coach.level = .spicy
        guard let g = coach.guidance(
            problem: logProblem, studentInput: "-2", correct: false)
        else { preconditionFailure("매운맛에서 진단이 비었다") }

        // 단계명은 화면의 칩 한 곳만 소유한다. 엔진 본문은 유형 이름부터 시작한다.
        precondition(g.observation.hasPrefix("로그방정식"),
                     "관찰은 유형 이름으로 시작해야 함: \(g.observation)")
        precondition(g.observation.contains("“-2”"),
                     "관찰에 이번 제출값이 없다: \(g.observation)")
        precondition(g.observation.contains("음수 부호를 포함한 답"),
                     "제출값의 형식 설명이 사라졌다: \(g.observation)")
        precondition(g.reason.hasPrefix("①") && g.reason.contains("②"),
                     "점검 지점은 두 개여야 함: \(g.reason)")
        precondition(g.reason.contains("밑 조건과 진수가 양수"),
                     "유형별 점검 지점이 사라졌다: \(g.reason)")
        // 바로 할 행동도 학생이 낸 값 위에서 만들어져야 한다.
        precondition(g.nextAction.contains("“-2”"),
                     "다음 행동에 이번 제출값이 없다: \(g.nextAction)")
        for word in speculation {
            precondition(!lines(g).contains(word),
                         "확인되지 않은 원인 추정(\(word))이 들어갔다: \(lines(g))")
        }
    }

    // 같은 값을 다시 낸 것은 확인 가능한 사실이므로 그대로 말한다.
    static func repeatedAnswerIsNamedAsFact() {
        var coach = CoachEngine()
        coach.level = .mild
        _ = coach.guidance(problem: logProblem, studentInput: "-2", correct: false)
        guard let g = coach.guidance(
            problem: logProblem, studentInput: "-2", correct: false)
        else { preconditionFailure("두 번째 시도 진단이 비었다") }

        precondition(g.observation.contains("직전 시도와 같은 값입니다."),
                     "반복 제출이 관찰에 없다: \(g.observation)")
        precondition(g.reason.contains("바뀐 줄이 없습니다"),
                     "반복 제출이 점검 순서를 바꾸지 못했다: \(g.reason)")

        // 기록이 쌓이면 셀 수 있는 사실을 말한다 (같은 값 반복이 아닐 때).
        var counter = CoachEngine()
        counter.level = .mild
        _ = counter.guidance(problem: logProblem, studentInput: "-2", correct: false)
        _ = counter.guidance(problem: logProblem, studentInput: "0", correct: false)
        guard let third = counter.guidance(
            problem: logProblem, studentInput: "5", correct: false)
        else { preconditionFailure("세 번째 시도 진단이 비었다") }
        precondition(
            third.observation.contains("이번 세션에서 이 유형은 3번 중 3번 틀렸습니다."),
            "현재 제출까지 포함한 유형별 누적이 관찰에 없다: \(third.observation)")
        precondition(
            !third.observation.contains("2번 중 2번"),
            "현재 제출을 빼고 이전 기록만 표시한다: \(third.observation)")
    }

    // 순한맛·매운맛은 말투만 바꾼다. 진단 내용과 수학적 판단은 같아야 한다.
    static func spiceChangesToneOnly() {
        var mild = CoachEngine()
        mild.level = .mild
        var spicy = CoachEngine()
        spicy.level = .spicy

        guard
            let m = mild.guidance(problem: logProblem, studentInput: "-2", correct: false),
            let s = spicy.guidance(problem: logProblem, studentInput: "-2", correct: false)
        else { preconditionFailure("수위 비교 진단이 비었다") }

        precondition(m.observation == s.observation, "수위가 관찰을 바꿨다")
        precondition(m.reason == s.reason, "수위가 점검 순서를 바꿨다")
        precondition(s.nextAction.contains("답을 다시 찍지 말고"),
                     "매운맛 말투가 사라졌다: \(s.nextAction)")
        precondition(!m.nextAction.contains("답을 다시 찍지 말고"),
                     "순한맛에 매운맛 말투가 붙었다: \(m.nextAction)")
        precondition(
            s.nextAction.replacingOccurrences(of: "답을 다시 찍지 말고, ", with: "")
                == m.nextAction,
            "수위가 지시 내용까지 바꿨다")
    }

    // 정답도 이번 제출값 위에서 말한다 (예전엔 고정 세 줄이었다).
    static func correctAnswerUsesThisAttempt() {
        var coach = CoachEngine()
        coach.level = .mild
        _ = coach.guidance(problem: logProblem, studentInput: "-2", correct: false)
        guard let g = coach.guidance(
            problem: logProblem, studentInput: "2", correct: true)
        else { preconditionFailure("정답 진단이 비었다") }

        precondition(g.observation.contains("“2”"),
                     "정답 관찰에 제출값이 없다: \(g.observation)")
        precondition(g.observation.contains("직전에 낸 “-2”를 이번에 고쳤습니다."),
                     "직전 오답을 고친 사실이 없다: \(g.observation)")
        precondition(g.reason.contains("갈라진 첫 줄"),
                     "정답 점검이 값에 붙지 않았다: \(g.reason)")
        for word in speculation {
            precondition(!lines(g).contains(word),
                         "정답 진단에 추측(\(word))이 들어갔다: \(lines(g))")
        }

        // 바로 앞 시도가 정답이면 "직전에 고쳤다" 고 말할 수 없다.
        guard let again = coach.guidance(
            problem: logProblem, studentInput: "2", correct: true)
        else { preconditionFailure("연속 정답 진단이 비었다") }
        precondition(!again.observation.contains("직전에 낸"),
                     "직전이 정답인데 고쳤다고 말한다: \(again.observation)")
    }

    // 객관식은 보기 키(a·b·c)가 아니라 학생이 화면에서 본 번호로 말한다.
    static func multipleChoiceUsesTheNumberOnScreen() {
        var coach = CoachEngine()
        coach.level = .mild
        guard let g = coach.guidance(
            problem: choiceProblem, studentInput: "c", correct: false)
        else { preconditionFailure("객관식 진단이 비었다") }

        precondition(g.observation.contains("“3번”"),
                     "고른 보기 번호가 없다: \(g.observation)")
        precondition(g.observation.contains("선택한 보기"),
                     "객관식 형식 설명이 없다: \(g.observation)")
        precondition(g.nextAction.contains("3번을 정답이라고 두고"),
                     "다음 행동이 고른 보기로 만들어지지 않았다: \(g.nextAction)")
    }

    // 무음은 문구를 내지 않는다.
    static func silentStaysSilent() {
        var coach = CoachEngine()
        coach.level = .silent
        precondition(
            coach.guidance(problem: logProblem, studentInput: "-2", correct: false) == nil,
            "무음에서 진단이 나왔다")
        // 무음이어도 학습 온도는 계속 쌓인다 (게이지는 문구가 아니다).
        precondition(coach.wrongStreak == 1, "무음에서 상태 전이가 멈췄다")
    }

    // 3연속 오답이면 수위와 무관하게 순한맛 말투로 내려간다 (기획 15장 안전 밸브).
    static func streakStillSoftens() {
        var coach = CoachEngine()
        coach.level = .spicy
        _ = coach.guidance(problem: logProblem, studentInput: "1", correct: false)
        _ = coach.guidance(problem: logProblem, studentInput: "2", correct: false)
        guard let third = coach.guidance(
            problem: logProblem, studentInput: "3", correct: false)
        else { preconditionFailure("3연속 오답 진단이 비었다") }

        precondition(coach.softened, "3연속 오답인데 완화되지 않았다")
        precondition(!third.nextAction.contains("답을 다시 찍지 말고"),
                     "무너진 학생에게 화력을 올렸다: \(third.nextAction)")
        precondition(coach.shu > 0, "학습 온도가 쌓이지 않았다")
    }

    // 진단 문장에는 랜덤 대사 풀이 끼어들지 않는다.
    // 같은 상태의 엔진 둘이 같은 입력에서 다른 문장을 내면 어딘가 난수가 남은 것이다.
    static func guidanceIsDeterministic() {
        for _ in 0..<20 {
            var a = CoachEngine()
            a.level = .spicy
            var b = CoachEngine()
            b.level = .spicy
            guard
                let ga = a.guidance(problem: logProblem, studentInput: "-2", correct: false),
                let gb = b.guidance(problem: logProblem, studentInput: "-2", correct: false)
            else { preconditionFailure("결정성 확인 진단이 비었다") }
            precondition(ga == gb, "같은 입력에 다른 진단이 나왔다:\n\(lines(ga))\n\(lines(gb))")
        }
    }

    // 관찰/점검/다음 단계명은 SwiftUI가 한 번만 표시한다. 생성 본문이 같은
    // 접두사를 다시 소유하면 화면에서 `관찰 관찰:`처럼 중복된다.
    static func labelsHaveOneOwner() {
        var coach = CoachEngine()
        coach.level = .mild
        guard let guidance = coach.guidance(
            problem: logProblem, studentInput: "-2", correct: false)
        else { preconditionFailure("단계명 소유권 확인 진단이 비었다") }

        let ownedPrefixes = [
            "관찰:", "관찰 ·", "점검:", "점검 ·", "점검 순서:", "점검 순서 ·",
            "다음:", "다음 ·", "다음 행동:", "다음 행동 ·",
        ]
        for body in [guidance.observation, guidance.reason, guidance.nextAction] {
            precondition(!ownedPrefixes.contains(where: body.hasPrefix),
                         "엔진 본문이 UI 단계명을 중복 소유한다: \(body)")
        }
        precondition(guidance.accessibilityText.hasPrefix("관찰. "),
                     "접근성 설명에서 단계 순서가 사라졌다")
    }
}
