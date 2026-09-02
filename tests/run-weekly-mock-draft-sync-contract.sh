#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OUTPUT="/tmp/matths-weekly-mock-draft-sync-cases"
MODULE_CACHE="/tmp/matths-weekly-mock-draft-sync-module-cache"
SCREEN="$ROOT/Matths/WeeklyMockScreen.swift"

xcrun swiftc \
  "$ROOT/tests/WeeklyMockDraftSyncStateCases.swift" \
  "$ROOT/Matths/WeeklyMockDraftSyncState.swift" \
  -module-cache-path "$MODULE_CACHE" \
  -o "$OUTPUT"

"$OUTPUT"

# 순수 상태 정책이 실제 화면의 GET/PATCH 경로에 연결되어 있어야 한다.
grep -Fq 'let loadRequest = draftSyncState.beginLoad()' "$SCREEN"
grep -Fq 'finishLoading(loadRequest)' "$SCREEN"
grep -Fq 'draftSyncState.shouldApplyMetadata(loadRequest)' "$SCREEN"
grep -Fq 'draftSyncState.shouldPreserveLocalDraft(loadRequest)' "$SCREEN"
grep -Fq 'let saveRequest = draftSyncState.beginSave()' "$SCREEN"
grep -Fq 'draftSyncState.markSaveSucceeded(saveRequest)' "$SCREEN"
grep -Fq 'draftSyncState.hasEdits(after: saveRequest)' "$SCREEN"
grep -Fq 'draftSyncState.canApplySaveResponse(saveRequest)' "$SCREEN"
grep -Fq 'restoredDraftIsDirty()' "$SCREEN"
grep -Fq 'persistDraftSyncState()' "$SCREEN"
grep -Fq 'WeeklyMockDraftRecovery.answers(' "$SCREEN"
grep -Fq 'Task { @MainActor in await save(reportError: false) }' "$SCREEN"
grep -Fq 'draftSyncState.markTerminal()' "$SCREEN"

echo 'Weekly mock screen is wired to the draft revision policy.'
