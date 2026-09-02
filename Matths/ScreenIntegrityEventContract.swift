//  ScreenIntegrityEventContract.swift
//  Matths
//
//  보호 화면 캡처 신호의 클라이언트 경계. 서버가 받는 값은 이 파일의 세 이벤트,
//  비식별 실행 코드, 고정된 화면 이름뿐이다. 계정명·이메일·경기/문항 ID는 넣지 않는다.

import Foundation

enum ScreenIntegrityEventContract {
    static let allowedEventTypes: Set<String> = [
        "protected-screen-screenshot",
        "protected-screen-capture-started",
        "protected-screen-capture-ended",
    ]

    static let allowedSurfaces: Set<String> = [
        "session",
        "assessment",
        "assessment-paper",
        "kice-exam",
        "placement-exam",
        "weekly-mock",
        "goat-arena",
        // GoatArenaScreen 의 경기 fullScreenCover 가 실제로 넘기는 값. 화이트리스트에
        // 없어서 모든 경기 캡처 신호가 "protected" 로 뭉개지고 있었다 — 어느 화면에서
        // 찍혔는지 서버가 알 수 없다는 뜻이다. 화면 이름 자체는 고정 문자열이고
        // 개인정보가 아니므로 그대로 통과시킨다.
        "goat-arena-match",
        // 아레나 웹 브리지(ArenaWeb/ArenaWebDestination.protectionSurfaceName)가 넘기는 값.
        // goat-arena-match 와 **정확히 같은 이유**로 빠져 있었다 — 서버가 "아레나 경기를
        // 웹으로 보는 중에 찍혔다" 를 구분하지 못하고 protected 로 뭉개서 받고 있었다.
        // 웹뷰 경기는 AAC 시스템 잠금이 걸리지 않으므로(설계상 의도) 사후 감사가
        // 유일한 추적 수단인데, 그 감사마저 익명화되면 남는 게 없다.
        "goat-arena-web",
        "protected",
    ]

    static func normalizedEventType(_ rawValue: String) -> String? {
        let value = rawValue.lowercased()
        return allowedEventTypes.contains(value) ? value : nil
    }

    /// 현재 생성기가 만드는 UUID 앞 8자리(hex)만 허용한다. 임의 문자열을 단순히
    /// 잘라 보내면 이메일 같은 사용자 입력도 영숫자만 남아 유출될 수 있으므로,
    /// 형식이 다르면 원문을 버리고 비식별 실패 표식만 보낸다.
    static func normalizedSessionCode(_ rawValue: String) -> String {
        let value = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        guard value.count == 8,
              value.allSatisfy({ "0123456789ABCDEF".contains($0) }) else {
            return "UNKNOWN"
        }
        return value
    }

    /// 보호 modifier가 겹친 경우 쉼표로 합친 고정 화면 이름은 보존한다. 그 밖의
    /// 문자열은 개인정보가 섞였을 가능성이 있으므로 원문을 버리고 `protected`로 축약한다.
    static func normalizedSurface(_ rawValue: String) -> String {
        let values = rawValue
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { allowedSurfaces.contains($0) }
        let safeValues = Array(Set(values)).sorted()
        return safeValues.isEmpty ? "protected" : safeValues.joined(separator: ",")
    }
}
