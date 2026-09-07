import Combine
import Foundation
import PencilKit

@MainActor
final class PracticeWorkspaceDraftModel: ObservableObject {
    @Published var answer = "" { didSet { if answer != oldValue { changed() } } }
    @Published var pickedKey: String? { didSet { if pickedKey != oldValue { changed() } } }
    @Published var drawing = PKDrawing() {
        didSet { if !drawing.strokes.isEmpty || !oldValue.strokes.isEmpty { changed() } }
    }
    @Published var zoom: CGFloat = 1 { didSet { if zoom != oldValue { changed() } } }
    @Published private(set) var error: String?
    @Published private(set) var isLoading = false
    @Published private(set) var isWritable = false

    private var handle: PracticeWorkspaceDraftRepository.Handle?
    private var failedHandle: PracticeWorkspaceDraftRepository.Handle?
    private var ownsSession: () -> Bool = { false }
    private var allowedChoiceKeys = Set<String>()
    private var hydrating = false
    private var loadID = UUID()
    private var edits: UInt64 = 0
    private var failureObserver: AnyCancellable?
    private var pendingSourceID: UUID?

    private struct DecodedDrawing: @unchecked Sendable { let value: PKDrawing }
    var canResetPreservingOriginal: Bool { failedHandle != nil && !isLoading }

    init() {
        failureObserver = NotificationCenter.default.publisher(for: PracticeWorkspaceDraftRepository.saveFailedNotification)
            .sink { [weak self] notification in
                guard let failedHandle = notification.object as? PracticeWorkspaceDraftRepository.Handle,
                      let rawID = notification.userInfo?["sourceID"] as? String,
                      let sourceID = UUID(uuidString: rawID) else { return }
                Task { @MainActor [weak self] in
                    guard let self, self.handle == failedHandle, self.pendingSourceID == sourceID,
                          self.ownsSession() else { return }
                    self.error = "풀이를 저장하지 못했습니다. 입력은 화면에 유지되어 있습니다. 저장 공간과 필기 크기를 확인해 주세요."
                }
            }
    }

    func open(fingerprint: String, allowedChoiceKeys: Set<String> = [], store: AppStore) async {
        if handle?.fingerprint == fingerprint, ownsSession(), isWritable {
            // The retry action on a write error must retry the current in-memory
            // input, not discard it by reading an older disk snapshot.
            if error != nil { _ = await flush() }
            return
        }
        let requestID = UUID()
        loadID = requestID
        let owner = store.captureAccountSessionBoundary()
        let slot = DataScope.slot
        let previousSlot = handle?.slot
        self.handle = nil
        self.failedHandle = nil
        self.pendingSourceID = nil
        self.isWritable = false
        self.isLoading = true
        self.allowedChoiceKeys = allowedChoiceKeys
        ownsSession = { [weak store] in store?.ownsCurrentAccountSession(owner) == true }
        hydrating = true
        answer = ""; pickedKey = nil; drawing = PKDrawing(); zoom = 1
        hydrating = false
        error = nil
        let loadEdits = edits
        defer { if loadID == requestID { isLoading = false } }

        if let previousSlot, !(await PracticeWorkspaceDraftRepository.flush(slot: previousSlot)) {
            guard loadID == requestID, ownsSession() else { return }
            error = "이전 문제의 풀이를 아직 디스크에 저장하지 못했습니다. 입력은 메모리에 보관 중이며 다시 저장을 시도합니다."
        }
        guard loadID == requestID, ownsSession(), !Task.isCancelled,
              let target = PracticeWorkspaceDraftRepository.handle(fingerprint: fingerprint, slot: slot) else { return }
        handle = target
        let loaded = await PracticeWorkspaceDraftRepository.load(target)
        guard loadID == requestID, ownsSession(), !Task.isCancelled,
              handle == target, edits == loadEdits else { return }
        switch loaded {
        case .missing:
            isWritable = true
        case .unreadable:
            error = "이 문제의 저장된 풀이를 읽지 못했습니다. 원본 파일은 보관되어 있으며 덮어쓰지 않았습니다."
            failedHandle = target; handle = nil
        case .loaded(let draft):
            guard draft.pickedKey.map({ allowedChoiceKeys.contains($0) }) ?? true else {
                error = "문제의 보기 구성이 달라 저장된 풀이를 적용하지 않았습니다. 원본은 보관되어 있습니다."
                failedHandle = target; handle = nil
                return
            }
            let decoded: DecodedDrawing? = await Task.detached(priority: .utility) {
                let value: PKDrawing
                if draft.drawingData.isEmpty { value = PKDrawing() }
                else {
                    guard let restored = try? PKDrawing(data: draft.drawingData) else { return nil }
                    value = restored
                }
                guard Self.drawingIsWithinBudget(value) else { return nil }
                return DecodedDrawing(value: value)
            }.value
            guard loadID == requestID, ownsSession(), !Task.isCancelled,
                  handle == target, edits == loadEdits else { return }
            guard let decoded else {
                error = "필기 데이터가 손상되었거나 너무 큽니다. 원본 파일은 보관되어 있으며 덮어쓰지 않았습니다."
                failedHandle = target; handle = nil
                return
            }
            hydrating = true
            answer = draft.answer
            pickedKey = draft.pickedKey
            drawing = decoded.value
            zoom = CGFloat(draft.zoom)
            hydrating = false
            isWritable = true
        }
    }

