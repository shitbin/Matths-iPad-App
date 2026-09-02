//  AppleSignInCoordinator.swift
//  Matths
//
//  Sign in with Apple — 심사지침 4.8 대응.
//
//  왜 필요한가. 지침 4.8 은 제3자 소셜 로그인(우리는 Google)을 제공하면 동등한 대안을
//  함께 주라고 요구한다. 자체 이메일 가입이 대안으로 인정되려면 수집 항목이 **이름과
//  이메일로 제한**돼야 하는데, Matths 는 실명·학교·학년까지 받는다(학년 기반 진도와
//  학교 리그가 그 위에 서 있다). 그래서 현재 구성은 4.8 을 만족하지 못하고, 애플 로그인
//  없이는 반려된다.
//
//  ■ 왜 Google 처럼 웹 왕복이 아니라 네이티브인가
//
//  Google 은 ASWebAuthenticationSession 으로 브라우저를 열어 서버 왕복을 한다
//  (GoogleSignInCoordinator). 애플은 그 길로도 되지만 네이티브를 쓴다:
//    ① 심사자가 기대하는 모습이 시스템 시트(Face ID)다. 브라우저가 뜨면 "Sign in with
//       Apple 을 붙였다" 로 안 읽힐 위험이 있다.
//    ② 로그인 자체에는 서버의 client_secret(ES256 JWT)이 필요 없다. 네이티브가 준
//       identityToken 을 서버가 애플 공개키(JWKS)로 검증하면 끝난다.
//    ③ PKCE·grant 저장소(mobileSocialAuthGrantService)를 거치지 않아 왕복이 하나 준다.
//
//  ■ 붙는 자리는 Google 과 **똑같다**
//
//  이 코디네이터는 AuthResponse 를 돌려주고, 그다음은 기존 4단 파이프를 그대로 탄다:
//      beginAuthenticationAttempt() → signInServer(auth, attemptID:)
//      (old-slot flush 성공 직후 AppStore가 acceptAuthentication을 원자적으로 수행)
//  슬롯 전환·게스트 기록 승계·동기화가 전부 거기에 이미 있다. 새 경로를 만들지 않는다.
//
//  ■ 이름과 이메일은 **최초 1회만 온다**
//
//  애플은 사용자가 처음 승인할 때만 fullName·email 을 준다. 같은 애플 ID로 두 번째
//  로그인하면 둘 다 nil 이다. 그래서 이 값들은 받은 그 순간 서버로 보내고, 서버가
//  그때 저장해야 한다 — 놓치면 영영 못 받는다. 앱이 로컬에 캐시해 두었다가 나중에
//  보내는 식으로 때우지 않는다(기기를 바꾸면 사라지고, 그 사실을 아무도 모른다).

import AuthenticationServices
import CryptoKit
import Foundation
import SwiftUI

@MainActor
final class AppleSignInCoordinator: NSObject, ObservableObject {

    /// 진행 중인 요청. 화면을 벗어나면 끊는다.
    private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?
    private var controller: ASAuthorizationController?
    /// 이번 요청에 쓴 원본 nonce. 서버가 identityToken 안의 해시와 대조한다.
    private var currentNonce: String?

    // MARK: 진입점

    func signIn() async throws -> AuthResponse {
        #if DEBUG
        // 데모 모드는 서버도 애플 시트도 없이 UI 만 본다. 실제 시트를 띄우면
        // 계정 없는 시뮬레이터에서 그냥 실패한다.
        if DemoMode.isOn {
            guard let response: AuthResponse = try DemoMode.canned(
                method: "POST", path: "/api/v1/auth/apple/exchange") else {
                throw DemoMode.missingFixture(method: "POST", path: "/api/v1/auth/apple/exchange")
            }
            return response
        }
        #endif

        // 서버가 애플 로그인을 켜 뒀는지 먼저 묻는다. Google 과 같은 사전 게이트다 —
        // 서버 준비가 안 된 상태에서 애플 시트를 띄우면 학생이 인증을 마친 **뒤에**
        // 교환에서 실패한다. 그 순서는 "애플 계정에 뭔가 문제가 있다" 로 오해된다.
        let providers = try await ServerAPI.socialAuthProviders()
        guard providers.contains(where: { $0.key == "apple" && $0.configured }) else {
            throw ServerAPIError(
                message: "Apple 로그인이 아직 준비되지 않았습니다.",
                code: "SOCIAL_AUTH_NOT_CONFIGURED")
        }
        // 화면 이탈이나 다른 로그인 수단 선택이 provider 조회와 겹쳤다면 여기서
        // 멈춘다. 취소된 작업이 뒤늦게 시스템 Apple 시트를 띄우면 안 된다.
        try Task.checkCancellation()

        let rawNonce = Self.makeNonce()
        currentNonce = rawNonce

        let credential = try await requestCredential(
            nonceHash: Self.sha256(rawNonce),
            requestedScopes: [.fullName, .email])

        guard let tokenData = credential.identityToken,
              let identityToken = String(data: tokenData, encoding: .utf8),
              !identityToken.isEmpty else {
            throw ServerAPIError(
                message: "Apple 로그인 정보를 받지 못했습니다.",
                code: "APPLE_AUTH_IDENTITY_TOKEN_MISSING")
        }
        // authorizationCode 는 로그인에는 필요 없지만 **서버가 애플 토큰을 폐기**할 때
        // 쓴다. 탈퇴 시 revoke 는 App Store 심사 요구사항이라 여기서 같이 넘긴다.
        let authorizationCode = credential.authorizationCode
            .flatMap { String(data: $0, encoding: .utf8) }

        return try await ServerAPI.exchangeAppleIdentity(
            identityToken: identityToken,
            authorizationCode: authorizationCode,
            nonce: rawNonce,
            fullName: Self.displayName(from: credential.fullName),
            email: credential.email)
    }

