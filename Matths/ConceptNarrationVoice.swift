//  ConceptNarrationVoice.swift
//  Matths
//
//  개념 영상의 해설 음성을 켜고 끄고, 성우를 고른다.
//
//  앱의 기본값은 여성 성우다. `off`는 별도 효과음 모드가 아니라 해설 음성을
//  재생하지 않는 상태다. 현재 모션 자산에는 독립된 효과음 트랙이 없다.

import Foundation

enum ConceptNarrationVoice: String, CaseIterable, Identifiable {
    /// 해설 음성을 내지 않는다.
    case off
    /// 여성 성우. 앱 기본값이다.
    case female
    /// 남성 성우.
    case male

    var id: String { rawValue }

    var label: String {
        switch self {
        case .off: "음성 끄기"
        case .female: "여성"
        case .male: "남성"
        }
    }

    /// 이 성우의 음성 파일이 사는 폴더 이름.
    /// 제작 쪽 `assets/voice` · `assets/voice-female` 와 같은 갈래다.
    var assetFolder: String? {
        switch self {
        case .off: nil
        case .female: "voice-female"
        case .male: "voice"
        }
    }

    var isSpoken: Bool { self != .off }

    /// 이 성우의 음성이 **실제로 기기에 있는가.**
    ///
    /// WHY 이게 필요한가 — 앱 다운로드 용량 때문에 음성 세트를 한 벌만 동봉한다
    /// (한 벌이 약 70MB 다. 두 벌이면 셀룰러 다운로드 경고선을 혼자 넘긴다).
    /// 그런데 선택지는 열거형에 그대로 남아 있어서, 없는 성우를 고를 수 있으면
    /// **소리만 조용히 안 나온다.** 학생 눈에는 앱이 고장 난 것으로 보인다.
    ///
    /// 그래서 "무엇을 넣었는가" 를 코드에 박지 않고 **번들을 실제로 들여다본다.**
    /// 나중에 남성 음성을 다시 넣거나 서버에서 내려받게 되면, 이 함수는 고칠 것이
    /// 없고 선택지가 저절로 다시 생긴다.
    var isInstalled: Bool {
        guard let folder = assetFolder else { return true }   // 끄기는 언제나 가능
        for root in ConceptMotionWebAsset.roots {
            let directory = root
                .appendingPathComponent("assets", isDirectory: true)
                .appendingPathComponent(folder, isDirectory: true)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(
                atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue
            else { continue }
            // 폴더만 있고 비어 있는 경우가 실제로 있다(동기화가 중간에 끊긴 사본).
            // 한 개라도 실물이 있어야 "설치됨" 이다.
            let contents = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
            if !contents.isEmpty { return true }
        }
        return false
    }

    /// 화면에 보여 줄 선택지. 설치된 성우만 남긴다.
    static var installedCases: [ConceptNarrationVoice] {
        allCases.filter(\.isInstalled)
    }
}

enum ConceptNarrationPreference {
    static let key = "matths.concept.voice"

    /// 앱 기본은 여성 목소리다.
    static let appDefault: ConceptNarrationVoice = .female

    /// 지금 고른 성우. **설치돼 있지 않으면 설치된 것으로 되돌린다.**
    ///
    /// 업데이트로 음성 세트가 빠질 수 있다. 그때 저장된 선호가 그대로 남아 있으면
    /// 학생은 아무것도 안 바꿨는데 어느 날부터 해설이 무음이 된다. 원인을 알 방법도
    /// 없다. 그래서 읽는 자리에서 한 번 걸러 준다.
    static var current: ConceptNarrationVoice {
        guard let raw = UserDefaults.standard.string(forKey: key),
              let v = ConceptNarrationVoice(rawValue: raw) else { return appDefault }
        if v.isInstalled { return v }
        return appDefault.isInstalled ? appDefault : .off
    }

    static func set(_ voice: ConceptNarrationVoice) {
        UserDefaults.standard.set(voice.rawValue, forKey: key)
    }
}
