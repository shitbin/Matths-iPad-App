#!/bin/sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

grep -q 'case stuckPoint' "$ROOT/Matths/SyncEngine.swift"
grep -q 'case progressReset' "$ROOT/Matths/SyncEngine.swift"
grep -q 'await pullStuckPoints()' "$ROOT/Matths/SyncEngine.swift"
grep -q 'ServerAPI.postStuckPoint' "$ROOT/Matths/SyncEngine.swift"
grep -q 'ServerAPI.resetLearningProgress' "$ROOT/Matths/SyncEngine.swift"
grep -q '"POST", "/api/v1/wrong-notes/stuck-points"' "$ROOT/Matths/ServerAPI.swift"
grep -q '"GET", "/api/v1/wrong-notes/stuck-points"' "$ROOT/Matths/ServerAPI.swift"
grep -q '"POST", "/api/v1/learning/progress/reset"' "$ROOT/Matths/ServerAPI.swift"
grep -q 'SyncEngine.shared.enqueueStuckPoint(record)' "$ROOT/Matths/MatthsApp.swift"
grep -q 'await SyncEngine.shared.enqueueProgressResetDurably()' "$ROOT/Matths/MatthsApp.swift"
grep -q '계정과 이 기기의 진도 지우기' "$ROOT/Matths/ProfileScreen.swift"

if grep -q '다음 동기화 때 서버에서 다시 내려받아 복원됩니다' "$ROOT/Matths/ProfileScreen.swift"; then
  echo "서버 진도가 되살아난다는 구형 계약이 남아 있습니다." >&2
  exit 1
fi

echo "learning state sync contract passed"
