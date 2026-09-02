//  CoachEngine.swift
//  Matths
//
//  맵쓰 코치 — "동물의숲 NPC" 방식. LLM 호출 없이 (상황 × 수위) 스크립트 풀에서 뽑는다.
//  mapss-demo/shared/coach.js 의 Swift 이식판. 대사 풀도 그대로 가져왔다.
//
//  수위: 순한맛 / 매운맛 / 무음. 웹·서버와 같은 세 모드만 사용한다.
//
//  안전 밸브 (기획 15장): 같은 흐름에서 3연속 오답이면 수위와 무관하게
//  순한맛으로 강제 전환한다. 무너진 학생에게 화력을 올리지 않는다.

import Foundation

/// 코치 말투.
///
/// **서버 스키마는 `["mild","spicy","silent"]` 만 받는다**
/// (레포 `models/matthsModel.js` preferenceSchema.coachMode, 기본값 mild).
/// 서버의 `preferences.coachMode`와 같은 enum만 사용한다. 앱 전용 모드를
/// 추가하면 같은 학생이 웹과 앱에서 다른 설정을 보게 되므로 허용하지 않는다.
enum SpiceLevel: String, CaseIterable, Identifiable, Sendable {
    case mild, spicy, silent
    var id: String { rawValue }

    var name: String {
        switch self {
        case .mild:   return "순한맛"
        case .spicy:  return "매운맛"
        case .silent: return "무음"
        }
    }

    /// 서버 `preferences.coachMode` 에 올릴 값. 스키마에 없는 값은 보내지 않는다.
    var serverValue: String { rawValue }

    /// 서버에서 받은 값 → 앱 모드
    static func fromServer(_ raw: String?) -> SpiceLevel {
        SpiceLevel(rawValue: raw ?? "") ?? .mild
    }
}

enum CoachSituation {
    case quizIntro, correct1, correctRetry, wrong1, wrong2, wrong3, done
}

/// 결과 화면에 필요한 것은 랜덤 격려문이 아니라 관찰 → 점검 이유 → 다음 행동이다.
/// 채점 권한은 갖지 않으며, 확정할 수 없는 원인을 사실처럼 말하지 않는다.
struct CoachGuidance: Equatable {
    let observation: String
    let reason: String
    let nextAction: String

    var accessibilityText: String {
        "관찰. \(observation). 점검. \(reason). 다음. \(nextAction)"
    }
}

struct CoachEngine {
    var level: SpiceLevel = .mild       // 웹 정본과 같은 기본값: 순한맛
    var wrongStreak = 0
    var shu = 0                         // 오답 누적 게이지 (Scoville)
    var softened = false                // 3연속 오답 → 자동 완화
    private var lastLine = ""
    private var rng = SystemRandomNumberGenerator()

    // MARK: 유형별 시도 기록 (이번 앱 세션 한정)
    //
    // 코치가 "이 유형을 최근 3번 중 2번 틀렸습니다" 라고 **셀 수 있는** 근거.
    // 서버 왕복 없이 guidance() 가 지나갈 때만 쌓는다. 디버그 프리뷰
    // (onWrong/onCorrect 직접 호출)로는 오염되지 않는다.
    private struct TypeRecord {
        var outcomes: [Bool] = []       // 오래된 것 → 최신
        var lastAnswers: [String] = []  // outcomes 와 같은 길이
        var touchedAt: Date = Date()
    }
    private static let historyLimit = 5
    private static let historyTypeLimit = 40
    private var records: [String: TypeRecord] = [:]

    // MARK: 대사 풀 — mapss-demo coach.js 에서 그대로 이식

