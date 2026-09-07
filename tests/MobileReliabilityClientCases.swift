import Foundation

// HTTP fixture boundary only. The production mobile support/API, state merge,
// ownership epoch, payload hashing and durable request ledger are compiled below.
struct ServerAPIError: LocalizedError, Decodable {
    var message: String?
    var code: String?
    var statusCode: Int? = nil
    var isRouteMissing: Bool { statusCode == 404 && (code == nil || code == "HTTP_404") }
}
enum ServerAPI {
    static let baseURL = LiveMobileFixture.value?.origin ?? URL(string: "https://mobile-reliability-test.invalid")!
    struct AuthorizationSnapshot: Sendable { let token: String }
    static var token = LiveMobileFixture.value?.token ?? "owner-A"
    static var hasToken: Bool { !token.isEmpty }
    static let clientBuildVersion = "mobile-client-test"
    static func authorizationForCurrentRequest() -> AuthorizationSnapshot { .init(token: token) }
    static func captureAuthorization() -> AuthorizationSnapshot? { .init(token: token) }
    static func isCurrentAuthorization(_ value: AuthorizationSnapshot) -> Bool { token == value.token }
    static func authorizedRequest(_ method: String, _ path: String, contentType: String? = nil, timeout: TimeInterval = 60,
                                  authorization: AuthorizationSnapshot? = nil) throws -> URLRequest {
        guard let authorization, isCurrentAuthorization(authorization) else { throw CancellationError() }
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method; request.httpBody = nil
        request.setValue("Bearer " + authorization.token, forHTTPHeaderField: "Authorization")
        if let contentType { request.setValue(contentType, forHTTPHeaderField: "Content-Type") }
        return request
    }
    static func bearerToken(from request: URLRequest) -> String? { request.value(forHTTPHeaderField: "Authorization") }
    static func validateAuthorizedResponse(_ response: URLResponse, errorBody: Data = Data(), requestToken: String?) throws {
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200..<300).contains(http.statusCode) else {
            var error = (try? JSONDecoder().decode(ServerAPIError.self, from: errorBody)) ?? .init()
            error.statusCode = http.statusCode; throw error
        }
    }
    static func request<T: Decodable>(_ method: String, _ path: String, body: [String: Any]?, authed: Bool,
                                      query: [String: String] = [:], headers: [String: String] = [:], authorization: AuthorizationSnapshot? = nil) async throws -> T {
        var request = try authorizedRequest(method, path, authorization: authorization)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !query.isEmpty {
            var components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }; request.url = components.url
        }
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        if let body { request.httpBody = try JSONSerialization.data(withJSONObject: body) }
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateAuthorizedResponse(response, errorBody: data, requestToken: bearerToken(from: request))
        return try JSONDecoder().decode(T.self, from: data)
    }
}

private struct LiveMobileFixture {
    let origin: URL
    let token: String
    let communityPostID: String
    static let value: Self? = {
        guard let marker = CommandLine.arguments.firstIndex(of: "--local-manifest"), CommandLine.arguments.indices.contains(marker + 1) else { return nil }
        // The generated manifest is already private (0600). Its secret values
        // are used only in request headers and never printed or copied to repo.
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[marker + 1])),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any], object["fixtureOnly"] as? Bool == true,
              let originText = object["origin"] as? String, let origin = URL(string: originText),
              ["127.0.0.1", "localhost"].contains(origin.host ?? ""),
              let accounts = object["accounts"] as? [String: [String: Any]], let account = accounts["returningStudent"],
              let token = account["token"] as? String,
              let fixtures = object["fixtures"] as? [String: Any], let postID = fixtures["communityPostId"] as? String else {
            fatalError("A valid local-only fixture manifest is required; no network request was made.")
        }
        return .init(origin: origin, token: token, communityPostID: postID)
    }()
}

@MainActor final class SyncEngine {
    static let shared = SyncEngine()
    var deadLettered = 0
    var quarantinedLines = 0
}

