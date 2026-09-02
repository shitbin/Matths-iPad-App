//  CurriculumStore.swift
//  Matths
//
//  구 앱의 완료 개념 ID 저장소.
//
//  13과목·220개념 데이터와 현재 진도는 CurriculumV2/ProgressV2Store가 정본이다.
//  이 파일은 업데이트 전 사용자의 67개념 완료 ID를 v2 legacy.appId로 한 번
//  승계하고, 과거 평가 기록과의 하위 호환을 유지하는 저장 경계만 남긴다.

import Foundation

struct Progress {
    /// UserDefaults 키 — 완료한 개념 id 집합. **슬롯 이름을 붙인다.**
    ///
    /// 파일(progress-v2·오답·이벤트)은 DataScope 로 계정별로 갈라 놨는데 이 키만
    /// 전역 하나로 남아 있어서, 로그아웃하고 다른 계정으로 들어와도 앞사람의
    /// 완료 개념 수·해금 상태가 그대로 보였다. 더 나쁜 건 CurriculumV2 의
    /// migrate(fromLegacyCompleted:) 가 그 값을 읽어 **뒷사람 슬롯 파일에**
    /// 앞사람 진도를 굳혀 버린다는 점이다. 표시만 새는 게 아니라 데이터가 섞인다.
    /// 한 기기를 형제·친구가 같이 쓰는 상황을 전제하므로 원천에서 막는다.
    static var storeKey: String { "matths.completedConcepts." + DataScope.slot }

    /// 슬롯 도입 이전에 쓰던 전역 키 — 첫 로드에서 현재 슬롯으로 옮기고 지운다
    private static let legacyStoreKey = "matths.completedConcepts"

    static func load() -> Set<String> {
        let defaults = UserDefaults.standard
        if let saved = defaults.stringArray(forKey: storeKey) { return Set(saved) }
        // 기존 사용자 보호 — 슬롯 없던 시절의 기록은 지금 슬롯이 물려받는다(DataScope
        // 의 파일 이관과 같은 규약: 복사가 아니라 이동). 전역 키를 남겨 두면
        // 다음 계정도 똑같이 물려받으므로 옮긴 즉시 비운다.
        if let legacy = defaults.stringArray(forKey: legacyStoreKey) {
            defaults.removeObject(forKey: legacyStoreKey)
            let set = Set(legacy)
            save(set)
            return set
        }
        return []
    }

    static func save(_ set: Set<String>) {
        UserDefaults.standard.set(Array(set).sorted(), forKey: storeKey)
    }
}
