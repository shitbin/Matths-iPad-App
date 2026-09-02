//  CheatingDetectionModels.swift
//  Matths
//
//  온디바이스 풀이 무결성 판정의 데이터 계약과 보수적 후검증.
//  모델은 후보 근거를 제안할 뿐이고, 최종 `의심` 승격은 이 파일이 맡는다.
//  서버 규칙이나 Arena 정산과 연결하지 않는다.

import Foundation

enum CheatingDetectionVerdict: String, Codable, Sendable {
    case normal
    case suspicious
    case inconclusive

    var koreanLabel: String {
        switch self {
        case .normal:       return "정상"
        case .suspicious:   return "의심"
        case .inconclusive: return "판정불가"
        }
    }
}

enum CheatingEvidenceKind: String, Codable, Sendable {
    /// 풀이가 필요한 문항인데 정답만 적혀 있음.
    case answerOnly = "answer-only"
    /// 중간 연결 없이 모범 풀이의 결론으로 갑자기 점프함.
    case unexplainedJump = "unexplained-jump"
    /// 모범 풀이에만 있는 긴 문구가 그대로 나타남.
    case referencePhraseMatch = "reference-phrase-match"
    /// 필기와 다른 인쇄 블록·붙여넣기 경계가 사진에서 직접 보임.
    case visualPasteArtifact = "visual-paste-artifact"
    /// 글씨체가 섞여 보이는 약한 신호. 이것만으로 의심 판정하지 않는다.
    case mixedWritingStyle = "mixed-writing-style"
    case unreadable
    case other

    fileprivate var canBeStrong: Bool {
        switch self {
        case .answerOnly, .unexplainedJump, .referencePhraseMatch, .visualPasteArtifact:
            return true
        case .mixedWritingStyle, .unreadable, .other:
            return false
        }
    }
}

/// 이미지 좌상단이 (0, 0), 우하단이 (1, 1)인 정규화 좌표.
struct CheatingEvidenceBox: Codable, Equatable, Sendable {
    let minX: Double
    let minY: Double
    let maxX: Double
    let maxY: Double

    var width: Double { maxX - minX }
    var height: Double { maxY - minY }

    /// UI가 실제 화소 박스를 그릴 때 쓸 수 있는 값. UIKit 의존 없이 유지한다.
    func pixelValues(width: Double, height: Double) -> (x: Double, y: Double, width: Double, height: Double) {
        (minX * width, minY * height, self.width * width, self.height * height)
    }

    fileprivate static func parse(_ value: Any?) -> Self? {
        guard let raw = value as? [Any], raw.count == 4,
              let a = number(raw[0]), let b = number(raw[1]),
              let c = number(raw[2]), let d = number(raw[3]) else { return nil }

        // 프롬프트 계약은 0...1000이지만 소형 모델이 0...1로 답하는 경우도 받는다.
        let divisor = max(abs(a), abs(b), abs(c), abs(d)) <= 1.0 ? 1.0 : 1000.0
        let x1 = clamp(a / divisor), y1 = clamp(b / divisor)
        let x2 = clamp(c / divisor), y2 = clamp(d / divisor)
        guard x2 > x1, y2 > y1,
              (x2 - x1) >= 0.005, (y2 - y1) >= 0.005 else { return nil }
        return Self(minX: x1, minY: y1, maxX: x2, maxY: y2)
    }

    private static func number(_ value: Any) -> Double? {
        if let n = value as? NSNumber { return n.doubleValue }
        if let s = value as? String { return Double(s) }
        return nil
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value.isFinite ? value : 0))
    }
}

struct CheatingDetectionEvidence: Codable, Equatable, Sendable {
    let kind: CheatingEvidenceKind
    /// 사진에서 실제로 읽힌 짧은 문구 또는 보이는 현상의 짧은 설명.
    let quote: String
    let box: CheatingEvidenceBox
    let confidence: Double
    /// 정책 검증 뒤에도 강한 근거로 남았는지. 모델의 self-report를 그대로 믿지 않는다.
    let isStrong: Bool
}