    private static let lines: [SpiceLevel: [String: [String]]] = [
        .mild: [
            "quizIntro":    ["이제 확인해볼 시간이에요. 부담 갖지 말고 골라보세요.",
                             "방금 관찰한 걸 떠올리면서 풀어보세요."],
            "correct1":     ["정답이에요! 방금 그 사고 과정이 핵심이에요.",
                             "완벽해요. 개념이 제대로 자리 잡았네요."],
            "correctRetry": ["좋아요, 결국 해냈네요. 틀렸던 과정도 다 공부예요.",
                             "정답! 다시 도전한 용기가 멋져요."],
            "wrong1":       ["아쉬워요! 풀이를 한 번 더 살펴볼까요?",
                             "괜찮아요. 어디서 헷갈렸는지 같이 찾아봐요."],
            "wrong2":       ["이 부분이 원래 헷갈려요. 모범 풀이와 비교해 보는 것도 방법이에요.",
                             "한 번 더 천천히 생각해봐요. 급할 것 없어요."],
            "wrong3":       ["괜찮아요. 지금부터 차근차근 다시 설명해줄게요."],
            "done":         ["이 시험 완료! 다음 것도 이렇게 정복해봐요."],
        ],
        .spicy: [
            "quizIntro":    ["자, 실전이다. 방금 배운 거 그대로 나온다.",
                             "문제 나간다. 틀리면 알지?"],
            "correct1":     ["오 정답. 방금 네 뇌가 제 기능을 했다.",
                             "맞았네? 오늘 컨디션 좋은데?",
                             "정답. 출제자 의도를 네가 먼저 읽었다."],
            "correctRetry": ["그래, 결국 맞췄네. 처음부터 이렇게 하지 그랬어.",
                             "정답. 오답과의 장기연애 드디어 청산했다."],
            "wrong1":       ["땡. 이건 함정도 아니었는데 네가 직접 구덩이를 팠다.",
                             "오답. 정답이 코앞에서 손 흔들었는데 모른 척했네.",
                             "틀렸다. 공식은 잘못이 없어. 네 대입이 잠깐 외출했을 뿐."],
            "wrong2":       ["또 틀렸다? 이제 우연이라는 변명은 압수한다.",
                             "두 번째다. 감으로 찍지 말고 풀이를 봐."],
            "wrong3":       ["됐다, 그만. 지금부터 내가 떠먹여준다. 눈만 뜨고 있어."],
            "done":         ["시험 하나 격파. 이 맛에 수학 하는 거지."],
        ],
    ]

    // MARK: 대사 뽑기

    private mutating func say(_ situation: CoachSituation) -> String {
        let key = String(describing: situation)

        // 자동 완화: 무너진 학생에게는 수위와 무관하게 순한맛
        var effective = level
        if softened, ["wrong1", "wrong2", "wrong3", "quizIntro"].contains(key) {
            effective = .mild
        }

        // 무음 모드는 **문구를 내지 않는다.** 웹 yaml 의 silent 가 그런 뜻이다
        // (모드가 있는데 폴백으로 순한맛 문구가 튀어나오면 무음이 아니게 된다).
        if effective == .silent { lastLine = ""; return "" }

        // 문구는 **웹 coach-messages.yaml 이 진실원이다.**
        //
        // 예전엔 Swift 소스에 별도 배열을 박아 뒀고 웹 문구와 **일치하는 게 한 줄도
        // 없었다.** 같은 학생이 웹과 앱에서 전혀 다른 코치를 만났다.
        // 이제 그 yaml 을 번들(coach-messages.json)로 넣고 여기서 읽는다.
        //
        // 축이 다르므로 매핑한다 — 웹은 상황 3종, 앱은 7종이다:
        //   correct    → correct1 · correctRetry
        //   incorrect  → wrong1 · wrong2 · wrong3
        //   unanswered → quizIntro
        //   done       → 웹에 대응이 없다(앱 전용 마무리 멘트) → 기존 풀 유지
        if let webPool = CoachMessages.pool(mode: effective, situation: key), !webPool.isEmpty {
            var line = webPool.randomElement(using: &rng) ?? "…"
            var g = 0
            while line == lastLine && webPool.count > 1 && g < 5 {
                line = webPool.randomElement(using: &rng) ?? line
                g += 1
            }
            lastLine = line
            return line
        }

        let pool = Self.lines[effective]?[key] ?? Self.lines[.mild]?[key] ?? ["…"]
        var line = pool.randomElement(using: &rng) ?? "…"
        var guardCount = 0
        while line == lastLine && pool.count > 1 && guardCount < 5 {
            line = pool.randomElement(using: &rng) ?? line
            guardCount += 1
        }
        lastLine = line
        return line
    }

