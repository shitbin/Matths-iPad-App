import Foundation

/// Owned once by the screen's State, and therefore shared by View values
/// captured on opposite sides of an async file read. Environment ScenePhase
/// belongs to a rendered View value and must not decide a late task's restart.
@MainActor final class KiceTimerLifecycle {
    private(set) var isVisible = false
    private(set) var isSceneActive = false
    var permitsRunning: Bool { isVisible && isSceneActive }

    func appeared(sceneIsActive: Bool) {
        isVisible = true
        isSceneActive = sceneIsActive
    }
    func sceneChanged(isActive: Bool) { isSceneActive = isActive }
    func disappeared() { isVisible = false }
}
