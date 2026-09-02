//  AssessmentV2.swift
//  Matths
//
//  평가 체계 v2 — 웹(assessmentService.js)이 진실원이다.
//
//  규칙(웹 원문 그대로):
//    · 소단원 중간평가 10문항 → 대단원 기말평가 20문항 → 과목 종합평가 40문항
//    · 배점은 100/문항수 균등, 총점 100. PASS_SCORE = 80.
//    · 해금 사슬: 소단원 = 연결 개념 전부 완료 / 기말 = 개념 완료 + 소단원 중간 전부 통과
//      / 종합 = 모든 기말 통과. 한번 통과하면 계속 열림. 재응시 무제한.
//    · 최근 3회 응시의 유형은 뽑기에서 후순위(avoidedTypeIds).
//    · 제출 후 전체 리뷰에서 정답·해설 공개 (시험지 모드의 웹 계약 —
//      개념 연습의 "정답 비공개"와 다른 트랙이다).
//  앱 적응(정직한 편차):
//    · 웹 계산형 생성기와 심화 템플릿을 빌드 시 IIFE로 묶어 JavaScriptCore에서 실행한다.
//    · 생성기 풀이 얇은 범위는 '발문 중복 금지 + 유형 반복 최소화'로 완화한다.

import Foundation

// MARK: - 카탈로그 (웹 ASSESSMENT_CATALOG + EXAM_COURSES 병합 추출본)

struct AssessGen: Codable { let id: String; let points: Int }

struct AssessSubunit: Codable, Identifiable {
    let id: String
    let title: String
    let conceptIds: [String]
    let gens: [AssessGen]
}

struct AssessUnit: Codable, Identifiable {
    let unitId: String
    let bankUnitId: String
    let title: String
    let numeral: String
    let subunits: [AssessSubunit]
    var id: String { unitId }
}

struct AssessCourse: Codable, Identifiable {
    let courseId: String
    let bankCourseId: String
    let title: String
    let units: [AssessUnit]
    var id: String { courseId }
}

struct PaperPlan: Codable {
    let count: Int
    let mix: PaperMix
}

/// 평가 제한 시간 — **레포 `assessmentService.js` 의 TIME_LIMIT_MS 와 같은 값.**
///
/// 앱에는 제한 시간이 아예 없었다. 웹은 시간이 지나면 `disqualified`
/// (`disqualifiedReason: "time-limit"`)로 **0점 처리**하는데, 앱은 몇 시간이 걸려도
/// 정상 점수가 나왔다. 같은 시험을 앱에서 보면 더 유리했다.
enum AssessTimeLimit {
    static func ms(for scopeType: String) -> Int {
        switch scopeType {
        case "unit":   return 30 * 60 * 1000
        case "course": return 60 * 60 * 1000
        default:       return 10 * 60 * 1000   // subunit
        }
    }
}
struct PaperMix: Codable { let midHigh: Int; let applied: Int; let advanced: Int }

struct GradeBand: Codable { let grade: Int; let min: Int }

struct AssessCatalogData: Codable {
    let version: Int
    let passScore: Int
    let paperPlans: [String: PaperPlan]
    let gradeBands: [GradeBand]
    let courses: [AssessCourse]
}

enum AssessCatalog {
    private static let loaded: (data: AssessCatalogData, error: String?) = {
        do {
            guard let url = Bundle.main.url(
                forResource: "assessment-catalog",
                withExtension: "json"
            ) else {
                throw CocoaError(.fileNoSuchFile)
            }
            let raw = try Data(contentsOf: url)
            let parsed = try JSONDecoder().decode(AssessCatalogData.self, from: raw)
            guard !parsed.courses.isEmpty, !parsed.paperPlans.isEmpty else {
                throw CocoaError(.fileReadCorruptFile)
            }
            return (parsed, nil)
        } catch {
            NSLog("[Matths] assessment catalog unavailable: %@", error.localizedDescription)
            return (
                AssessCatalogData(
                    version: 0,
                    passScore: 80,
                    paperPlans: [:],
                    gradeBands: [],
                    courses: []
                ),
                "단계 평가 데이터를 열지 못했습니다. 주간 공식 모의고사는 계속 이용할 수 있으며, 앱을 다시 설치하면 단계 평가 데이터를 복구할 수 있습니다."
            )
        }
    }()

    static let data = loaded.data
    static let loadError = loaded.error

