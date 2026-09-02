import Foundation

@main
enum WeeklyMockDraftSyncStateCases {
    static func main() {
        saveCompletionKeepsNewerEditDirty()
        staleSaveResponseCannotApplyAnswers()
        persistedEnvelopeKeepsAnswersAndDirtyTogether()
        persistedDirtyDraftSurvivesNewInstance()
        terminalTransitionClearsPersistedDirty()
        failedSaveKeepsEveryEditDirty()
        loadStartedBeforeEditCannotOverwriteIt()
        loadStartedWithDirtyDraftCannotOverwriteIt()
        onlyNewestConcurrentLoadCanApply()
        print("Weekly mock draft revision and stale-response cases passed.")
    }

    private static func saveCompletionKeepsNewerEditDirty() {
        var state = WeeklyMockDraftSyncState()
        state.recordEdit()
        let firstRequest = state.beginSave()

        // 첫 저장이 await 중일 때 사용자가 답을 다시 바꾼 경우다.
        state.recordEdit()
        state.markSaveSucceeded(firstRequest)

        require(state.hasUnsavedChanges, "첫 응답이 최신 편집을 clean 처리하면 안 된다")
        require(state.hasEdits(after: firstRequest), "완료 직후 후속 저장을 요구해야 한다")

        let followUp = state.beginSave()
        state.markSaveSucceeded(followUp)
        require(!state.hasUnsavedChanges, "최신 snapshot의 ACK 뒤에만 clean이어야 한다")
        require(!state.hasEdits(after: followUp), "최신 snapshot 뒤에는 중복 저장이 없어야 한다")
    }

    private static func failedSaveKeepsEveryEditDirty() {
        var state = WeeklyMockDraftSyncState()
        state.recordEdit()
        let failedRequest = state.beginSave()
        state.recordEdit()

        // 실패 요청은 markSaveSucceeded를 호출하지 않는다.
        require(state.hasUnsavedChanges, "실패한 저장은 로컬 dirty 상태를 지우면 안 된다")
        require(state.hasEdits(after: failedRequest), "실패 중 생긴 최신 편집도 후속 저장 대상이어야 한다")
    }

    private static func staleSaveResponseCannotApplyAnswers() {
        var state = WeeklyMockDraftSyncState()
        state.recordEdit()
        let request = state.beginSave()
        require(state.canApplySaveResponse(request), "편집이 없으면 저장 응답을 적용할 수 있어야 한다")

        state.recordEdit()
        require(!state.canApplySaveResponse(request), "저장 중 새 답이 생기면 응답의 예전 answers를 적용하면 안 된다")
    }

    private static func persistedEnvelopeKeepsAnswersAndDirtyTogether() {
        let value = WeeklyMockPersistedDraft(answers: ["2"], dirty: true)
        let data = try! JSONEncoder().encode(value)
        require(WeeklyMockPersistedDraft.decode(data) == value, "답안과 dirty 메타는 같은 내구 payload로 복원되어야 한다")

        let legacy = try! JSONEncoder().encode(["1"])
        require(
            WeeklyMockPersistedDraft.decode(legacy, legacyDirty: true) ==
                WeeklyMockPersistedDraft(answers: ["1"], dirty: true),
            "기존 배열 draft와 분리 dirty 키도 마이그레이션해야 한다")
    }

