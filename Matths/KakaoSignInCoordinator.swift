//  KakaoSignInCoordinator.swift
//  Matths
//
//  카카오 로그인 — 공식 SDK 앱 전환 + 서버 검증·PKCE 교환.
//
//  네이티브 경로를 지원하는 서버에서는 카카오톡 인증을 먼저 사용한다.
//  SDK 토큰만으로 Matths에 로그인하지 않고 서버가 발급 앱·사용자를 검증한다.
//  본인 인증 뒤 가입 정보 입력은 SwiftUI에서 끝낸다. 카카오 공식 계정
//  인증창과 Matths 웹 가입 페이지는 별개이며, 후자는 절대로 열지 않는다.
//  아래 ASWebAuthenticationSession은 기존 탈퇴 재인증 전용이다.
//
//  GoogleSignInCoordinator의 정상 웹 인증 경로는 변경하지 않는다.

import AuthenticationServices
import CryptoKit
import SwiftUI
import UIKit

@MainActor
final class KakaoSignInCoordinator: NSObject, ObservableObject,
    ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?
    private var sessionRequestID: UUID?
    private var sessionContinuation: CheckedContinuation<URL, Error>?
    private var sessionDiagnosticAttemptID: UUID?
    #if canImport(KakaoSDKUser)
    private let nativeSignIn = KakaoNativeSignIn()
    #endif

    func signIn() async throws -> NativeSocialSignInResult {
        try Task.checkCancellation()
        let diagnosticAttemptID = AuthFlowDiagnostics.currentAttemptID
        AuthFlowDiagnostics.record("provider_lookup", attemptID: diagnosticAttemptID)
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
        #if canImport(KakaoSDKUser)
        guard providers.first(where: { $0.key == "kakao" })?.nativeConfigured == true else {
            throw ServerAPIError(message: "카카오 로그인 연결을 준비하고 있습니다. 잠시 후 다시 시도해 주세요.",
                                 code: "SOCIAL_AUTH_NOT_CONFIGURED")
        }
        AuthFlowDiagnostics.record("credential_requested", attemptID: diagnosticAttemptID)
        let token = try await nativeSignIn.token(onFallback: { code in
            AuthFlowDiagnostics.record("native_fallback", attemptID: diagnosticAttemptID, apiCode: code)
        })
        try Task.checkCancellation()
        AuthFlowDiagnostics.record("callback_received", attemptID: diagnosticAttemptID)
        AuthFlowDiagnostics.record("exchange_started", attemptID: diagnosticAttemptID)
        let response = try await ServerAPI.startNativeKakaoAuthentication(accessToken: token, codeChallenge: codeChallenge)
        return try await NativeSocialRegistrationContext.resolve(response, provider: "kakao", codeVerifier: codeVerifier,
                                                                 diagnosticAttemptID: diagnosticAttemptID)
        #else
        throw ServerAPIError(message: "카카오 로그인 기능을 불러오지 못했습니다. 앱을 업데이트해 주세요.",
                             code: "SOCIAL_AUTH_NOT_CONFIGURED")
        #endif
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
        try Task.checkCancellation()
        let proof = try callbackCode(callbackURL, expectedPath: "/kakao-reauth")
        return ServerAPI.KakaoWithdrawalReauthentication(
            proof: proof,
            codeVerifier: codeVerifier)
    }

    private func openAuthenticationSession(startURL: URL, diagnosticAttemptID: UUID? = nil) async throws -> URL {
        try Task.checkCancellation()
        cancel()
        let requestID = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard !Task.isCancelled else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                self.sessionRequestID = requestID
                self.sessionContinuation = continuation
                self.sessionDiagnosticAttemptID = diagnosticAttemptID
                let session = ASWebAuthenticationSession(
                    url: startURL,
                    callbackURLScheme: "matths"
                ) { [weak self] url, error in
                    Task { @MainActor in
                        if let error { self?.finishSession(requestID, result: .failure(error)); return }
                        guard let url else {
                            self?.finishSession(requestID, result: .failure(ServerAPIError(
                                message: "카카오 로그인 결과를 확인하지 못했습니다.",
                                code: "SOCIAL_AUTH_CALLBACK_MISSING")))
                            return
                        }
                        self?.finishSession(requestID, result: .success(url))
                    }
                }
                session.presentationContextProvider = self
                session.prefersEphemeralWebBrowserSession = false
                self.session = session
                guard session.start() else {
                    finishSession(requestID, result: .failure(ServerAPIError(
                        message: "카카오 로그인 화면을 열지 못했습니다.",
                        code: "SOCIAL_AUTH_START_FAILED")))
                    return
                }
                AuthFlowDiagnostics.record("browser_started", attemptID: diagnosticAttemptID)
            }
        } onCancel: { [weak self] in
            Task { @MainActor in self?.cancelSession(requestID) }
        }
    }

    private func finishSession(_ requestID: UUID, result: Result<URL, Error>) {
        guard sessionRequestID == requestID, let continuation = sessionContinuation else { return }
        if case .success = result { AuthFlowDiagnostics.record("callback_received", attemptID: sessionDiagnosticAttemptID) }
        sessionDiagnosticAttemptID = nil
        sessionRequestID = nil
        sessionContinuation = nil
        session = nil
        continuation.resume(with: result)
    }

    private func cancelSession(_ requestID: UUID) {
        guard sessionRequestID == requestID else { return }
        let previousSession = session
        let continuation = sessionContinuation
        // Retire ownership before cancel(), whose callback may arrive later or
        // immediately. A late callback can never release the next session.
        sessionRequestID = nil
        sessionContinuation = nil
        session = nil
        previousSession?.cancel()
        sessionDiagnosticAttemptID = nil
        // Programmatic cancel must finish our waiter even if the system does
        // not call its completion handler. User-cancel errors stay quiet in UI.
        continuation?.resume(throwing: ASWebAuthenticationSessionError(.canceledLogin))
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
        #if canImport(KakaoSDKUser)
        nativeSignIn.cancel()
        #endif
        guard let requestID = sessionRequestID else { return }
        cancelSession(requestID)
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
