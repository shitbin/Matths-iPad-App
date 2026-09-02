//  CheatingReviewModels.swift
//  Matths
//
//  온디바이스 풀이 무결성 검사의 영속 기록 계약.
//  이 기록은 관리자/개발자 검토 재료일 뿐 채점, 랭킹, 정산, 실격을 바꾸지 않는다.

import Foundation

enum CheatingReviewSource: String, Codable, Sendable {
    case practiceDrawing = "practice-drawing"
    case sheetPhoto = "sheet-photo"
    case goatArenaEvidence = "goat-arena-evidence"

    var koreanLabel: String {
        switch self {
        case .practiceDrawing: return "풀이 제출"
        case .sheetPhoto:      return "시험지 사진"
        case .goatArenaEvidence: return "GOAT Arena 풀이 증거"
        }
    }
}

enum CheatingReviewState: String, Codable, Sendable {
    case pending
    case completed
}

struct GoatArenaCheatingReviewDelivery: Codable, Equatable, Sendable {
    let matchId: String
    let evidenceId: String
    let clientBuildVersion: String
}

struct CheatingReviewRecord: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let source: CheatingReviewSource
    let problemID: String?
    let problemStatement: String
    let studentFinalAnswer: String?
    /// 강제 종료 뒤 GOAT 검토만 안전하게 다시 시작하기 위한 최소 입력.
    let problemContext: CheatingProblemContext?
    let arenaDelivery: GoatArenaCheatingReviewDelivery?
    /// 검토 화면에 쓸 축소 이미지. 계정 슬롯의 cheating-reviews/images 아래 파일명이다.
    let imageFile: String?
    let createdAt: Date
    var finishedAt: Date?
    var state: CheatingReviewState
    var result: CheatingDetectionResult?

    static func pending(source: CheatingReviewSource,
                        problemID: String?,
                        problemStatement: String,
                        studentFinalAnswer: String?,
                        imageFile: String?,
                        problemContext: CheatingProblemContext? = nil,
                        arenaDelivery: GoatArenaCheatingReviewDelivery? = nil,
                        id: UUID = UUID(),
                        createdAt: Date = Date()) -> Self {
        Self(id: id, source: source, problemID: problemID,
             problemStatement: problemStatement,
             studentFinalAnswer: studentFinalAnswer,
             problemContext: problemContext,
             arenaDelivery: arenaDelivery,
             imageFile: imageFile, createdAt: createdAt,
             finishedAt: nil, state: .pending, result: nil)
    }

    mutating func finish(_ value: CheatingDetectionResult, at date: Date = Date()) {
        guard state == .pending else { return }
        result = value
        state = .completed
        finishedAt = date
    }

    mutating func recoverInterrupted(at date: Date = Date()) {
        guard state == .pending else { return }
        finish(.inconclusive("이전 앱 실행이 종료되어 로컬 판정을 마치지 못했습니다."),
               at: date)
    }

    var displayResult: CheatingDetectionResult {
        result ?? .inconclusive("로컬 판정을 기다리는 중입니다.")
    }
}