final class FirstLearningFixtureService: @unchecked Sendable {
    private let lock = NSLock()
    var current: FirstLearningRemoteEnvelope
    var patchCount = 0
    var capabilityCount = 0
    var loseNextReply = false
    var rejectNextPatchWith: FirstLearningRemoteEnvelope?
    let capabilities: MobileFeatureCapabilities
    init(current: FirstLearningRemoteEnvelope, capabilities: MobileFeatureCapabilities) {
        self.current = current; self.capabilities = capabilities
    }
    func respond(_ request: URLRequest) throws -> (Int, Data) {
        lock.lock(); defer { lock.unlock() }
        if request.url?.path == "/api/v1/mobile-capabilities" {
            capabilityCount += 1
            return (200, try JSONEncoder().encode(capabilities))
        }
        if request.httpMethod == "GET" { return (200, try JSONEncoder().encode(current)) }
        patchCount += 1
        if let change = rejectNextPatchWith { current = change; rejectNextPatchWith = nil }
        let body = try MobileReliabilityClientCases.payload(request)
        if body["expectedRevision"] as? Int != current.revision {
            let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(current))
            return (409, try MobileReliabilityClientCases.json(["code": "FIRST_LEARNING_REVISION_CONFLICT", "current": object]))
        }
        let state = try JSONDecoder().decode(FirstLearningRemoteState.self, from: MobileReliabilityClientCases.json(body["state"]!))
        current = MobileReliabilityClientCases.envelope(current.revision + 1, state)
        if loseNextReply { loseNextReply = false; throw URLError(.networkConnectionLost) }
        return (200, try JSONEncoder().encode(current))
    }
}

final class MobileFixtureProtocol: URLProtocol {
    static let lock = NSLock()
    static var handler: (URLRequest) throws -> (Int, Data) = { _ in (500, Data()) }
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == ServerAPI.baseURL.host }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            Self.lock.lock(); let handle = Self.handler; Self.lock.unlock()
            let (status, data) = try handle(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
    static func respond(_ new: @escaping (URLRequest) throws -> (Int, Data)) {
        lock.lock(); handler = new; lock.unlock()
    }
}

