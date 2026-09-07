import Foundation
import SwiftUI

@MainActor final class TimerStore {
    struct Attempt { let id: String; let elapsedMs: Int }
    struct Receipt { let elapsedMs: Int }
    var kiceCurrentAttempt: Attempt? = .init(id: "restored-attempt", elapsedMs: 529_000)
    var kiceCurrentReceipt: Receipt?
    var canEditKice = true
}
@MainActor final class TimerScreenState { var restoredAttemptID: String? }
@MainActor struct KiceTimerScreenHarness {
    let store: TimerStore
    let timer: ExamTimer
    let state: TimerScreenState
    let timerLifecycle: KiceTimerLifecycle
    var scenePhase: ScenePhase
    var restoredAttemptID: String? {
        get { state.restoredAttemptID }
        nonmutating set { state.restoredAttemptID = newValue }
    }
}

@main enum KiceTimerResumeCases {
    @MainActor static func main() async throws {
        let store = TimerStore(), timer = ExamTimer(), state = TimerScreenState()
        let lifecycle = KiceTimerLifecycle()
        lifecycle.appeared(sceneIsActive: false)
        let capturedAtLaunch = KiceTimerScreenHarness(store: store, timer: timer, state: state, timerLifecycle: lifecycle, scenePhase: .inactive)
        let activeRender = KiceTimerScreenHarness(store: store, timer: timer, state: state, timerLifecycle: lifecycle, scenePhase: .active)
        // The file-loading task retained the first view value before its await.
        // A newer rendered view processes activation before that read returns.
        lifecycle.sceneChanged(isActive: true)
        activeRender.syncTimerAvailability(restore: true)
        precondition(timer.isRunning && timer.elapsedSeconds == 529)
        capturedAtLaunch.syncTimerAvailability(restore: true)
        if CommandLine.arguments.contains("--expect-stale") {
            precondition(!timer.isRunning && timer.elapsedSeconds == 529)
            print("REPRODUCED: late restore uses captured inactive ScenePhase and stops an already resumed 08:49 timer.")
        } else {
            precondition(timer.isRunning, "late restore must use the latest lifecycle, not a captured View environment")
            try await Task.sleep(for: .milliseconds(1100))
            precondition(timer.exactElapsedMs() >= 530_000, "restored 08:49 actually advances without a manual resume control")

            lifecycle.sceneChanged(isActive: false)
            activeRender.syncTimerAvailability()
            precondition(!timer.isRunning, "a stale active View cannot restart a now-inactive scene")
            let paused = timer.exactElapsedMs()
            try await Task.sleep(for: .milliseconds(60))
            precondition(timer.exactElapsedMs() == paused, "background time is not counted as active study")
            lifecycle.sceneChanged(isActive: true)
            capturedAtLaunch.syncTimerAvailability()
            precondition(timer.isRunning, "foreground resumes automatically even through a previously inactive View value")

            store.canEditKice = false
            activeRender.syncTimerAvailability()
            precondition(!timer.isRunning, "grade/storage/account gates still stop the clock")
            store.canEditKice = true
            activeRender.syncTimerAvailability()
            precondition(timer.isRunning)
            lifecycle.disappeared()
            activeRender.syncTimerAvailability(restore: true)
            precondition(!timer.isRunning, "late file completion cannot revive a disappeared screen")
            lifecycle.sceneChanged(isActive: true)
            capturedAtLaunch.syncTimerAvailability()
            precondition(!timer.isRunning, "offscreen activation remains paused")

            lifecycle.appeared(sceneIsActive: true)
            store.kiceCurrentReceipt = .init(elapsedMs: 529_000)
            store.canEditKice = false
            activeRender.syncTimerAvailability(restore: true)
            precondition(!timer.isRunning && timer.elapsedSeconds == 529, "durable result retains its frozen time")
            print("KICE actual ExamTimer/screen resume PASS: late inactive capture, active time advancement, pause/foreground resume, edit gate, disappearance and frozen results.")
        }
        timer.pause()
    }
}