    // MARK: 상태 전이 · 대사 뽑기 분리
    //
    // 예전에는 상태 전이가 **대사 뽑기의 부작용**으로만 일어나서, 진단
    // 문장을 만드는 guidance() 가 쓰지도 않을 대사를 한 줄 뽑아야 했다
    // (`let line = correct ? onCorrect() : onWrong()` — 그 줄은 버려졌다).
    // 이제 전이는 registerOutcome() 이 전담하고, 대사 풀은 아래 세 메서드
    // — 즉 **톤 프리뷰(코치 수위 미리보기)와 세트 마무리 멘트** — 에서만 쓴다.
    // 결과 화면의 진단 문장은 대사 풀을 건드리지 않는다.
    @discardableResult
    mutating func registerOutcome(correct: Bool) -> CoachSituation {
        if correct {
            let wasRetry = wrongStreak > 0
            wrongStreak = 0
            softened = false
            shu = max(0, shu - 4000)
            return wasRetry ? .correctRetry : .correct1
        }
        wrongStreak += 1
        shu += level == .spicy ? 6000 : 3000
        if wrongStreak >= 3 {
            softened = true
            return .wrong3
        }
        return wrongStreak == 1 ? .wrong1 : .wrong2
    }

    mutating func onCorrect() -> String {
        say(registerOutcome(correct: true))
    }

    mutating func onWrong() -> String {
        say(registerOutcome(correct: false))
    }

    mutating func onExamDone() -> String { say(.done) }

