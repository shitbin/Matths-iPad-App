# Student academy and weekly mock ownership — 2026-09-07

The residual audit found two native families still relying on a current global
Bearer at asynchronous wrapper entry. These paths now retain the account/session
owner before the UI creates a Task and explicitly forward its authorization.
This is not a production deployment or a complete weekly/academy E2E verdict.

## Student academy

`AcademyScreen` binds an `AccountRequestOwner` when mounted. Its `run` function
captures that value before Task creation. The leave confirmation retains the
owner from the time the confirmation opens. Account change and screen retirement
invalidate outstanding work and clear protected state.

`AcademyScreenModel` checks that owner before sending and before applying every
load, join, leave, check-in, week and download response. Exact load/week/action/
download IDs reject reordered or retired work; duplicate mutations have one
admission. A confirmed membership mutation also invalidates an overlapping old
dashboard GET. Closing a week prevents late week/file responses from reopening
it. HTTP 403 clears dashboard, week, preview, invitation/attendance inputs and
consent. Ordinary transport/5xx errors preserve existing content and input.

All six student JSON API wrappers accept a caller-evaluated authorization
snapshot; the existing scoped download wrapper retains its owner and cache.
Teacher/admin APIs and the common token implementation were not edited here.

## Weekly mock

The mounted weekly screen passes one immutable owner to center, attempt, result,
representative selection, integrity and objection views. A session change gives
the child tree a new identity. The 14 JSON/PDF/multipart wrappers explicitly
forward captured authorization; no path substitutes a later account token.

`WeeklyMockOperationGate` owns per-screen operation IDs and an epoch. Reads are
latest-only; mutation/download admissions are exclusive per operation. A retired
callback or finish cannot mutate/release a new operation. Reappearance uses a new
epoch. Existing weekly draft revision and dirty-answer merge policy is retained.

HTTP 403 clears protected in-memory exam, PDF, result, integrity and objection
state and invalidates pending callbacks. Transport errors do not clear the
existing exam/draft; in particular a foreground GET failure no longer sets the
current attempt to nil. File-import callbacks require the still-current owner.
Existing official timing, grading, representative-selection and idempotency
semantics remain server-owned.

## Executed evidence and limitations

```sh
sh tests/run-student-academy-ownership.sh
sh tests/run-weekly-mock-ownership.sh
```

- Student suite compiles the exact `AcademyScreenModel` source prefix with only
  its SwiftUI umbrella import replaced by Foundation/Combine. The API transport
  and the DTO fields consumed by this model are test doubles, not a live server.
- Student executed checks: 20 queued cross-account leave requests send zero;
  A→B→A rejection; 403 data eviction versus 503 preservation; reverse GET order;
  stale GET after membership mutation; week/download callbacks after close;
  20 duplicate leave admissions produce one request; retirement rejects results.
- Weekly suite compiles the real `AccountRequestOwner`, operation gate and all
  `WeeklyMockAPI` wrappers. A recording transport checks all 14 forwarded
  credentials and stops before network/file access. It tests 20 queued starts,
  A→B→A, latest-only responses, stale finish, 20 duplicate admissions, reset,
  retirement/reappearance and the 403-versus-transient policy.
- Weekly SwiftUI connection is separately checked in source. It is **not** an
  executed SwiftUI screen-model/gesture test. No production requests or real
  exam answers were sent by either suite.
- Existing account-bound weekly/exam, hosted-service parity, weekly draft,
  weekly landscape, native tutorial, native accessibility-label, active-P1 and
  account-bound server-screen contract scripts passed after updating obsolete
  source needles to the stronger owner contract. These labels/contracts do not
  count as full accessibility or screen QA.
- Swift parser checks passed. Combined target typecheck/build and simulator
  walkthrough are the parent task's responsibility; no simulator or physical
  device was operated during this subtask.

No commit, push, new branch, production restart or App Store submission occurred.
