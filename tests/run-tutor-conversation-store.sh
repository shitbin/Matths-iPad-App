#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

xcrun swiftc \
  "$ROOT/Matths/DataScope.swift" \
  "$ROOT/Matths/TutorConversationStore.swift" \
  "$ROOT/tests/TutorConversationStoreCases.swift" \
  -o "$WORK/tutor-conversation-store"
"$WORK/tutor-conversation-store"

grep -Fq '"tutor-conversation"' "$ROOT/Matths/DataScope.swift"
grep -Fq 'reloadConversationForCurrentSlot()' "$ROOT/Matths/MatthsApp.swift"
grep -Fq 'self.ownsRun(runID, slot: ownerSlot)' "$ROOT/Matths/AITutor.swift"

echo "Tutor conversation runtime contract passed"
