import Foundation

// All HTTP and draft storage are process-local test doubles. The actual product
// composer methods are extracted by the runner; no network or app build occurs.
struct PhotosPickerItem {}

@MainActor enum DataScope {
    static var slot = "A"
}

@MainActor final class AppStore {
    struct AccountSessionBoundary: Equatable {
        let slot: String
        let generation: Int
    }
    var generation = 0
    func captureAccountSessionBoundary() -> AccountSessionBoundary {
        .init(slot: DataScope.slot, generation: generation)
    }
    func ownsCurrentAccountSession(_ boundary: AccountSessionBoundary) -> Bool {
        boundary == captureAccountSessionBoundary()
    }
    func switchAccount(to slot: String) {
        generation += 1
        DataScope.slot = slot
        ServerAPI.token = "token-" + slot
    }
}

struct ServerAPIError: Error {
    let message: String
    var code: String? = nil
    var statusCode: Int? = nil
    var errorDescription: String? { message }
}

@MainActor enum ServerAPI {
    struct AuthorizationSnapshot: Equatable { let token: String }
    struct CommunityPost: Equatable { let id: String }
    struct CommunityPostingAccess { let remainingPosts: Int; let canUploadFiles: Bool }
    struct PostCall {
        let board: String
        let title: String
        let content: String
        let anonymous: Bool
        let files: [URL]
        let account: String
        let operationID: String
        let token: String
    }
    static var token = "token-A"
    static var calls: [PostCall] = []
    static var holdPost = false
    static var continuation: CheckedContinuation<Void, Never>?
    static var failure: ServerAPIError?
    static func captureAuthorization() -> AuthorizationSnapshot? { .init(token: token) }
    static func reset() {
        precondition(continuation == nil, "Previous HTTP continuation leaked")
        token = "token-A"; calls = []; holdPost = false; failure = nil
    }
    static func createCommunityPost(board: String, title: String, content: String,
                                    anonymous: Bool, files: [URL], originalNames: [String: String],
                                    account: String, operationID: String) async throws -> CommunityPost {
        calls.append(.init(board: board, title: title, content: content, anonymous: anonymous,
                           files: files, account: account, operationID: operationID, token: token))
        if holdPost { await withCheckedContinuation { continuation = $0 } }
        if let failure { throw failure }
        // Intentionally deliver even after switching accounts/cancellation: the
        // production UI guards must independently reject this late receipt.
        return .init(id: "post-acknowledged")
    }
    static func release() {
        let pending = continuation; continuation = nil; holdPost = false
        pending?.resume()
    }
}

@MainActor struct MobileRequestOwner {
    let account: String
    let authorization: ServerAPI.AuthorizationSnapshot
    func validate() throws {
        try Task.checkCancellation()
        guard account == DataScope.slot, authorization.token == ServerAPI.token else { throw CancellationError() }
    }
}

@MainActor final class CommunityRequestIdentity {
    static let shared = CommunityRequestIdentity()
    var hold = false
    var continuation: CheckedContinuation<Void, Never>?
    var began: [String] = []
    var finished: [String] = []
    func reset() {
        precondition(continuation == nil, "Previous acknowledgement continuation leaked")
        hold = false; began = []; finished = []
    }
    func finishAcknowledgedDraft(owner: MobileRequestOwner, operationID: String) async throws {
        began.append(operationID)
        // Models a queued actor call before the actual synchronous ledger write.
        if hold { await withCheckedContinuation { continuation = $0 } }
        try owner.validate()
        finished.append(operationID)
    }
    func release() {
        let pending = continuation; continuation = nil; hold = false
        pending?.resume()
    }
}

@MainActor enum NativeServiceDraftDisk {
    static var values: [String: NativeServiceDraft] = [:]
    static var failedWrites = false
    static var failedReads = false
    static var writes: [NativeServiceDraft] = []
    static var successfulWrites: [NativeServiceDraft] = []
    static func reset() { values = [:]; failedWrites = false; failedReads = false; writes = []; successfulWrites = [] }
    private static func key(_ slot: String, _ resource: String) -> String { slot + "|" + resource }
    static func load(slot: String, resource: String) throws -> NativeServiceDraft {
        if failedReads { throw CocoaError(.fileReadCorruptFile) }
        return values[key(slot, resource)] ?? .init(slot: slot, resource: resource)
    }
    static func save(_ value: NativeServiceDraft) throws {
        writes.append(value)
        if failedWrites { throw CocoaError(.fileWriteOutOfSpace) }
        guard value.isValid else { throw CocoaError(.coderInvalidValue) }
        values[key(value.slot, value.resource)] = value
        successfulWrites.append(value)
    }
    static func forceStore(_ value: NativeServiceDraft) { values[key(value.slot, value.resource)] = value }
    static func current(_ slot: String = "A") -> NativeServiceDraft? { values[key(slot, "community-composer")] }
}

