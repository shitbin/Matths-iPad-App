//  KiceBank.swift
//  Matths
//
//  수능 기출 아카이브 — KiceBank/kice-index.json 을 읽는다.
//
//  인덱스는 kice-archive/build-index.mjs 가 만든다. 그 스크립트는
//  배점 체크섬(공통 74점, 선택과목 각 26점, 총 100점)을 어서션으로 확인한
//  뒤에만 파일을 쓰므로, 여기 도착한 정답표는 이미 검증된 값이다.
//  (정답표 출처: 평가원 공개 정답 PDF — 2026·2024 텍스트 추출,
//   2025 는 이미지 스캔이라 Vision OCR + 표 렌더 육안 대조로 해독)
//
//  저작권: 평가원 기출 문항은 데모·내부 평가 목적으로만 번들한다.
//  상업 서비스 탑재 전 KICE 와 문항 사용계약이 필요하다 (docs/전체구조.md 참고).

import Foundation

struct KiceItem: Codable, Identifiable {
    let no: Int
    /// 선다형은 "1"~"5"(①~⑤), 단답형은 0~999 숫자 문자열
    let answer: String
    let points: Int
    let type: String            // "choice" | "short"

    var id: Int { no }
    var isChoice: Bool { type == "choice" }
}

struct KiceExam: Codable, Identifiable {
    let id: String
    let title: String           // "2026학년도 대학수학능력시험"
    let short: String           // "2026 수능"
    let heldOn: String          // 시행일 yyyy-MM-dd
    let form: String            // "홀수형"
    let pdf: String             // 번들 문제지 파일명
    let common: [KiceItem]      // 1~22
    let electives: [String: [KiceItem]]   // 과목명 → 23~30

    /// 표시용 형 — 모평 정답표에는 홀/짝 표기가 없어 "단일형"으로 들어오는데,
    /// 그건 데이터 사정이지 학생에게 보여줄 말이 아니다.
    var displayForm: String? { form == "단일형" ? nil : form }
}

struct KiceIndex: Codable {
    let version: Int
    let license: String
    let exams: [KiceExam]
}

enum KiceBank {
    /// 선택과목 표시 순서 — 사전순이 아니라 시험지 순서
    static let electiveOrder = ["확률과 통계", "미적분", "기하"]

    static let index: KiceIndex? = {
        // 번들 리소스는 루트로 평탄화된다 (LessonWeb 과 동일) — subdirectory 는 보험
        guard let url = Bundle.main.url(forResource: "kice-index", withExtension: "json",
                                        subdirectory: "KiceBank")
                ?? Bundle.main.url(forResource: "kice-index", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(KiceIndex.self, from: data)
    }()

    static var exams: [KiceExam] { index?.exams ?? [] }

    static func pdfURL(for exam: KiceExam) -> URL? {
        let name = (exam.pdf as NSString).deletingPathExtension
        return Bundle.main.url(forResource: name, withExtension: "pdf", subdirectory: "KiceBank")
            ?? Bundle.main.url(forResource: name, withExtension: "pdf")
    }

    // MARK: 최고 점수 (100점 만점) — 시험별 저장. 평가센터 행에 표시된다.

    /// 기출 최고점도 계정별로 — 남의 최고점이 내 화면에 뜨면 안 된다
    private static func bestKey(_ examID: String) -> String {
        AppStore.slotKey("matths.kice.best.\(examID)")
    }

    static func bestScore(_ examID: String) -> Int? {
        UserDefaults.standard.object(forKey: bestKey(examID)) as? Int
    }

    static func recordScore(_ examID: String, score: Int) {
        if score > (bestScore(examID) ?? -1) {
            UserDefaults.standard.set(score, forKey: bestKey(examID))
        }
    }
}
