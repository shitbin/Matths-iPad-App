#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/matths-account-owner.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
xcrun swiftc -swift-version 6 "$ROOT/Matths/AccountRequestOwner.swift" \
  "$ROOT/tests/AccountRequestOwnerCases.swift" -o "$TEST_DIR/cases"
"$TEST_DIR/cases"
grep -Fq 'private func saveNickname(owner: AccountRequestOwner?) {' "$ROOT/Matths/ProfileScreen.swift"
grep -Fq 'let submittedNickname = nicknameDraft' "$ROOT/Matths/ProfileScreen.swift"
grep -Fq 'updateNickname(submittedNickname, authorization: owner.authorization)' "$ROOT/Matths/ProfileScreen.swift"
grep -Fq 'reauthenticationOwner?.isCurrent(in: store)' "$ROOT/Matths/ProfileScreen.swift"
grep -Fq 'password: submittedPassword' "$ROOT/Matths/ProfileScreen.swift"
grep -Fq 'resetProgress(expectedAccount: account)' "$ROOT/Matths/ProfileScreen.swift"
grep -Fq 'guard profilePhotoRequestID == pickerID, owner.isCurrent(in: store) else {' "$ROOT/Matths/ProfileScreen.swift"
grep -Fq 'uploadProfilePhoto(image, owner: owner)' "$ROOT/Matths/ProfileScreen.swift"
grep -Fq 'nicknameEditorOwner?.id == owner.id,' "$ROOT/Matths/ProfileScreen.swift"
grep -Fq 'if let account = resetConfirmationOwner {' "$ROOT/Matths/ProfileScreen.swift"
grep -Fq 'quickPracticeStart(pointValue: selectedPointValue, authorization: owner.authorization)' "$ROOT/Matths/QuickPracticeScreen.swift"
grep -Fq 'elapsedMs: elapsed, authorization: owner.authorization)' "$ROOT/Matths/QuickPracticeScreen.swift"
grep -Fq 'quickPracticeExpire(instanceId: a.instanceId, authorization: owner.authorization)' "$ROOT/Matths/QuickPracticeScreen.swift"
