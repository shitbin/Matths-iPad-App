//  RuntimeMode.swift
//  Matths
//
//  실행 모드 판정 — 프로세스 인자 기반의 전역 스위치.
//  검수 회귀 R-01: -review 가 DebugBar 만 숨기고 화면 내부의 #if DEBUG UI
//  (채점 Pro 모델 피커, 풀이 세션 정오답 숏컷, KICE 답안 숏컷 등)는 그대로
//  노출됐다. 디버그 UI 는 예외 없이 이 게이트를 함께 검사한다:
//
//      #if DEBUG
//      if !RuntimeMode.isReviewCapture { debugModelPicker }
//      #endif
//
//  주의: -route/-exam/-kice 같은 화면 라우팅 인자는 캡처의 수단이므로
//  이 게이트와 무관하게 항상 동작해야 한다. 숨기는 것은 "보이는 UI" 뿐이다.

import Foundation

enum RuntimeMode {
    /// 디자인 검수 캡처 모드 — 디버그 UI 를 화면에서 완전히 제거한다.
    static let isReviewCapture =
        ProcessInfo.processInfo.arguments.contains("-review")
}