    /// 채점 직후 결과 화면에 올릴 진단.
    ///
    /// **말할 수 있는 것은 확정된 사실뿐이다.**
    ///   1) 이번에 제출한 값 (그대로 인용)
    ///   2) 같은 유형에서 이번 세션에 남은 정오 기록 (횟수만)
    ///   3) 유형별로 "다시 볼 곳" 두 군데 (원인 단정이 아니라 점검 지점)
    ///
    /// 학생이 왜 틀렸는지는 최종 답 하나로 확정할 수 없다. 단계별 verdict 는
    /// 서버 채점(ai-grader)이 나중에 내려주고 `divergenceStep` 은 이 시점에
    /// 아직 비어 있으므로, 여기서 원인을 짚는 척하지 않는다.
    ///
    /// **정답 값은 말하지 않는다** — 결과 화면 피드백이 "정답은 알려드리지
    /// 않습니다" 라고 명시하고 있어 코치가 그 옆에서 정답을 부르면 안 된다.
    /// 인용하는 값은 언제나 학생 자신이 낸 값이다.
    ///
    /// 순한맛·매운맛은 마지막 줄의 **말투만** 바꾼다. 관찰·점검 내용과
    /// 수학적 판단은 수위와 무관하게 같다.
    mutating func guidance(
        problem: GeneratedProblem,
        studentInput: String,
        correct: Bool
    ) -> CoachGuidance? {
        registerOutcome(correct: correct)
        // 직전 시도와의 비교는 현재 제출을 넣기 전 기록으로만 판단한다.
        let previousFacts = history(for: problem.typeKey)
        let answerText = submissionText(problem, studentInput: studentInput)
        appendRecord(typeKey: problem.typeKey, correct: correct, answer: answerText)
        // 횟수 문장은 방금 제출까지 저장한 뒤 읽어야 분자·분모가 한 회씩
        // 뒤처지지 않는다. 채점 결과 자체는 위에서 전달받은 correct를 그대로 쓴다.
        let facts = history(for: problem.typeKey)

        guard level != .silent else { return nil }

        let plan = diagnosticPlan(problem, studentInput: studentInput)
        let shape = submissionShape(problem, studentInput: studentInput)
        let submissionFact = answerText.isEmpty
            ? ""
            : "이번 제출: “\(answerText)”\(shape.isEmpty ? "" : " (\(shape))")."

        if correct {
            // "직전에 고쳤다" 는 **바로 앞 시도가 오답일 때만** 참이다.
            // 세 시도 전의 오답을 "직전" 이라고 부르면 그건 이미 추측이다.
            let previousWrongAnswer = previousFacts.previousWasWrong
                ? previousFacts.previousAnswer
                : nil

            let corrected: String
            if let previousWrong = previousWrongAnswer, previousWrong != answerText {
                corrected = "직전에 낸 “\(previousWrong)”를 이번에 고쳤습니다."
            } else if facts.total >= 2 {
                corrected = "이번 세션에서 이 유형은 \(facts.total)번 중 \(facts.correctCount)번 맞혔습니다."
            } else {
                corrected = ""
            }

            let anchor: String
            if let previousWrong = previousWrongAnswer, !answerText.isEmpty {
                anchor = "직전에 낸 “\(previousWrong)”와 이번 “\(answerText)”가 갈라진 첫 줄을 표시합니다."
            } else if !answerText.isEmpty {
                anchor = "이번 풀이에서 “\(answerText)”가 나온 마지막 계산 한 줄을 표시합니다."
            } else {
                anchor = "이번 풀이의 첫 줄에서 사용한 조건을 표시합니다."
            }

            return CoachGuidance(
                observation: sentence([
                    "\(problem.typeName).",
                    submissionFact,
                    "정답 조건을 만족했습니다.",
                    corrected,
                ]),
                reason: "① \(anchor) ② \(plan.second)",
                nextAction: "그 한 줄에서 사용한 핵심 조건 하나만 문제 옆에 옮겨 적고 다음 문제로 넘어가세요."
            )
        }

        let repeated = !answerText.isEmpty
            && previousFacts.previousWasWrong
            && previousFacts.previousAnswer == answerText
        let recordLine: String
        if repeated {
            recordLine = "직전 시도와 같은 값입니다."
        } else if facts.total >= 2 {
            recordLine = "이번 세션에서 이 유형은 \(facts.total)번 중 \(facts.wrongCount)번 틀렸습니다."
        } else {
            recordLine = ""
        }

        let firstCheck = repeated
            ? "직전과 같은 값을 다시 냈으므로 바뀐 줄이 없습니다. 첫 식부터 한 줄씩 다시 씁니다."
            : plan.first
        let secondCheck = repeated ? plan.first : plan.second

        // 바로 할 행동은 학생이 방금 낸 값으로 만든다. 검산(대입)은 원인을
        // 단정하지 않으면서 학생이 스스로 어긋나는 지점을 찾게 하는 동작이다.
        let recheck: String
        if answerText.isEmpty {
            recheck = plan.mildAction
        } else if problem.isMultipleChoice {
            recheck = "\(answerText)을 정답이라고 두고 발문의 조건에 맞춰 보아, 어긋나는 첫 지점 한 곳만 표시하세요."
        } else {
            recheck = "제출한 “\(answerText)”를 발문의 식에 그대로 대입해, 어긋나는 첫 지점 한 곳만 표시하세요."
        }

        let effectiveMild = softened || level == .mild
        return CoachGuidance(
            observation: sentence([
                "\(problem.typeName).",
                submissionFact,
                "정답 조건을 만족하지 않았습니다.",
                recordLine,
            ]),
            reason: "① \(firstCheck) ② \(secondCheck)",
            nextAction: effectiveMild
                ? recheck
                : "답을 다시 찍지 말고, \(recheck)"
        )
    }

    private func sentence(_ parts: [String]) -> String {
        parts.filter { !$0.isEmpty }.joined(separator: " ")
    }

    // MARK: 유형별 기록

    private struct TypeFacts {
        var total = 0
        var wrongCount = 0
        var correctCount = 0
        var previousAnswer: String?
        var previousWasWrong = false
    }

