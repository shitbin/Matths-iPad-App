import Foundation

struct OAuthToken { let accessToken: String }
struct ServerAPIError: Error { let message: String; let code: String }
struct ASWebAuthenticationSessionError: Error {
    enum Code { case canceledLogin }
    let code: Code
    init(_ code: Code) { self.code = code }
}

enum ClientFailureReason {
    case Unknown, Cancelled, TokenNotFound, NotSupported, BadParameter
    case MustInitAppKey, ExceedKakaoLinkSizeLimit, CastingFailed, IllegalState
}

enum AuthFailureReason {
    case Unknown, InvalidRequest, InvalidClient, InvalidScope, InvalidGrant
    case Misconfigured, Unauthorized, AccessDenied, UnauthorizedClient
    case LoginRequired, ConsentRequired, InteractionRequired, ServerError, AutoLogin
}

enum SdkError: Error {
    case client(ClientFailureReason)
    case auth(AuthFailureReason)
    case other

    var isClientFailed: Bool {
        if case .client = self { return true }
        return false
    }
    var isAuthFailed: Bool {
        if case .auth = self { return true }
        return false
    }
    func getClientError() -> (reason: ClientFailureReason, message: String?) {
        if case .client(let reason) = self { return (reason, nil) }
        return (.Unknown, nil)
    }
    func getAuthError() -> (reason: AuthFailureReason, info: Int?) {
        if case .auth(let reason) = self { return (reason, nil) }
        return (.Unknown, nil)
    }
}

@MainActor enum KakaoSDK { static func initSDK(appKey: String) {} }
@MainActor enum AuthApi { static func isKakaoTalkLoginUrl(_ url: URL) -> Bool { false } }
@MainActor enum AuthController { static func handleOpenUrl(url: URL) -> Bool { false } }

@MainActor final class UserApi {
    static let shared = UserApi()
    static var available = true
    static var calls: [(OAuthToken?, Error?) -> Void] = []
    static var methods: [String] = []
    static func isKakaoTalkLoginAvailable() -> Bool { available }
    static func reset(available: Bool) {
        self.available = available
        calls = []
        methods = []
    }
    func loginWithKakaoTalk(completion: @escaping (OAuthToken?, Error?) -> Void) {
        Self.methods.append("talk")
        Self.calls.append(completion)
    }
    func loginWithKakaoAccount(completion: @escaping (OAuthToken?, Error?) -> Void) {
        Self.methods.append("account")
        Self.calls.append(completion)
    }
}

@main enum KakaoNativeCancellationCases {
    @MainActor static func waitFor(_ count: Int) async {
        for _ in 0..<1_000 {
            if UserApi.calls.count >= count { return }
            await Task.yield()
        }
        preconditionFailure("SDK callback not registered")
    }

    @MainActor static func expectCancellation(_ task: Task<String, Error>) async {
        do {
            _ = try await task.value
            preconditionFailure("cancellation ignored")
        } catch is ASWebAuthenticationSessionError {
            return
        } catch {
            preconditionFailure("wrong cancellation error: \(type(of: error))")
        }
    }

    @MainActor static func expectServerCode(
        _ expected: String,
        _ task: Task<String, Error>
    ) async {
        do {
            _ = try await task.value
            preconditionFailure("expected failure returned success")
        } catch let error as ServerAPIError {
            precondition(error.code == expected, "unexpected safe error code \(error.code)")
        } catch {
            preconditionFailure("wrong failure type: \(type(of: error))")
        }
    }