@main enum MobileReliabilityClientCases {
    static var checks = 0
    static func check(_ value: @autoclosure () -> Bool, _ description: String) {
        precondition(value(), description); checks += 1
    }
    static func json(_ value: Any) throws -> Data { try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]) }
    static func envelope(_ revision: Int, _ state: FirstLearningRemoteState?) -> FirstLearningRemoteEnvelope {
        .init(schemaVersion: "FIRST_LEARNING_V1", supported: true, revision: revision, state: state, updatedAt: nil)
    }
    static func payload(_ request: URLRequest) throws -> [String: Any] {
        var data = request.httpBody ?? Data()
        if data.isEmpty, let stream = request.httpBodyStream {
            stream.open(); defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }; data.append(buffer, count: count)
            }
        }
        return try JSONSerialization.jsonObject(with: data) as! [String: Any]
    }
    @MainActor static func main() async throws {
        if let live = LiveMobileFixture.value { try await runLive(live); return }
        URLProtocol.registerClass(MobileFixtureProtocol.self)
        let oldSlot = DataScope.slot
        let slot = "mobile-test-" + UUID().uuidString
        _ = DataScope.switchTo(slot)
        defer { _ = DataScope.switchTo(oldSlot) }
        let owner = MobileRequestOwner(authorization: .init(token: "owner-A"))
        check(FirstLearningProfileReadiness.needsHydration(authProvider: "server", tutorialStatus: nil, shouldAutoStart: nil),
              "real login's small user envelope must hydrate GET me before onboarding decision")
        check(!FirstLearningProfileReadiness.needsHydration(authProvider: nil, tutorialStatus: nil, shouldAutoStart: nil),
              "signed-out launch cannot hydrate an authenticated profile")
        check(!FirstLearningProfileReadiness.needsHydration(authProvider: "server", tutorialStatus: "COMPLETED", shouldAutoStart: false),
              "explicit server false is a known state, not a retry trigger")
        let unloadedTrigger = FirstLearningProfileReadiness.trigger(slot: slot, authProvider: "server", role: "student", tutorialStatus: nil, shouldAutoStart: nil)
        let pendingTrigger = FirstLearningProfileReadiness.trigger(slot: slot, authProvider: "server", role: "student", tutorialStatus: "PENDING", shouldAutoStart: true)
        let completedTrigger = FirstLearningProfileReadiness.trigger(slot: slot, authProvider: "server", role: "student", tutorialStatus: "COMPLETED", shouldAutoStart: false)
        check(Set([unloadedTrigger, pendingTrigger, completedTrigger]).count == 3,
              "unloaded, true and explicit false own separate presentation tasks")
        let supported = MobileFeatureCapabilities(schemaVersion: "MOBILE_CAPABILITIES_V1", firstLearningState: true,
            firstLearningStateVersion: 1, communityIdempotency: true, communityIdempotencyVersion: 1)
        MobileFixtureProtocol.respond { _ in (200, try JSONEncoder().encode(supported)) }
        let actualSupport = try await MobileFeatureSupport().capabilities(for: owner)
        check(actualSupport == supported, "actual capability API decodes confirmed support")
        for status in [404, 405] {
            MobileFixtureProtocol.respond { _ in (status, try json(["code": "HTTP_\(status)"])) }
            let legacy = try await MobileFeatureSupport().capabilities(for: owner)
            check(legacy == .legacy, "only explicit old route is legacy")
        }
        for status in [401, 500, 503] {
            MobileFixtureProtocol.respond { _ in (status, try json(["code": "HTTP_\(status)"])) }
            do { _ = try await MobileFeatureSupport().capabilities(for: owner); preconditionFailure("must not downgrade \(status)") }
            catch { checks += 1 }
        }
        MobileFixtureProtocol.respond { _ in (200, try json(["schemaVersion": "MOBILE_CAPABILITIES_V1", "firstLearningState": "true"])) }
        do { _ = try await MobileFeatureSupport().capabilities(for: owner); preconditionFailure("malformed capability") }
        catch { checks += 1 }
        MobileFixtureProtocol.respond { _ in throw URLError(.networkConnectionLost) }
        do { _ = try await MobileFeatureSupport().capabilities(for: owner); preconditionFailure("lost network is not legacy") }
        catch { checks += 1 }

        var local = FirstLearningJourney(slot: slot, startedAt: Date(timeIntervalSince1970: 1_800_000_000))
        local.selectGoal(.review); local.answerDiagnosis(7); local.answerDiagnosis(3)
        _ = local.prepare(conceptID: "concept_1", seed: UInt64.max, problemIDs: ["p1", "p2", "p3"], baselineProgress: 4,
                          contentFingerprint: String(repeating: "a", count: 64), now: local.startedAt)
        _ = local.beginChecks()
        _ = local.recordAnswer(slot: slot, conceptID: "concept_1", problemID: "p1", correct: true)
        let remote = FirstLearningRemoteState(local)
        check(remote.isValid && remote.seed == "18446744073709551615", "UInt64 is an exact decimal string")
        let encoded = try JSONEncoder().encode(remote)
        let exported = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        for key in ["slot", "token", "confirmedProgress", "serverConfirmedAt", "pendingTutorialAction", "deadLetterBaseline", "quarantineBaseline", "passed", "unlock"] {
            check(exported[key] == nil, "local/private/official proof never exported: " + key)
        }
        var malformed = remote; malformed.seed = "018446744073709551615"
        check(!malformed.isValid, "noncanonical seed rejected")
        malformed.seed = "18446744073709551616"; check(!malformed.isValid, "overflow seed rejected")
        malformed = remote; malformed.checkedAnswers.append(.init(problemId: "p1", correct: false))
        check(!malformed.isValid, "duplicate answers rejected")
        malformed = remote; malformed.expectedProblemIds[0] = "../../other"
        check(!malformed.isValid, "unsafe IDs rejected")
        malformed = remote; malformed.stage = "result"
        check(!malformed.isValid, "result without all answers rejected")
        _ = local.recordAnswer(slot: slot, conceptID: "concept_1", problemID: "p2", correct: false)
        _ = local.recordAnswer(slot: slot, conceptID: "concept_1", problemID: "p3", correct: true)
        _ = local.confirmServer(progress: 8, now: local.startedAt)
        _ = local.finish(now: local.startedAt)
        let completed = FirstLearningRemoteState(local)
        let imported = try completed.localJourney(slot: "other-device-same-account", deadLetters: 4, quarantined: 2)
        check(imported.stage == .awaitingSync && imported.confirmedProgress == nil && imported.serverConfirmedAt == nil,
              "downloaded completion is downgraded until independent canonical refresh")
        check(!imported.canCompleteTutorial && imported.pendingTutorialAction == nil, "remote blob cannot send COMPLETE")
        check(imported.deadLetterBaseline == 4 && imported.quarantineBaseline == 2, "destination queue proof is local only")

        let base = FirstLearningSyncCache(slot: slot, origin: owner.origin, revision: 4, baseState: remote, localBaseline: remote)
        check(FirstLearningMergeDecision.decide(local: remote, cache: base, remote: envelope(4, remote), pristine: false) == .acknowledged, "same revision ack")
        check(FirstLearningMergeDecision.decide(local: completed, cache: base, remote: envelope(4, remote), pristine: false) == .uploadLocal, "dirty local sends against known revision")
        check(FirstLearningMergeDecision.decide(local: remote, cache: base, remote: envelope(5, completed), pristine: false) == .adoptRemote, "clean local adopts newer remote")
        var other = remote; other.goal = "measure"
        check(FirstLearningMergeDecision.decide(local: completed, cache: base, remote: envelope(5, other), pristine: false) == .conflict, "two dirty devices require choice")
        check(FirstLearningMergeDecision.decide(local: completed, cache: base, remote: envelope(5, nil), pristine: false) == .conflict, "remote dashboard clear cannot be revived")
        check(FirstLearningMergeDecision.decide(local: completed, cache: base, remote: envelope(5, completed), pristine: false) == .acknowledged, "lost PATCH success recognizes exact current payload")
        check(FirstLearningMergeDecision.decide(local: remote, cache: nil, remote: envelope(0, nil), pristine: false) == .uploadLocal, "legacy local draft can initialize a truly empty server")
        check(FirstLearningMergeDecision.decide(local: remote, cache: nil, remote: envelope(9, nil), pristine: false) == .conflict, "reinstall cannot overwrite a later clear")

        MobileFixtureProtocol.respond { request in
            if request.httpMethod == "GET" { return (200, try JSONEncoder().encode(envelope(4, remote))) }
            let body = try payload(request)
            precondition(body["expectedRevision"] as? Int == 4)
            let value = body["state"] as! [String: Any]
            precondition(value["seed"] as? String == "18446744073709551615")
            return (200, try JSONEncoder().encode(envelope(5, remote)))
        }
        let fetched = try await ServerAPI.getFirstLearningState(owner: owner)
        check(fetched == envelope(4, remote), "real GET wrapper restores schema and revision")
        let saved = try await ServerAPI.patchFirstLearningState(remote, revision: 4, owner: owner)
        check(saved == .saved(envelope(5, remote)), "real PATCH wrapper verifies increment and exact state")
        MobileFixtureProtocol.respond { _ in
            let current = try JSONSerialization.jsonObject(with: JSONEncoder().encode(envelope(6, other)))
            return (409, try json(["code": "FIRST_LEARNING_REVISION_CONFLICT", "current": current]))
        }
        let conflict = try await ServerAPI.patchFirstLearningState(remote, revision: 4, owner: owner)
        check(conflict == .conflict(envelope(6, other)), "409 keeps full current envelope instead of losing it in generic error")
        MobileFixtureProtocol.respond { _ in (409, try json(["code": "OTHER_CONFLICT", "current": [:]])) }
        do { _ = try await ServerAPI.patchFirstLearningState(remote, revision: 4, owner: owner); preconditionFailure("bad conflict") }
        catch { checks += 1 }

        let scope = UUID().uuidString
        let fingerprint = try CommunityRequestFingerprint.make(operation: "comment", fields: ["postId": "one", "content": "hello"], attachments: [])
        let firstKey = try await CommunityRequestIdentity().requestID(owner: owner, operationID: scope, fingerprint: fingerprint, capability: supported)
        let reloadedKey = try await CommunityRequestIdentity().requestID(owner: owner, operationID: scope, fingerprint: fingerprint, capability: supported)
        check(firstKey != nil && firstKey == reloadedKey, "request ID survives process-style ledger reload and response loss")
        let changed = try CommunityRequestFingerprint.make(operation: "comment", fields: ["postId": "one", "content": "changed"], attachments: [])
        let changedKey = try await CommunityRequestIdentity().requestID(owner: owner, operationID: scope, fingerprint: changed, capability: supported)
        check(changedKey != firstKey, "changed submitted content has a different request ID")
        let revertedKey = try await CommunityRequestIdentity().requestID(owner: owner, operationID: scope, fingerprint: fingerprint, capability: supported)
        check(revertedKey == firstKey, "returning to an uncertain original body reuses its original ID")
        do { _ = try await CommunityRequestIdentity().requestID(owner: owner, operationID: scope, fingerprint: fingerprint, capability: .legacy)
            preconditionFailure("keyed retry must not become keyless") } catch { checks += 1 }
        let legacyScope = UUID().uuidString
        let legacyKey = try await CommunityRequestIdentity().requestID(owner: owner, operationID: legacyScope, fingerprint: fingerprint, capability: .legacy)
        let upgradedKey = try await CommunityRequestIdentity().requestID(owner: owner, operationID: legacyScope, fingerprint: fingerprint, capability: supported)
        check(legacyKey == nil && upgradedKey == nil, "uncertain old keyless operation is not recast as a new keyed write")
        let newDraftKey = try await CommunityRequestIdentity().requestID(owner: owner, operationID: UUID().uuidString, fingerprint: fingerprint, capability: supported)
        check(newDraftKey != firstKey, "explicit new draft may intentionally repeat content")
        let ledgerPath = DataScope.url(CommunityRequestIdentity.fileName, for: slot)
        let beforeAcknowledgement = try JSONDecoder().decode(CommunityRequestLedger.self, from: Data(contentsOf: ledgerPath))
        try await CommunityRequestIdentity().finishAcknowledgedDraft(owner: owner, operationID: scope)
        let afterAcknowledgement = try JSONDecoder().decode(CommunityRequestLedger.self, from: Data(contentsOf: ledgerPath))
        check(afterAcknowledgement.entries.count == beforeAcknowledgement.entries.count - 2,
              "durably acknowledged draft cleanup removes only its original and edited payload identities")
        check(afterAcknowledgement.entries.values.contains { $0.requestID == newDraftKey }, "other pending draft identities survive acknowledged cleanup")

        let file = DataScope.url("fixture-attachment.bin", for: slot)
        try Data(repeating: 7, count: 600_000).write(to: file)
        let attachment = CommunityMultipartBody.Attachment(url: file, filename: "same.bin", mimeType: "application/octet-stream", maximumBytes: 1_000_000)
        let bytesBefore = try CommunityRequestFingerprint.make(operation: "post", fields: [:], attachments: [attachment])
        try Data(repeating: 8, count: 600_000).write(to: file)
        let bytesAfter = try CommunityRequestFingerprint.make(operation: "post", fields: [:], attachments: [attachment])
        check(bytesBefore != bytesAfter, "same name and length with different bytes gets a different fingerprint")

        // Exercise the production ObservableObject coordinator, not only the
        // merge function. The only fake is the HTTP service above.
        let fixture = FirstLearningFixtureService(current: envelope(0, nil), capabilities: supported)
        MobileFixtureProtocol.respond(fixture.respond)
        let singleFlightSupport = MobileFeatureSupport()
        try await withThrowingTaskGroup(of: Bool.self) { group in
            for _ in 0..<12 { group.addTask { try await singleFlightSupport.capabilities(for: owner) == supported } }
            for try await value in group { check(value, "coalesced capability caller receives verified value") }
        }
        check(fixture.capabilityCount == 1, "12 concurrent support reads share one actual HTTP request")
        let coordinator = FirstLearningJourneyStore.shared
        await coordinator.synchronize()
        check(coordinator.remoteCache?.revision == 0 && coordinator.remoteConflict == nil, "real store GET initializes durable revision")
        coordinator.suppressRemoteScheduling = true
        _ = coordinator.update { $0.selectGoal(.review) }
        coordinator.suppressRemoteScheduling = false
        await coordinator.synchronize()
        check(fixture.current.state?.goal == "review" && fixture.current.state?.stage == "diagnosis", "real store PATCH uploads navigation state")
        check(fixture.patchCount == 1 && coordinator.remoteCache?.revision == 1, "one coalesced CAS patch persisted")

        coordinator.suppressRemoteScheduling = true
        _ = coordinator.update { $0.answerDiagnosis(7) }
        coordinator.suppressRemoteScheduling = false
        fixture.loseNextReply = true
        await coordinator.synchronize()
        check(coordinator.syncMessage != nil && coordinator.journey.diagnosticAnswers == [7], "lost reply retains local draft and exposes recovery")
        check(coordinator.remoteSyncNeedsRetry, "failed confirmation offers a retry action")
        let afterLost = fixture.patchCount
        await coordinator.synchronize()
        check(fixture.patchCount == afterLost && coordinator.syncMessage == nil && coordinator.remoteCache?.revision == 2,
              "GET acknowledges lost successful PATCH without resending a new mutation")
        check(!coordinator.remoteSyncNeedsRetry, "successful confirmation does not show an unnecessary retry")

        coordinator.suppressRemoteScheduling = true
        _ = coordinator.update { $0.answerDiagnosis(3) }
        coordinator.suppressRemoteScheduling = false
        var conflicting = FirstLearningRemoteState(coordinator.journey); conflicting.goal = "measure"
        fixture.rejectNextPatchWith = envelope(3, conflicting)
        await coordinator.synchronize()
        check(coordinator.remoteConflict?.revision == 3 && coordinator.journey.goal == .review, "409 exposes remote choice and preserves local draft")
        let beforeChoice = fixture.patchCount
        await coordinator.synchronize()
        check(fixture.patchCount == beforeChoice, "ordinary retry never blindly overwrites a conflict")
        await coordinator.keepLocalJourney()
        check(coordinator.remoteConflict == nil && fixture.current.state?.goal == "review" && fixture.current.revision == 4,
              "explicit keep-local choice rebases once against latest revision")

        // Simulate a remote completed UX state with arbitrary correct answers.
        // The store must not import its claimed official confirmation.
        fixture.current = envelope(5, completed)
        await coordinator.synchronize()
        check(coordinator.journey.stage == .awaitingSync && coordinator.journey.confirmedProgress == nil,
              "real store restoration forces independent canonical refresh")
        let withoutLocalChange = fixture.patchCount
        await coordinator.synchronize()
        check(fixture.patchCount == withoutLocalChange, "lowered local result baseline is not uploaded as an accidental rollback")
        let cacheURL = DataScope.url(FirstLearningJourneyStore.syncFileName, for: slot)
        let cacheReloaded = try JSONDecoder().decode(FirstLearningSyncCache.self, from: Data(contentsOf: cacheURL))
        check(cacheReloaded.isValid && cacheReloaded.revision == 5 && cacheReloaded.slot == slot, "revision and owner survive disk reload")

        // A different device cleared the dashboard after this device edited.
        coordinator.suppressRemoteScheduling = true
        _ = coordinator.update { $0.goal = .school }
        coordinator.suppressRemoteScheduling = false
        fixture.current = envelope(6, nil)
        await coordinator.synchronize()
        check(coordinator.remoteConflict?.state == nil && coordinator.remoteConflict?.revision == 6,
              "remote completion/restart clear cannot be resurrected by stale dirty state")
        coordinator.useRemoteJourney()
        check(coordinator.remoteConflict == nil && coordinator.journey.stage == .goal && coordinator.remoteCache?.revision == 6,
              "explicit remote choice accepts clear and preserves original as a backup")
        let backups = try FileManager.default.contentsOfDirectory(atPath: DataScope.directory.path)
        check(backups.contains { $0.contains("conflict-") && $0.hasSuffix(".json") }, "conflict resolution preserves local draft backup")

        coordinator.resetRemoteSession()
        let damaged = Data("{damaged cache, keep original}".utf8)
        try damaged.write(to: cacheURL)
        await coordinator.synchronize()
        check(coordinator.remoteCacheBlocked && coordinator.syncMessage != nil, "corrupt revision cache blocks writes instead of guessing zero")
        check((try? Data(contentsOf: cacheURL)) == damaged, "corrupt cache original is not silently overwritten")
        await coordinator.recoverRemoteCache()
        check(!coordinator.remoteCacheBlocked && coordinator.remoteCache?.revision == 6, "explicit repair preserves original and refetches canonical revision")
        let repairedBackups = try FileManager.default.contentsOfDirectory(atPath: DataScope.directory.path)
        check(repairedBackups.contains { $0.contains("unreadable-") }, "repair retains unreadable source backup")

        _ = DataScope.switchTo("mobile-other-" + UUID().uuidString)
        _ = DataScope.switchTo(slot)
        check(!owner.isCurrent, "A B A slot switch rejects original owner's delayed response")
        do { _ = try await CommunityRequestIdentity().requestID(owner: owner, operationID: scope, fingerprint: fingerprint, capability: supported)
            preconditionFailure("old epoch must not write") } catch { checks += 1 }
        print("PASS mobile reliability client: \(checks) executable assertions (HTTP fixture, CAS merge, strict DTO, epoch, durable idempotency).")
    }

    @MainActor private static func runLive(_ fixture: LiveMobileFixture) async throws {
        let oldSlot = DataScope.slot
        let slot = "mobile-local-http-" + UUID().uuidString
        _ = DataScope.switchTo(slot); defer { _ = DataScope.switchTo(oldSlot) }
        let owner = MobileRequestOwner(authorization: .init(token: fixture.token))
        let support = try await MobileFeatureSupport.shared.capabilities(for: owner, force: true)
        check(support.firstLearningState && support.communityIdempotency, "local real server advertises both prepared capabilities")
        let original = try await ServerAPI.getFirstLearningState(owner: owner)
        var journey = FirstLearningJourney(slot: slot)
        journey.selectGoal(.review)
        let state = FirstLearningRemoteState(journey)
        let outcome = try await ServerAPI.patchFirstLearningState(state, revision: original.revision, owner: owner)
        guard case .saved(let saved) = outcome else { preconditionFailure("isolated local account should accept initial CAS") }
        check(saved.state == state && saved.revision == original.revision + 1, "actual Node/Mongo CAS saves exact DTO")
        let stale = try await ServerAPI.patchFirstLearningState(state, revision: original.revision, owner: owner)
        check(stale == .conflict(saved), "actual Node/Mongo rejects stale revision with complete current state")
        let loaded = try await ServerAPI.getFirstLearningState(owner: owner)
        check(loaded == saved, "actual GET persists exact seed/date/navigation contract")

        let postOperation = UUID().uuidString
        let title = "Local reliability fixture " + String(UUID().uuidString.prefix(8))
        let post = try await ServerAPI.createCommunityPost(board: "high-school", title: title,
            content: "Isolated local fixture content for native request identity verification.", anonymous: false, files: [],
            account: slot, operationID: postOperation, authorization: owner.authorization)
        let replay = try await ServerAPI.createCommunityPost(board: "high-school", title: title,
            content: "Isolated local fixture content for native request identity verification.", anonymous: false, files: [],
            account: slot, operationID: postOperation, authorization: owner.authorization)
        check(post.id == replay.id, "actual native multipart API reuses requestId and gets original post")
        let commentOperation = UUID().uuidString
        let text = "Local comment fixture " + UUID().uuidString
        let comment = try await ServerAPI.createCommunityComment(postId: post.id, content: text, anonymous: false,
            account: slot, operationID: commentOperation, authorization: owner.authorization)
        let commentReplay = try await ServerAPI.createCommunityComment(postId: post.id, content: text, anonymous: false,
            account: slot, operationID: commentOperation, authorization: owner.authorization)
        check(comment.id == commentReplay.id, "actual native comment API replays one stored comment")
        let detail = try await ServerAPI.communityDetail(post, authorization: owner.authorization)
        check(detail.comments.filter { $0.id == comment.id }.count == 1, "real database has one visible comment after replay")
        try await ServerAPI.deleteCommunityPost(postId: post.id, authorization: owner.authorization)
        do {
            _ = try await ServerAPI.createCommunityPost(board: "high-school", title: title,
                content: "Isolated local fixture content for native request identity verification.", anonymous: false, files: [],
                account: slot, operationID: postOperation, authorization: owner.authorization)
            preconditionFailure("deleted post replay must not recreate")
        } catch let error as ServerAPIError {
            check(error.statusCode == 410 && error.code == "COMMUNITY_REQUEST_NO_LONGER_VISIBLE", "deleted keyed replay remains deleted")
        }

        struct Tutorial: Decodable { let tutorial: [String: AnyJSON] }
        let _: Tutorial = try await ServerAPI.request("PATCH", "/api/v1/me/tutorials/dashboard", body: ["action": "RESTART"], authed: true, authorization: owner.authorization)
        let cleared = try await ServerAPI.getFirstLearningState(owner: owner)
        check(cleared.state == nil && cleared.revision > saved.revision, "existing tutorial RESTART atomically clears resume and bumps revision")
        let afterClear = try await ServerAPI.patchFirstLearningState(state, revision: saved.revision, owner: owner)
        check(afterClear == .conflict(cleared), "actual server clear cannot be revived by in-flight stale PATCH")
        print("PASS local Node/Mongo integration: \(checks) native-client checks; local fixture only, no production account or storage.")
    }
}

private struct AnyJSON: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { return }
        if (try? container.decode(String.self)) != nil || (try? container.decode(Bool.self)) != nil || (try? container.decode(Double.self)) != nil { return }
        if (try? container.decode([String: AnyJSON].self)) != nil || (try? container.decode([AnyJSON].self)) != nil { return }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid fixture response")
    }
}