    private func history(for typeKey: String) -> TypeFacts {
        guard let entry = records[typeKey], !entry.outcomes.isEmpty else {
            return TypeFacts()
        }
        var facts = TypeFacts()
        facts.total = entry.outcomes.count
        facts.wrongCount = entry.outcomes.filter { !$0 }.count
        facts.correctCount = facts.total - facts.wrongCount
        facts.previousWasWrong = entry.outcomes.last == false
        let lastAnswer = entry.lastAnswers.last ?? ""
        facts.previousAnswer = lastAnswer.isEmpty ? nil : lastAnswer
        return facts
    }

    private mutating func appendRecord(typeKey: String, correct: Bool, answer: String) {
        guard !typeKey.isEmpty else { return }
        var entry = records[typeKey] ?? TypeRecord()
        entry.outcomes.append(correct)
        entry.lastAnswers.append(answer)
        if entry.outcomes.count > Self.historyLimit {
            entry.outcomes.removeFirst(entry.outcomes.count - Self.historyLimit)
            entry.lastAnswers.removeFirst(entry.lastAnswers.count - Self.historyLimit)
        }
        entry.touchedAt = Date()
        records[typeKey] = entry

        guard records.count > Self.historyTypeLimit else { return }
        records
            .sorted { $0.value.touchedAt < $1.value.touchedAt }
            .prefix(records.count - Self.historyTypeLimit)
            .forEach { records.removeValue(forKey: $0.key) }
    }

    private struct DiagnosticPlan {
        let first: String
        let second: String
        let mildAction: String
        let spicyAction: String
    }

