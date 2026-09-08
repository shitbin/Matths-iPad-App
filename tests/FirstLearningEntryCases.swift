import Foundation

@MainActor enum DataScope { static var slot = "A" }
@MainActor final class EntryModel {
    var journey = FirstLearningJourney(slot: "A")
    var remoteConflict: Bool?
    var writesSucceed = true
    var writes = 0
    func update(_ change: (inout FirstLearningJourney) -> Void) -> Bool {
        guard writesSucceed else { return false }
        var candidate = journey
        change(&candidate)
        guard candidate.isValid else { return false }
        journey = candidate
        writes += 1
        return true
    }
}
@MainActor final class EntryStore {
    enum Route { case home, curriculum }
    var route: Route = .home
}
@MainActor final class EntryHarness {
    let model = EntryModel()
    let store = EntryStore()
    var dismissed = false
    var receipts: [String] = []
    func deferJourney() { dismissed = true; store.route = .home }
    func saveTutorialReceipt() { if let action = model.journey.pendingTutorialAction { receipts.append(action) } }
}

@main struct FirstLearningEntryCases {
    @MainActor static func main() {
        let direct = EntryHarness()
        direct.exerciseBrowse()
        precondition(direct.store.route == .curriculum && direct.dismissed)
        precondition(direct.model.journey.stage == .skipped && direct.receipts == ["SKIP"])
        precondition(direct.model.journey.checkedAnswers.isEmpty && !direct.model.journey.topicRead)
        precondition(direct.model.journey.serverConfirmedAt == nil && direct.model.journey.confirmedProgress == nil)
        direct.exerciseBrowse()
        precondition(direct.receipts == ["SKIP"] && direct.model.writes == 1)
        let conflict = EntryHarness()
        conflict.model.remoteConflict = true
        conflict.exerciseBrowse()
        precondition(!conflict.dismissed && conflict.model.journey.stage == .goal && conflict.receipts.isEmpty)
        let failed = EntryHarness()
        failed.model.writesSucceed = false
        failed.exerciseBrowse()
        precondition(!failed.dismissed && failed.store.route == .home && failed.receipts.isEmpty)
        let inProgress = EntryHarness()
        inProgress.model.journey.stage = .diagnosis
        inProgress.exerciseBrowse()
        precondition(inProgress.model.journey.stage == .diagnosis && !inProgress.dismissed)
        let other = EntryHarness()
        DataScope.slot = "B"
        other.exerciseBrowse()
        precondition(other.receipts.isEmpty && !other.dismissed && other.model.writes == 0)
        print("First learning course-first entry: actual method skip receipt, no false progress, conflict, storage, stage and owner guards PASS")
    }
}
