#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/matths-kice-stats.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
python3 - "$ROOT" "$WORK" <<'PY'
from pathlib import Path
import sys
root, out = map(Path, sys.argv[1:])
source = (root / "Matths/MatthsApp.swift").read_text()
screen = (root / "Matths/KiceExamScreen.swift").read_text()
def declaration(marker):
    start = source.index(marker)
    brace = source.index("{", start)
    depth = 0
    for index in range(brace, len(source)):
        if source[index] == "{": depth += 1
        if source[index] == "}":
            depth -= 1
            if depth == 0: return source[start:index + 1]
    raise AssertionError(marker)
parts = [declaration("var solvedTotal: Int"), declaration("var correctTotal: Int"), declaration("private func persistBaseStatistics()"), declaration("private func restoreKiceReceiptMirrors(")]
(out / "ProductionStatsProjection.swift").write_text("extension AppStore {\n" + "\n".join(parts) + "\nfunc persist() { persistBaseStatistics() }\nfunc restoreMirrors(_ archive: KiceStudyArchive) { restoreKiceReceiptMirrors(archive) }\n}\n")
assert "UserDefaults.standard.set(solvedTotal," not in source
assert "UserDefaults.standard.set(correctTotal," not in source
record = declaration("func recordKice(")
assert "solvedTotal +=" not in record and "correctTotal +=" not in record
assert "receiptID: receipt.gradingEventID" in record and "occurredAt: receipt.gradedAt" in record
assert record.index("persistLearningImmediately(.wrongNotes") < record.index("archive.markLocalEffectsApplied")
assert record.index("EventLog.flushPendingWrites") < record.index("archive.markEffectsApplied")
assert "KiceStudyRepository.flush(slot: slot)" in source
assert "KiceStudyRepository.invalidate(slot: slot)" in source
assert source.count("KiceStudyRepository.activate(slot: target)") == 2
assert "ArenaDraftPersistence.flush(slot: slot)" in source, "other agent's Arena hook must remain"
assert "@State private var result: KiceGradeResult" not in screen
assert "store.kiceCurrentReceipt?.result" in screen and "timer.restore(elapsedMs:" in screen
assert "store.ownsCurrentAccountSession(sessionOwner)" in screen
assert "expectedOwner: sessionOwner, expectedAttemptID: attemptID" in screen
assert "let displayedOwner = sessionOwner" in screen
assert "private var loadIdentity: String { store.kiceLoadIdentity }" in screen
assert "self.restoreKiceReceiptMirrors(value)" in declaration("private func loadKiceStudyIfNeeded()")
assert "EventLog" not in declaration("private func restoreKiceReceiptMirrors(")
PY
swiftc "$ROOT/Matths/KiceStudyArchive.swift" "$ROOT/Matths/ProtectedFileWriter.swift" \
  "$ROOT/tests/KiceStatisticsProjectionCases.swift" "$WORK/ProductionStatsProjection.swift" -o "$WORK/cases"
"$WORK/cases"
