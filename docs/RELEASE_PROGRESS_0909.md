# Release integration status — 2026-09-09

This is an implementation and verification record, not an App Store approval.
It supersedes the 0908 audit's statements that Kakao editor access is unavailable
and that retained community posts/comments still keep their original text.

## Verified in this batch

- Final local contract suite: 191/191 PASS. The new root-level Kakao URL query
  scheme placement assertion was rerun separately after the full suite.
- iPad simulator: defense entry → explicit lobby start → DEFENDER question,
  timer and left problem/right note workspace. Synthetic data only.
- Profile photo: web-original six vector avatar assets, normalized 512 px JPEG
  preparation (9 orientation/shape cases plus invalid image), immediate shared
  cache update with revision and account-ownership protection.
- Coach: all objective/subjective correct/incorrect feedback honors selected
  tone; silent mode and consecutive-error softening retained. Mutation requests
  serialized; failed saves restore the prior choice.
- Arena: role-consistent start/question packs, stable timer across advancement,
  duplicate regular-width menus removed, matched-state wording corrected.
- Kakao: existing app 1539001 Editor access verified; existing native key's
  kr.matths.app bundle id and App Store id 6803569629 saved in the console.
  Official SDK 2.29.0 integrates Talk/account login and callback ownership.
  SDK token is verified server-side for app id, user id and expiration;
  existing PKCE grant exchange remains the Matths session authority.
  Unregistered accounts retain existing web registration/consent flow.
- Kakao cancellation/late/duplicate callbacks tested with controlled SDK
  boundaries. Server token verification and actual grant controller tested
  with isolated DB; no real provider credentials or operating accounts used.
- Kakao and Alamofire licenses and privacy manifests included in device build.
- Device Debug build 21 and production-identity development signing preflight
  passed. This is not App Store distribution signing or a completed login.
- Backend batch 024bb3e pushed to existing main: native Kakao, 13-course release,
  teacher role/invitation parity, AASA route and withdrawal text erasure.
- Isolated DB verified: native invitations/role revocation, withdrawal erasure
  with other authors unchanged, existing withdrawal policy, native Kakao grants.

## Unresolved external verification and release gates

- App Store Connect browser authentication expired; current page redirects
  to login with authResult=FAILED. No metadata posted or review submitted.
- Authorized iPhone installation failed with CoreDevice 4000 / connection reset.
  Existing phone installation is not claimed to include this build.
- Operating providers endpoint still lacks nativeConfigured; AASA is still
  HTTP 404 at the last check after backend push. Git push is not server deployment.
  Privacy and terms URLs returned HTTP 200.
- Actual Apple/Kakao login, latest Google retest, real profile upload/relogin,
  StoreKit Sandbox lifecycle and cross-account transaction tests remain NOT_RUN.
- Qwen2.5-VL-3B commercial license is still unverified. Official pinned license
  requires requesting commercial rights. No large replacement model was downloaded
  and no paid feature was silently disabled or relabeled as licensed.
- Whole-app current operating-account web/iOS parity and complete device UI
  matrix are not established by the passing source/contract suite.
- Release archive/distribution signing and TestFlight upload remain outstanding.

No production account deletion, real matchmaking, purchase, payout, or user
content cleanup was used as a test. No new branch was created.