struct CheatingProblemContext: Codable, Equatable, Sendable {
    let statement: String
    let expectedAnswer: String
    let referenceSteps: [String]
    let studentFinalAnswer: String?
    /// 서버 정답을 내려받지 않는 경기에서 사진 속 답과 학생이 실제 제출한 답을
    /// 보수적으로 대조하기 위한 값. 정답이나 채점 결과가 아니다.
    let studentSubmittedAnswers: [String]?
    /// 객관식처럼 과정 제출이 필수가 아닌 문항이면 false.
    let requiresWork: Bool

    init(statement: String,
         expectedAnswer: String,
         referenceSteps: [String] = [],
         studentFinalAnswer: String? = nil,
         studentSubmittedAnswers: [String]? = nil,
         requiresWork: Bool = true) {
        self.statement = statement
        self.expectedAnswer = expectedAnswer
        self.referenceSteps = referenceSteps
        self.studentFinalAnswer = studentFinalAnswer
        self.studentSubmittedAnswers = studentSubmittedAnswers
        self.requiresWork = requiresWork
    }
}

struct CheatingDetectionResult: Codable, Equatable, Sendable {
    let verdict: CheatingDetectionVerdict
    let confidence: Double
    let reason: String
    let evidence: [CheatingDetectionEvidence]

    static func inconclusive(_ reason: String, confidence: Double = 0) -> Self {
        Self(verdict: .inconclusive,
             confidence: min(1, max(0, confidence)),
             reason: reason,
             evidence: [])
    }
}

/// 자유 형식 VLM 출력을 앱 계약으로 바꾸는 마지막 관문.
/// 좌표·문구가 없는 근거, 글씨체 차이만 있는 근거, 낮은 확신은 `의심`으로 못 올라간다.
enum CheatingDetectionPolicy {
    static func finalize(raw: String, context: CheatingProblemContext) -> CheatingDetectionResult {
        guard let object = jsonObject(from: raw) else {
            return .inconclusive("모델 응답을 구조화하지 못했습니다.")
        }

        let proposed = CheatingDetectionVerdict(rawValue: string(object["verdict"])) ?? .inconclusive
        let rawConfidence = normalizedConfidence(object["confidence"])
        let evidence = parseEvidence(object["evidence"], context: context)
        let strong = evidence.filter(\.isStrong)

        switch proposed {
        case .suspicious:
            guard rawConfidence >= 0.78, !strong.isEmpty else {
                return CheatingDetectionResult(
                    verdict: .inconclusive,
                    confidence: min(rawConfidence, 0.77),
                    reason: "사진에서 확인되는 강한 근거가 부족해 의심으로 단정하지 않습니다.",
                    evidence: evidence)
            }
            let supported = min(rawConfidence, strong.map(\.confidence).max() ?? rawConfidence)
            return CheatingDetectionResult(
                verdict: .suspicious,
                confidence: supported,
                reason: suspiciousReason(for: strong),
                evidence: evidence)

        case .normal:
            // 모델이 정상이라 했어도 강한 반대 근거가 같이 나오면 서로 모순이다.
            guard rawConfidence >= 0.70, strong.isEmpty else {
                return CheatingDetectionResult(
                    verdict: .inconclusive,
                    confidence: min(rawConfidence, 0.69),
                    reason: "정상 판정과 근거가 서로 맞지 않아 다시 확인해야 합니다.",
                    evidence: evidence)
            }
            return CheatingDetectionResult(
                verdict: .normal,
                confidence: rawConfidence,
                reason: "풀이 단계와 제출 답이 자연스럽게 이어집니다.",
                evidence: evidence)

        case .inconclusive:
            return CheatingDetectionResult(
                verdict: .inconclusive,
                confidence: rawConfidence,
                reason: "사진이 흐리거나 풀이 근거가 부족합니다.",
                evidence: evidence)
        }
    }