    func flush() async -> Bool {
        guard ownsSession(), isWritable, let handle else { return !isWritable && error == nil }
        while ownsSession(), !Task.isCancelled, self.handle == handle {
            let capturedEdits = edits
            guard let draft = snapshot(fingerprint: handle.fingerprint) else { return false }
            pendingSourceID = draft.id
            guard PracticeWorkspaceDraftRepository.schedule(draft, for: handle) else { return false }
            let result = await PracticeWorkspaceDraftRepository.flush(slot: handle.slot)
            guard ownsSession(), self.handle == handle else { return false }
            guard result else {
                error = "풀이를 저장하지 못했습니다. 저장 공간을 확인한 뒤 화면을 닫기 전에 다시 시도해 주세요."
                return false
            }
            if edits == capturedEdits { error = nil; return true }
        }
        return false
    }

    /// Invalidate visual ownership when a view is replaced/account changes.
    /// The already scheduled old-account snapshot is flushed by AppStore before
    /// its slot switch; it must never be copied into the next account's handle.
    func detach() {
        loadID = UUID()
        handle = nil
        failedHandle = nil
        pendingSourceID = nil
        ownsSession = { false }
        isWritable = false
        isLoading = false
    }

    func resetPreservingOriginal() async -> Bool {
        guard ownsSession(), let failedHandle else { return false }
        let recoveryID = UUID(); loadID = recoveryID
        isLoading = true
        defer { if loadID == recoveryID { isLoading = false } }
        let result = await PracticeWorkspaceDraftRepository.resetPreservingOriginal(failedHandle)
        guard loadID == recoveryID, ownsSession(), !Task.isCancelled else { return false }
        guard result else {
            error = "원본 풀이를 안전하게 보관하지 못해 새 기록을 시작하지 않았습니다. 저장 공간을 확인한 뒤 다시 시도해 주세요."
            return false
        }
        handle = failedHandle
        self.failedHandle = nil
        hydrating = true
        answer = ""; pickedKey = nil; drawing = PKDrawing(); zoom = 1
        hydrating = false
        isWritable = true
        error = nil
        return true
    }

    private func changed() {
        guard !hydrating else { return }
        edits &+= 1
        pendingSourceID = nil
        guard ownsSession(), isWritable, let handle,
              let draft = snapshot(fingerprint: handle.fingerprint) else { return }
        pendingSourceID = draft.id
        if !PracticeWorkspaceDraftRepository.schedule(draft, for: handle) {
            error = "계정 상태가 바뀌어 풀이를 저장하지 않았습니다. 문제를 다시 열어 주세요."
        }
    }

    private func snapshot(fingerprint: String) -> PracticeWorkspaceDraftSource? {
        guard pickedKey.map({ allowedChoiceKeys.contains($0) }) ?? true,
              Self.drawingIsWithinBudget(drawing), answer.utf8.count <= PracticeWorkspaceDraft.maximumAnswerBytes,
              zoom.isFinite, (0.25...8).contains(zoom) else {
            error = "필기 양이 저장 한도를 넘었습니다. 현재 화면의 필기는 유지되지만 마지막 저장본은 갱신하지 못했습니다."
            return nil
        }
        let copy = DecodedDrawing(value: drawing)
        let answer = answer
        let pickedKey = pickedKey
        let zoom = Double(zoom)
        return PracticeWorkspaceDraftSource {
            try PracticeWorkspaceDraft(fingerprint: fingerprint, answer: answer,
                                       pickedKey: pickedKey, drawingData: copy.value.dataRepresentation(), zoom: zoom)
        }
    }

    private nonisolated static func drawingIsWithinBudget(_ drawing: PKDrawing) -> Bool {
        guard drawing.strokes.count <= 10_000 else { return false }
        var points = 0
        for stroke in drawing.strokes {
            points += stroke.path.count
            if points > 200_000 { return false }
        }
        if drawing.strokes.isEmpty { return true }
        let bounds = drawing.bounds
        return bounds.minX.isFinite && bounds.minY.isFinite && bounds.maxX.isFinite && bounds.maxY.isFinite
            && abs(bounds.minX) <= 100_000 && abs(bounds.minY) <= 100_000
            && abs(bounds.maxX) <= 100_000 && abs(bounds.maxY) <= 100_000
            && bounds.width <= 100_000 && bounds.height <= 100_000
    }
}