    /// 최종 답만으로 학생의 실제 사고 원인을 단정하지 않는다. 문제 유형에 따라
    /// 다시 확인할 두 지점과 바로 실행할 한 동작만 제안한다.
    private func diagnosticPlan(
        _ problem: GeneratedProblem,
        studentInput: String
    ) -> DiagnosticPlan {
        let key = problem.typeKey.lowercased()
        if key.contains("conditional") || key.contains("condition") {
            return plan(
                "분모를 전체가 아니라 조건이 주어진 표본공간으로 다시 잡습니다.",
                "그 안에서 두 사건이 함께 일어나는 경우만 분자로 셉니다.",
                "조건 사건에 울타리를 치고 울타리 안 전체를 센 다음 겹치는 부분을 세는 순서로 다시 해 보세요."
            )
        }
        if key.contains("binomial") {
            return plan(
                "시행 횟수, 성공 확률, 구하려는 성공 횟수를 각각 표시합니다.",
                "조합계수와 성공·실패 확률의 지수가 횟수와 맞는지 확인합니다.",
                "n, p, r 세 값을 문제 옆에 먼저 적고 이항확률 한 항만 다시 만드세요."
            )
        }
        if key.contains("normal") {
            return plan(
                "원래 값을 평균 0, 표준편차 1인 z값으로 바꾼 방향을 확인합니다.",
                "구간이 평균의 왼쪽인지 오른쪽인지 표시한 뒤 표의 넓이를 고릅니다.",
                "정규곡선에 평균과 경계값을 찍고 필요한 영역만 칠한 뒤 z값을 다시 계산하세요."
            )
        }
        if key.contains("confidence") || key.contains("sampling") {
            return plan(
                "표본통계량과 모집단 모수 중 무엇을 추정하는지 먼저 구분합니다.",
                "표준오차에서 표본크기의 제곱근이 분모에 들어갔는지 확인합니다.",
                "‘추정 대상, 표준오차, 신뢰계수’ 세 칸을 순서대로 적고 수치를 다시 배치하세요."
            )
        }
        if key.contains("variance") || key.contains("deviation") || key.contains("stat") {
            return plan(
                "각 값과 평균의 차이를 먼저 만들고 그 차이를 제곱했는지 확인합니다.",
                "편차제곱의 합을 어떤 개수로 나누는 문제인지 다시 읽습니다.",
                "평균을 가운데 적고 차이, 제곱, 평균 세 단계만 순서대로 다시 계산하세요."
            )
        }
        if key.contains("prob") || key.contains("count") || key.contains("comb") || key.contains("permut") {
            return plan(
                "순서를 구분하는지, 같은 대상을 중복해서 고를 수 있는지 먼저 결정합니다.",
                "전체 경우와 조건을 만족하는 경우를 같은 기준으로 세었는지 확인합니다.",
                "작은 예를 세 칸만 직접 나열한 뒤 순서·중복 표시를 공식에 연결하세요."
            )
        }
        if key.contains("log") || key.contains("exp") {
            return plan(
                "로그의 밑 조건과 진수가 양수라는 조건을 식 옆에 적습니다.",
                "로그를 지수식으로 바꾸거나 밑을 통일한 첫 줄의 괄호를 확인합니다.",
                "정의역을 먼저 표시하고 첫 변형 한 줄만 역으로 되돌려 검산하세요."
            )
        }
        if key.contains("limit") {
            return plan(
                "대입만으로 정해지는지, 0/0 꼴이라 변형이 필요한지 먼저 판별합니다.",
                "약분·유리화 뒤에도 극한을 취하는 방향과 값이 유지되는지 확인합니다.",
                "대입 결과를 첫 줄에 쓰고 0/0이면 공통인수 또는 유리화 대상 하나만 표시하세요."
            )
        }
        if key.contains("tangent") || key.contains("derivative") || key.contains("extremum") {
            return plan(
                "미분한 식에 어느 x값을 넣어 기울기를 구하는지 표시합니다.",
                "극값 문제라면 도함수가 0인 후보와 실제 부호 변화 여부를 구분합니다.",
                "도함수, 기준 x값, 부호표 중 빠진 한 칸을 채운 뒤 계산을 다시 시작하세요."
            )
        }
        if key.contains("integral") || key.contains("area") {
            return plan(
                "적분 구간과 위·아래 함수를 먼저 표시합니다.",
                "넓이라면 함수값의 부호가 바뀌는 지점에서 구간을 나눴는지 확인합니다.",
                "수직선에 경계값을 찍고 각 구간의 ‘위 함수 − 아래 함수’를 한 줄씩 적으세요."
            )
        }
        if key.contains("circle") || key.contains("distance") || key.contains("vector") || key.contains("geo") {
            return plan(
                "그림에 기준점·방향·거리의 대상을 직접 표시합니다.",
                "좌표나 벡터를 식에 옮길 때 시작점과 끝점의 순서가 바뀌지 않았는지 확인합니다.",
                "그림에서 아는 값은 파란 밑줄, 구할 값은 노란 상자로 표시한 뒤 식을 다시 세우세요."
            )
        }
        if key.contains("seq") {
            return plan(
                "공차·공비 또는 반복되는 한 주기의 길이를 먼저 확정합니다.",
                "완전한 묶음의 합과 마지막에 남는 항을 분리했는지 확인합니다.",
                "항 번호를 세 칸만 직접 써서 규칙을 확인한 뒤 ‘묶음 + 나머지’로 다시 계산하세요."
            )
        }
        if key.contains("quad") || key.contains("disc") || key.contains("vieta") {
            return plan(
                "이차식의 모든 항을 한쪽으로 모아 계수 a, b, c를 다시 읽습니다.",
                "판별식 또는 근과 계수 공식에 넣을 때 b의 부호와 제곱을 확인합니다.",
                "a, b, c 아래에 값을 적고 b만 괄호로 묶어 한 줄을 다시 계산하세요."
            )
        }
        return plan(
            "발문에서 주어진 조건과 구해야 하는 값을 서로 다른 표시로 나눕니다.",
            "첫 변형에서 괄호를 푸는 순서와 음수 부호가 유지됐는지 확인합니다.",
            "모범 풀이 1단계와 내 첫 식만 나란히 놓고 달라진 기호 하나를 찾으세요."
        )
    }

    private func plan(
        _ first: String,
        _ second: String,
        _ mildAction: String
    ) -> DiagnosticPlan {
        DiagnosticPlan(
            first: first,
            second: second,
            mildAction: mildAction,
            spicyAction: "답을 다시 찍지 말고, \(mildAction)"
        )
    }