    static func course(_ webCourseID: String) -> AssessCourse? {
        data.courses.first { $0.courseId == webCourseID }
    }

    /// 점수 → 등급 (GRADE_BANDS: 90/80/70/55)
    static func grade(for score: Int) -> Int {
        data.gradeBands.first { score >= $0.min }?.grade ?? 5
    }
}

// MARK: - 응시 기록 (웹 AssessmentAttempt 의 로컬판)

enum PaperScope: String, Codable, Sendable { case subunit, unit, course }

struct PaperQuestion: Codable, Identifiable, Sendable {
    let no: Int
    let typeKey: String
    let prompt: String
    let choices: [String]?
    let answer: String          // 선다 a~e | 단답 문자열
    let points: Int             // 난이도 표기(3=중상, 4=응용·심화) — 채점은 균등 배점
    let solution: String
    /// 서버 AssessmentAttempt.questions.questionId. 로컬 생성 회차는 nil이고,
    /// Bearer draft/submit은 이 값으로만 답안을 매칭한다.
    var serverQuestionId: String? = nil
    var id: Int { no }
    var isChoice: Bool { choices != nil }
}

struct AssessmentAttemptV2: Codable, Identifiable, Sendable {
    let id: String
    let scope: PaperScope
    let courseId: String
    let unitId: String?
    let subunitId: String?
    let title: String
    let questions: [PaperQuestion]
    var answers: [String]                 // 문항 순서대로, 미응답 ""
    var submittedAt: Date?
    var scorePercent: Int?
    var passed: Bool?
    let createdAt: Date
    /// 제한 시간(ms). 시작할 때 scope 로 정해 박아 둔다 — 도중에 규칙이 바뀌어도
    /// 이미 시작한 시험의 조건은 변하지 않아야 한다(레포와 같은 취급).
    var timeLimitMs: Int?
    /// 시간 초과로 실격됐는가. 레포의 `status:"disqualified", reason:"time-limit"`.
    var disqualified: Bool?
    /// true면 AssessmentAttempt 서버 문서가 이 회차의 정본이다. 구버전 로컬
    /// 회차는 nil이라 그대로 보존하되 서버 해금 상태와 섞어 덮어쓰지 않는다.
    var serverBacked: Bool? = nil
    var serverUpdatedAt: Date? = nil

    var scopeKey: String { "\(scope.rawValue)/\(courseId)/\(unitId ?? "-")/\(subunitId ?? "-")" }

    /// 남은 시간(초). 시작 시각은 createdAt 이다.
    ///
    /// **월클럭과 단조 시계 중 더 많이 흐른 쪽을 쓴다.**
    /// 월클럭만 보면 기기 시각을 되돌려 실격을 피할 수 있고,
    /// 단조 시계만 보면 앱을 껐다 켠 시간이 빠져 무한정 늘어난다.
    func remainingSeconds(monotonicElapsed: TimeInterval) -> Int {
        let limit = Double(timeLimitMs ?? AssessTimeLimit.ms(for: scope.rawValue)) / 1000
        let wall = Date().timeIntervalSince(createdAt)
        return Int((limit - max(wall, monotonicElapsed)).rounded(.down))
    }
}

struct AttemptStoreV2 {
    private(set) var attempts: [AssessmentAttemptV2] = []

    static var fileURL: URL {
        DataScope.url("assessments.json")
    }

    static func load() -> AttemptStoreV2 {
        var s = AttemptStoreV2()
        if let data = try? Data(contentsOf: fileURL),
           let list = try? JSONDecoder().decode([AssessmentAttemptV2].self, from: data) {
            s.attempts = list
        }
        return s
    }

    func save() {
        _ = Self.persist(attempts, for: DataScope.slot)
    }

