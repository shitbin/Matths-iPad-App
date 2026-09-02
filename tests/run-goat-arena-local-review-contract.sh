#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

grep -Fq 'case goatArenaEvidence = "goat-arena-evidence"' "$ROOT/Matths/CheatingReviewModels.swift"
grep -Fq 'enqueueGoatArenaEvidenceReviews' "$ROOT/Matths/GoatArenaEvidencePanel.swift"
grep -Fq '사진은 마감 전에 먼저 접수됩니다.' "$ROOT/Matths/GoatArenaEvidencePanel.swift"
grep -Fq '사진은 제출 전까지 이 계정으로 로그인한 기기에만 임시 저장됩니다.' "$ROOT/Matths/GoatArenaEvidencePanel.swift"
grep -Fq 'submitGoatArenaClientReview' "$ROOT/Matths/GoatArenaClientReviewOutbox.swift"
grep -Fq '.completeFileProtection' "$ROOT/Matths/GoatArenaClientReviewOutbox.swift"
grep -Fq 'static func recoverCompleted' "$ROOT/Matths/GoatArenaClientReviewOutbox.swift"
grep -Fq 'goat-arena-client-review-finalized.json' "$ROOT/Matths/GoatArenaClientReviewOutbox.swift"
grep -Fq 'let startingSlot = DataScope.slot' "$ROOT/Matths/GoatArenaClientReviewOutbox.swift"
grep -Fq 'let finalized = finalizedIDs(from: receiptURL)' "$ROOT/Matths/GoatArenaClientReviewOutbox.swift"
grep -Fq 'removeFromQueue(item.id, at: queueURL)' "$ROOT/Matths/GoatArenaClientReviewOutbox.swift"
grep -Fq '코드 없는 404' "$ROOT/Matths/GoatArenaClientReviewOutbox.swift"
grep -Fq 'recoverCompleted(store.cheatingReviews)' "$ROOT/Matths/MatthsApp.swift"
grep -Fq '"goat-arena-client-review-outbox.json"' "$ROOT/Matths/DataScope.swift"
grep -Fq '"goat-arena-client-review-finalized.json"' "$ROOT/Matths/DataScope.swift"
grep -Fq '/evidence/client-review' "$ROOT/Matths/ServerAPI.swift"
grep -Fq 'result.verdict == .suspicious' "$ROOT/Matths/GoatArenaClientReviewOutbox.swift"
grep -Fq 'filter(\.isStrong)' "$ROOT/Matths/GoatArenaClientReviewOutbox.swift"
grep -Fq 'resumePendingGoatArenaCheatingReviews' "$ROOT/Matths/MatthsApp.swift"
grep -Fq 'isResumableArenaReview' "$ROOT/Matths/CheatingReviewStore.swift"
grep -Fq 'arenaDelivery: GoatArenaCheatingReviewDelivery?' "$ROOT/Matths/CheatingReviewModels.swift"

# 로컬 검토가 60초 증거 업로드의 선행 조건이 되어서는 안 된다.
upload_line=$(grep -n 'submitGoatArenaEvidence' "$ROOT/Matths/GoatArenaEvidencePanel.swift" | head -1 | cut -d: -f1)
review_line=$(grep -n 'enqueueGoatArenaEvidenceReviews' "$ROOT/Matths/GoatArenaEvidencePanel.swift" | head -1 | cut -d: -f1)
test "$upload_line" -lt "$review_line"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
xcrun swiftc \
  "$ROOT/Matths/CheatingDetectionModels.swift" \
  "$ROOT/Matths/GoatArenaLocalReviewContext.swift" \
  "$ROOT/tests/GoatArenaLocalReviewContextCases.swift" \
  -o "$WORK/goat-arena-review-context"
"$WORK/goat-arena-review-context"

echo "GOAT Arena local review follow-up contract: ok"
