import Foundation

// Synthetic values only. The actual DTOs/body builders and context are compiled
// alongside these stubs; there is no URLSession, keychain, or external account.
struct AuthResponse: Codable { let token: String; let userID: String }
struct ServerAPIError: Error {
    let message: String
    let code: String?
    var statusCode: Int? = nil
    var errorDescription: String { message }
}
@MainActor enum NativeRegistrationLifecycleGate {
    static var continuation: CheckedContinuation<Void, Never>?
    static func pause() async { await withCheckedContinuation { continuation = $0 } }
    static func release() { let pending = continuation; continuation = nil; pending?.resume() }
}
@MainActor enum AuthFlowDiagnostics {
    static var events: [(stage: String, attemptID: UUID?)] = []
    static func record(_ stage: String, attemptID: UUID?) { events.append((stage, attemptID)) }
}
@MainActor enum NativeSocialTransport {
    struct Request { let method: String; let path: String; let body: [String: Any]; let authed: Bool }
    struct Reply { let path: String; let result: Result<Data, Error>; let hold: Bool }
    static var replies: [Reply] = []
    static var requests: [Request] = []
    static var continuation: CheckedContinuation<Data, Error>?
    static var pendingResult: Result<Data, Error>?
    static func reset() {
        precondition(continuation == nil, "Controlled request must be released before reset")
        replies = []; requests = []; pendingResult = nil; AuthFlowDiagnostics.events = []
    }
    static func json(_ path: String, _ object: [String: Any], hold: Bool = false) {
        replies.append(.init(path: path, result: .success(try! JSONSerialization.data(withJSONObject: object)), hold: hold))
    }
    static func failure(_ path: String, code: String = "SYNTHETIC_HTTP_FAILURE", status: Int = 503, hold: Bool = false) {
        replies.append(.init(path: path, result: .failure(ServerAPIError(message: "Synthetic failure", code: code, statusCode: status)), hold: hold))
    }
    static func request(_ method: String, _ path: String, body: [String: Any]?, authed: Bool) async throws -> Data {
        precondition(!replies.isEmpty, "Unexpected extra HTTP operation")
        let reply = replies.removeFirst()
        precondition(reply.path == path && method == "POST", "Unexpected route/method")
        // Assert the real body can be serialized without Optional wrappers.
        if let body { _ = try JSONSerialization.data(withJSONObject: body) }
        requests.append(.init(method: method, path: path, body: body ?? [:], authed: authed))
        if reply.hold {
            pendingResult = reply.result
            return try await withCheckedThrowingContinuation { continuation = $0 }
        }
        return try reply.result.get()
    }
    static func release() {
        guard let waiter = continuation, let result = pendingResult else { preconditionFailure("No pending request") }
        continuation = nil; pendingResult = nil; waiter.resume(with: result)
    }
}