    /// 평가 draft writer용 슬롯 고정 저장. 전체 회차 인코딩은 호출부 메인 액터가
    /// 아니라 직렬 writer에서 수행한다.
    @discardableResult
    static func persist(_ snapshot: [AssessmentAttemptV2], for slot: String) -> Bool {
        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: DataScope.url("assessments.json", for: slot), options: .atomic)
            return true
        } catch {
            NSLog("ASSESSMENT-STORAGE-ERROR 저장 실패 (slot=%@): %@", slot, error.localizedDescription)
            return false
        }
    }

    mutating func upsert(_ a: AssessmentAttemptV2) {
        if let i = attempts.firstIndex(where: { $0.id == a.id }) { attempts[i] = a }
        else { attempts.append(a) }
    }

    /// 계정 서버 스냅샷을 원자적으로 교체한다. 동일 서버 id는 최신 응답으로
    /// 갱신하고, 구버전 로컬 회차는 마이그레이션 손실을 피하려 보존한다.
    mutating func replaceServerSnapshot(_ remote: [AssessmentAttemptV2]) {
        let legacy = attempts.filter { $0.serverBacked != true }
        var byID = Dictionary(uniqueKeysWithValues: legacy.map { ($0.id, $0) })
        for item in remote { byID[item.id] = item }
        attempts = Array(byID.values).sorted { $0.createdAt > $1.createdAt }
    }

    // ── 웹 상태 계산과 동일한 조회들 ──────────────────────────────
    func submitted(scopeKey: String) -> [AssessmentAttemptV2] {
        attempts.filter { $0.scopeKey == scopeKey && $0.submittedAt != nil }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// 아직 제출하지 않은 같은 시험 회차.
    ///
    /// 평가센터는 이 값이 있으면 행을 "진행 중"으로 표시한다. 표시만 그렇게 하고
    /// 탭할 때 새 시험지를 만들면 저장해 둔 답안으로 돌아갈 길이 사라지므로,
    /// 시작 경로도 반드시 같은 조회를 사용해야 한다. 구 버전에서 중복 열린 회차가
    /// 생겼을 수 있어 답이 가장 많이 적힌 회차를 우선하고, 동률이면 최신 회차를 연다.
    func openAttempt(scopeKey: String) -> AssessmentAttemptV2? {
        attempts
            .filter { $0.scopeKey == scopeKey && $0.submittedAt == nil }
            .max { lhs, rhs in
                let lhsAnswered = lhs.answers.filter {
                    !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }.count
                let rhsAnswered = rhs.answers.filter {
                    !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }.count
                if lhsAnswered != rhsAnswered { return lhsAnswered < rhsAnswered }
                return lhs.createdAt < rhs.createdAt
            }
    }

    func passed(scopeKey: String) -> Bool {
        submitted(scopeKey: scopeKey).contains { $0.passed == true }
    }

    func bestScore(scopeKey: String) -> Int? {
        submitted(scopeKey: scopeKey).compactMap(\.scorePercent).max()
    }

    /// 최근 3회 응시의 유형 — 뽑기 후순위 (웹 avoidedTypeIds)
    func avoidedTypeKeys(scopeKey: String) -> Set<String> {
        Set(submitted(scopeKey: scopeKey).prefix(3).flatMap { $0.questions.map(\.typeKey) })
    }
}

// MARK: - 시험지 조립 (웹 PAPER_PLANS)

