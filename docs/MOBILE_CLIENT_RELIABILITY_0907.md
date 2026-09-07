# Mobile reliability client integration — 2026-09-07

The iOS client now integrates the additive mobile capability, first-learning
resume, and community idempotency APIs. This does not mean the new server code
is deployed to production, nor that all app workflows have passed real-device QA.

## Contract and safe rollout

- `GET /api/v1/mobile-capabilities` is authenticated. Support is cached for up to
  60 monotonic seconds by origin and account/session epoch; parallel reads share
  one task. Only a missing route (404) or 405 selects the old-server fallback.
  Auth failures, malformed JSON/schema, timeouts and 5xx never permit a silent
  downgrade to an unsafe write.
- Confirmed old servers retain local first-learning navigation state and the
  previous explicitly-retried community behavior. Previously-keyed operations
  pause if capability support is later removed. They never retry without a key.
- `GET /api/v1/me/first-learning` loads the revision before any `PATCH`.
  PATCH uses `expectedRevision`; HTTP 409 preserves the full `current` envelope.
- Wire state uses `flowVersion: 2`, a decimal **string** for UInt64 seed, bounded
  diagnostic/problem/answer arrays, safe IDs and UTC ISO8601 dates. Local account
  slots, auth tokens, queue counts and official confirmation/pass/unlock fields
  cannot be encoded by this DTO.

The matching server contract is maintained with the backend change in
`docs/MOBILE_RELIABILITY_CONTRACT_2026-09-07.md` of that repository. Deploy all
server instances and verify unique indexes before advertising community support;
the iOS change does not prepare database indexes or restart production services.

## First-learning behavior

`FirstLearningJourneyRemoteSync.swift` coordinates the existing local journey.
It persists the GET/CAS base in `mobile-first-learning-sync-v1.json` in the
account's data directory before writing remotely. A clean local journey adopts a
newer remote state. A dirty local journey and a changed remote state show an
explicit choice; ordinary retry never overwrites the other device automatically.

Choosing a record makes a separate backup of the original local journey. A
corrupt revision cache blocks remote writes; the explicit recovery button moves
the unreadable source to a backup and fetches a fresh server revision. It does
not guess revision zero or discard the local learning journal.

A lost PATCH response is resolved through an equal GET/409 payload, so it does
not create a new operation simply because the acknowledgement was lost. Store
tasks are coalesced and invalidated across account epochs, including A→B→A.

Downloaded `result` or `completed` is lowered to `awaitingSync`. No official
confirmation comes from the remote navigation blob. The screen still requires
the account-owned learning queue to durably drain, unchanged rejected/quarantined
record counts, and a fresh, valid canonical learning response. It displays the
actual returned progress, including zero; it does not fabricate a completion
percentage. An unrelated pull error no longer substitutes for this receipt:
`flushForLearningReceipt()` joins the actual learning queue completion signal.

Existing dashboard COMPLETE/SKIP/RESTART actions cancel stale local publication
and are followed by a new GET for the server's incremented revision. Terminal
navigation blobs are not uploaded after the dashboard action clears resume data.

## Community behavior

The composer and comment draft persist a submission scope before calling the
network. Within that draft scope, a fingerprint includes the operation target,
actual submitted fields, ordered attachment metadata and streamed SHA256 of the
attachment bytes. Same name/length with changed bytes is not treated as the same
attachment. Multipart upload remains file-backed; it is not assembled in a large
in-memory `Data` value.

`community-request-ledger-v1.json` stores the request ID **and the selected mode**
before sending. Uncertain retries and process-style reloads reuse that ID. Edits
to submitted content use a different ID, and returning to the old uncertain
content restores its original ID. A legacy uncertain operation is not converted
to a new keyed operation after a server upgrade. Request identities are scoped
by account and server origin.

Successful responses alone do not delete request identities. The UI must also
durably clear the submitted draft before acknowledging its scope for cleanup.
Other pending scopes remain. A 410 replay of a deleted/hidden post is shown as an
error and never turned into a new keyless create. Unknown/corrupt ledger files
fail closed; unfinished entries are not silently evicted when the bounded ledger
is full.

## Reproduce the checks

From this repository:

```sh
bash tests/run-mobile-reliability-client.sh
bash tests/run-native-community-contract.sh
bash tests/run-community-multipart-body.sh
bash tests/run-native-service-recovery.sh
bash tests/run-student-flow-domain.sh
```

The first suite compiles the production DTO, merge policy, API wrappers,
ObservableObject coordinator, ownership epoch, multipart/hash helper, native
community API and durable request ledger. The HTTP fixture boundary is explicit.
It currently exercises 84 assertions, including 12 concurrent capability callers,
malformed/legacy/transient responses, CAS and response loss, explicit conflict
selection, safe imported completion, corrupt-cache recovery, and A→B→A rejection.

An optional local integration mode reads the backend's private generated fixture
manifest and refuses non-loopback or non-fixture origins:

```sh
bash tests/run-mobile-reliability-client.sh --local-manifest /path/to/private-local-fixture.json
```

This mode passed 10 checks against the isolated Node/Mongo fixture: real
capability/GET/PATCH/CAS, native multipart post replay, native comment replay with
one stored comment, deleted-resource 410, and existing tutorial RESTART clearing
resume and blocking a stale PATCH. It uses only the `returningStudent` fixture;
the root simulator walkthrough uses `student`. A temporary test post is deleted
after its replay checks. The fixture account is left in RESTART tutorial state.
Tokens/passwords are read in memory and never printed or copied into this repo.

## Evidence limits

- The optional local server uses an isolated database and controlled external
  storage boundary. These checks do not prove production deployment, live
  Cloudinary/R2 availability, delivery through multiple production instances, or
  real students' cross-device state.
- Host-based Swift tests are executable code checks, not screenshots or physical
  device interaction. Parent-task simulator UI evidence is tracked separately.
- A device-target unsigned Debug compile succeeded during integration; it was
  not installed on the connected iPhone. The final combined simulator/release
  build is owned by the parent integration task.
- No commit, branch, push, production restart, TestFlight upload or App Store
  submission was performed by this client subtask.

## Debug-only first-learning diagnostics

The real login API returns a smaller `user` than GET `/api/v1/me`; its tutorial
field is absent, not `false`. The first-learning overlay hydrates the shared
profile after authentication before evaluating automatic presentation. Its task
identity distinguishes unloaded state, explicit server false, and pending true.
This fixes a real-loopback regression where the new Today screen stayed visible
after successful login despite GET `/me` returning PENDING/shouldAutoStart=true.

When launched with `-firstLearningJourneyFixture`, a Debug build writes
`first-learning-receipt-diagnostic.json` in the current data directory. It contains
the last checkpoint, stage, answer count, queue/baseline counters, whether a global
error exists, and canonical validity/progress when available. It does not contain
raw error bodies, identities, credentials or problem/answer text. Release builds
do not compile this diagnostic writer.
