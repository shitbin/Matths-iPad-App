import Foundation

@MainActor
private final class DelayedCurriculumSpeechProvider: CurriculumSpeechProviding {
    weak var delegate: (any CurriculumSpeechProviderDelegate)?
    var isAvailable = true
    var isSpeaking = false
    var isPaused = false
    private(set) var requests: [CurriculumSpeechRequest] = []

    func speak(_ request: CurriculumSpeechRequest) {
        requests.append(request)
        isSpeaking = true
        isPaused = false
    }

    func pause() -> Bool {
        guard isSpeaking, !isPaused else { return false }
        isPaused = true
        return true
    }

    func resume() -> Bool {
        guard isPaused else { return false }
        isPaused = false
        return true
    }

    func stop() {
        isSpeaking = false
        isPaused = false
        // 의도적으로 callback을 폐기하지 않는다. 실제 원격/AV adapter가 stop 뒤에도
        // 늦은 완료를 배달하는 조건을 재현한다.
    }

    func finish(_ request: CurriculumSpeechRequest) {
        delegate?.curriculumSpeechProviderDidFinish(self, request: request)
    }
}

private final class RecordingCurriculumCheckpointStore: CurriculumNarrationCheckpointStoring {
    private(set) var values: [String: Int] = [:]
    private(set) var savedSlots: [String] = []

    func load(conceptID: String, maximum: Int, accountSlot: String) -> Int {
        let value = values["\(accountSlot)|\(conceptID)"] ?? 0
        return value >= 0 && value < maximum ? value : 0
    }

    func save(_ index: Int, conceptID: String, accountSlot: String) {
        values["\(accountSlot)|\(conceptID)"] = index
        savedSlots.append(accountSlot)
    }

    func clear(conceptID: String, accountSlot: String) {
        values.removeValue(forKey: "\(accountSlot)|\(conceptID)")
    }
}

@main
struct CurriculumSpeechPlayerCases {
    @MainActor
    static func main() {
        precondition(CurriculumNarrationTimingPolicy.systemSpeechRateFactor == 0.55)
        precondition(CurriculumNarrationTimingPolicy.approximateMinimumSeconds == 230)
        precondition(CurriculumNarrationTimingPolicy.approximateMaximumSeconds == 360)
        precondition(SystemCurriculumSpeechProvider.preferredFemaleVoice()?.gender == .female)

        let scenes = CurriculumStorySceneKind.allCases.enumerated().map { index, kind in
            CurriculumStudentStoryScene(
                id: "scene-\(index)",
                kind: kind,
                title: kind.label,
                subtitle: "학생 화면에 보이는 짧고 명확한 자막입니다.",
                narration: "첫 문장은 판단 기준을 설명합니다. 두 번째 문장은 다음 문제에서 꺼낼 질문을 남깁니다."
            )
        }
        let story = CurriculumStudentStory(
            courseID: "course",
            unitID: "unit",
            conceptID: "concept",
            revision: 1,
            title: "테스트 기억선",
            openingQuestion: "무엇을 먼저 판단할까요?",
            estimatedSeconds: 300,
            scenes: scenes
        )
        let provider = DelayedCurriculumSpeechProvider()
        let checkpoints = RecordingCurriculumCheckpointStore()
        var accountSlot = "acct-first"
        let player = CurriculumNarrationPlayer(
            provider: provider,
            checkpoints: checkpoints,
            accountSlotProvider: { accountSlot }
        )

        player.load(story)
        player.play()
        let staleRequest = provider.requests[0]
        player.restart()
        let restartedRequest = provider.requests[1]
        precondition(staleRequest.id != restartedRequest.id)

        provider.finish(staleRequest)
        precondition(player.currentChunkIndex == 0, "늦은 이전 완료가 새 재생을 건너뛰었습니다.")
        provider.finish(restartedRequest)
        precondition(player.currentChunkIndex == 1)

        // load 시점 계정에 체크포인트를 고정한다. 재생 중 로그아웃/계정 전환이
        // 일어나도 이전 학생의 진행을 새 슬롯에 쓰면 안 된다.
        accountSlot = "guest"
        player.stopAndPreserve()
        precondition(checkpoints.savedSlots.allSatisfy { $0 == "acct-first" })

        // story가 사라지는 fail-closed 전환은 이전 음성과 하이라이트도 함께 닫는다.
        player.unload()
        precondition(player.state == .idle)
        precondition(player.currentSceneID == nil)

        print("Curriculum speech player cases passed: request identity, slot capture, and unload.")
    }
}