enum PaperFactory {
    /// 소단원/대단원/과목 시험지 조립.
    /// 중상 = 뱅크 3점, 응용 = 뱅크 4점, 심화 = **웹 심화 템플릿**(WebGen 브리지,
    /// 학습 개념 스테이지 선택 — learned 전달). 템플릿이 못 채우면 뱅크 4점 폴백.
    static func make(scope: PaperScope, course: AssessCourse,
                     unit: AssessUnit?, subunit: AssessSubunit?,
                     seed: UInt64, avoid: Set<String>, learned: [String] = []) -> [PaperQuestion] {
        guard let plan = AssessCatalog.data.paperPlans[scope.rawValue] else { return [] }

        // 배점 조회용: gen id → points
        var pointsByType: [String: Int] = [:]
        for u in course.units { for s in u.subunits { for g in s.gens {
            pointsByType["bank-\(g.id)"] = g.points
        } } }

        // 풀 생성 — 범위의 소단원들을 시드를 바꿔가며 반복 호출
        let subs: [(String, String)]   // (bankUnitId, subId)
        switch scope {
        case .subunit:
            guard let unit, let subunit else { return [] }
            subs = [(unit.bankUnitId, subunit.id)]
        case .unit:
            guard let unit else { return [] }
            subs = unit.subunits.map { (unit.bankUnitId, $0.id) }
        case .course:
            subs = course.units.flatMap { u in u.subunits.map { (u.bankUnitId, $0.id) } }
        }
        var pool: [GeneratedProblem] = []
        let roundsPerSub = max(2, Int(ceil(Double(plan.count * 3) / Double(max(1, subs.count * 4)))))
        for (si, sub) in subs.enumerated() {
            for r in 0..<roundsPerSub {
                pool += JSBank.subExam(course: course.bankCourseId, unit: sub.0, sub: sub.1,
                                       seed: seed &+ UInt64(si * 101 + r))
            }
        }

        // ── 로컬 개념 생성기도 풀에 합류시킨다 ──────────────────────────
        //
        // 웹 assessmentService 는 문항 뱅크와 **로컬 개념 생성기**를 같이 후보로 쓴다.
        // 앱은 뱅크만 썼다. 그래서 뱅크 생성기가 1~4종뿐인 소단원에서는
        // 시험지가 같은 유형의 반복이 됐고, 발문 상한(예: perm/binom 9종)에 걸려
        // **10문항 계약을 못 채우고 8~9문항으로 조용히 줄어들었다.**
        // 여기서 개념 생성기를 더해 후보를 넓힌다 — 부족분을 메우는 용도이지
        // 뱅크를 밀어내지 않는다(선택 단계에서 유형 반복이 적은 쪽이 먼저 뽑힌다).
        let conceptSubs: [(AssessUnit, AssessSubunit)]
        switch scope {
        case .subunit:
            conceptSubs = (unit.flatMap { u in subunit.map { [(u, $0)] } }) ?? []
        case .unit:
            conceptSubs = unit.map { u in u.subunits.map { (u, $0) } } ?? []
        case .course:
            conceptSubs = course.units.flatMap { u in u.subunits.map { (u, $0) } }
        }
        // 소단원에 뱅크 생성기가 없는 공통수학도 계산형 WebGen은 유형 10종을
        // 갖는다. 개념당 3개만 요청하면 10문항 평가가 3문항으로 축소되므로,
        // 중복 제거 후에도 계약 수를 채울 만큼 계산형 후보를 미리 요청한다.
        let generatedPerConcept = max(
            3,
            Int(ceil(Double(plan.count * 2) / Double(max(1, conceptSubs.count))))
        )
        for (ci, pair) in conceptSubs.enumerated() {
            for (cj, conceptId) in pair.1.conceptIds.enumerated() {
                pool += WebGen.practiceProblems(
                    courseId: course.courseId, unitId: pair.0.unitId, conceptId: conceptId,
                    count: generatedPerConcept,
                    seed: seed &+ UInt64(4000 + ci * 37 + cj))
            }
        }

        // 심화 몫 — 웹 템플릿에서 먼저 뽑는다 (대단원 기말·과목 종합만 해당)
        var advancedPicked: [GeneratedProblem] = []
        if plan.mix.advanced > 0 {
            let targetUnits: [AssessUnit] = scope == .unit ? (unit.map { [$0] } ?? []) : course.units
            var remaining = plan.mix.advanced
            for (ui, u) in targetUnits.enumerated() where remaining > 0 {
                let share = max(1, remaining / max(1, targetUnits.count - ui))
                let drawn = WebGen.drawAdvanced(
                    courseId: course.courseId, unitId: u.unitId,
                    learned: learned, count: share, seed: seed &+ UInt64(9000 + ui))
                advancedPicked += drawn
                remaining -= drawn.count
            }
            advancedPicked = Array(advancedPicked.prefix(plan.mix.advanced))
        }

        // 선택 — 발문 중복 금지, 회피 유형 후순위, 유형 반복 최소화, 몫 충족
        let target3 = plan.mix.midHigh
        // 템플릿이 못 채운 심화 몫은 뱅크 4점으로 폴백(정직한 편차 유지)
        let target4 = plan.mix.applied + (plan.mix.advanced - advancedPicked.count)
        var seenPrompts = Set<String>()
        var typeUse: [String: Int] = [:]
        var picked: [GeneratedProblem] = []

        func take(from candidates: [GeneratedProblem], upTo n: Int) {
            let ranked = candidates.sorted {
                let a = (avoid.contains($0.typeKey) ? 1 : 0, typeUse[$0.typeKey] ?? 0)
                let b = (avoid.contains($1.typeKey) ? 1 : 0, typeUse[$1.typeKey] ?? 0)
                return a < b
            }
            for item in ranked where picked.count < plan.count {
                guard n > 0 else { break }
                guard !seenPrompts.contains(item.statement) else { continue }
                seenPrompts.insert(item.statement)
                typeUse[item.typeKey, default: 0] += 1
                picked.append(item)
                if pickedCount(points: pointsFor(item)) >= (pointsFor(item) == 3 ? target3 : target4) { break }
            }
        }
        /// 배점 판정.
        ///
        /// 뱅크 문항은 카탈로그가 배점을 준다. **로컬 개념 생성기 문항은 그 표에
        /// 없으므로** 예전 규칙(`?? 3`)대로면 전부 3점(중상)으로 세어졌다.
        /// 그러면 4점(응용) 몫이 영영 안 차서 화면 표기와 실제 시험지가 어긋난다.
        /// 개념 생성기 문항은 예상 소요 시간으로 가른다 — 웹도 난이도를 그 축으로 나눈다.
        func pointsFor(_ p: GeneratedProblem) -> Int {
            if let known = pointsByType[p.typeKey] { return known }
            if p.typeKey.hasPrefix("adv-") { return 5 }
            return p.minutes >= 3 ? 4 : 3
        }
        func pickedCount(points: Int) -> Int { picked.filter { pointsFor($0) == points }.count }

        // 3점 몫 → 4점 몫 → 모자라면 후보를 넓혀 채운다.
        //
        // **몫을 못 채워도 시험지를 막지 않는다.** 레포도 그렇게 한다 —
        // 선호 후보(preferred)가 모자라면 미사용 후보로 범위를 넓히지, 예외를
        // 던지지 않는다. 막아 버리면 뱅크가 얇은 소단원은 웹에서는 응시 가능한데
        // 앱에서만 응시 불가가 되어 오히려 나빠진다.
        let bankTarget = plan.count - advancedPicked.count
        take(from: pool.filter { pointsFor($0) == 3 }, upTo: target3)
        take(from: pool.filter { pointsFor($0) == 4 }, upTo: target4)
        if picked.count < bankTarget {
            for item in pool.shuffled() where picked.count < bankTarget {
                guard !seenPrompts.contains(item.statement) else { continue }
                seenPrompts.insert(item.statement)
                picked.append(item)
            }
        }

        // 심화는 시험지 뒤쪽에 (웹 시험지 관례: 뒤로 갈수록 어렵다)
        let ordered = picked.prefix(bankTarget) + advancedPicked
        return ordered.enumerated().map { i, p in
            let isAdvanced = p.typeKey.hasPrefix("adv-")
            return PaperQuestion(no: i + 1, typeKey: p.typeKey, prompt: p.statement,
                                 choices: p.choices, answer: p.answer,
                                 points: isAdvanced ? 5 : pointsFor(p),
                                 // 해설 **전문**을 넘긴다. `.first` 만 넘기던 시절엔
                                 // 심화 문항의 "출제 근거: …" 병기 줄이 화면에 영영
                                 // 닿지 않았다(17차 약속이 리팩터로 깨진 회귀).
                                 solution: p.steps.joined(separator: "\n"))
        }
    }