@main enum NativeSocialRegistrationContextCases {
    static let register = "/api/v1/auth/native-social/register"
    static let exchange = "/api/v1/auth/social/exchange"
    static let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
    @MainActor static var checks = 0
    @MainActor static var scenarios = 0
    @MainActor static func check(_ condition: @autoclosure () -> Bool, _ label: String) {
        guard condition() else { print("FAIL: " + label); exit(1) }
        checks += 1
    }
    @MainActor static func until(_ condition: () -> Bool) async {
        for _ in 0..<20_000 { if condition() { return }; await Task.yield() }
        print("FAIL: controlled transport suspension not reached"); exit(1)
    }
    static func info(provider: String = "kakao", expiresAt: String? = nil,
                     token: String = "synthetic-registration-proof", terms: String = "terms-v1", privacy: String = "privacy-v1") -> ServerAPI.NativeSocialRegistrationInfo {
        .init(token: token, provider: provider,
              expiresAt: expiresAt ?? ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600)),
              email: "fixture@example.invalid", suggestedRealName: nil, termsVersion: terms, privacyVersion: privacy)
    }
    static func profile(grade: Int = 10, region: String? = "서울", school: String? = "SYNTHETIC_SCHOOL",
                        schoolName: String? = nil, university: String? = nil, universityName: String? = nil,
                        terms: Bool = true, privacy: Bool = true) -> NativeSocialRegistrationProfile {
        .init(realName: "테스트 사용자", name: "fixture-student", birthDate: "2006-01-02", schoolGrade: grade,
              schoolRegion: region, schoolCode: school, schoolName: schoolName,
              universityCode: university, universityName: universityName, termsAccepted: terms, privacyAccepted: privacy)
    }
    @MainActor static func expectCode(_ code: String, _ body: () async throws -> Void) async {
        do { try await body(); check(false, "Expected error " + code) }
        catch let error as ServerAPIError { check(error.code == code, "Expected finite error code " + code) }
        catch { check(false, "Unexpected error kind for " + code) }
    }
    @MainActor static func expectCancellation<T>(_ task: Task<T, Error>) async {
        do { _ = try await task.value; check(false, "Cancelled operation returned a successful value") }
        catch is CancellationError { check(true, "Cancellation propagated") }
        catch { check(false, "Cancellation returned another error") }
    }
    @MainActor static func grantReply(hold: Bool = false) {
        NativeSocialTransport.json(exchange, ["token": "synthetic-matths-token", "userID": "synthetic-user"], hold: hold)
    }
    @MainActor static func main() async throws {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-nativeRegistrationCapture") {
            NativeSocialTransport.reset()
            let context = NativeSocialRegistrationContext(registration: info(), codeVerifier: verifier)
            await expectCode("NATIVE_SOCIAL_CAPTURE_ONLY") { _ = try await context.submit(profile: profile()) }
            check(NativeSocialTransport.requests.isEmpty, "Capture mode sends no registration or exchange")
            print("Native social registration capture guard: \(checks) checks PASS (no network).")
            return
        }
        #endif

        // A valid proof is not an authenticated session. Only a completed native
        // profile can produce the one-time grant consumed by the exchange API.
        for provider in ["apple", "kakao"] {
            NativeSocialTransport.reset(); let attempt = UUID()
            let start = ServerAPI.NativeSocialStartResponse(status: "registration_required", code: nil, registration: info(provider: provider))
            let result = try await NativeSocialRegistrationContext.resolve(start, provider: provider, codeVerifier: verifier, diagnosticAttemptID: attempt)
            guard case .registration(let context) = result else { preconditionFailure("Profile required before authentication") }
            check(NativeSocialTransport.requests.isEmpty, "Registration-required response must not exchange a grant")
            check(context.registration.provider == provider && context.codeVerifier == verifier, "Context retains provider and PKCE owner")
            check(context.diagnosticAttemptID == attempt, "Context diagnostics keep original attempt")
            check(AuthFlowDiagnostics.events.map(\.stage) == ["registration_required"], "No authenticated stage before profile")
            NativeSocialTransport.json(register, ["code": "synthetic-one-time-grant"]); grantReply()
            let auth = try await context.submit(profile: profile())
            check(auth.userID == "synthetic-user", "Final auth response returned only after grant exchange")
            check(NativeSocialTransport.requests.map(\.path) == [register, exchange], "Profile completion precedes grant exchange")
            check(NativeSocialTransport.requests.allSatisfy { !$0.authed }, "Pre-session requests do not attach previous account bearer")
            let body = NativeSocialTransport.requests[0].body
            check(body["registrationToken"] as? String == context.registration.token && body["codeVerifier"] as? String == verifier, "Profile uses exact proof and verifier")
            check(body["termsAccepted"] as? Bool == true && body["privacyAccepted"] as? Bool == true, "Both explicit consent booleans are transmitted")
            check(body["termsVersion"] as? String == "terms-v1" && body["privacyVersion"] as? String == "privacy-v1", "Consent versions come from the server proof")
            check(body["realName"] as? String == "테스트 사용자" && body["name"] as? String == "fixture-student" && body["birthDate"] as? String == "2006-01-02", "Real profile fields are transmitted")
            check(body["schoolRegion"] as? String == "서울" && body["schoolCode"] as? String == "SYNTHETIC_SCHOOL", "High school choice is transmitted")
            let exchangeBody = NativeSocialTransport.requests[1].body
            check(exchangeBody["code"] as? String == "synthetic-one-time-grant" && exchangeBody["codeVerifier"] as? String == verifier, "Exchange consumes exact registration grant with original verifier")
            check(AuthFlowDiagnostics.events.last?.stage == "exchange_succeeded" && AuthFlowDiagnostics.events.allSatisfy { $0.attemptID == attempt }, "Success diagnostics stay on the same attempt")
            scenarios += 1
        }
        do {
            NativeSocialTransport.reset(); grantReply()
            let result = try await NativeSocialRegistrationContext.resolve(.init(status: "authenticated", code: "existing-account-grant", registration: nil), provider: "kakao", codeVerifier: verifier)
            guard case .authenticated(let auth) = result else { preconditionFailure("Existing user must exchange grant") }
            check(auth.userID == "synthetic-user" && NativeSocialTransport.requests.count == 1, "Existing account follows the shared exchange only")
            check(NativeSocialTransport.requests[0].body["codeVerifier"] as? String == verifier, "Existing account exchange retains PKCE")
            scenarios += 1
        }
        let invalid: [(ServerAPI.NativeSocialStartResponse, String)] = [
            (.init(status: "unknown", code: nil, registration: nil), "kakao"),
            (.init(status: "authenticated", code: nil, registration: nil), "kakao"),
            (.init(status: "authenticated", code: "", registration: nil), "kakao"),
            (.init(status: "authenticated", code: "grant", registration: info()), "kakao"),
            (.init(status: "registration_required", code: "grant", registration: info()), "kakao"),
            (.init(status: "registration_required", code: nil, registration: nil), "kakao"),
            (.init(status: "registration_required", code: nil, registration: info(provider: "apple")), "kakao"),
            (.init(status: "registration_required", code: nil, registration: info(provider: "google")), "google"),
            (.init(status: "registration_required", code: nil, registration: info(token: "")), "kakao"),
            (.init(status: "registration_required", code: nil, registration: info(terms: "")), "kakao"),
            (.init(status: "registration_required", code: nil, registration: info(privacy: "")), "kakao"),
        ]
        for (response, provider) in invalid {
            NativeSocialTransport.reset()
            await expectCode("NATIVE_SOCIAL_RESPONSE_INVALID") { _ = try await NativeSocialRegistrationContext.resolve(response, provider: provider, codeVerifier: verifier) }
            check(NativeSocialTransport.requests.isEmpty, "Invalid/mismatched start response cannot exchange or register")
            scenarios += 1
        }
        for expiry in ["2000-01-01T00:00:00Z", "not-a-date", ""] {
            NativeSocialTransport.reset(); let registration = info(expiresAt: expiry)
            await expectCode("NATIVE_SOCIAL_REGISTRATION_EXPIRED") {
                _ = try await NativeSocialRegistrationContext.resolve(.init(status: "registration_required", code: nil, registration: registration), provider: "kakao", codeVerifier: verifier)
            }
            let context = NativeSocialRegistrationContext(registration: registration, codeVerifier: verifier)
            await expectCode("NATIVE_SOCIAL_REGISTRATION_EXPIRED") { _ = try await context.submit(profile: profile()) }
            check(NativeSocialTransport.requests.isEmpty, "Expired or unparseable proof fails before transport")
            scenarios += 1
        }
        do {
            let format = ISO8601DateFormatter(); format.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let context = NativeSocialRegistrationContext(registration: info(expiresAt: format.string(from: Date().addingTimeInterval(3600))), codeVerifier: verifier)
            check(!context.isExpired, "Fractional ISO server expiry is supported")
            let simple = NativeSocialRegistrationContext(registration: info(), codeVerifier: verifier)
            check(!simple.isExpired && simple.id != context.id, "Plain ISO expiry and presentation IDs are supported")
            scenarios += 1
        }
        do {
            // RFC 7636 Appendix B's fixed S256 test vector, plus real Security entropy.
            check(NativeSocialPKCE.challenge(verifier) == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM", "PKCE S256 challenge matches fixed RFC vector")
            var generated: Set<String> = []
            for _ in 0..<32 {
                let value = try NativeSocialPKCE.makeVerifier()
                check(value.utf8.count == 43 && value.utf8.allSatisfy { (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 45 || $0 == 95 }, "Secure verifier is unpadded base64url of 32 bytes")
                generated.insert(value)
            }
            check(generated.count == 32, "Independent PKCE attempts have independent verifier values")
            scenarios += 1
        }
        for selection in [
            profile(grade: 10, school: "OVERSEAS_HIGH_SCHOOL", schoolName: "Synthetic overseas school"),
            profile(grade: 14, university: "SYNTHETIC_UNIVERSITY"),
            profile(grade: 14, university: "OVERSEAS_UNIVERSITY", universityName: "Synthetic overseas university"),
            profile(grade: 13), profile(grade: 15),
        ] {
            NativeSocialTransport.reset(); NativeSocialTransport.json(register, ["code": "grant"]); grantReply()
            let context = NativeSocialRegistrationContext(registration: info(), codeVerifier: verifier)
            _ = try await context.submit(profile: selection)
            let body = NativeSocialTransport.requests[0].body
            check(body["schoolGrade"] as? Int == selection.schoolGrade, "Student category stays exact")
            if selection.schoolGrade == 10 {
                check(body["overseasSchoolName"] as? String == selection.schoolName && body["universityCode"] == nil, "Overseas high school uses the canonical field only")
            } else if selection.schoolGrade == 14 {
                check(body["universityCode"] as? String == selection.universityCode && body["schoolRegion"] == nil && body["schoolCode"] == nil, "University choice excludes stale high-school fields")
                check(body["overseasUniversityName"] as? String == (selection.universityCode == "OVERSEAS_UNIVERSITY" ? selection.universityName : nil), "Only overseas university sends its custom name")
            } else {
                check(body["schoolCode"] == nil && body["universityCode"] == nil, "Retaker/worker category excludes stale institution fields")
            }
            scenarios += 1
        }
        do {
            NativeSocialTransport.reset(); NativeSocialTransport.failure(register, code: "CONSENT_REQUIRED", status: 400)
            let context = NativeSocialRegistrationContext(registration: info(), codeVerifier: verifier)
            await expectCode("CONSENT_REQUIRED") { _ = try await context.submit(profile: profile(terms: false, privacy: false)) }
            check(NativeSocialTransport.requests[0].body["termsAccepted"] as? Bool == false && NativeSocialTransport.requests[0].body["privacyAccepted"] as? Bool == false, "Consent is never silently fabricated by the API body builder")
            check(NativeSocialTransport.requests.count == 1 && !AuthFlowDiagnostics.events.contains { $0.stage == "exchange_succeeded" }, "HTTP consent rejection cannot fake authentication")
            scenarios += 1
        }
        for failedPath in [register, exchange] {
            NativeSocialTransport.reset()
            if failedPath == exchange { NativeSocialTransport.json(register, ["code": "grant"]) }
            NativeSocialTransport.failure(failedPath)
            let context = NativeSocialRegistrationContext(registration: info(), codeVerifier: verifier)
            await expectCode("SYNTHETIC_HTTP_FAILURE") { _ = try await context.submit(profile: profile()) }
            check(!AuthFlowDiagnostics.events.contains { $0.stage == "exchange_succeeded" }, "HTTP failure does not publish success diagnostics")
            scenarios += 1
        }
        do {
            NativeSocialTransport.reset(); NativeSocialTransport.json(register, ["code": ""])
            let context = NativeSocialRegistrationContext(registration: info(), codeVerifier: verifier)
            await expectCode("SOCIAL_AUTH_GRANT_MISSING") { _ = try await context.submit(profile: profile()) }
            check(NativeSocialTransport.requests.count == 1, "Empty registration grant is not exchanged")
            scenarios += 1
        }
        for malformed in [[String: Any](), ["code": 7]] {
            NativeSocialTransport.reset(); NativeSocialTransport.json(register, malformed)
            let context = NativeSocialRegistrationContext(registration: info(), codeVerifier: verifier)
            do { _ = try await context.submit(profile: profile()); check(false, "Malformed grant decoded as success") }
            catch is DecodingError { check(true, "Malformed native grant rejected") }
            check(NativeSocialTransport.requests.count == 1, "Malformed grant cannot reach exchange")
            scenarios += 1
        }
        for path in ["/api/v1/auth/native-social/kakao/start", "/api/v1/auth/native-social/apple/start"] {
            NativeSocialTransport.reset(); NativeSocialTransport.json(path, ["status": "authenticated", "code": "grant"])
            if path.contains("kakao") {
                _ = try await ServerAPI.startNativeKakaoAuthentication(accessToken: "synthetic-kakao-token", codeChallenge: "synthetic-challenge")
                check(NativeSocialTransport.requests[0].body["accessToken"] as? String == "synthetic-kakao-token", "Kakao start sends provider token only to native route")
            } else {
                _ = try await ServerAPI.startNativeAppleAuthentication(identityToken: "synthetic-identity", authorizationCode: "synthetic-auth-code", nonce: "synthetic-nonce", fullName: "Synthetic Person", codeChallenge: "synthetic-challenge")
                let body = NativeSocialTransport.requests[0].body
                check(body["nonce"] as? String == "synthetic-nonce" && body["identityToken"] as? String == "synthetic-identity" && body["authorizationCode"] as? String == "synthetic-auth-code", "Apple start retains nonce and revocation authorization")
                check(!body.keys.contains("email"), "Apple native start must not forward an unnecessary client email claim")
            }
            check(NativeSocialTransport.requests[0].body["codeChallenge"] as? String == "synthetic-challenge" && !NativeSocialTransport.requests[0].authed, "Native provider start includes PKCE without previous bearer")
            scenarios += 1
        }
        for cancellationPoint in ["before", register, exchange] {
            NativeSocialTransport.reset(); let context = NativeSocialRegistrationContext(registration: info(), codeVerifier: verifier)
            if cancellationPoint != "before" {
                NativeSocialTransport.json(register, ["code": "grant"], hold: cancellationPoint == register)
                if cancellationPoint == exchange { grantReply(hold: true) }
            }
            let task = Task { @MainActor in try await context.submit(profile: profile()) }
            if cancellationPoint != "before" { await until { NativeSocialTransport.continuation != nil } }
            task.cancel()
            if cancellationPoint != "before" { NativeSocialTransport.release() }
            await expectCancellation(task)
            check(NativeSocialTransport.requests.count == (cancellationPoint == "before" ? 0 : cancellationPoint == register ? 1 : 2), "Cancellation stops at its current protocol phase")
            check(!AuthFlowDiagnostics.events.contains { $0.stage == "exchange_succeeded" }, "Late reply to cancelled registration cannot return success")
            scenarios += 1
        }
        do {
            NativeSocialTransport.reset(); grantReply(hold: true)
            let task = Task { @MainActor in try await NativeSocialRegistrationContext.resolve(.init(status: "authenticated", code: "grant", registration: nil), provider: "apple", codeVerifier: verifier) }
            await until { NativeSocialTransport.continuation != nil }; task.cancel(); NativeSocialTransport.release()
            await expectCancellation(task)
            check(!AuthFlowDiagnostics.events.contains { $0.stage == "exchange_succeeded" }, "Cancelled existing-account exchange cannot masquerade as success")
            scenarios += 1
        }
        do {
            let context = NativeSocialRegistrationContext(registration: info(), codeVerifier: verifier)
            let form = NativeRegistrationLifecycleHarness(context: context)
            form.isSubmitting = true; form.submissionID = UUID()
            let submission = Task { @MainActor in await NativeRegistrationLifecycleGate.pause() }
            form.submissionTask = submission
            await until { NativeRegistrationLifecycleGate.continuation != nil }
            form.disappear()
            check(submission.isCancelled, "In-flight form disappearance cancels its own submission")
            check(!form.isSubmitting && form.submissionTask == nil && form.submissionID == nil, "Reappearing form is no longer locked busy or owned by the cancelled submission")
            check(form.serverError?.contains("같은 가입 요청") == true, "Uncertain disappearance offers a result-check retry, not fake success")
            NativeRegistrationLifecycleGate.release(); await submission.value
            scenarios += 1
        }
        do {
            let context = NativeSocialRegistrationContext(registration: info(), codeVerifier: verifier)
            let form = NativeRegistrationLifecycleHarness(context: context)
            let idleID = UUID(); form.submissionID = idleID
            form.disappear()
            check(form.submissionID == idleID && form.serverError == nil, "School/birthday temporary presentation does not cancel an idle form")
            scenarios += 1
        }
        do {
            let context = NativeSocialRegistrationContext(registration: info(), codeVerifier: verifier)
            let form = NativeRegistrationLifecycleHarness(context: context)
            // Actual submit() clears this handle immediately before onComplete;
            // AuthScreen owns the newly created signInServer task independently.
            form.isSubmitting = true; form.submissionTask = nil; form.submissionID = UUID()
            var parentCompleted = false
            let parentTask = Task { @MainActor in
                await NativeRegistrationLifecycleGate.pause()
                if !Task.isCancelled { parentCompleted = true }
            }
            await until { NativeRegistrationLifecycleGate.continuation != nil }
            form.disappear()
            check(!parentTask.isCancelled, "Completed form dismissal cannot cancel its parent's authentication handoff task")
            NativeRegistrationLifecycleGate.release(); await parentTask.value
            check(parentCompleted, "Parent handoff continues after normal success dismisses the form")
            scenarios += 1
        }
        for code in ["SOCIAL_AUTH_GRANT_EXPIRED", "SOCIAL_AUTH_GRANT_INVALID", "SOCIAL_AUTH_CODE_INVALID",
                     "NATIVE_SOCIAL_REGISTRATION_EXPIRED", "NATIVE_SOCIAL_REGISTRATION_INVALID",
                     "NATIVE_SOCIAL_REGISTRATION_CONSUMED", "NATIVE_SOCIAL_POLICY_VERSION_MISMATCH",
                     "NATIVE_SOCIAL_REGISTRATION_CONFLICT"] {
            let form = NativeRegistrationLifecycleHarness(context: .init(registration: info(), codeVerifier: verifier))
            form.handleRegistrationError(ServerAPIError(message: "Synthetic retry boundary", code: code, statusCode: 409))
            check(form.hasExpired, "Consumed/invalid/expired proof or grant routes back to authentication: " + code)
            scenarios += 1
        }
        do {
            let form = NativeRegistrationLifecycleHarness(context: .init(registration: info(), codeVerifier: verifier))
            form.handleRegistrationError(ServerAPIError(message: "Synthetic transient error", code: "SYNTHETIC_HTTP_FAILURE", statusCode: 503))
            check(!form.hasExpired && form.serverError == "Synthetic transient error", "Transient transport error retains same-proof retry instead of declaring expiry")
            scenarios += 1
        }
        print("Native social context: \(scenarios) scenarios, \(checks) checks PASS (actual context, API body builders and form lifecycle; no network/session mutation).")
    }
}
