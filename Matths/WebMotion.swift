//  WebMotion.swift
//  Matths
//
//  웹뷰 안 애니메이션에도 **같은 모션 스위치**를 적용한다.
//
//  왜 필요한가: Motion.swift 의 규칙은 "스위치는 하나(화면 모션)이고, 시스템
//  '동작 줄이기' 가 켜져 있으면 앱 설정과 무관하게 전부 정지" 다. 그런데 그 규칙은
//  SwiftUI 쪽에만 걸려 있었고, WKWebView 로 도는 세 가지 — 풀이 플레이어 자동재생,
//  힌트 순차 드로잉, 풀이 씬(ScenarioPlayer) — 는 스위치를 아예 보지 않고 무조건
//  재생했다(2026-07-29 감사 적발). 모션에 예민한 학생에게는 그 셋이 가장 크게 움직이는
//  화면이라, 규칙이 사실상 지켜지지 않고 있었다.
//
//  값을 뷰 인자로 흘려보내지 않고 여기서 직접 읽는다. 둘 다 전역 상태이고
//  (UserDefaults + 접근성), 호출부 8곳에 인자를 추가하면 실수로 빠뜨리는 곳이 생긴다.

import Foundation
import UIKit

enum WebMotion {
    static let preferenceKey = "matths.motion"

    /// AppStore.motionOn 이 쓰는 것과 같은 사용자 선택값.
    static var userEnabled: Bool {
        UserDefaults.standard.object(forKey: preferenceKey) as? Bool ?? true
    }

    /// 앱 설정과 시스템 동작 줄이기를 한 곳에서 합성한다.
    /// WebContentAccessibility도 같은 식을 JS에 주입하므로 어느 쪽도 다른 쪽을
    /// 덮어쓰지 않는다.
    static func allowed(userEnabled: Bool, reduceMotion: Bool) -> Bool {
        userEnabled && !reduceMotion
    }

    static var allowed: Bool {
        allowed(userEnabled: userEnabled,
                reduceMotion: UIAccessibility.isReduceMotionEnabled)
    }
}
