//  UniversalLayoutPolicy.swift
//  Matths
//
//  iPhone/iPad 공용 레이아웃의 숫자와 입력 기본값을 한곳에서 결정한다.
//  UIKit/SwiftUI 타입을 받지 않으므로 호스트에서 빠른 실행 계약으로도 검증할 수 있다.

import Foundation

enum MatthsDeviceClass: String, Sendable {
    case phone
    case pad
}

enum MatthsLayoutClass: String, Sendable {
    case compact
    case regular
    case unspecified
}

enum UniversalLayoutPolicy {
    /// Apple Pencil이 없는 iPhone은 손가락 입력이 꺼진 채 시작하면 풀이를 쓸 수 없다.
    /// iPad는 기존 Pencil 우선·팜 리젝션 동작을 그대로 유지한다.
    static func defaultsToFingerDrawing(on device: MatthsDeviceClass) -> Bool {
        device == .phone
    }

    /// iPhone 또는 세로 공간이 짧은 가로모드에서는 워드마크 대신 심볼을 써서
    /// 스트릭·튜터·프로필의 44pt 조작 영역을 침범하지 않는다.
    static func usesCompactTopChrome(
        on device: MatthsDeviceClass,
        vertical: MatthsLayoutClass
    ) -> Bool {
        device == .phone || vertical == .compact
    }

    static func topBarMinimumHeight(
        on device: MatthsDeviceClass,
        vertical: MatthsLayoutClass,
        accessibilityText: Bool
    ) -> CGFloat {
        if accessibilityText { return 68 }
        if vertical == .compact { return 44 }
        return device == .phone ? 50 : 52
    }

    static func tabMinimumHeight(vertical: MatthsLayoutClass) -> CGFloat {
        vertical == .compact ? 44 : 50
    }

    /// 스크롤 화면 안의 최소 높이다. iPhone 가로에서 기존 420pt를 강제하면
    /// 문제와 도구막대가 캔버스에 밀려 한 화면에서 방향을 잃는다.
    static func solutionCanvasMinimumHeight(
        on device: MatthsDeviceClass,
        horizontal: MatthsLayoutClass,
        vertical: MatthsLayoutClass
    ) -> CGFloat {
        if device == .phone {
            return vertical == .compact ? 220 : 360
        }
        if vertical == .compact { return 280 }
        return horizontal == .compact ? 420 : 620
    }
}
