//  KakaoSignInCoordinator.swift
//  Matths
//
//  카카오 로그인 — 서버 PKCE 왕복. **카카오 SDK 를 쓰지 않는다.**
//
//  왜 SDK 가 아닌가: SDK 를 넣으면 앱에 네이티브 키가 박히고, 카카오톡 앱 전환
//  경로와 웹 폴백 두 갈래를 각각 관리해야 하며, 서드파티 의존이 하나 더 는다
//  (고지 목록도 따라 늘어난다 — ProfileScreen.licenses). 서버는 이미 카카오
//  OAuth 를 웹에서 돌리고 있었고, 앱용 진입점 한 줄만 없었다. 그래서 구글이
//  쓰던 길을 그대로 탄다.
//
//    앱 → GET  /auth/kakao/app?code_challenge=…   (ASWebAuthenticationSession)
//        → 카카오 동의 → 서버 콜백
//        → matths://oauth/kakao?code=…            (딥링크로 앱 복귀)
//    앱 → POST /api/v1/auth/social/exchange       (code + codeVerifier)
//        → AuthResponse
//
//  GoogleSignInCoordinator 와 거의 같은 모양이다. **일부러 합치지 않았다.**
//  구글 경로는 지금 유일하게 살아 있는 소셜 로그인이고, 8/23 심사 제출 이틀 전에
//  공용 부모로 끌어올리면 그 경로까지 같이 흔든다. 제출 뒤 둘을 하나로 모으는 게
//  맞고, 그때 이 주석이 근거가 된다.

import AuthenticationServices
import CryptoKit
import SwiftUI
import UIKit