    /// 웹 채점 규칙: 균등 배점, 유니코드 마이너스/쉼표 정규화, 분수·수치 비교
    static func grade(questions: [PaperQuestion], answers: [String]) -> (scorePercent: Int, verdicts: [Bool]) {
        var correct = 0
        var verdicts: [Bool] = []
        for (i, q) in questions.enumerated() {
            let raw = i < answers.count ? answers[i] : ""
            let ok = isCorrect(question: q, input: raw)
            verdicts.append(ok)
            if ok { correct += 1 }
        }
        let pct = Int((Double(correct) / Double(max(1, questions.count)) * 100).rounded())
        return (pct, verdicts)
    }

    /// 채점 — **MathAnswer 한 곳에서만** 한다.
    ///
    /// 여기 있던 normalize/scalarEqual 은 지웠다. 파서가 없어 근호·원주율·거듭제곱
    /// 답을 못 읽었고, 쉼표 구분자로 전각 세미콜론(U+FF1B)을 쓰고 있어 웹의
    /// ASCII ';' 와 어긋나 있었다.
    static func isCorrect(question: PaperQuestion, input: String) -> Bool {
        let normalized = MathAnswer.normalizeAnswerText(input)
        guard !normalized.isEmpty else { return false }
        if question.isChoice { return normalized == MathAnswer.normalizeAnswerText(question.answer) }
        return MathAnswer.answersEquivalent(question.answer, input)
    }
}