    /// 제출값의 표시 문자열. 객관식 키(a·b·c…)는 학생이 화면에서 본 번호로 바꾼다.
    /// 그 외에는 학생이 쓴 글자를 **그대로** 인용한다 (`2\pi` 를 "2 pi" 로
    /// 고쳐 쓰면 인용이 아니라 각색이 된다).
    private func submissionText(
        _ problem: GeneratedProblem,
        studentInput: String
    ) -> String {
        let raw = studentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return "" }

        if problem.isMultipleChoice {
            let key = raw.lowercased()
            if key.count == 1,
               let scalar = key.unicodeScalars.first,
               scalar.value >= UnicodeScalar("a").value,
               scalar.value <= UnicodeScalar("e").value {
                let index = Int(scalar.value - UnicodeScalar("a").value) + 1
                return "\(index)번"
            }
        }

        let collapsed = raw.split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        guard collapsed.count > 24 else { return collapsed }
        return String(collapsed.prefix(24)) + "…"
    }

    /// 제출값의 겉모양. 원인이 아니라 **눈에 보이는 형식**만 말한다.
    /// ("분수로 썼다" 는 확인 가능한 사실이고, "분수를 몰랐다" 는 추측이다.)
    /// 특징이 없으면 빈 문자열 — 관찰 문장에서 통째로 생략한다.
    private func submissionShape(
        _ problem: GeneratedProblem,
        studentInput: String
    ) -> String {
        if problem.isMultipleChoice { return "선택한 보기" }
        let input = studentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if input.contains("=") { return "등식 형태로 쓴 답" }
        if input.contains("/") || input.contains("⁄") { return "분수 형태로 쓴 답" }
        if input.contains(".") || input.contains(",") { return "소수 형태로 쓴 답" }
        if input.contains("-") || input.contains("−") { return "음수 부호를 포함한 답" }
        if input.rangeOfCharacter(from: .letters) != nil { return "문자식을 포함한 답" }
        return ""
    }

    /// 오답이 누적될수록 다음 설명을 더 직접적으로 제시하는 학습 온도.
    var shuLabel: String {
        if shu <= 0 { return "학습 온도 안정" }
        let formatted = NumberFormatter.localizedString(from: NSNumber(value: shu), number: .decimal)
        if shu < 10_000 { return "학습 온도 \(formatted) (점검)" }
        if shu < 30_000 { return "학습 온도 \(formatted) (집중)" }
        return "학습 온도 \(formatted) (다시 설명)"
    }

    /// 게이지 진행률 (0...1) — 내부 누적값 40,000을 가득으로 본다.
    var shuProgress: Double { min(1, Double(shu) / 40_000) }
}


// MARK: - 웹 코치 문구 (coach-messages.yaml 이식본)
//
// 레포 `content_folder/coach-messages.yaml` 을 그대로 JSON 으로 옮긴 것이다.
// 문구를 고쳐야 하면 **레포 yaml 을 먼저 고치고** 여기로 다시 뽑는다 —
// 여기서 먼저 고치면 웹과 앱이 또 갈라진다.
enum CoachMessages {
    private struct File: Decodable {
        struct Mode: Decodable { let label: String; let messages: [String: [String]] }
        let modes: [String: Mode]
    }

    private static let file: File? = {
        guard let url = Bundle.main.url(forResource: "coach-messages", withExtension: "json"),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return try? JSONDecoder().decode(File.self, from: data)
    }()

    /// 앱 상황 키(7종) → 웹 상황 키(3종)
    private static func webSituation(_ appKey: String) -> String? {
        switch appKey {
        case "correct1", "correctRetry":     return "correct"
        case "wrong1", "wrong2", "wrong3":   return "incorrect"
        case "quizIntro":                    return "unanswered"
        default:                             return nil   // "done" 은 웹에 없다
        }
    }

    static func pool(mode: SpiceLevel, situation appKey: String) -> [String]? {
        guard let situation = webSituation(appKey) else { return nil }
        return file?.modes[mode.rawValue]?.messages[situation]
    }
}
