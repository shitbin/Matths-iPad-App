//  GradingModels.swift
//  Matths
//
//  AI 채점 응답 계약 — 서버의 ai-grader/src/contract.js 와 1:1 대응.
//  한쪽을 고치면 반드시 다른 쪽도 고쳐야 한다. 이게 클라이언트/서버 계약이다.

import Foundation

/// 전체 판정
enum Overall: String, Codable {
    case correct                          // 답·풀이 모두 옳음
    case partiallyCorrect = "partially-correct"
    case incorrect
    case answerOnly = "answer-only"       // 답만 맞고 풀이가 성립하지 않음 (요주의)
    case unreadable

    /// 통과로 볼 것인가. answer-only 는 통과가 아니다.
    var isAccepted: Bool { self == .correct }

    var koreanLabel: String {
        switch self {
        case .correct:          return "정답입니다"
        case .partiallyCorrect: return "일부만 맞았습니다"
        case .incorrect:        return "다시 풀어야 합니다"
        case .answerOnly:       return "답만 맞았습니다"
        case .unreadable:       return "판독하지 못했습니다"
        }
    }
}

/// 단계별 판정
enum StepVerdict: String, Codable {
    case correct, incorrect, unverifiable, irrelevant
}

/// 오류 유형 — class 로 계산 실수와 개념 오류를 구분한다
enum ErrorType: String, Codable {
    case none
    case arithmeticError    = "arithmetic-error"
    case signError          = "sign-error"
    case algebraError       = "algebra-error"
    case transcriptionError = "transcription-error"
    case conceptError       = "concept-error"
    case formulaMisuse      = "formula-misuse"
    case domainOmission     = "domain-omission"
    case caseOmission       = "case-omission"
    case logicGap           = "logic-gap"
    case unjustifiedLeap    = "unjustified-leap"
    case incomplete
    case unreadable

    enum Category: String { case none, calculation, conceptual, procedural }

    var category: Category {
        switch self {
        case .none:
            return .none
        case .arithmeticError, .signError, .algebraError, .transcriptionError:
            return .calculation
        case .conceptError, .formulaMisuse, .domainOmission, .caseOmission:
            return .conceptual
        case .logicGap, .unjustifiedLeap, .incomplete, .unreadable:
            return .procedural
        }
    }
}

struct StepResult: Codable, Identifiable {
    let step: Int
    let verdict: StepVerdict
    let comment: String
    let errorType: ErrorType?

    var id: Int { step }
}

/// 채점 결과 — 서버가 이 형식을 보장한다(strict tool schema)
struct GradingResult: Codable {
    let overall: Overall
    let firstErrorStep: Int?
    let errorType: ErrorType
    let stepResults: [StepResult]
    let awardedPoints: Double?
    let feedback: String
    let confidence: Double
    let needsHumanReview: Bool

    /// 학생에게 결과를 그대로 보여도 되는가.
    /// 저확신이거나 검토 요청이면 "선생님 확인 중" 으로 표시한다.
    var isDisplayable: Bool { !needsHumanReview && confidence >= 0.7 }
}

/// 제출 — 필기(PencilKit) 는 별도 멀티파트로 올린다
struct Submission: Codable {
    let problemId: String
    let steps: [String]
    let finalAnswer: String
    let errorTag: String?
    let elapsedMs: Int
}