    @MainActor static func main() async throws {
        // Retiring an old request must make all of its later callbacks inert.
        UserApi.reset(available: true)
        let login = KakaoNativeSignIn()
        let first = Task { try await login.token() }
        await waitFor(1)
        let stale = UserApi.calls[0]
        login.cancel()
        await expectCancellation(first)

        UserApi.available = false
        let second = Task { try await login.token() }
        await waitFor(2)
        stale(OAuthToken(accessToken: "old"), nil)
        UserApi.calls[1](OAuthToken(accessToken: "current"), nil)
        let secondValue = try await second.value
        precondition(secondValue == "current")
        precondition(UserApi.methods == ["talk", "account"])
        UserApi.calls[1](OAuthToken(accessToken: "duplicate"), nil)

        // The concrete field failure: KakaoTalk cannot be opened after the SDK's
        // own Universal Link -> custom-scheme retry. Fall back exactly once to
        // the official Kakao Account method under the same request owner.
        UserApi.reset(available: true)
        var fallbackCodes: [String] = []
        let fallback = Task {
            try await login.token { fallbackCodes.append($0) }
        }
        await waitFor(1)
        let talk = UserApi.calls[0]
        talk(nil, SdkError.client(.NotSupported))
        await waitFor(2)
        precondition(UserApi.methods == ["talk", "account"])
        precondition(fallbackCodes == ["KAKAO_NATIVE_NOT_SUPPORTED"])
        talk(OAuthToken(accessToken: "late-talk"), nil)
        talk(nil, SdkError.client(.NotSupported))
        precondition(UserApi.methods == ["talk", "account"],
                     "late or duplicate Talk callback started another fallback")
        UserApi.calls[1](OAuthToken(accessToken: "account-token"), nil)
        let fallbackValue = try await fallback.value
        precondition(fallbackValue == "account-token")
        UserApi.calls[1](OAuthToken(accessToken: "duplicate-account"), nil)
        precondition(fallbackCodes.count == 1)

        // User cancellation must never open another login surface.
        for cancellation in [
            SdkError.client(.Cancelled),
            SdkError.auth(.AccessDenied),
        ] {
            UserApi.reset(available: true)
            var codes: [String] = []
            let cancelled = Task { try await login.token { codes.append($0) } }
            await waitFor(1)
            UserApi.calls[0](nil, cancellation)
            await expectCancellation(cancelled)
            precondition(UserApi.methods == ["talk"] && codes.isEmpty)
        }

        // Configuration failures are not disguised by an account fallback.
        UserApi.reset(available: true)
        let invalidClient = Task { try await login.token() }
        await waitFor(1)
        UserApi.calls[0](nil, SdkError.auth(.InvalidClient))
        await expectServerCode("KAKAO_NATIVE_INVALID_CLIENT", invalidClient)
        precondition(UserApi.methods == ["talk"])

        // Cancellation during account fallback retires both phase callbacks;
        // a new request can then complete without the old account result winning.
        UserApi.reset(available: true)
        let cancelledFallback = Task { try await login.token() }
        await waitFor(1)
        let oldTalk = UserApi.calls[0]
        oldTalk(nil, SdkError.client(.NotSupported))
        await waitFor(2)
        let oldAccount = UserApi.calls[1]
        cancelledFallback.cancel()
        await expectCancellation(cancelledFallback)
        oldTalk(OAuthToken(accessToken: "late-talk-after-cancel"), nil)
        oldAccount(OAuthToken(accessToken: "late-account-after-cancel"), nil)
        precondition(UserApi.calls.count == 2)

        UserApi.available = false
        let afterCancellation = Task { try await login.token() }
        await waitFor(3)
        UserApi.calls[2](OAuthToken(accessToken: "new-account"), nil)
        let afterCancellationValue = try await afterCancellation.value
        precondition(afterCancellationValue == "new-account")

        // Direct account login has no fallback event, and final SDK errors expose
        // only finite allowlisted codes rather than provider messages or URLs.
        UserApi.reset(available: false)
        var directCodes: [String] = []
        let directFailure = Task { try await login.token { directCodes.append($0) } }
        await waitFor(1)
        UserApi.calls[0](nil, SdkError.auth(.Misconfigured))
        await expectServerCode("KAKAO_NATIVE_MISCONFIGURED", directFailure)
        precondition(UserApi.methods == ["account"] && directCodes.isEmpty)

        UserApi.reset(available: false)
        let missing = Task { try await login.token() }
        await waitFor(1)
        UserApi.calls[0](nil, nil)
        await expectServerCode("KAKAO_NATIVE_TOKEN_MISSING", missing)

        // Native presentation disappearances must preserve both Talk and direct
        // account callbacks; explicit cancellation remains the only teardown.
        for available in [true, false] {
            UserApi.reset(available: available)
            let presented = Task { try await login.token() }
            await waitFor(1)
            for _ in 0..<3 {
                if NativeAuthenticationPresentationPolicy.shouldCancelOnAuthScreenDisappear(
                    isBusy: true,
                    sessionPublished: false
                ) {
                    presented.cancel()
                    login.cancel()
                }
                await Task.yield()
            }
            UserApi.calls[0](OAuthToken(accessToken: "presentation-fixture"), nil)
            let presentedValue = try await presented.value
            precondition(presentedValue == "presentation-fixture")
            precondition(!presented.isCancelled)
        }

        print("PASS Kakao native request owner: NotSupported account fallback once, cancellation, phase isolation, finite safe errors, direct account and presentation callbacks")
    }
}
