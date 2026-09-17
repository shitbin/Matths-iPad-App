import Foundation
import CryptoKit
import Security

enum NativeSocialSignInResult {
    case authenticated(AuthResponse)
    case registration(NativeSocialRegistrationContext)
}

struct NativeSocialRegistrationProfile {
    let realName: String
    let name: String
    let birthDate: String
    let schoolGrade: Int
    var schoolRegion: String? = nil
    var schoolCode: String? = nil
    var schoolName: String? = nil
    var universityCode: String? = nil
    var universityName: String? = nil
    let termsAccepted: Bool
    let privacyAccepted: Bool
}

/// Short-lived proof is held only by the currently presented native form.
/// Never serialize this context, put it in UserDefaults, or log it.
struct NativeSocialRegistrationContext: Identifiable {
    let id = UUID()
    let registration: ServerAPI.NativeSocialRegistrationInfo
    let codeVerifier: String
    var diagnosticAttemptID: UUID? = nil

    var expirationDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: registration.expiresAt) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: registration.expiresAt)
    }
    var isExpired: Bool { expirationDate.map { $0 <= Date() } ?? true }

    @MainActor
    func submit(profile: NativeSocialRegistrationProfile) async throws -> AuthResponse {
        try Task.checkCancellation()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-nativeRegistrationCapture") {
            throw ServerAPIError(message: "화면 검수 모드에서는 가입 정보를 전송하지 않습니다.",
                                 code: "NATIVE_SOCIAL_CAPTURE_ONLY")
        }
        #endif
        guard !isExpired else {
            throw ServerAPIError(message: "인증 시간이 지났습니다. 다시 로그인해 주세요.",
                                 code: "NATIVE_SOCIAL_REGISTRATION_EXPIRED")
        }
        let attemptID = diagnosticAttemptID
        AuthFlowDiagnostics.record("registration_submitted", attemptID: attemptID)
        let code = try await ServerAPI.completeNativeSocialRegistration(
            registration: registration, codeVerifier: codeVerifier, profile: profile)
        try Task.checkCancellation()
        let auth = try await ServerAPI.exchangeSocialAuthCode(code, codeVerifier: codeVerifier)
        try Task.checkCancellation()
        AuthFlowDiagnostics.record("exchange_succeeded", attemptID: attemptID)
        return auth
    }

    @MainActor
    static func resolve(_ response: ServerAPI.NativeSocialStartResponse,
                        provider: String, codeVerifier: String,
                        diagnosticAttemptID: UUID? = nil) async throws -> NativeSocialSignInResult {
        try Task.checkCancellation()
        switch response.status {
        case "authenticated":
            guard let code = response.code, !code.isEmpty, response.registration == nil else {
                throw invalidResponse()
            }
            let auth = try await ServerAPI.exchangeSocialAuthCode(code, codeVerifier: codeVerifier)
            try Task.checkCancellation()
            AuthFlowDiagnostics.record("exchange_succeeded", attemptID: diagnosticAttemptID)
            return .authenticated(auth)
        case "registration_required":
            guard response.code == nil, let registration = response.registration,
                  registration.provider == provider, ["apple", "kakao"].contains(provider),
                  !registration.token.isEmpty, !registration.termsVersion.isEmpty,
                  !registration.privacyVersion.isEmpty else { throw invalidResponse() }
            let context = Self(registration: registration, codeVerifier: codeVerifier, diagnosticAttemptID: diagnosticAttemptID)
            guard !context.isExpired else {
                throw ServerAPIError(message: "인증 시간이 지났습니다. 다시 로그인해 주세요.",
                                     code: "NATIVE_SOCIAL_REGISTRATION_EXPIRED")
            }
            AuthFlowDiagnostics.record("registration_required", attemptID: diagnosticAttemptID)
            return .registration(context)
        default:
            throw invalidResponse()
        }
    }

    private static func invalidResponse() -> ServerAPIError {
        ServerAPIError(message: "로그인 결과를 확인하지 못했습니다. 다시 시도해 주세요.",
                       code: "NATIVE_SOCIAL_RESPONSE_INVALID")
    }
}

enum NativeSocialPKCE {
    static func makeVerifier() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw ServerAPIError(message: "보안 로그인 값을 만들지 못했습니다. 다시 시도해 주세요.",
                                 code: "SOCIAL_AUTH_SECURE_RANDOM_UNAVAILABLE")
        }
        return encode(Data(bytes))
    }
    static func challenge(_ verifier: String) -> String {
        encode(Data(SHA256.hash(data: Data(verifier.utf8))))
    }
    private static func encode(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
}
