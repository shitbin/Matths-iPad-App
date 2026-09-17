@main
enum NativeAuthenticationPresentationPolicyCases {
    static func main() {
        precondition(
            !NativeAuthenticationPresentationPolicy.shouldCancelOnAuthScreenDisappear(
                isBusy: true,
                sessionPublished: false
            ),
            "a transient native presentation must not cancel its own attempt"
        )
        precondition(
            !NativeAuthenticationPresentationPolicy.shouldCancelOnAuthScreenDisappear(
                isBusy: true,
                sessionPublished: true
            ),
            "publishing the session must not cancel the task that is finishing sign-in"
        )
        precondition(
            !NativeAuthenticationPresentationPolicy.shouldCancelOnAuthScreenDisappear(
                isBusy: false,
                sessionPublished: true
            ),
            "a completed session owns the root transition"
        )
        precondition(
            NativeAuthenticationPresentationPolicy.shouldCancelOnAuthScreenDisappear(
                isBusy: false,
                sessionPublished: false
            ),
            "an idle unauthenticated teardown must still clean stale native state"
        )
        print("Native authentication presentation lifecycle cases passed.")
    }
}
