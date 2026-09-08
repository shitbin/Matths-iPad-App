import AuthenticationServices
import UIKit
import KakaoSDKCommon
import KakaoSDKAuth
import KakaoSDKUser

@MainActor
final class KakaoNativeSignIn {
    private var requestID: UUID?
    private var continuation: CheckedContinuation<String, Error>?
    private static var initialized = false

    static func handle(_ url: URL) -> Bool {
        guard initialized, url.scheme == "kakao54f59f482b5e69baaf8102c6f1433c1f" else { return false }
        guard AuthApi.isKakaoTalkLoginUrl(url) else { return false }
        return AuthController.handleOpenUrl(url: url)
    }

    func token() async throws -> String {
        try Task.checkCancellation()
        if !Self.initialized {
            // Public native platform identifier, not an admin key or secret.
            KakaoSDK.initSDK(appKey: "54f59f482b5e69baaf8102c6f1433c1f")
            Self.initialized = true
        }
        cancel()
        let id = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { waiter in
                guard !Task.isCancelled else {
                    waiter.resume(throwing: CancellationError())
                    return
                }
                requestID = id
                continuation = waiter
                let completion: (OAuthToken?, Error?) -> Void = { [weak self] token, error in
                    Task { @MainActor in
                        guard let self, self.requestID == id, let pending = self.continuation else { return }
                        self.requestID = nil
                        self.continuation = nil
                        if let error {
                            if let sdk = error as? SdkError, sdk.isClientFailed,
                               sdk.getClientError().reason == .Cancelled {
                                pending.resume(throwing: ASWebAuthenticationSessionError(.canceledLogin))
                            } else {
                                pending.resume(throwing: ServerAPIError(
                                    message: "카카오 인증을 완료하지 못했습니다. 다시 시도해 주세요.",
                                    code: "KAKAO_NATIVE_AUTH_FAILED"))
                            }
                        }
                        else if let token { pending.resume(returning: token.accessToken) }
                        else { pending.resume(throwing: ServerAPIError(
                            message: "카카오 인증 결과를 받지 못했습니다.", code: "KAKAO_NATIVE_TOKEN_MISSING")) }
                    }
                }
                if UserApi.isKakaoTalkLoginAvailable() {
                    UserApi.shared.loginWithKakaoTalk(completion: completion)
                } else {
                    UserApi.shared.loginWithKakaoAccount(completion: completion)
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.cancel(id: id) }
        }
    }

    func cancel() { if let id = requestID { cancel(id: id) } }

    private func cancel(id: UUID) {
        guard requestID == id else { return }
        let pending = continuation
        requestID = nil
        continuation = nil
        pending?.resume(throwing: ASWebAuthenticationSessionError(.canceledLogin))
    }
}
