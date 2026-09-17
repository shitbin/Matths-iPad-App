import AuthenticationServices
import UIKit
import KakaoSDKCommon
import KakaoSDKAuth
import KakaoSDKUser

@MainActor
final class KakaoNativeSignIn {
    private enum Phase {
        case talk
        case account
    }

    private var requestID: UUID?
    private var phase: Phase?
    private var continuation: CheckedContinuation<String, Error>?
    private static var initialized = false

    static func handle(_ url: URL) -> Bool {
        guard initialized, url.scheme == "kakao54f59f482b5e69baaf8102c6f1433c1f" else { return false }
        guard AuthApi.isKakaoTalkLoginUrl(url) else { return false }
        return AuthController.handleOpenUrl(url: url)
    }

    func token(onFallback: ((String) -> Void)? = nil) async throws -> String {
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
                if UserApi.isKakaoTalkLoginAvailable() {
                    phase = .talk
                    requestTalk(id: id, onFallback: onFallback)
                } else {
                    phase = .account
                    requestAccount(id: id, onFallback: onFallback)
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.cancel(id: id) }
        }
    }

    func cancel() { if let id = requestID { cancel(id: id) } }

    private func requestTalk(id: UUID, onFallback: ((String) -> Void)?) {
        UserApi.shared.loginWithKakaoTalk { [weak self] token, error in
            Task { @MainActor in
                self?.receive(
                    token: token,
                    error: error,
                    id: id,
                    callbackPhase: .talk,
                    onFallback: onFallback)
            }
        }
    }

    private func requestAccount(id: UUID, onFallback: ((String) -> Void)?) {
        guard self.requestID == id, phase == .account else { return }
        UserApi.shared.loginWithKakaoAccount { [weak self] token, error in
            Task { @MainActor in
                self?.receive(
                    token: token,
                    error: error,
                    id: id,
                    callbackPhase: .account,
                    onFallback: onFallback)
            }
        }
    }

    private func receive(
        token: OAuthToken?,
        error: Error?,
        id: UUID,
        callbackPhase: Phase,
        onFallback: ((String) -> Void)?
    ) {
        guard requestID == id, phase == callbackPhase,
              continuation != nil else { return }

        if let error {
            if Self.isCancellation(error) {
                finish(
                    .failure(ASWebAuthenticationSessionError(.canceledLogin)),
                    id: id,
                    phase: callbackPhase)
                return
            }

            // Kakao SDK 2.29 retries Universal Link with a custom scheme before
            // reporting NotSupported. If Talk still cannot be opened, use the
            // official Kakao Account browser method once, under the same Matths
            // request owner. Configuration/auth errors are not hidden by a
            // fallback and keep their finite, non-sensitive error code.
            if callbackPhase == .talk, Self.shouldFallbackToAccount(error) {
                phase = .account
                let code = Self.safeCode(error)
                onFallback?(code)
                requestAccount(id: id, onFallback: onFallback)
                return
            }

            finish(
                .failure(ServerAPIError(
                    message: "카카오 인증을 완료하지 못했습니다. 다시 시도해 주세요.",
                    code: Self.safeCode(error))),
                id: id,
                phase: callbackPhase)
            return
        }

        guard let token else {
            finish(
                .failure(ServerAPIError(
                    message: "카카오 인증 결과를 받지 못했습니다.",
                    code: "KAKAO_NATIVE_TOKEN_MISSING")),
                id: id,
                phase: callbackPhase)
            return
        }
        finish(.success(token.accessToken), id: id, phase: callbackPhase)
    }

    private func finish(
        _ result: Result<String, Error>,
        id: UUID,
        phase completedPhase: Phase
    ) {
        guard requestID == id, phase == completedPhase,
              let pending = continuation else { return }
        requestID = nil
        phase = nil
        continuation = nil
        pending.resume(with: result)
    }

    private func cancel(id: UUID) {
        guard requestID == id else { return }
        let pending = continuation
        requestID = nil
        phase = nil
        continuation = nil
        pending?.resume(throwing: ASWebAuthenticationSessionError(.canceledLogin))
    }

    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let web = error as? ASWebAuthenticationSessionError,
           web.code == .canceledLogin { return true }
        guard let sdk = error as? SdkError else { return false }
        if sdk.isClientFailed,
           sdk.getClientError().reason == .Cancelled { return true }
        if sdk.isAuthFailed,
           sdk.getAuthError().reason == .AccessDenied { return true }
        return false
    }

    private static func shouldFallbackToAccount(_ error: Error) -> Bool {
        guard let sdk = error as? SdkError, sdk.isClientFailed else { return false }
        return sdk.getClientError().reason == .NotSupported
    }

    /// Whitelisted diagnostics only. Never return SDK messages, callback URLs,
    /// tokens, account data or arbitrary NSError domains to the app/log layer.
    private static func safeCode(_ error: Error) -> String {
        guard let sdk = error as? SdkError else { return "KAKAO_NATIVE_AUTH_FAILED" }
        if sdk.isClientFailed {
            switch sdk.getClientError().reason {
            case .Unknown: return "KAKAO_NATIVE_AUTH_FAILED"
            case .Cancelled: return "KAKAO_NATIVE_AUTH_FAILED"
            case .TokenNotFound: return "KAKAO_NATIVE_TOKEN_NOT_FOUND"
            case .NotSupported: return "KAKAO_NATIVE_NOT_SUPPORTED"
            case .BadParameter: return "KAKAO_NATIVE_BAD_PARAMETER"
            case .MustInitAppKey: return "KAKAO_NATIVE_NOT_INITIALIZED"
            case .ExceedKakaoLinkSizeLimit: return "KAKAO_NATIVE_AUTH_FAILED"
            case .CastingFailed: return "KAKAO_NATIVE_CASTING_FAILED"
            case .IllegalState: return "KAKAO_NATIVE_ILLEGAL_STATE"
            @unknown default: return "KAKAO_NATIVE_AUTH_FAILED"
            }
        }
        if sdk.isAuthFailed {
            switch sdk.getAuthError().reason {
            case .Unknown: return "KAKAO_NATIVE_AUTH_FAILED"
            case .InvalidRequest: return "KAKAO_NATIVE_INVALID_REQUEST"
            case .InvalidClient: return "KAKAO_NATIVE_INVALID_CLIENT"
            case .InvalidScope: return "KAKAO_NATIVE_INVALID_SCOPE"
            case .InvalidGrant: return "KAKAO_NATIVE_INVALID_GRANT"
            case .Misconfigured: return "KAKAO_NATIVE_MISCONFIGURED"
            case .Unauthorized: return "KAKAO_NATIVE_UNAUTHORIZED"
            case .AccessDenied: return "KAKAO_NATIVE_AUTH_FAILED"
            case .UnauthorizedClient: return "KAKAO_NATIVE_UNAUTHORIZED_CLIENT"
            case .LoginRequired: return "KAKAO_NATIVE_LOGIN_REQUIRED"
            case .ConsentRequired: return "KAKAO_NATIVE_CONSENT_REQUIRED"
            case .InteractionRequired: return "KAKAO_NATIVE_INTERACTION_REQUIRED"
            case .ServerError: return "KAKAO_NATIVE_SERVER_ERROR"
            case .AutoLogin: return "KAKAO_NATIVE_AUTH_FAILED"
            @unknown default: return "KAKAO_NATIVE_AUTH_FAILED"
            }
        }
        return "KAKAO_NATIVE_AUTH_FAILED"
    }
}