    /// 모델의 자유 서술은 언어 혼합·환각·공격적인 표현이 섞일 수 있으므로
    /// 학생에게 직접 노출하지 않는다. 검증을 통과한 근거 종류만 앱의 고정 문구로 바꾼다.
    private static func suspiciousReason(for evidence: [CheatingDetectionEvidence]) -> String {
        guard let primary = evidence.max(by: { $0.confidence < $1.confidence }) else {
            return "풀이 흐름과 맞지 않는 근거가 확인됐습니다."
        }
        switch primary.kind {
        case .answerOnly:
            return "풀이가 필요한 문항인데 정답만 확인됩니다."
        case .unexplainedJump:
            return "중간 연결 없이 결론으로 넘어간 부분이 확인됩니다."
        case .referencePhraseMatch:
            return "모범 풀이와 동일한 고유 표현이 사진에서 확인됩니다."
        case .visualPasteArtifact:
            return "필기와 다른 인쇄 블록 경계가 사진에서 확인됩니다."
        case .mixedWritingStyle, .unreadable, .other:
            return "풀이 흐름과 맞지 않는 근거가 확인됐습니다."
        }
    }

    private static func parseEvidence(_ value: Any?, context: CheatingProblemContext) -> [CheatingDetectionEvidence] {
        guard let rows = value as? [[String: Any]] else { return [] }
        return rows.prefix(6).compactMap { row in
            let quote = clipped(string(row["quote"]), limit: 160)
            guard !quote.isEmpty, let box = CheatingEvidenceBox.parse(row["bbox"]) else { return nil }

            let kind = CheatingEvidenceKind(rawValue: string(row["kind"])) ?? .other
            let confidence = normalizedConfidence(row["confidence"])
            let modelStrong = string(row["strength"]) == "strong"
            let policyStrong = kind.canBeStrong
                && modelStrong
                && confidence >= 0.72
                && allowedAsStrong(kind: kind, quote: quote, context: context)

            return CheatingDetectionEvidence(
                kind: kind, quote: quote, box: box,
                confidence: confidence, isStrong: policyStrong)
        }
    }

    private static func allowedAsStrong(kind: CheatingEvidenceKind,
                                        quote: String,
                                        context: CheatingProblemContext) -> Bool {
        switch kind {
        case .answerOnly:
            guard context.requiresWork,
                  let student = context.studentFinalAnswer,
                  !student.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
            // 정답 형식의 완전한 수학 동치성은 MathAnswer가 담당한다. 여기서는 최소한
            // 모델이 본 학생 답과 앱이 가진 비교값이 같은 문자열 계열인지 확인한다.
            if !context.expectedAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return compact(student) == compact(context.expectedAnswer)
            }
            // GOAT Arena는 정답을 기기에 보내지 않는다. 모델 quote가 학생이 실제로
            // 제출한 답 하나와 정확히 같을 때만 answer-only 후보를 유지한다.
            let observed = compactAnswerQuote(quote)
            guard !observed.isEmpty else { return false }
            return (context.studentSubmittedAnswers ?? []).contains {
                observed == compact($0)
            }

        case .unexplainedJump:
            return context.requiresWork && !context.referenceSteps.isEmpty

        case .referencePhraseMatch:
            let needle = compact(quote)
            guard needle.count >= 4 else { return false }
            return context.referenceSteps.map(compact).contains { step in
                step.contains(needle) || needle.contains(step)
            }

        case .visualPasteArtifact:
            return true

        case .mixedWritingStyle, .unreadable, .other:
            return false
        }
    }

    private static func jsonObject(from raw: String) -> [String: Any]? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        text = text.replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
        guard let first = text.firstIndex(of: "{"), let last = text.lastIndex(of: "}"), first <= last else {
            return nil
        }
        let body = String(text[first...last])
        guard let data = body.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return object
    }

    private static func string(_ value: Any?) -> String {
        (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func normalizedConfidence(_ value: Any?) -> Double {
        let raw: Double
        if let n = value as? NSNumber { raw = n.doubleValue }
        else if let s = value as? String, let n = Double(s) { raw = n }
        else { return 0 }
        let normalized = raw > 1 && raw <= 100 ? raw / 100 : raw
        return min(1, max(0, normalized.isFinite ? normalized : 0))
    }

    private static func clipped(_ value: String, limit: Int) -> String {
        value.count <= limit ? value : String(value.prefix(limit))
    }

    private static func compact(_ value: String) -> String {
        value.lowercased().filter { $0.isLetter || $0.isNumber || "√+-=*/^".contains($0) }
    }

    private static func compactAnswerQuote(_ value: String) -> String {
        let normalized = value.lowercased()
            .replacingOccurrences(of: "정답", with: "")
            .replacingOccurrences(of: "답", with: "")
        return compact(normalized)
    }
}