    /// 탈퇴 직전 본인 확인. 새 Apple 시스템 시트가 발급한 토큰만 서버에 보내며,
    /// 서버는 토큰의 sub가 현재 Bearer 계정에 저장된 Apple subject와 같은지 확인한다.
    func reauthenticateForAccountDeletion()
    async throws -> ServerAPI.AppleWithdrawalReauthentication {
        let rawNonce = Self.makeNonce()
        currentNonce = rawNonce
        let credential = try await requestCredential(
            nonceHash: Self.sha256(rawNonce),
            requestedScopes: [])
        guard let tokenData = credential.identityToken,
              let identityToken = String(data: tokenData, encoding: .utf8),
              !identityToken.isEmpty else {
            throw ServerAPIError(
                message: "Apple 본인 확인 정보를 받지 못했습니다.",
                code: "APPLE_AUTH_IDENTITY_TOKEN_MISSING")
        }
        return ServerAPI.AppleWithdrawalReauthentication(
            identityToken: identityToken,
            nonce: rawNonce)
    }

    /// 화면 이탈·재시도. 진행 중이던 시트를 끊고 대기를 풀어 준다.
    func cancel() {
        controller = nil
        currentNonce = nil
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(throwing: ASAuthorizationError(.canceled))
    }

    // MARK: 애플 시트

    private func requestCredential(
        nonceHash: String,
        requestedScopes: [ASAuthorization.Scope]
    ) async throws -> ASAuthorizationAppleIDCredential {
        // 앞 요청이 살아 있으면 먼저 끊는다. 두 시트가 겹치면 어느 쪽 결과인지
        // 알 수 없고, 늦게 온 쪽이 새 로그인을 덮는다.
        cancel()

        let request = ASAuthorizationAppleIDProvider().createRequest()
        // 이름·이메일은 최초 1회만 온다(파일 머리 참조). 그래도 매번 요청해야
        // 첫 승인 때 사용자에게 선택지가 뜬다.
        request.requestedScopes = requestedScopes
        request.nonce = nonceHash

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            self.controller = controller
            controller.performRequests()
        }
    }

    private func finish(_ result: Result<ASAuthorizationAppleIDCredential, Error>) {
        controller = nil
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }

    // MARK: nonce
    //
    // 재생 공격 방지. 원본 nonce 의 SHA-256 을 요청에 담으면 애플이 그 값을
    // identityToken 안에 그대로 박아 준다. 서버는 앱이 보낸 원본을 해싱해 토큰 안의
    // 값과 같은지 본다 — 남의 토큰을 주워 와도 원본 nonce 를 모르면 통과하지 못한다.

    private static func makeNonce(length: Int = 32) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        if SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) != errSecSuccess {
            // 시스템 난수가 실패하는 상황은 사실상 없지만, 실패했는데 예측 가능한
            // 값으로 조용히 내려앉으면 nonce 가 있으나 마나가 된다.
            bytes = (0..<length).map { _ in UInt8.random(in: .min ... .max) }
        }
        return Data(bytes).base64URLEncodedString()
    }

    private static func sha256(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    /// 애플이 준 이름 조각을 서버에 보낼 한 문자열로. 한국어 이름은 성+이름 순이다.
    private static func displayName(from components: PersonNameComponents?) -> String? {
        guard let components else { return nil }
        let formatted = PersonNameComponentsFormatter.localizedString(
            from: components, style: .default)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return formatted.isEmpty ? nil : formatted
    }
}

// MARK: - 델리게이트

extension AppleSignInCoordinator: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        let credential = authorization.credential as? ASAuthorizationAppleIDCredential
        Task { @MainActor in
            guard let credential else {
                finish(.failure(ServerAPIError(
                    message: "Apple 로그인 정보를 받지 못했습니다.",
                    code: "APPLE_AUTH_CREDENTIAL_INVALID")))
                return
            }
            finish(.success(credential))
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in finish(.failure(error)) }
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(
        for controller: ASAuthorizationController
    ) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            // Google 코디네이터와 같은 3단 폴백. keyWindow 가 없는 순간(전환 중)에도
            // 시트를 띄울 자리는 있어야 한다.
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            if let key = scenes.flatMap(\.windows).first(where: \.isKeyWindow) { return key }
            if let first = scenes.flatMap(\.windows).first { return first }
            return ASPresentationAnchor()
        }
    }
}

// MARK: - base64url

private extension Data {
    /// nonce 는 URL·JWT 문맥에 들어가므로 표준 base64 의 `+ / =` 를 쓰면 안 된다.
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
