import Foundation
struct OAuthToken { let accessToken: String }
struct ServerAPIError: Error { let message: String; let code: String }
struct ASWebAuthenticationSessionError: Error {
    enum Code { case canceledLogin }
    let code: Code
    init(_ code: Code) { self.code = code }
}
enum SdkError: Error {
    case cancelled
    enum Reason { case Cancelled }
    var isClientFailed: Bool { true }
    func getClientError() -> (reason: Reason, message: String?) { (.Cancelled, nil) }
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
    func loginWithKakaoTalk(completion: @escaping (OAuthToken?, Error?) -> Void) {
        Self.methods.append("talk"); Self.calls.append(completion)
    }
    func loginWithKakaoAccount(completion: @escaping (OAuthToken?, Error?) -> Void) {
        Self.methods.append("account"); Self.calls.append(completion)
    }
}
@main enum KakaoNativeCancellationCases {
    @MainActor static func waitFor(_ count: Int) async {
        for _ in 0..<1000 {
            if UserApi.calls.count >= count { return }
            await Task.yield()
        }
        preconditionFailure("SDK callback not registered")
    }
    @MainActor static func main() async throws {
        let login = KakaoNativeSignIn()
        let first = Task { try await login.token() }
        await waitFor(1)
        let stale = UserApi.calls[0]
        login.cancel()
        do { _ = try await first.value; preconditionFailure("cancel ignored") }
        catch is ASWebAuthenticationSessionError {}
        UserApi.available = false
        let second = Task { try await login.token() }
        await waitFor(2)
        stale(OAuthToken(accessToken: "old"), nil)
        UserApi.calls[1](OAuthToken(accessToken: "current"), nil)
        let value = try await second.value
        precondition(value == "current")
        precondition(UserApi.methods == ["talk", "account"])
        UserApi.calls[1](OAuthToken(accessToken: "duplicate"), nil)
        let third = Task { try await login.token() }
        await waitFor(3)
        UserApi.calls[2](nil, SdkError.cancelled)
        do { _ = try await third.value; preconditionFailure("user cancel ignored") }
        catch is ASWebAuthenticationSessionError {}
        let fourth = Task { try await login.token() }
        await waitFor(4)
        fourth.cancel()
        do { _ = try await fourth.value; preconditionFailure("Task cancel ignored") }
        catch is ASWebAuthenticationSessionError {}
        print("PASS actual Kakao native coordinator: app/account selection, cancellation, late/duplicate callback isolation")
    }
}