    private static func persistedDirtyDraftSurvivesNewInstance() {
        var firstScreen = WeeklyMockDraftSyncState()
        firstScreen.recordEdit()
        require(firstScreen.hasUnsavedChanges, "저장 실패 전 로컬 편집은 dirty여야 한다")

        // 화면이 새로 만들어져도 UserDefaults에서 복원한 dirty 메타가 서버의
        // nonempty 예전 답을 적용하지 못하게 해야 한다.
        var reopenedScreen = WeeklyMockDraftSyncState(
            persistedDirty: firstScreen.hasUnsavedChanges)
        let staleServerLoad = reopenedScreen.beginLoad()
        require(reopenedScreen.shouldApplyMetadata(staleServerLoad), "재진입 시 최신 시험 상태 메타데이터는 적용해야 한다")
        require(reopenedScreen.shouldPreserveLocalDraft(staleServerLoad), "재진입 직후 서버 예전 답이 로컬 최신 draft를 덮으면 안 된다")

        var visibleState: String?
        if reopenedScreen.shouldApplyMetadata(staleServerLoad) {
            visibleState = "in-progress"
        }
        let visibleAnswers = WeeklyMockDraftRecovery.answers(
            server: ["1"],
            local: ["2"],
            current: [],
            count: 1,
            preserveLocal: reopenedScreen.shouldPreserveLocalDraft(staleServerLoad))
        require(visibleState == "in-progress", "dirty 복원 중에도 taking 상태로 화면을 열어야 한다")
        require(visibleAnswers == ["2"], "서버의 nonempty 예전 답보다 로컬 최신 답을 보존해야 한다")
        require(reopenedScreen.hasUnsavedChanges, "복원 답안을 화면에 적용한 것만으로 dirty를 지우면 안 된다")

        let upload = reopenedScreen.beginSave()
        reopenedScreen.markSaveSucceeded(upload)
        require(!reopenedScreen.hasUnsavedChanges, "복원 draft의 ACK 뒤에는 clean으로 내구 저장할 수 있어야 한다")
    }

    private static func loadStartedBeforeEditCannotOverwriteIt() {
        var state = WeeklyMockDraftSyncState()
        let request = state.beginLoad()
        state.recordEdit()

        require(state.isLatest(request), "편집은 GET 세대를 바꾸지 않으므로 loading은 종료할 수 있어야 한다")
        require(state.shouldApplyMetadata(request), "GET 시작 뒤 편집해도 최신 상태 메타데이터는 적용해야 한다")
        require(state.shouldPreserveLocalDraft(request), "GET 시작 뒤 입력한 답을 stale 서버 응답이 덮으면 안 된다")
    }

    private static func terminalTransitionClearsPersistedDirty() {
        var state = WeeklyMockDraftSyncState(persistedDirty: true)
        var persisted: WeeklyMockPersistedDraft? = .init(answers: ["2"], dirty: true)

        state.markTerminal()
        persisted = nil

        require(!state.hasUnsavedChanges, "submitted/expired 정본 뒤에는 sync 상태가 clean이어야 한다")
        require(persisted == nil, "terminal 회차의 과거 답안과 dirty envelope를 삭제해야 한다")
    }

    private static func loadStartedWithDirtyDraftCannotOverwriteIt() {
        var state = WeeklyMockDraftSyncState()
        state.recordEdit()
        let request = state.beginLoad()

        // GET과 PATCH가 겹쳐 PATCH가 먼저 성공해도 GET body는 그보다 오래됐을 수 있다.
        state.markSaveSucceeded(state.beginSave())
        require(state.shouldPreserveLocalDraft(request), "dirty 상태에서 시작한 GET은 뒤늦게 clean이 되어도 예전 answers를 적용하면 안 된다")
    }

    private static func onlyNewestConcurrentLoadCanApply() {
        var state = WeeklyMockDraftSyncState()
        let older = state.beginLoad()
        let newest = state.beginLoad()

        require(!state.isLatest(older), "이전 GET은 최신 loading 상태를 종료하면 안 된다")
        require(state.isLatest(newest), "최신 GET은 loading 상태를 종료할 수 있어야 한다")
        require(!state.shouldApplyMetadata(older), "늦게 도착한 이전 GET 응답은 폐기해야 한다")
        require(state.shouldApplyMetadata(newest), "편집이 없으면 최신 GET 메타데이터를 적용해야 한다")
        require(!state.shouldPreserveLocalDraft(newest), "clean 최신 GET은 서버 answers를 적용해야 한다")
    }

    private static func require(
        _ condition: @autoclosure () -> Bool,
        _ message: String
    ) {
        guard condition() else {
            fputs("FAIL: \(message)\n", stderr)
            exit(1)
        }
    }
}
