#if DEBUG
import Foundation

/// Test setup only: real login transport and production session acceptance, but
/// synthetic credentials from an isolated loopback fixture. No UI-login verdict.
@MainActor
enum LocalNativeIntegrationLogin {
    private static var started = false
    static func runIfRequested(store: AppStore) async {
        #if targetEnvironment(simulator)
        let environment = ProcessInfo.processInfo.environment
        guard !started, !DemoMode.isOn,
              Bundle.main.bundleIdentifier == "kr.matths.app.uiqa",
              ProcessInfo.processInfo.arguments.contains("-localIntegrationLogin"),
              ServerAPI.baseURL.scheme == "http",
              ["127.0.0.1", "localhost", "::1"].contains(ServerAPI.baseURL.host ?? ""),
              ServerAPI.baseURL.port != nil,
              let email = environment["MATTHS_LOCAL_QA_EMAIL"], email.hasSuffix("@qa.invalid"),
              let password = environment["MATTHS_LOCAL_QA_PASSWORD"], !password.isEmpty else { return }
        started = true
        let identity = ServerAPI.beginAuthenticationAttempt()
        var evidence: [String: Any] = ["schemaVersion": "LOCAL_NATIVE_LOGIN_QA_V1", "uiLoginInteractionTest": false,
            "productionServer": false, "realHTTPLogin": true, "recordedAt": ISO8601DateFormatter().string(from: Date())]
        do {
            let response = try await ServerAPI.login(email: email, password: password)
            let entered = try await store.signInServer(response, attemptID: identity)
            evidence["status"] = entered ? "PASS" : "FAIL"
            evidence["sessionAccepted"] = entered
        } catch {
            ServerAPI.cancelAuthenticationAttempt(identity)
            evidence["status"] = "FAIL"
            evidence["errorCode"] = (error as? ServerAPIError)?.code ?? "TRANSPORT_OR_DECODE"
        }
        if let data = try? JSONSerialization.data(withJSONObject: evidence, options: [.sortedKeys, .prettyPrinted]),
           let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            try? data.write(to: directory.appendingPathComponent("native-local-login-qa.json"), options: .atomic)
        }
        #endif
    }
}
#endif
