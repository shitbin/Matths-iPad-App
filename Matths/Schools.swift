//  Schools.swift
//  Matths
//
//  전국 고등학교 2,403개교 — 웹 kr-high-schools.yaml(나이스 학교기본정보)의 슬림 변환본.
//  경쟁전(학교 리그)의 기반 데이터다. 지역(17개 시·도) → 학교 순으로 고른다.
//  웹 규칙: 가입·변경 시 서버가 (지역, 코드) 재검증 — 앱도 목록 밖 학교는 저장하지 않는다.

import Foundation

struct SchoolRegion: Codable, Identifiable {
    let name: String
    let officeCode: String
    let schools: [School]
    var id: String { officeCode }
}

struct School: Codable, Identifiable, Hashable {
    let code: String
    let name: String
    let type: String        // 일반고/특목고/특성화고/자율고
    var id: String { code }
}

enum Schools {
    struct SchoolsFile: Codable { let regions: [SchoolRegion] }

    private static let loaded: (regions: [SchoolRegion], error: String?) = {
        do {
            guard let url = Bundle.main.url(forResource: "schools", withExtension: "json") else {
                throw CocoaError(.fileNoSuchFile)
            }
            let raw = try Data(contentsOf: url)
            let parsed = try JSONDecoder().decode(SchoolsFile.self, from: raw)
            guard !parsed.regions.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
            return (parsed.regions, nil)
        } catch {
            // 가입 화면은 서버 학교 목록을 정본으로 먼저 사용한다. 번들 fallback이
            // 깨져도 앱 전체를 종료하지 않고 서버 목록 또는 직접 재시도를 허용한다.
            NSLog("[Matths] bundled school catalog unavailable: %@", error.localizedDescription)
            return ([], "내장 학교 목록을 열지 못했습니다. 네트워크에 연결해 학교 목록을 다시 불러와 주세요.")
        }
    }()

    static let regions = loaded.regions
    static let loadError = loaded.error

    static func find(region: String, code: String) -> School? {
        regions.first { $0.name == region }?.schools.first { $0.code == code }
    }
}

// MARK: - 학년도 · 자동 승급 (웹 userLifecycleService)

enum AcademicYear {
    /// 학년도 — KST 기준 3월 1일에 새 학년도가 시작된다
    static func current(_ date: Date = Date()) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        let y = cal.component(.year, from: date)
        return cal.component(.month, from: date) >= 3 ? y : y - 1
    }

    /// 승급 계산 — 학년도가 지난 만큼 올리되 고3 다음은 N수생(13)에서 멈춘다.
    /// 학년도당 1회만 적용(lastPromotionYear). 웹 synchronizeUserLifecycle 과 동일.
    static func promote(grade: Int, lastPromotionYear: Int?) -> (grade: Int, year: Int) {
        let now = current()
        guard let last = lastPromotionYear else { return (grade, now) }
        let promotions = max(0, now - last)
        return (min(13, max(10, grade) + promotions), now)
    }
}
