// NativeAuthenticationPresentationPolicy.swift
//
// Apple authorization and KakaoTalk temporarily take presentation ownership
// away from AuthScreen. SwiftUI can report that as `onDisappear` even though
// the user has not left authentication. Cancelling there retires the exact
// attempt whose native callback is about to arrive, and the cancellation is
// deliberately silent in AuthScreen.

enum NativeAuthenticationPresentationPolicy {
    /// Cleanup is needed only when the authentication screen is genuinely idle
    /// and has not already published a server session.
    ///
    /// A busy native provider owns the transient disappearance. Email entry and
    /// switching providers explicitly cancel before navigating, so preserving a
    /// busy attempt here cannot let an old provider overwrite the next one.
    static func shouldCancelOnAuthScreenDisappear(
        isBusy: Bool,
        sessionPublished: Bool
    ) -> Bool {
        !isBusy && !sessionPublished
    }
}
