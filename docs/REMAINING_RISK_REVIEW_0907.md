# Residual audit: five concrete work candidates

> Historical discovery report, retained for the original evidence and ownership boundaries. Arena durability, conditional attendance and the native Pro pipeline have since received implementation and execution work. Read [the current implementation/verification status](IMPLEMENTATION_AND_VERIFICATION_0907.md) before treating any “next task” below as still unimplemented. AI semantic quality and commercial licensing remain unresolved; an implementation fix is not release approval.

Reviewed the original 23 findings and 24 feature families against the current
shared dirty source, not only the earlier clean `64d9055` completion report.
Inputs read: master report, feature QA, technical blueprint, web parity request,
conflict matrix, parity test matrix and `COMPLETION_AUDIT_2026-09-07.md`.

The original documents contain historical/static candidates, not authority to
rewrite working server policy. Source and new runtime evidence take precedence
when adjudicating whether those candidates are still open.

## 1. Student academy account/permission boundary

- Original mapping: SEC-001, STATE-001; F14, F22, F24.
- Found: leave/join/check-in built requests without a frozen owner; a queued
  account-A leave could be constructed with B's current credential. Student
  403 errors also left the selected week and file preview visible.
- Current disposition: **fixed in this follow-up; focused model tests PASS**.
  `AcademyScreen.swift` now checks owner + generation + exact operation ID,
  clears protected state on 403, and preserves it on 503.
- Remaining next check: latest integrated simulator build with two isolated
  accounts; open A's leave confirmation, switch account, invoke old callback;
  then revoke membership during a week/file view and verify the 403 transition.
  No live operational student account is necessary.

## 2. Weekly official mock mutations and late responses

- Original mapping: SEC-001, ARC-001, STATE-001; F08, F22, F24.
- Found: only account-slot comparisons surrounded start/draft/submit/expire/
  representative/evidence/objection calls; wrappers still read current auth.
- Current disposition: **fixed in this follow-up; API/gate tests PASS**.
  `WeeklyMockScreen.swift`, `WeeklyMockAPI.swift` and
  `WeeklyMockOperationGate.swift` retain the mounted owner and reject stale work.
- Remaining next check: actual SwiftUI center→attempt→result/selection and
  integrity/objection flows under delayed replies, A→B→A, 403 and 503. Validate
  protected-content eviction, retained drafts, picker retirement and one request
  after 20 taps. Current host API/gate checks do not replace this UI evidence.

## 3. Arena local drawing, answer and evidence durability

- Original mapping: STATE-001, LAY-003, AI-001 auxiliary inputs; F06, F10, F24.
- Concrete source gap remains: `GoatArenaMatchPlayScreen.swift`'s
  `GoatArenaSolutionBoardDraftStore.load/save` turns read/decode failure into nil
  and discards write errors with `try?`. `installSolutionDrawing` converts an
  unreadable PKDrawing to a blank one; `solutionDrawingChanged` then clears its
  save error regardless of whether disk save succeeded. The match-draft
  `readAll/write` and `GoatArenaEvidenceDraftStore.readAll/write` similarly turn
  corrupt collections into empty collections and silently overwrite on save.
- This is separate from the newly completed ordinary practice/official
  assessment draft repositories; those must not be relabeled unimplemented.
- Next task: inject corrupt/truncated data and disk-write denial into these
  exact Arena stores, verify original-byte retention and visible recovery,
  then migrate their failure contract narrowly. Add bounded PKDrawing size and
  canvas-extent rejection tests before attempting image export. Do not change
  Arena scoring, evidence deadlines or settlement policy.

## 4. Cross-role attendance stale-write verification

- Original mapping: ROLE-001, STATE-001; F14, F15, F16, F24.
- Current code has independent staff workspaces, draft merge, 403 eviction and
  owner guards. These are implemented, not missing.
- Remaining risk: `TeacherAcademyScreenModel.saveAttendance` submits the whole
  roster, while `saveTeacherAcademyAttendance` carries no baseline version or
  conditional-write field. Pure `StaffDraftMerge` tests do not prove a GET→
  concurrent student check-in/admin override→teacher save sequence is safe.
- Classification: **server-integrated evidence gap, not a confirmed server
  overwrite bug**. Root's weekday mapping correction and official-assessment
  expectedRevision work are separate from this scenario.
- Next task: isolated real Mongo/HTTP, three roles; teacher loads, student checks
  in, admin corrects another row, teacher edits one row and saves. Assert all
  unrelated changes and audit entries remain. If it fails, agree an additive
  conditional-write contract with the backend owner; do not invent client rules.
  Extend to partial-success bulk operations with a failing refresh.

## 5. Actual Pro vision→reasoning and interrupted-stage execution

- Original mapping: AI-001, ARC-004; F12, F13, F24.
- Already proven: one approved DeepSeek text GGUF's actual native generation,
  cancellation, generation after cancel, unload and lease return; see
  `NATIVE_LLM_SIMULATOR_SMOKE_0907.md`. Artifact guards, shared leases, successful
  JSON checkpoints and recovery have executable synthetic/disk tests.
- Remaining evidence: the actual approved vision/projector path, image crops,
  vision→text engine replacement and resuming a real successful inference stage
  have not been exercised by that text-only run. The 20-stage JSON journal test
  is not 20 real image analyses or a measured native model switch.
- Next task: simulator only; first one synthetic sheet, approved pinned model
  pair and verified hashes, hard disk/RAM/time bounds, cancellation at a real
  stage boundary and restart with checkpoint reuse. Escalate to bounded repeated
  images only after measuring single-image load/unload. Model replacement or
  arbitrary private/large Downloads models are not authorized by this review.

## Excluded or deliberately not reopened

- Full VoiceOver/large-text/high-contrast/keyboard/pointer matrix is deferred per
  the user's priority. Physical devices, physical Pencil/thermal and real
  payment transactions remain unverified under the simulator-only instruction;
  they are not represented as completed or proposed as automatic next actions.
- First-learning local persistence, remote GET/CAS/conflict handling and actual
  canonical receipt now exist (`FirstLearningJourney*`, `MobileFeatureAPI`).
- Official assessment local recovery and expectedRevision forwarding now exist
  (`AssessmentDraftRecovery`, `AssessmentSyncAPI`, current AppStore paths).
- StoreKit purchase admission, community idempotency, protected writes, hosted
  web account isolation and WebView duplicate-load fixes have new evidence.
- A missing national-exam schedule API remains an explicit server dependency,
  not permission to populate invented dates. Broad architectural or visual
  refactoring by file size alone ranks below the concrete risks above.

The only product edits authorized during this review were items 1 and 2. Items
3–5 are handed to the root for allocation. The review itself performed no
simulator operation, server mutation, commit or push.
