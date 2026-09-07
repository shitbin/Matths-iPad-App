import Foundation

/// Independent of token text: A → B → A invalidates work started in the first A
/// session, even when the resulting slot or credential happens to be identical.
final class MobileSessionEpoch: @unchecked Sendable {
    static let shared = MobileSessionEpoch()
    private let lock = NSLock()
    private var epoch: UInt64 = 0
    private var observer: NSObjectProtocol?
    private init() {
        observer = NotificationCenter.default.addObserver(forName: DataScope.didSwitchNotification, object: nil, queue: nil) { [weak self] _ in
            guard let self else { return }; self.lock.lock(); self.epoch &+= 1; self.lock.unlock()
        }
    }
    var current: UInt64 { lock.lock(); defer { lock.unlock() }; return epoch }
}

struct MobileRequestOwner: Sendable {
    let slot: String
    let epoch: UInt64
    let origin: String
    let authorization: ServerAPI.AuthorizationSnapshot
    init(account: String = DataScope.slot, authorization: ServerAPI.AuthorizationSnapshot) {
        slot = account; epoch = MobileSessionEpoch.shared.current
        origin = ServerAPI.baseURL.absoluteString; self.authorization = authorization
    }
    var isCurrent: Bool {
        slot == DataScope.slot && epoch == MobileSessionEpoch.shared.current
            && origin == ServerAPI.baseURL.absoluteString && ServerAPI.isCurrentAuthorization(authorization)
    }
    func validate() throws { try Task.checkCancellation(); guard isCurrent else { throw CancellationError() } }
    var cacheKey: String { origin + ":" + slot + ":" + String(epoch) }
}

actor MobileFeatureSupport {
    static let shared = MobileFeatureSupport()
    private struct Cached { let value: MobileFeatureCapabilities; let at: TimeInterval; let authorization: ServerAPI.AuthorizationSnapshot }
    private var cache: [String: Cached] = [:]
    private var requests: [String: (UUID, Task<MobileFeatureCapabilities, Error>)] = [:]
    func capabilities(for owner: MobileRequestOwner, force: Bool = false) async throws -> MobileFeatureCapabilities {
        try owner.validate()
        if !force, let hit = cache[owner.cacheKey], ServerAPI.isCurrentAuthorization(hit.authorization),
           ProcessInfo.processInfo.systemUptime - hit.at < 60 { return hit.value }
        if let existing = requests[owner.cacheKey] {
            let value = try await existing.1.value; try owner.validate(); return value
        }
        let id = UUID()
        let task = Task { try await ServerAPI.mobileCapabilities(owner: owner) }
        requests[owner.cacheKey] = (id, task)
        defer { if requests[owner.cacheKey]?.0 == id { requests.removeValue(forKey: owner.cacheKey) } }
        do {
            let value = try await task.value; try owner.validate()
            cache = cache.filter { $0.key == owner.cacheKey }
            cache[owner.cacheKey] = .init(value: value, at: ProcessInfo.processInfo.systemUptime, authorization: owner.authorization)
            return value
        } catch { try owner.validate(); throw error }
    }
}

enum FirstLearningRemoteWrite: Equatable { case saved(FirstLearningRemoteEnvelope), conflict(FirstLearningRemoteEnvelope) }

extension ServerAPI {
    static func mobileCapabilities(owner: MobileRequestOwner) async throws -> MobileFeatureCapabilities {
        #if DEBUG
        if DemoMode.isOn { return .legacy }
        #endif
        try owner.validate()
        do {
            let value: MobileFeatureCapabilities = try await request("GET", "/api/v1/mobile-capabilities", body: nil,
                                                                       authed: true, headers: ["Cache-Control": "no-cache"], authorization: owner.authorization)
            try owner.validate()
            guard value.isValid else { throw mobileContractError() }
            return value
        } catch let error as ServerAPIError where error.isRouteMissing || error.statusCode == 405 {
            try owner.validate(); return .legacy
        }
    }
    static func getFirstLearningState(owner: MobileRequestOwner) async throws -> FirstLearningRemoteEnvelope {
        try owner.validate()
        let value: FirstLearningRemoteEnvelope = try await request("GET", "/api/v1/me/first-learning", body: nil,
                                                                    authed: true, headers: ["Cache-Control": "no-cache"], authorization: owner.authorization)
        try owner.validate()
        guard value.isValid else { throw mobileContractError() }
        return value
    }
    static func patchFirstLearningState(_ state: FirstLearningRemoteState, revision: Int, owner: MobileRequestOwner) async throws -> FirstLearningRemoteWrite {
        try owner.validate()
        guard revision >= 0, state.isValid else { throw mobileContractError() }
        struct Body: Encodable { let schemaVersion = 1; let expectedRevision: Int; let state: FirstLearningRemoteState }
        var request = try authorizedRequest("PATCH", "/api/v1/me/first-learning", contentType: "application/json", timeout: 20,
                                            authorization: owner.authorization)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.httpBody = try JSONEncoder().encode(Body(expectedRevision: revision, state: state))
        let (data, response) = try await URLSession.shared.data(for: request)
        try owner.validate()
        guard data.count <= 131_072 else { throw mobileContractError() }
        if (response as? HTTPURLResponse)?.statusCode == 409 {
            struct Conflict: Decodable { let code: String; let current: FirstLearningRemoteEnvelope }
            let conflict = try JSONDecoder().decode(Conflict.self, from: data)
            guard conflict.code == "FIRST_LEARNING_REVISION_CONFLICT", conflict.current.isValid else { throw mobileContractError() }
            return .conflict(conflict.current)
        }
        try validateAuthorizedResponse(response, errorBody: data, requestToken: bearerToken(from: request))
        let value = try JSONDecoder().decode(FirstLearningRemoteEnvelope.self, from: data)
        guard value.isValid, value.revision > revision, value.state == state else { throw mobileContractError() }
        return .saved(value)
    }
    static func mobileContractError() -> ServerAPIError {
        .init(message: "계정 간 이어하기 지원 상태를 확인하지 못했습니다. 이 기기의 기록은 보관됩니다. 연결 후 다시 확인해 주세요.", code: "MOBILE_CONTRACT_INVALID")
    }
}
