import AuthenticationServices
import CryptoKit
import SwiftUI
import UIKit

@MainActor
final class GoogleSignInCoordinator: NSObject, ObservableObject,
    ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?

    func signIn() async throws -> AuthResponse {
        let providers = try await ServerAPI.socialAuthProviders()
        guard providers.first(where: { $0.key == "google" })?.configured == true else {
            throw ServerAPIError(
                message: "Google 로그인이 아직 설정되지 않았습니다.",
                code: "SOCIAL_AUTH_NOT_CONFIGURED")
        }
        // provider 조회 중 화면을 떠났다면 브라우저 세션을 새로 열지 않는다.
        try Task.checkCancellation()
        let codeVerifier = try Self.makeCodeVerifier()
        let codeChallenge = Self.makeCodeChallenge(codeVerifier)
        // 로그인 전 공개 진입점은 Bearer API router와 분리한다. 운영 서버에서
        // `/api/v1` 미들웨어 순서가 바뀌어 Google 시작 요청이 401로 잠겼던
        // 회귀를 구조적으로 피하고, callback/exchange만 API 계약을 사용한다.
        var startComponents = URLComponents(
            url: ServerAPI.baseURL.appendingPathComponent("/auth/google/app"),
            resolvingAgainstBaseURL: false
        )
        startComponents?.queryItems = [
            URLQueryItem(name: "code_challenge", value: codeChallenge)
        ]
        guard let startURL = startComponents?.url else {
            throw ServerAPIError(
                message: "Google 로그인 주소를 만들지 못했습니다.",
                code: "SOCIAL_AUTH_START_URL_INVALID")
        }
        let callbackURL = try await openAuthenticationSession(startURL: startURL)

        let code = try callbackCode(
            callbackURL,
            expectedPath: "/google",
            missingCodeMessage: "Google 로그인 확인 코드가 없습니다.")
        // 교환은 provider 를 보지 않는다 — 카카오와 같은 주소를 쓴다.
        return try await ServerAPI.exchangeSocialAuthCode(
            code,
            codeVerifier: codeVerifier
        )
    }

    func reauthenticateForAccountDeletion()
    async throws -> ServerAPI.GoogleWithdrawalReauthentication {
        let codeVerifier = try Self.makeCodeVerifier()
        let codeChallenge = Self.makeCodeChallenge(codeVerifier)
        let start = try await ServerAPI.startGoogleWithdrawalReauthentication(
            codeChallenge: codeChallenge)
        guard let startURL = URL(string: start.authorizationUrl),
              startURL.scheme?.lowercased() == ServerAPI.baseURL.scheme?.lowercased(),
              startURL.host?.lowercased() == ServerAPI.baseURL.host?.lowercased() else {
            throw ServerAPIError(
                message: "Google 본인 확인 주소가 올바르지 않습니다.",
                code: "ACCOUNT_REAUTHENTICATION_START_URL_INVALID")
        }
        let callbackURL = try await openAuthenticationSession(startURL: startURL)
        let proof = try callbackCode(
            callbackURL,
            expectedPath: "/google-reauth",
            missingCodeMessage: "Google 본인 확인 코드가 없습니다.")
        return ServerAPI.GoogleWithdrawalReauthentication(
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
                            message: "Google 로그인 결과를 확인하지 못했습니다.",
                            code: "SOCIAL_AUTH_CALLBACK_MISSING"))
                        return
                    }
                    continuation.resume(returning: url)
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.session = session
            guard session.start() else {
                self.session = nil
                continuation.resume(throwing: ServerAPIError(
                    message: "Google 로그인 화면을 열지 못했습니다.",
                    code: "SOCIAL_AUTH_START_FAILED"))
                return
            }
        }
    }

    private func callbackCode(
        _ callbackURL: URL,
        expectedPath: String,
        missingCodeMessage: String
    ) throws -> String {
        guard callbackURL.scheme?.lowercased() == "matths",
              callbackURL.host?.lowercased() == "oauth",
              callbackURL.path == expectedPath else {
            throw ServerAPIError(
                message: "Google 로그인 결과 주소가 올바르지 않습니다.",
                code: "SOCIAL_AUTH_CALLBACK_INVALID")
        }
        let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)
        var values: [String: String] = [:]
        for item in components?.queryItems ?? [] {
            if values[item.name] != nil {
                throw ServerAPIError(
                    message: "Google 로그인 결과가 중복되었습니다. 다시 시도해주세요.",
                    code: "SOCIAL_AUTH_CALLBACK_DUPLICATE")
            }
            values[item.name] = item.value ?? ""
        }
        if let message = values["error"], !message.isEmpty {
            throw ServerAPIError(message: message, code: "SOCIAL_AUTH_CANCELLED")
        }
        guard let code = values["code"], !code.isEmpty else {
            throw ServerAPIError(
                message: missingCodeMessage,
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
            // PKCE verifier를 예측 가능한 값으로 대체할 수는 없다. 그렇다고
            // precondition으로 앱 전체를 종료하면 일시적인 보안 서비스 장애가
            // 데이터 유실처럼 보인다. 로그인 시도만 안전하게 실패시킨다.
            throw ServerAPIError(
                message: "보안 로그인 값을 만들지 못했습니다. 잠시 후 다시 시도해주세요.",
                code: "SOCIAL_AUTH_SECURE_RANDOM_UNAVAILABLE")
        }
        return Data(bytes).base64URLEncodedString()
    }

    private static func makeCodeChallenge(_ verifier: String) -> String {
        Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncodedString()
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
