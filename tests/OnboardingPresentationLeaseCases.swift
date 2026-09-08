import Foundation
@main struct OnboardingPresentationLeaseCases {
    @MainActor static func main() async {
        var count = 0
        func check(_ condition: @autoclosure () -> Bool, _ label: String) {
            guard condition() else { print("FAIL: " + label); exit(1) }; count += 1
        }
        let store = Store(), first = Harness(Store())
        let onboarding = Harness(store), nativeA = UUID()
        store.claimNativeTutorialPresentation(nativeA)
        onboarding.ownerTaskStarted()
        check(store.nativeTutorialPresentationOwner == nativeA && store.isTutorialPresentationActive,
              "A non-presented first-learning owner task must not erase the native tutorial lease")
        check(!onboarding.canShow, "First-learning cannot present above a native tutorial")
        onboarding.presented = true
        onboarding.ownerTaskStarted()
        check(!onboarding.presented && store.nativeTutorialPresentationOwner == nativeA,
              "Retired first-learning presentation does not own a newer native lease")
        store.releaseNativeTutorialPresentation(nativeA)
        check(onboarding.canShow, "First-learning remains eligible when no native tutorial owns presentation")
        first.presented = true
        first.store.isTutorialPresentationActive = true
        first.ownerTaskStarted()
        check(!first.presented && !first.store.isTutorialPresentationActive,
              "The actual first-learning owner still releases its own presentation")
        first.store.isTutorialPresentationActive = true
        first.ownerTaskStarted()
        check(first.store.isTutorialPresentationActive,
              "Unpresented first-learning does not release another overlay's shared flag")
        let queued = Task { @MainActor in onboarding.ownerTaskStarted() }
        let nativeB = UUID()
        store.claimNativeTutorialPresentation(nativeB)
        await queued.value
        check(store.nativeTutorialPresentationOwner == nativeB && store.isTutorialPresentationActive,
              "Queued profile hydration cannot revoke a native tutorial claimed before task execution")
        check(!onboarding.canShow, "Native ownership still blocks late first-learning presentation")
        print("First-success production owner-task/reset/native lease contract: PASS (\(count) cases)")
    }
}