@MainActor final class CompletionLog {
    var entries: [(post: String, board: String)] = []
    func record(_ post: ServerAPI.CommunityPost, _ board: String) { entries.append((post.id, board)) }
}

@main enum CommunityComposerAcknowledgementCases {
    @MainActor static var checks = 0
    @MainActor static var cases = 0
    @MainActor static func check(_ value: @autoclosure () -> Bool, _ message: String) {
        guard value() else { print("FAIL: " + message); exit(1) }
        checks += 1
    }
    @MainActor static func until(_ predicate: () -> Bool) async {
        for _ in 0..<20_000 { if predicate() { return }; await Task.yield() }
        print("FAIL: controlled continuation was not reached"); exit(1)
    }
    @MainActor static func fixture() -> (AppStore, CommunityComposerHarness, CompletionLog) {
        ServerAPI.reset(); NativeServiceDraftDisk.reset(); CommunityRequestIdentity.shared.reset(); DataScope.slot = "A"
        let store = AppStore(), log = CompletionLog()
        let flow = CommunityComposerHarness(store: store, onCreated: log.record)
        return (store, flow, log)
    }
    @MainActor static func main() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("community-ack-cases-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: folder) }
        func attachment() throws -> URL {
            let url = folder.appendingPathComponent("community-draft-" + UUID().uuidString + ".pdf")
            try Data("owned source attachment".utf8).write(to: url)
            return url
        }

        do {
            let (_, flow, log) = fixture(); let file = try attachment(); flow.seed(files: [file])
            await flow.saveForTest()
            check(ServerAPI.calls.count == 1, "normal save sends exactly one POST")
            check(log.entries.count == 1 && log.entries[0].board == "school", "normal save completes with original board")
            check(flow.finalized && flow.currentFields["content"] == "", "normal save clears RAM after durable clear")
            check(NativeServiceDraftDisk.current()?.fields["content"] == "", "normal clear is durable")
            check(NativeServiceDraftDisk.current()?.submissionID == nil, "cleared draft has no old submission ticket")
            check(!FileManager.default.fileExists(atPath: file.path), "normal acknowledged clear removes its attachment")
            check(CommunityRequestIdentity.shared.finished == [ServerAPI.calls[0].operationID], "acknowledged ticket retired once")
            await flow.saveForTest(); await flow.finishForTest()
            check(ServerAPI.calls.count == 1 && log.entries.count == 1, "finalized callbacks and POST are not repeated")
            cases += 1
        }
        do {
            let (_, flow, log) = fixture(); let file = try attachment(); flow.seed(files: [file])
            ServerAPI.holdPost = true
            let operation = Task { @MainActor in await flow.saveForTest() }
            await until { ServerAPI.continuation != nil }
            flow.edit(board: "high-school", title: "후속 제목", content: "서버에 보내지 않은 후속 편집", anonymous: true)
            NativeServiceDraftDisk.failedWrites = true
            check(!flow.persistForTest(), "onChange draft write is forced to fail")
            ServerAPI.release(); await operation.value
            check(ServerAPI.calls[0].board == "school" && ServerAPI.calls[0].content == "원본 내용", "POST arguments stay frozen during editing")
            check(flow.currentFields["content"] == "서버에 보내지 않은 후속 편집", "server success must not discard newer RAM text")
            check(flow.currentFiles == [file] && FileManager.default.fileExists(atPath: file.path), "server success preserves attachment needed by newer draft")
            check(log.entries.isEmpty && !flow.finalized && flow.hasAcknowledgement, "failed preservation retains acknowledged state and keeps sheet open")
            check(flow.error?.contains("등록되었습니다") == true, "error accurately distinguishes successful POST from local failure")
            await flow.saveForTest()
            check(ServerAPI.calls.count == 1 && log.entries.isEmpty, "retry under ongoing disk failure performs zero extra POST")
            NativeServiceDraftDisk.failedWrites = false
            await flow.saveForTest()
            check(ServerAPI.calls.count == 1, "successful local retry still performs zero extra POST")
            check(log.entries.count == 1 && log.entries[0].board == "school", "callback uses acknowledged board, not later draft board")
            check(NativeServiceDraftDisk.current()?.fields["board"] == "high-school" && NativeServiceDraftDisk.current()?.fields["content"] == "서버에 보내지 않은 후속 편집", "latest draft and selected board are durable before close")
            check(NativeServiceDraftDisk.current()?.submissionID == nil && NativeServiceDraftDisk.current()?.attachments == [file.lastPathComponent], "later draft keeps attachment without reusing acknowledged ticket")
            check(FileManager.default.fileExists(atPath: file.path), "preserved draft attachment survives completed callback")
            cases += 1
        }
        do {
            let (_, flow, log) = fixture()
            let original = try attachment(), replacement = try attachment()
            flow.seed(files: [original]); ServerAPI.holdPost = true
            let operation = Task { @MainActor in await flow.saveForTest() }
            await until { ServerAPI.continuation != nil }
            let unchangedFields = flow.currentFields
            // Keep title/content/board/anonymous AND every originalNames entry
            // identical. Only [URL] changes, independently exercising the
            // production currentAttachments == acknowledged.attachments guard.
            flow.replaceOnlyAttachmentListForQueuedEvent([replacement])
            check(flow.currentFields == unchangedFields, "attachment-only fixture does not change any draftFields or originalNames")
            NativeServiceDraftDisk.failedWrites = true
            check(!flow.persistForTest(), "attachment-only edit fails its local draft write")
            ServerAPI.release(); await operation.value
            check(flow.currentFiles == [replacement] && FileManager.default.fileExists(atPath: replacement.path), "attachment-only edit remains in RAM and on disk after server success")
            check(flow.currentFields == unchangedFields, "attachment-only failure keeps unrelated input unchanged")
            check(log.entries.isEmpty && flow.hasAcknowledgement && !flow.finalized, "attachment-only persistence failure does not dismiss")
            check(ServerAPI.calls.count == 1 && ServerAPI.calls[0].files == [original], "attachment-only edit never changes the already submitted payload")
            await flow.saveForTest()
            check(ServerAPI.calls.count == 1 && log.entries.isEmpty, "attachment-only retry during disk failure performs no extra POST")
            NativeServiceDraftDisk.failedWrites = false
            await flow.saveForTest()
            check(NativeServiceDraftDisk.current()?.attachments == [replacement.lastPathComponent], "attachment-only local retry persists exact new attachment list")
            check(NativeServiceDraftDisk.current()?.fields == unchangedFields && NativeServiceDraftDisk.current()?.submissionID == nil, "attachment-only preserved draft retains fields but not acknowledged ticket")
            check(ServerAPI.calls.count == 1 && log.entries.count == 1, "attachment-only successful retry closes once with POST count unchanged")
            check(flow.currentFiles == [replacement] && FileManager.default.fileExists(atPath: replacement.path), "attachment-only local recovery never deletes the new file")
            cases += 1
        }
        do {
            let (_, flow, log) = fixture(); let file = try attachment(); flow.seed(files: [file])
            ServerAPI.holdPost = true
            let operation = Task { @MainActor in await flow.saveForTest() }
            await until { ServerAPI.continuation != nil }
            NativeServiceDraftDisk.failedWrites = true
            ServerAPI.release(); await operation.value
            check(flow.currentFields["content"] == "원본 내용" && flow.currentFiles == [file], "failed durable clear keeps original RAM and files")
            check(FileManager.default.fileExists(atPath: file.path) && NativeServiceDraftDisk.current()?.submissionID != nil, "attachment is not removed before clear commits")
            check(log.entries.isEmpty && flow.hasAcknowledgement && !flow.finalized, "clear failure keeps local-only retry available")
            flow.denyNewPosts(); NativeServiceDraftDisk.failedWrites = false
            await flow.saveForTest()
            check(ServerAPI.calls.count == 1 && log.entries.count == 1, "acknowledged retry bypasses quota checks but never POSTs")
            check(!FileManager.default.fileExists(atPath: file.path), "attachment removed only after retry clear succeeds")
            cases += 1
        }
        do {
            let (_, flow, log) = fixture(); flow.seed()
            NativeServiceDraftDisk.failedWrites = true
            await flow.saveForTest()
            check(ServerAPI.calls.isEmpty && log.entries.isEmpty, "initial draft write failure never starts POST")
            check(flow.currentFields["content"] == "원본 내용", "initial write failure keeps RAM content")
            cases += 1
        }
        do {
            let (_, flow, log) = fixture(); flow.seed(); ServerAPI.holdPost = true
            let operation = Task { @MainActor in await flow.saveForTest() }
            await until { ServerAPI.continuation != nil }
            // Represents an input event whose onChange has not run yet.
            flow.edit(content: "아직 onChange 전인 입력")
            ServerAPI.release(); await operation.value
            check(NativeServiceDraftDisk.current()?.fields["content"] == "아직 onChange 전인 입력", "RAM comparison catches queued onChange not yet on disk")
            check(flow.currentFields["content"] == "아직 onChange 전인 입력" && log.entries.count == 1, "new input preserved before normal completion")
            cases += 1
        }
        do {
            let (_, flow, log) = fixture(); let file = try attachment(); flow.seed(files: [file]); ServerAPI.holdPost = true
            let operation = Task { @MainActor in await flow.saveForTest() }
            await until { ServerAPI.continuation != nil }
            var other = NativeServiceDraft(slot: "A", resource: "community-composer")
            other.fields = ["title": "다른 창", "content": "다른 작성 화면이 보관한 글"]
            NativeServiceDraftDisk.forceStore(other)
            ServerAPI.release(); await operation.value
            check(NativeServiceDraftDisk.current() == other, "different durable presentation draft is not erased")
            check(log.entries.count == 1 && flow.finalized, "existing different durable draft permits receipt completion")
            check(!flow.persistForTest() && NativeServiceDraftDisk.current() == other, "onDisappear cannot overwrite another presentation draft")
            check(FileManager.default.fileExists(atPath: file.path), "unmatched durable draft does not authorize attachment cleanup")
            cases += 1
        }
        do {
            let (_, flow, log) = fixture(); flow.seed(); ServerAPI.holdPost = true
            let operation = Task { @MainActor in await flow.saveForTest() }
            await until { ServerAPI.continuation != nil }
            NativeServiceDraftDisk.failedReads = true
            ServerAPI.release(); await operation.value
            check(log.entries.isEmpty && flow.hasAcknowledgement && flow.currentFields["content"] == "원본 내용", "corrupt/unreadable draft keeps receipt and RAM")
            NativeServiceDraftDisk.failedReads = false
            await flow.saveForTest()
            check(ServerAPI.calls.count == 1 && log.entries.count == 1, "read recovery finishes locally without reposting")
            cases += 1
        }
        do {
            let (_, flow, log) = fixture(); let file = try attachment(); flow.seed(files: [file]); ServerAPI.holdPost = true
            let operation = Task { @MainActor in await flow.saveForTest() }
            await until { ServerAPI.continuation != nil }
            var differentTicket = NativeServiceDraftDisk.current()!
            differentTicket.submissionID = UUID().uuidString
            NativeServiceDraftDisk.forceStore(differentTicket)
            ServerAPI.release(); await operation.value
            check(NativeServiceDraftDisk.current() == differentTicket, "same fields with another presentation ticket must not be cleared")
            check(FileManager.default.fileExists(atPath: file.path) && log.entries.count == 1, "different ticket preserves attachment while original receipt completes")
            check(!flow.persistForTest() && CommunityRequestIdentity.shared.finished.isEmpty, "different ticket is not overwritten or retired")
            cases += 1
        }
        do {
            let (store, flow, log) = fixture(); flow.seed(); let before = NativeServiceDraftDisk.successfulWrites.count
            store.switchAccount(to: "B")
            await flow.saveForTest()
            check(ServerAPI.calls.isEmpty && log.entries.isEmpty && NativeServiceDraftDisk.successfulWrites.count == before, "queued old-account save cannot request or mutate")
            cases += 1
        }
        for returnsToA in [false, true] {
            let (store, flow, log) = fixture(); let file = try attachment(); flow.seed(files: [file]); ServerAPI.holdPost = true
            let operation = Task { @MainActor in await flow.saveForTest() }
            await until { ServerAPI.continuation != nil }
            let before = NativeServiceDraftDisk.successfulWrites.count
            store.switchAccount(to: "B"); if returnsToA { store.switchAccount(to: "A") }
            ServerAPI.release(); await operation.value
            check(ServerAPI.calls.count == 1 && ServerAPI.calls[0].account == "A" && ServerAPI.calls[0].token == "token-A", "in-flight request retains original account")
            check(log.entries.isEmpty && !flow.hasAcknowledgement, "late response cannot acknowledge after session replacement")
            check(NativeServiceDraftDisk.successfulWrites.count == before && FileManager.default.fileExists(atPath: file.path), "late response cannot clear prior account draft or attachments")
            cases += 1
        }
        do {
            let (store, flow, log) = fixture(); flow.seed(); ServerAPI.holdPost = true
            let operation = Task { @MainActor in await flow.saveForTest() }
            await until { ServerAPI.continuation != nil }
            NativeServiceDraftDisk.failedWrites = true
            ServerAPI.release(); await operation.value
            let before = NativeServiceDraftDisk.writes.count
            store.switchAccount(to: "B"); NativeServiceDraftDisk.failedWrites = false
            await flow.saveForTest(); await flow.finishForTest()
            check(ServerAPI.calls.count == 1 && NativeServiceDraftDisk.writes.count == before && log.entries.isEmpty, "acknowledged old-account retry cannot act in replacement account")
            cases += 1
        }
        do {
            let (store, flow, log) = fixture(); flow.seed(); CommunityRequestIdentity.shared.hold = true
            let operation = Task { @MainActor in await flow.saveForTest() }
            await until { CommunityRequestIdentity.shared.continuation != nil }
            let before = NativeServiceDraftDisk.successfulWrites.count
            store.switchAccount(to: "B")
            CommunityRequestIdentity.shared.release(); await operation.value
            check(log.entries.isEmpty && CommunityRequestIdentity.shared.finished.isEmpty, "account replacement during ledger await prevents final callback and stale ledger mutation")
            check(NativeServiceDraftDisk.successfulWrites.count == before, "no draft mutation follows ledger ownership loss")
            cases += 1
        }
        do {
            let (_, flow, log) = fixture(); flow.seed(); CommunityRequestIdentity.shared.hold = true
            let operation = Task { @MainActor in await flow.saveForTest() }
            await until { CommunityRequestIdentity.shared.continuation != nil }
            let file = try attachment()
            flow.edit(title: "완료 직전 새 입력", content: "ledger await 중 queued 입력")
            flow.replaceFilesForQueuedEvent([file])
            check(!flow.persistForTest(), "finalized UI state prevents premature onChange overwrite")
            CommunityRequestIdentity.shared.release(); await operation.value
            check(log.entries.isEmpty && !flow.finalized && flow.hasAcknowledgement, "queued input during ledger await must reopen local preservation without dismissal")
            check(flow.currentFields["content"] == "ledger await 중 queued 입력" && FileManager.default.fileExists(atPath: file.path), "queued text and attachment retained")
            NativeServiceDraftDisk.failedWrites = true
            await flow.saveForTest()
            check(ServerAPI.calls.count == 1 && log.entries.isEmpty, "queued-input retry never POSTs while storage unavailable")
            NativeServiceDraftDisk.failedWrites = false
            await flow.saveForTest()
            check(ServerAPI.calls.count == 1 && log.entries.count == 1, "queued-input recovery callback happens once without extra POST")
            check(NativeServiceDraftDisk.current()?.fields["content"] == "ledger await 중 queued 입력" && NativeServiceDraftDisk.current()?.attachments == [file.lastPathComponent], "queued data becomes durable before close")
            cases += 1
        }
        do {
            let (_, flow, log) = fixture(); flow.seed(); ServerAPI.holdPost = true
            let operation = Task { @MainActor in await flow.saveForTest() }
            await until { ServerAPI.continuation != nil }
            let before = NativeServiceDraftDisk.successfulWrites.count
            operation.cancel(); ServerAPI.release(); await operation.value
            check(log.entries.isEmpty && NativeServiceDraftDisk.successfulWrites.count == before, "cancelled POST continuation cannot clear drafts or complete")
            cases += 1
        }
        do {
            let (_, flow, log) = fixture(); flow.seed(); CommunityRequestIdentity.shared.hold = true
            let operation = Task { @MainActor in await flow.saveForTest() }
            await until { CommunityRequestIdentity.shared.continuation != nil }
            operation.cancel(); CommunityRequestIdentity.shared.release(); await operation.value
            check(log.entries.isEmpty && CommunityRequestIdentity.shared.finished.isEmpty, "cancelled acknowledgement continuation cannot complete or retire ledger")
            check(!flow.finalized && flow.hasAcknowledgement, "cancelled acknowledgement leaves local recovery available")
            await flow.saveForTest()
            check(ServerAPI.calls.count == 1 && log.entries.count == 1, "cancelled acknowledgement retry completes without extra POST")
            cases += 1
        }
        do {
            let (_, flow, log) = fixture(); flow.seed(); ServerAPI.failure = .init(message: "Synthetic server rejection", statusCode: 403)
            await flow.saveForTest()
            check(ServerAPI.calls.count == 1 && !flow.hasAcknowledgement && !flow.finalized && log.entries.isEmpty, "server rejection never enters acknowledged cleanup")
            check(flow.currentFields["content"] == "원본 내용", "server rejection preserves draft")
            cases += 1
        }
        print("Community composer acknowledgement: \(cases) scenarios, \(checks) checks PASS (actual production functions; no network).")
    }
}
