import Foundation

@MainActor enum DataScope {
    static var slot = "a"
    static var directory: URL { URL(fileURLWithPath: "/synthetic/\(slot)") }
}
struct ServerAPIError: LocalizedError {
    var message: String?; var code: String?
    var errorDescription: String? { message }
}
@MainActor final class AppStore {
    struct AccountSessionBoundary { let slot: String; let generation: UUID }
    var generation = UUID()
    func captureAccountSessionBoundary() -> AccountSessionBoundary { .init(slot: DataScope.slot, generation: generation) }
    func ownsCurrentAccountSession(_ value: AccountSessionBoundary) -> Bool { value.slot == DataScope.slot && value.generation == generation }
}
@MainActor enum ServerAPI {
    struct AuthorizationSnapshot { let token: String }
    struct Call { let method: String; let token: String; let body: [String: Any]? }
    static var token = "token-a"
    static var calls: [Call] = []
    static var pause = false
    static var pending: [CheckedContinuation<Data, Never>] = []
    static let clientBuildVersion = "test"
    static func captureAuthorization() -> AuthorizationSnapshot? { .init(token: token) }
    static func isCurrentAuthorization(_ value: AuthorizationSnapshot) -> Bool { value.token == token }
    static func payload(_ bank: String = "Synthetic bank") -> Data {
        Data("""
        {"schemaVersion":"GOAT_ARENA_PAYBACK_ACCOUNT_V1","account":{"confirmed":true,"bankName":"\(bank)","last4":"0000","confirmedAt":null},"payoutEligible":true,"bankSuggestions":[]}
        """.utf8)
    }
    static func request<T: Decodable>(_ method: String, _ path: String, body: [String: Any]?, authed: Bool,
                                      headers: [String: String] = [:], authorization: AuthorizationSnapshot? = nil) async throws -> T {
        // Hold the transport before the default-credential lookup. Wrappers must
        // supply the mounted account; the simulator/device/network are not used.
        let data: Data
        if pause { data = await withCheckedContinuation { pending.append($0) } }
        else { data = payload() }
        let captured = authorization ?? captureAuthorization()!
        guard isCurrentAuthorization(captured) else { throw CancellationError() }
        calls.append(.init(method: method, token: captured.token, body: body))
        return try JSONDecoder().decode(T.self, from: data)
    }
    static func finish(_ index: Int = 0, bank: String = "Synthetic bank") { pending.remove(at: index).resume(returning: payload(bank)) }
}
@MainActor final class PaybackHarness {
    let store = AppStore()
    var status: ServerAPI.GoatArenaPaybackAccountStatus?
    var bankName = "Synthetic bank"
    var accountHolderName = "Synthetic holder"
    var accountNumber = "00000000"
    var isLoading = false
    var isSaving = false
    var errorMessage: String?
    var successMessage: String?
    var showsFinalConfirmation = false
    var accountSlot = DataScope.slot
    var lifecycleID = UUID()
    var isActive = true
    var mountedOwner: AccountRequestOwner?
    var confirmation: GoatArenaPaybackAccountSubmission?
    var loadRequestID: UUID?
    enum Field { case bank, holder, number }
    var focusedField: Field?
    init() { mountedOwner = AccountRequestOwner(store: store) }
    func replaceSession(slot: String) {
        DataScope.slot = slot; ServerAPI.token = "replacement"; store.generation = UUID()
        lifecycleID = UUID(); clearForTest()
    }
}
@main enum PaybackAccountOwnershipCases {
    @MainActor static var failures: [String] = []
    @MainActor static func check(_ value: Bool, _ name: String) { if !value { failures.append(name) } }
    @MainActor static func wait(_ predicate: () -> Bool) async {
        for _ in 0..<10_000 { if predicate() { return }; await Task.yield() }
        fatalError("payback test did not reach requested transport boundary")
    }
    @MainActor static func fixture() -> PaybackHarness {
        DataScope.slot = "a"; ServerAPI.token = "token-a"; ServerAPI.calls = []
        ServerAPI.pause = false; ServerAPI.pending = []
        return PaybackHarness()
    }
    @MainActor static func main() async {
        let snapshot = fixture(); snapshot.prepareConfirmation()
        snapshot.accountHolderName = "Changed after confirmation"
        await snapshot.exerciseSave()
        check(ServerAPI.calls.count == 1 && ServerAPI.calls.first?.body?["accountHolderName"] as? String == "Synthetic holder",
              "confirmation must submit the displayed immutable values, not later field edits")
        check(!snapshot.isSaving && snapshot.successMessage != nil, "successful save clears busy and confirms receipt")

        for slot in ["b", "a"] {
            let changed = fixture(); changed.prepareConfirmation(); ServerAPI.pause = true
            let work = Task { await changed.exerciseSave() }
            await wait { ServerAPI.pending.count == 1 }
            changed.replaceSession(slot: slot)
            ServerAPI.finish(); await work.value
            check(ServerAPI.calls.isEmpty, "in-flight old account bank request must not use replacement \(slot) credential")
            check(changed.status == nil && changed.successMessage == nil, "old account response cannot become new account's bank receipt")
        }

        let loads = fixture(); ServerAPI.pause = true
        let first = Task { await loads.exerciseLoad() }; await wait { ServerAPI.pending.count == 1 }
        let second = Task { await loads.exerciseLoad() }; await wait { ServerAPI.pending.count == 2 }
        ServerAPI.finish(1, bank: "Newer reply"); await second.value
        ServerAPI.finish(0, bank: "Older reply"); await first.value
        check(loads.status?.account.bankName == "Newer reply", "reversed refresh replies keep only the latest state")
        check(!loads.isLoading, "refresh busy is released")

        let savedDuringRead = fixture(); ServerAPI.pause = true
        let oldRead = Task { await savedDuringRead.exerciseLoad() }; await wait { ServerAPI.pending.count == 1 }
        savedDuringRead.prepareConfirmation()
        let save = Task { await savedDuringRead.exerciseSave() }; await wait { ServerAPI.pending.count == 2 }
        ServerAPI.finish(1, bank: "Saved receipt"); await save.value
        ServerAPI.finish(0, bank: "Pre-save read"); await oldRead.value
        check(savedDuringRead.status?.account.bankName == "Saved receipt", "pre-save GET must not overwrite the confirmed account")

        let repeated = fixture(); repeated.prepareConfirmation(); ServerAPI.pause = true
        let repeats = (0..<20).map { _ in Task { await repeated.exerciseSave() } }
        await wait { ServerAPI.pending.count == 1 }
        for _ in 0..<300 { await Task.yield() }
        check(ServerAPI.pending.count == 1, "20 confirmation taps admit one request")
        ServerAPI.finish(); for work in repeats { await work.value }
        check(ServerAPI.calls.count == 1 && !repeated.isSaving, "one confirmed receipt releases purchase-form busy")

        let queued = fixture(); queued.prepareConfirmation(); queued.replaceSession(slot: "b")
        await queued.exerciseSave()
        check(ServerAPI.calls.isEmpty, "old confirmation queued before a session change must not send")
        let retired = fixture(); retired.prepareConfirmation(); retired.isActive = false
        await retired.exerciseSave(); await retired.exerciseLoad()
        check(ServerAPI.calls.isEmpty, "dismissed sheet cannot start requests")
        if !failures.isEmpty { failures.forEach { print("FAIL: \($0)") }; exit(1) }
        print("PASS: actual payback view functions and API wrappers preserve confirmation values, fixed account credentials, replacement sessions and latest-read ownership")
    }
}
