//
//  ServerTokenOwnership.swift
//  Matths
//
//  계정 A 요청의 늦은 401이 계정 B 로그인 뒤 돌아와 새 토큰을 지우는
//  경합을 막는 순수 판정. 실제 비교·삭제는 TokenBox 잠금 안에서 수행한다.
//

import Foundation

enum ServerTokenOwnership {
    enum RestoredSessionAction: Equatable {
        case keep
        case discardOrphanedToken
        case requireSignIn
    }

    static func shouldClear(
        requestToken: String?,
        currentToken: String?
    ) -> Bool {
        guard let requestToken, !requestToken.isEmpty else { return false }
        return requestToken == currentToken
    }

    /// 디스크에 남겨도 되는 로그인 표식은 실제 제품 경계 두 개뿐이다. Debug의
    /// `debug` 또는 손상·구버전 문자열이 Release로 넘어오면 로그인 화면을 건너뛰고
    /// 데모 프로필을 제품 데이터처럼 보여 주므로 시작 시 nil로 정규화한다.
    static func sanitizedPersistedProvider(_ provider: String?) -> String? {
        switch provider {
        case "guest", "server": return provider
        default: return nil
        }
    }

    /// UserDefaults의 화면 로그인 상태와 Keychain의 실제 Bearer 토큰은 서로 다른
    /// 저장소다. 앱 재설치·키체인 정리·서버 서명키 회전 뒤 둘 중 하나만 남아도
    /// 로그인 화면을 건너뛰어 모든 API가 401을 반복하면 안 된다.
    static func restoredSessionAction(
        authProvider: String?,
        hasToken: Bool
    ) -> RestoredSessionAction {
        if authProvider == "server" {
            return hasToken ? .keep : .requireSignIn
        }
        return hasToken ? .discardOrphanedToken : .keep
    }
}
