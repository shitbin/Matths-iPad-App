import Foundation

// Typechecking dependencies only. This file is never included in an app target
// and no implementation can make a network request or authenticate a user.
struct AuthResponse {}
struct ServerAPIError: Error { var message: String; var code: String }
enum ServerAPI {
    struct Provider { var key: String; var configured: Bool }
    struct Start { var authorizationUrl: String }
    struct GoogleWithdrawalReauthentication { var proof: String; var codeVerifier: String }
    struct KakaoWithdrawalReauthentication { var proof: String; var codeVerifier: String }
    struct AppleWithdrawalReauthentication { var identityToken: String; var nonce: String }
    static let baseURL = URL(string: "https://example.invalid")!
    static func socialAuthProviders() async throws -> [Provider] { [] }
    static func exchangeSocialAuthCode(_ code: String, codeVerifier: String) async throws -> AuthResponse { throw CancellationError() }
    static func startGoogleWithdrawalReauthentication(codeChallenge: String) async throws -> Start { throw CancellationError() }
    static func startKakaoWithdrawalReauthentication(codeChallenge: String) async throws -> Start { throw CancellationError() }
    static func exchangeAppleIdentity(identityToken: String, authorizationCode: String?, nonce: String, fullName: String?, email: String?) async throws -> AuthResponse { throw CancellationError() }
}
