import Foundation

#if DEBUG || MATTHS_AUTH_DIAGNOSTICS
import AuthenticationServices

/// Diagnostic metadata only. This type and its storage path do not exist in a
/// normal Release build. The public adapter also requires an explicit launch flag.
@MainActor
final class AuthFlowDiagnosticRecorder {
    static let maximumEvents = 60
    static let providers: Set<String> = ["google", "kakao", "apple", "email"]
    static let stages: Set<String> = [
        "begin", "provider_lookup", "browser_started", "credential_requested", "callback_received",
        "exchange_started", "exchange_succeeded", "cancel_requested", "keychain_accepted",
        "slot_switched", "session_published", "sign_in_finished", "slot_switch_rejected", "failed",
    ]
    private static let apiCodes: Set<String> = [
        "UNAUTHORIZED", "TOKEN_REVOKED", "INVALID_CREDENTIALS", "INVALID_LOGIN", "INVALID_EMAIL", "INVALID_PASSWORD",
        "ACCOUNT_INACTIVE", "ACCOUNT_SUSPENDED", "ACCOUNT_WITHDRAWN", "LOGIN_FAILED", "RATE_LIMITED",
        "SOCIAL_AUTH_NOT_CONFIGURED", "SOCIAL_AUTH_START_URL_INVALID", "SOCIAL_AUTH_START_FAILED",
        "SOCIAL_AUTH_CALLBACK_MISSING", "SOCIAL_AUTH_CALLBACK_INVALID", "SOCIAL_AUTH_CALLBACK_DUPLICATE",
        "SOCIAL_AUTH_CANCELLED", "SOCIAL_AUTH_GRANT_MISSING", "SOCIAL_AUTH_GRANT_INVALID", "SOCIAL_AUTH_GRANT_EXPIRED",
        "SOCIAL_AUTH_CODE_INVALID", "SOCIAL_AUTH_EXCHANGE_FAILED", "SOCIAL_AUTH_SECURE_RANDOM_UNAVAILABLE",
        "SOCIAL_AUTH_PKCE_INVALID", "SOCIAL_AUTH_PKCE_MISMATCH", "AUTHENTICATION_SUPERSEDED",
        "AUTH_TOKEN_STORAGE_FAILED", "SOCIAL_AUTH_STATE_INVALID", "SOCIAL_AUTH_ACCOUNT_CONFLICT", "SOCIAL_AUTH_PARENT_ACCOUNT",
        "APPLE_AUTH_IDENTITY_TOKEN_MISSING", "APPLE_AUTH_CREDENTIAL_INVALID", "APPLE_AUTH_AUDIENCE_INVALID",
        "APPLE_AUTH_ISSUER_INVALID", "APPLE_AUTH_NONCE_INVALID", "APPLE_AUTH_NONCE_MISMATCH",
        "APPLE_AUTH_TOKEN_INVALID", "APPLE_AUTH_TOKEN_EXPIRED", "APPLE_AUTH_SIGNATURE_INVALID",
        "APPLE_AUTH_NOT_CONFIGURED", "APPLE_AUTH_KEYS_UNAVAILABLE", "TOKEN_KEYCHAIN_WRITE_FAILED",
        "APPLE_AUTH_ALG_UNSUPPORTED", "APPLE_AUTH_JWKS_UNAVAILABLE", "APPLE_AUTH_KEY_NOT_FOUND",
        "APPLE_AUTH_NICKNAME_UNAVAILABLE", "APPLE_AUTH_NONCE_REQUIRED", "APPLE_AUTH_SUBJECT_MISSING",
        "APPLE_AUTH_TOKEN_MALFORMED", "APPLE_AUTH_TOKEN_NOT_YET_VALID",
    ]
    struct Event: Codable {
        let stage: String
        let elapsedMilliseconds: Int
        var errorDomain: String?
        var errorCode: Int?
        var apiCode: String?
        var httpStatus: Int?
    }
    struct Trace: Encodable {
        let schemaVersion = "AUTH_FLOW_DIAGNOSTICS_V1"
        let provider: String
        let attemptID: UUID
        let startedAt: Date
        var events: [Event]
    }
    private let enabled: Bool
    private let destination: URL
    private let write: (Data, URL) throws -> Void
    private let clock: () -> TimeInterval
    private var startedAtUptime: TimeInterval = 0
    private(set) var trace: Trace?
    var currentAttemptID: UUID? { enabled ? trace?.attemptID : nil }

