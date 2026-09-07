import Foundation
import Combine

@MainActor
final class FirstLearningJourneyStore: ObservableObject {
    static let shared = FirstLearningJourneyStore()
    @Published var journey: FirstLearningJourney
    @Published var error: String?
    @Published var goal: LearningGoal
    #if os(iOS) || MOBILE_SYNC_TEST
    @Published var syncMessage: String?
    @Published var remoteSyncNeedsRetry = false
    @Published var remoteConflict: FirstLearningRemoteEnvelope?
    @Published var isSyncing = false
    var remoteCache: FirstLearningSyncCache?
    var remoteTask: Task<Void, Never>?
    var remoteGeneration = UUID()
    var remoteCacheBlocked = false
    var suppressRemoteScheduling = false
    #endif
    private var scopeSubscription: AnyCancellable?
    private var blockedByCorruptFile = false
    private var needsRetry = false
    static let fileName = "first-learning-journey-v2.json"

    private init() {
        journey = .init(slot: DataScope.slot)
        goal = .school
        load(slot: DataScope.slot)
        scopeSubscription = NotificationCenter.default.publisher(for: DataScope.didSwitchNotification)
            .sink { [weak self] _ in
                MainActor.assumeIsolated { self?.load(slot: DataScope.slot) }
            }
    }
    func goalKey(_ slot: String) -> String { "matths.learning.goal.v2." + slot }
    func setGoal(_ value: LearningGoal) {
        guard journey.slot == DataScope.slot else { return }
        goal = value
        UserDefaults.standard.set(value.rawValue, forKey: goalKey(journey.slot))
    }
    private func load(slot: String) {
        #if os(iOS) || MOBILE_SYNC_TEST
        resetRemoteSession()
        #endif
        error = nil; blockedByCorruptFile = false; needsRetry = false
        let defaults = UserDefaults.standard
        goal = defaults.string(forKey: goalKey(slot)).flatMap(LearningGoal.init(rawValue:))
            ?? LearningGoal(legacyTitle: defaults.string(forKey: "matths.demo.onboarding.v1." + slot + ".goal"))
        let url = DataScope.url(Self.fileName, for: slot)
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                let value = try FirstLearningJourneyPersistence.load(from: url, slot: slot)
                journey = value
            } catch {
                journey = .init(slot: slot, goal: goal)
                blockedByCorruptFile = true
                self.error = "첫 학습 기록을 읽지 못했습니다. 기존 기록은 보관되어 있습니다. 처음부터 다시 시작할 수 있어요."
            }
        } else {
            journey = .init(slot: slot, goal: goal)
            if defaults.string(forKey: "matths.demo.onboarding.v1." + slot + ".pending") == "SKIP" {
                journey.skip()
            }
        }
    }

    /// Persist first, publish second. A failed write never advances the UI.
    @discardableResult
    func update(_ mutation: (inout FirstLearningJourney) -> Void) -> Bool {
        guard journey.slot == DataScope.slot, !blockedByCorruptFile else { return false }
        var next = journey
        mutation(&next)
        guard next.isValid else { return false }
        do {
            try FirstLearningJourneyPersistence.save(next, to: DataScope.url(Self.fileName, for: next.slot))
            journey = next; error = nil; needsRetry = false
            #if os(iOS) || MOBILE_SYNC_TEST
            scheduleRemoteSync()
            #endif
            return true
        } catch {
            self.error = "첫 학습 기록을 저장하지 못했습니다. 저장 공간을 확인한 뒤 다시 시도해 주세요."
            return false
        }
    }

    func recordCheck(slot: String, conceptID: String?, seed: UInt64, problemID: String, correct: Bool) {
        guard slot == journey.slot, journey.stage == .checks,
              seed == journey.seed,
              conceptID == journey.conceptID, journey.expectedProblemIDs.contains(problemID),
              journey.checkedAnswers[problemID] == nil else { return }
        var recorded = journey
        guard recorded.recordAnswer(slot: slot, conceptID: conceptID, problemID: problemID, correct: correct) else { return }
        if !update({ $0 = recorded }) {
            // The existing learning boundary has already accepted this answer.
            // Retain it in memory and expose failure; do not replay it in this
            // session simply because the navigation receipt could not be saved.
            journey = recorded; needsRetry = true
        }
    }
    @discardableResult
    func retryPendingSave() -> Bool {
        !needsRetry || update { _ in }
    }

    func restart() {
        guard journey.slot == DataScope.slot else { return }
        do {
            let original = DataScope.url(Self.fileName, for: journey.slot)
            if FileManager.default.fileExists(atPath: original.path) {
                let backup = original.deletingPathExtension().appendingPathExtension("backup-\(UUID().uuidString).json")
                try FileManager.default.copyItem(at: original, to: backup)
            }
            blockedByCorruptFile = false
            update { $0 = .init(slot: DataScope.slot, goal: goal) }
        } catch {
            self.error = "기존 기록을 안전하게 보관하지 못했습니다. 저장 공간을 확인해 주세요."
        }
    }
}
