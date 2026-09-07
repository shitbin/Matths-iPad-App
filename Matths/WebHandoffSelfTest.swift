#if DEBUG
import Foundation
import WebKit

@MainActor
private protocol HostedHandoffTestModel: AnyObject {
    var debugHandoffClient: ((ServerAPI.AuthorizationSnapshot) async throws -> String)? { get set }
    var debugLoadedURLs: [URL] { get }
    var debugHandoffTask: Task<Void, Never>? { get }
    var webView: WKWebView { get }
    func debugBeginHandoffForSelfTest()
    func accountDidChange()
    func stop()
}
extension CommunityWebModel: HostedHandoffTestModel {}
extension ArenaWebModel: HostedHandoffTestModel {}

@MainActor
enum WebHandoffSelfTest {
    private static var started = false
    @MainActor private final class DelayedClient {
        private var responses: [Int: CheckedContinuation<String, Error>] = [:]
        private var watchers: [(Int, CheckedContinuation<Void, Never>)] = []
        private var count = 0
        func issue() async throws -> String {
            try await withCheckedThrowingContinuation { continuation in
                let index = count; count += 1
                responses[index] = continuation
                let ready = watchers.filter { $0.0 <= count }
                watchers.removeAll { $0.0 <= count }
                ready.forEach { $0.1.resume() }
            }
        }
        func waitForRequests(_ requested: Int) async {
            if count >= requested { return }
            await withCheckedContinuation { watchers.append((requested, $0)) }
        }
        func respond(_ index: Int) {
            // Intentionally ignores Task cancellation, as a late network/SDK
            // callback can. The real model must reject its returned URL.
            let url = ServerAPI.baseURL.appendingPathComponent("app/commerce/synthetic-\(index)")
            responses.removeValue(forKey: index)?.resume(returning: url.absoluteString)
        }
    }

    static func runIfRequested() {
        guard DemoMode.isOn, !started, ProcessInfo.processInfo.arguments.contains("-webHandoffSelfTest") else { return }
        started = true
        Task { @MainActor in
            let community = await exercise(CommunityWebModel(), name: "CommunityWebModel")
            let arena = await exercise(ArenaWebModel.debugMakeForHandoffSelfTest(), name: "ArenaWebModel")
            let results = [community, arena]
            let report: [String: Any] = [
                "schemaVersion": "MATTHS_HOSTED_WEB_HANDOFF_QA_V1",
                "usesActualWebModels": true, "networkRequestsExecuted": false,
                "transport": "delayed injected responses ignoring cancellation; URL loads intercepted",
                "results": results,
                "status": results.allSatisfy { $0["passed"] as? Bool == true } ? "PASS" : "FAIL",
            ]
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) {
                try? data.write(to: documents.appendingPathComponent("web-handoff-device-qa.json"), options: .atomic)
            }
        }
    }

    private static func exercise(_ model: any HostedHandoffTestModel, name: String) async -> [String: Any] {
        let client = DelayedClient()
        model.debugHandoffClient = { _ in try await client.issue() }
        model.debugBeginHandoffForSelfTest()
        await client.waitForRequests(1)
        let previousTask = model.debugHandoffTask
        let oldView = model.webView
        model.accountDidChange()
        let viewReplaced = oldView !== model.webView
        model.debugBeginHandoffForSelfTest()
        await client.waitForRequests(2)
        let currentTask = model.debugHandoffTask
        client.respond(1); client.respond(0)
        await previousTask?.value; await currentTask?.value
        let switchedSafely = model.debugLoadedURLs.map(\.lastPathComponent) == ["synthetic-1"]

        model.debugBeginHandoffForSelfTest()
        await client.waitForRequests(3)
        let stoppedTask = model.debugHandoffTask
        model.stop()
        client.respond(2)
        await stoppedTask?.value
        let stoppedSafely = model.debugLoadedURLs.count == 1

        var burst: [Task<Void, Never>] = []
        for index in 3..<23 {
            model.debugBeginHandoffForSelfTest()
            await client.waitForRequests(index + 1)
            if let task = model.debugHandoffTask { burst.append(task) }
        }
        for index in (3..<23).reversed() { client.respond(index) }
        for task in burst { await task.value }
        let latestOnly = model.debugLoadedURLs.map(\.lastPathComponent) == ["synthetic-1", "synthetic-22"]
        return ["model": name, "retiredViewReplaced": viewReplaced, "oldAccountResponseRejected": switchedSafely,
                "stopRejectsLateURL": stoppedSafely, "twentyResponsesLatestOnly": latestOnly,
                "passed": viewReplaced && switchedSafely && stoppedSafely && latestOnly]
    }
}
#endif
