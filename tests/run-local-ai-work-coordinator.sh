#!/bin/sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
CACHE="${TMPDIR:-/tmp}/matths-local-ai-work-coordinator-module-cache"
mkdir -p "$CACHE"

xcrun swiftc \
  -module-cache-path "$CACHE" \
  "$ROOT/Matths/LocalAIWorkCoordinator.swift" \
  "$ROOT/tests/LocalAIWorkCoordinatorCases.swift" \
  -o "${TMPDIR:-/tmp}/matths-local-ai-work-coordinator-tests"

"${TMPDIR:-/tmp}/matths-local-ai-work-coordinator-tests"

grep -Fq 'LocalAIWorkCoordinator.shared.acquire(.sheetGrading)' "$ROOT/Matths/ProScreen.swift"
grep -Fq 'LocalAIWorkCoordinator.shared.acquire(.tutorResponse)' "$ROOT/Matths/AITutor.swift"
grep -Fq 'LocalAIWorkCoordinator.shared.acquire(.integrityReview)' "$ROOT/Matths/MatthsApp.swift"
grep -Fq 'workLease: LocalAIWorkCoordinator.Lease' "$ROOT/Matths/SheetGrader.swift"
grep -Fq 'private var queuedWorkRunID: UUID?' "$ROOT/Matths/AITutor.swift"
grep -Fq 'clearQueuedWorkTask(ifOwnedBy:' "$ROOT/Matths/AITutor.swift"
grep -Fq 'guard queuedWorkRunID == runID else { return }' "$ROOT/Matths/AITutor.swift"
grep -Fq 'analysisPreparationTask?.cancel()' "$ROOT/Matths/ProScreen.swift"
grep -Fq 'assertAnalysisOwnership(ownerSlot, preparationID:' "$ROOT/Matths/ProScreen.swift"
grep -Fq 'guard analysisPreparationID == preparationID else { return }' "$ROOT/Matths/ProScreen.swift"
grep -Fq 'Self.analysisStartFailureMessage(error)' "$ROOT/Matths/ProScreen.swift"
grep -Fq '기기의 저장 공간을 확인한 뒤 다시 시도해 주세요.' "$ROOT/Matths/ProScreen.swift"
grep -Fq '다른 앱을 닫고 같은 사진으로 다시 시도해 주세요.' "$ROOT/Matths/ProScreen.swift"
grep -Fq '다른 앱을 닫고 사진을 다시 확인한 뒤 재시도해 주세요.' "$ROOT/Matths/AITutor.swift"
grep -Fq '다른 앱을 닫고 질문을 다시 보내 주세요.' "$ROOT/Matths/AITutor.swift"

# 낮은 우선순위 무결성 검토는 다운로드·해시가 끝난 뒤에만 엔진 lease를 잡아야 한다.
# 순서가 뒤집히면 첫 모델 준비 전체 시간 동안 전경 채점·튜터가 막힌다.
python3 - "$ROOT/Matths/MatthsApp.swift" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text(encoding="utf-8")
start = source.index("private func runCheatingReview(imagePath:")
end = source.index("private func runCheatingReviewWithLease(", start)
body = source[start:end]
prepare = body.index("prepareForSheetAnalysis()")
acquire = body.index("LocalAIWorkCoordinator.shared.acquire(.integrityReview)")
if prepare >= acquire:
    raise SystemExit("integrity review must prepare model files before acquiring engine lease")
PY

echo "Local AI grading, tutor, and integrity review all use the single-engine coordinator"