    init(enabled: Bool, destination: URL, clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         write: @escaping (Data, URL) throws -> Void = { try ProtectedFileWriter.write($0, to: $1) }) {
        self.enabled = enabled; self.destination = destination; self.clock = clock; self.write = write
    }
    func begin(provider: String, attemptID: UUID) {
        guard enabled, Self.providers.contains(provider) else { return }
        startedAtUptime = clock()
        trace = Trace(provider: provider, attemptID: attemptID, startedAt: Date(), events: [])
        record("begin", attemptID: attemptID)
    }
    func record(_ stage: String, attemptID: UUID?) {
        guard accepts(attemptID), Self.stages.contains(stage) else { return }
        append(Event(stage: stage, elapsedMilliseconds: elapsed()))
    }
    func fail(_ error: Error, attemptID: UUID?) {
        guard accepts(attemptID) else { return }
        var event = Event(stage: "failed", elapsedMilliseconds: elapsed())
        if let error = error as? ServerAPIError {
            event.errorDomain = "ServerAPIError"
            if let code = error.code, Self.apiCodes.contains(code) { event.apiCode = code }
            if let status = error.statusCode, (100...599).contains(status) { event.httpStatus = status }
        } else if error is CancellationError {
            event.errorDomain = "Swift.CancellationError"
            event.errorCode = 1
        } else {
            // Never serialize userInfo, descriptions, URLs or arbitrary domains.
            let value = error as NSError
            let allowedDomains: Set<String> = [NSURLErrorDomain, NSCocoaErrorDomain, NSOSStatusErrorDomain,
                ASAuthorizationErrorDomain, ASWebAuthenticationSessionErrorDomain]
            if allowedDomains.contains(value.domain), (-100_000...100_000).contains(value.code) {
                event.errorDomain = value.domain; event.errorCode = value.code
            }
        }
        append(event)
    }
    private func accepts(_ attemptID: UUID?) -> Bool {
        enabled && attemptID != nil && attemptID == trace?.attemptID
    }
    private func elapsed() -> Int {
        let value = (clock() - startedAtUptime) * 1_000
        guard value.isFinite else { return 0 }
        return Int(min(Double(Int32.max), max(0, value)))
    }
    private func append(_ event: Event) {
        guard trace != nil else { return }
        trace?.events.append(event)
        if let count = trace?.events.count, count > Self.maximumEvents { trace?.events.removeFirst(count - Self.maximumEvents) }
        do {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]; encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(trace)
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
            try write(data, destination)
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            var file = destination; try? file.setResourceValues(values)
        } catch {
            // Diagnostics are best effort. Disk-full/protection failures never
            // change authentication state, throw into login, or log raw errors.
        }
    }
}
#endif

@MainActor
enum AuthFlowDiagnostics {
    static var isEnabled: Bool {
        #if DEBUG || MATTHS_AUTH_DIAGNOSTICS
        ProcessInfo.processInfo.arguments.contains("-authDiagnostics")
        #else
        false
        #endif
    }
    #if DEBUG || MATTHS_AUTH_DIAGNOSTICS
    private static let recorder = AuthFlowDiagnosticRecorder(
        enabled: isEnabled,
        destination: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("auth-flow-diagnostics.json"))
    #endif
    static var currentAttemptID: UUID? {
        #if DEBUG || MATTHS_AUTH_DIAGNOSTICS
        recorder.currentAttemptID
        #else
        nil
        #endif
    }
    static func begin(provider: String, attemptID: UUID) {
        #if DEBUG || MATTHS_AUTH_DIAGNOSTICS
        recorder.begin(provider: provider, attemptID: attemptID)
        #endif
    }
    static func record(_ stage: String, attemptID: UUID?) {
        #if DEBUG || MATTHS_AUTH_DIAGNOSTICS
        recorder.record(stage, attemptID: attemptID)
        #endif
    }
    static func fail(_ error: Error, attemptID: UUID?) {
        #if DEBUG || MATTHS_AUTH_DIAGNOSTICS
        recorder.fail(error, attemptID: attemptID)
        #endif
    }
}