@MainActor
final class KakaoSignInCoordinator: NSObject, ObservableObject,
    ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?

    func signIn() async throws -> AuthResponse {
        let providers = try await ServerAPI.socialAuthProviders()
        guard providers.first(where: { $0.key == "kakao" })?.configured == true else {
            throw ServerAPIError(
                message: "카카오 로그인이 아직 설정되지 않았습니다.",
                code: "SOCIAL_AUTH_NOT_CONFIGURED")
        }
        // provider 조회 중 화면을 떠났다면 브라우저 세션을 새로 열지 않는다.
        try Task.checkCancellation()
        let codeVerifier = try Self.makeCodeVerifier()
        let codeChallenge = Self.makeCodeChallenge(codeVerifier)
        // 로그인 전 공개 진입점이라 Bearer API router 와 분리돼 있다.
        // (구글에서 `/api/v1` 미들웨어 순서 때문에 시작 요청이 401 로 잠겼던 회귀가 있었다.)
        var startComponents = URLComponents(
            url: ServerAPI.baseURL.appendingPathComponent("/auth/kakao/app"),
            resolvingAgainstBaseURL: false
        )
        startComponents?.queryItems = [
            URLQueryItem(name: "code_challenge", value: codeChallenge)
        ]
        guard let startURL = startComponents?.url else {
            throw ServerAPIError(
                message: "카카오 로그인 주소를 만들지 못했습니다.",
                code: "SOCIAL_AUTH_START_URL_INVALID")
        }
        let callbackURL = try await openAuthenticationSession(startURL: startURL)
        let code = try callbackCode(callbackURL, expectedPath: "/kakao")
        return try await ServerAPI.exchangeSocialAuthCode(
            code,
            codeVerifier: codeVerifier
        )
    }

    func reauthenticateForAccountDeletion()
    async throws -> ServerAPI.KakaoWithdrawalReauthentication {
        let codeVerifier = try Self.makeCodeVerifier()
        let codeChallenge = Self.makeCodeChallenge(codeVerifier)
        let start = try await ServerAPI.startKakaoWithdrawalReauthentication(
            codeChallenge: codeChallenge)
        guard let startURL = URL(string: start.authorizationUrl),
              startURL.scheme?.lowercased() == ServerAPI.baseURL.scheme?.lowercased(),
              startURL.host?.lowercased() == ServerAPI.baseURL.host?.lowercased() else {
            throw ServerAPIError(
                message: "카카오 본인 확인 주소가 올바르지 않습니다.",
                code: "ACCOUNT_REAUTHENTICATION_START_URL_INVALID")
        }
        let callbackURL = try await openAuthenticationSession(startURL: startURL)
        let proof = try callbackCode(callbackURL, expectedPath: "/kakao-reauth")
        return ServerAPI.KakaoWithdrawalReauthentication(
            proof: proof,
            codeVerifier: codeVerifier)
    }

    private func openAuthenticationSession(startURL: URL) async throws -> URL {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(
                url: startURL,
                callbackURLScheme: "matths"
            ) { [weak self] url, error in
                Task { @MainActor in
                    self?.session = nil
                    if let error { continuation.resume(throwing: error); return }
                    guard let url else {
                        continuation.resume(throwing: ServerAPIError(
                            message: "카카오 로그인 결과를 확인하지 못했습니다.",
                            code: "SOCIAL_AUTH_CALLBACK_MISSING"))
                        return
                    }
                    continuation.resume(returning: url)
                }
            }
            session.presentationContextProvider = self
            // 카카오톡·카카오계정 로그인 상태를 살리려면 사파리 쿠키를 공유해야 한다.
            // ephemeral 이면 매번 아이디부터 다시 치게 된다.
            session.prefersEphemeralWebBrowserSession = false
            self.session = session
            guard session.start() else {
                self.session = nil
                continuation.resume(throwing: ServerAPIError(
                    message: "카카오 로그인 화면을 열지 못했습니다.",
                    code: "SOCIAL_AUTH_START_FAILED"))
                return
            }
        }
    }

    /// 콜백은 반드시 `matths://oauth/kakao` 여야 한다. 경로를 확인하지 않으면
    /// 구글 왕복 결과가 카카오 로그인으로 들어와 어느 쪽을 끝낸 것인지 뒤섞인다.
    private func callbackCode(_ callbackURL: URL, expectedPath: String) throws -> String {
        guard callbackURL.scheme?.lowercased() == "matths",
              callbackURL.host?.lowercased() == "oauth",
              callbackURL.path == expectedPath else {
            throw ServerAPIError(
                message: "카카오 로그인 결과 주소가 올바르지 않습니다.",
                code: "SOCIAL_AUTH_CALLBACK_INVALID")
        }
        let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)
        var values: [String: String] = [:]
        for item in components?.queryItems ?? [] {
            if values[item.name] != nil {
                throw ServerAPIError(
                    message: "카카오 로그인 결과가 중복되었습니다. 다시 시도해주세요.",
                    code: "SOCIAL_AUTH_CALLBACK_DUPLICATE")
            }
            values[item.name] = item.value ?? ""
        }
        if let message = values["error"], !message.isEmpty {
            throw ServerAPIError(message: message, code: "SOCIAL_AUTH_CANCELLED")
        }
        guard let code = values["code"], !code.isEmpty else {
            throw ServerAPIError(
                message: "카카오 로그인 확인 코드가 없습니다.",
                code: "SOCIAL_AUTH_GRANT_MISSING")
        }
        return code
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.flatMap(\.windows).first(where: \.isKeyWindow)
            ?? scenes.first?.windows.first
            ?? ASPresentationAnchor()
    }

    func cancel() {
        session?.cancel()
        session = nil
    }

    private static func makeCodeVerifier() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            // 실패 시 약한 verifier로 내려앉지 않고 로그인 시도만 끝낸다.
            // 시스템 난수 장애가 앱 강제 종료로 번지면 탈퇴 본인 확인 중에도
            // 사용자가 작성 중이던 다른 화면 상태까지 잃는다.
            throw ServerAPIError(
                message: "보안 로그인 값을 만들지 못했습니다. 잠시 후 다시 시도해주세요.",
                code: "SOCIAL_AUTH_SECURE_RANDOM_UNAVAILABLE")
        }
        return Data(bytes).kakaoBase64URLEncodedString()
    }

    private static func makeCodeChallenge(_ verifier: String) -> String {
        Data(SHA256.hash(data: Data(verifier.utf8))).kakaoBase64URLEncodedString()
    }
}

private extension Data {
    /// GoogleSignInCoordinator 에도 같은 것이 private 로 있다. 파일 밖으로 꺼내면
    /// 두 확장이 충돌하므로 이름을 달리 둔다 — 둘을 합칠 때 같이 정리한다.
    func kakaoBase64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
