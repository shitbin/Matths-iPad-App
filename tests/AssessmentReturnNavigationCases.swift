import Foundation

@MainActor final class AppStore {
    enum Route { case paper, assess, curriculum, home }
    var generation = UUID()
    var currentAttemptID: String? = "attempt-a"
    var assessmentReturnRoute: Route = .curriculum
    var route: Route = .paper
    var draftFlushes = 0
    func captureAccountSessionBoundary() -> UUID { generation }
    func ownsCurrentAccountSession(_ value: UUID) -> Bool { generation == value }
    func flushAssessmentDraft() async { draftFlushes += 1 }
}

@MainActor final class Scratchpad {
    var succeeds = true
    var pauses = false
    var calls = 0
    var pending: CheckedContinuation<Bool, Never>?
    func flush() async -> Bool {
        calls += 1
        if pauses { return await withCheckedContinuation { pending = $0 } }
        return succeeds
    }
    func finish() { pending?.resume(returning: succeeds); pending = nil }
}

@MainActor final class PaperHarness {
    let store = AppStore()
    let scratchpad = Scratchpad()
}

@main enum AssessmentReturnNavigationCases {
    @MainActor static func yieldUntil(_ predicate: () -> Bool) async {
        for _ in 0..<10_000 {
            if predicate() { return }
            await Task.yield()
        }
        fatalError("actual close action did not reach expected state")
    }
    @MainActor static func settle() async { for _ in 0..<300 { await Task.yield() } }

    @MainActor static func main() async {
        let course = PaperHarness()
        course.exerciseClose()
        await yieldUntil { course.store.route == .curriculum }
        precondition(course.scratchpad.calls == 1 && course.store.draftFlushes == 1)

        let official = PaperHarness()
        official.store.assessmentReturnRoute = .assess
        official.exerciseClose()
        await yieldUntil { official.store.route == .assess }

        let failedSave = PaperHarness()
        failedSave.scratchpad.succeeds = false
        failedSave.exerciseClose(); await settle()
        precondition(failedSave.store.route == .paper && failedSave.store.draftFlushes == 0,
                     "failed memo persistence must not navigate away")

        let missing = PaperHarness()
        missing.store.currentAttemptID = nil
        missing.exerciseClose()
        await yieldUntil { missing.store.route == .curriculum }
        precondition(missing.scratchpad.calls == 0 && missing.store.draftFlushes == 0)

        for mutation in 0..<3 {
            let late = PaperHarness()
            late.scratchpad.pauses = true
            late.exerciseClose()
            await yieldUntil { late.scratchpad.pending != nil }
            switch mutation {
            case 0: late.store.generation = UUID(); late.store.route = .home
            case 1: late.store.currentAttemptID = "attempt-b"
            default: late.store.route = .home
            }
            let expected = late.store.route
            late.scratchpad.finish(); await settle()
            precondition(late.store.draftFlushes == 0,
                         "a stale close must not invoke another account or paper's draft flush")
            precondition(late.store.route == expected,
                         "late close from another account, attempt or screen must not steal navigation")
        }
        print("PASS: actual assessment close action preserves both origins, saves first, handles absent paper and rejects late account/attempt/navigation callbacks")
    }
}
