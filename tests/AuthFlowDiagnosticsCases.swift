import Foundation

struct ServerAPIError: Error { var message: String?; var code: String?; var statusCode: Int? }

@main struct AuthFlowDiagnosticsCases {
    @MainActor static func main() throws {
        let launchFlag = ProcessInfo.processInfo.arguments.contains("-authDiagnostics")
        #if DEBUG || MATTHS_AUTH_DIAGNOSTICS
        precondition(AuthFlowDiagnostics.isEnabled == launchFlag)
        #else
        precondition(!AuthFlowDiagnostics.isEnabled, "normal Release must ignore the opt-in launch argument")
        #endif
        // Public disabled API may not acquire an owner. Active storage is tested
        // below using the exact recorder with a private temporary destination,
        // never the Mac user's real Library/Caches.
        if !AuthFlowDiagnostics.isEnabled {
            let id = UUID()
            AuthFlowDiagnostics.begin(provider: "google", attemptID: id)
            AuthFlowDiagnostics.record("exchange_started", attemptID: id)
            AuthFlowDiagnostics.fail(NSError(domain: NSURLErrorDomain, code: -1009), attemptID: id)
            precondition(AuthFlowDiagnostics.currentAttemptID == nil)
        }
        #if DEBUG || MATTHS_AUTH_DIAGNOSTICS
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("matths-diag-case-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appendingPathComponent("auth-flow-diagnostics.json")
        var writeCount = 0
        var rejectsWrite = false
        var clock: TimeInterval = 100
        let recorder = AuthFlowDiagnosticRecorder(enabled: true, destination: destination, clock: { clock }) { bytes, path in
            writeCount += 1
            if rejectsWrite { throw NSError(domain: NSCocoaErrorDomain, code: 513) }
            try ProtectedFileWriter.write(bytes, to: path)
        }
        let a = UUID(), b = UUID()
        recorder.record("provider_lookup", attemptID: nil)
        recorder.fail(NSError(domain: NSURLErrorDomain, code: -1009), attemptID: a)
        precondition(writeCount == 0 && recorder.currentAttemptID == nil)
        recorder.begin(provider: "not-an-allowed-provider", attemptID: a)
        precondition(writeCount == 0 && recorder.currentAttemptID == nil)
        recorder.begin(provider: "google", attemptID: a)
        precondition(recorder.currentAttemptID == a && recorder.trace?.events.count == 1)
        let original = try Data(contentsOf: destination)
        recorder.record("callback_received", attemptID: nil)
        recorder.record("callback_received", attemptID: b)
        recorder.record("untrusted-stage-with-payload", attemptID: a)
        recorder.begin(provider: "google-with-extra-data", attemptID: b)
        let unchanged = try Data(contentsOf: destination)
        precondition(unchanged == original && writeCount == 1)
        for stage in AuthFlowDiagnosticRecorder.stages.sorted() {
            clock += 0.125; recorder.record(stage, attemptID: a)
        }
        recorder.record("cancel_requested", attemptID: a)
        recorder.record("sign_in_finished", attemptID: a)
        precondition(recorder.currentAttemptID == a, "cleanup request is not a final cancellation verdict")
        for _ in 0..<100 { recorder.record("provider_lookup", attemptID: a) }
        precondition(recorder.trace?.events.count == 60)
        let bounded = try JSONSerialization.jsonObject(with: Data(contentsOf: destination)) as! [String: Any]
        precondition((bounded["events"] as? [[String: Any]])?.count == 60)
        recorder.begin(provider: "apple", attemptID: b)
        precondition(recorder.currentAttemptID == b && recorder.trace?.events.count == 1)
        let afterBeginWrites = writeCount
        recorder.record("exchange_succeeded", attemptID: a)
        recorder.fail(ServerAPIError(message: "obsolete", code: "AUTH_TOKEN_STORAGE_FAILED", statusCode: 401), attemptID: a)
        precondition(writeCount == afterBeginWrites)

        let sentinel = "PRIVACY_SENTINEL_NOT_FOR_OUTPUT"
        let privateURL = "https://example.invalid/" + sentinel
        let privateEmail = sentinel + "@example.invalid"
        let privateInfo: [String: Any] = [NSLocalizedDescriptionKey: sentinel, NSURLErrorFailingURLErrorKey: URL(string: privateURL)!,
            "email": privateEmail, "token": sentinel, "nonce": sentinel, "code": sentinel]
        recorder.fail(NSError(domain: NSURLErrorDomain, code: -1200, userInfo: privateInfo), attemptID: b)
        precondition(recorder.trace?.events.last?.errorDomain == NSURLErrorDomain && recorder.trace?.events.last?.errorCode == -1200)
        recorder.fail(NSError(domain: sentinel, code: 1234, userInfo: privateInfo), attemptID: b)
        precondition(recorder.trace?.events.last?.errorDomain == nil && recorder.trace?.events.last?.errorCode == nil)
        recorder.fail(NSError(domain: NSOSStatusErrorDomain, code: -34018, userInfo: privateInfo), attemptID: b)
        precondition(recorder.trace?.events.last?.errorCode == -34018)
        for code in ["AUTH_TOKEN_STORAGE_FAILED", "SOCIAL_AUTH_STATE_INVALID", "SOCIAL_AUTH_ACCOUNT_CONFLICT", "SOCIAL_AUTH_PARENT_ACCOUNT",
                     "APPLE_AUTH_ALG_UNSUPPORTED", "APPLE_AUTH_JWKS_UNAVAILABLE", "APPLE_AUTH_KEY_NOT_FOUND", "APPLE_AUTH_NICKNAME_UNAVAILABLE",
                     "APPLE_AUTH_NONCE_REQUIRED", "APPLE_AUTH_SUBJECT_MISSING", "APPLE_AUTH_TOKEN_MALFORMED", "APPLE_AUTH_TOKEN_NOT_YET_VALID"] {
            recorder.fail(ServerAPIError(message: sentinel, code: code, statusCode: 401), attemptID: b)
            precondition(recorder.trace?.events.last?.apiCode == code && recorder.trace?.events.last?.httpStatus == 401)
        }
        recorder.fail(ServerAPIError(message: sentinel, code: sentinel, statusCode: Int.max), attemptID: b)
        precondition(recorder.trace?.events.last?.apiCode == nil && recorder.trace?.events.last?.httpStatus == nil)
        let safeBytes = try Data(contentsOf: destination)
        let safeText = String(decoding: safeBytes, as: UTF8.self)
        precondition(!safeText.contains(sentinel) && !safeText.contains(privateEmail) && !safeText.contains(privateURL))
        let object = try JSONSerialization.jsonObject(with: safeBytes) as! [String: Any]
        precondition(Set(object.keys) == ["schemaVersion", "provider", "attemptID", "startedAt", "events"])
        let allowedEventKeys: Set<String> = ["stage", "elapsedMilliseconds", "errorDomain", "errorCode", "apiCode", "httpStatus"]
        for event in object["events"] as! [[String: Any]] { precondition(Set(event.keys).isSubset(of: allowedEventKeys)) }
        let permissions = try FileManager.default.attributesOfItem(atPath: destination.path)[.posixPermissions] as! NSNumber
        precondition(permissions.intValue == 0o600)
        let backupValues = try destination.resourceValues(forKeys: [.isExcludedFromBackupKey])
        precondition(backupValues.isExcludedFromBackup == true)
        rejectsWrite = true
        recorder.record("slot_switched", attemptID: b)
        precondition(recorder.currentAttemptID == b && recorder.trace?.events.last?.stage == "slot_switched")
        let afterFailure = try Data(contentsOf: destination)
        precondition(afterFailure == safeBytes, "diagnostic write failure damaged prior trace")
        rejectsWrite = false
        clock = .infinity; recorder.record("sign_in_finished", attemptID: b)
        precondition(recorder.trace?.events.last?.elapsedMilliseconds == 0)

        let disabledPath = directory.appendingPathComponent("disabled.json")
        var disabledWrites = 0
        let disabled = AuthFlowDiagnosticRecorder(enabled: false, destination: disabledPath, write: { _, _ in disabledWrites += 1 })
        disabled.begin(provider: "google", attemptID: a)
        disabled.record("callback_received", attemptID: a)
        disabled.fail(NSError(domain: NSURLErrorDomain, code: -1009, userInfo: privateInfo), attemptID: a)
        precondition(disabledWrites == 0 && disabled.currentAttemptID == nil && !FileManager.default.fileExists(atPath: disabledPath.path))
        print("Auth trace compiled opt-in mode, launch flag \(launchFlag ? "on" : "off"): privacy/allowlists/owner/nil/bounded60/600/backup exclusion/write-failure PASS")
        #else
        print("Auth trace normal Release, launch flag \(launchFlag ? "on" : "off"): no-op PASS")
        #endif
    }
}
