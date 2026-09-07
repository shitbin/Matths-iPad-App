#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/matths-kice-timer.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
python3 - "$ROOT" "$WORK" <<'PY'
from pathlib import Path
import sys
root, out = map(Path, sys.argv[1:])
source = (root / "Matths/KiceExamScreen.swift").read_text()
start = source.index("private func syncTimerAvailability(")
brace = source.index("{", start)
depth = 0
for end in range(brace, len(source)):
    if source[end] == "{": depth += 1
    if source[end] == "}":
        depth -= 1
        if depth == 0: break
else: raise AssertionError("timer method body not found")
body = source[start:end + 1].replace("private func", "func", 1)
assert "@State private var timerLifecycle = KiceTimerLifecycle()" in source
assert "timerLifecycle.sceneChanged(isActive: phase == .active)" in source
assert "timerLifecycle.disappeared()" in source
assert "!Task.isCancelled, timerLifecycle.isVisible" in source
(out / "ProductionTimerScreen.swift").write_text("import Foundation\nimport SwiftUI\nextension KiceTimerScreenHarness {\n" + body + "\n}\n")
PY
swiftc "$ROOT/Matths/ExamTimer.swift" "$ROOT/Matths/KiceTimerLifecycle.swift" "$ROOT/tests/KiceTimerResumeCases.swift" \
    "$WORK/ProductionTimerScreen.swift" -o "$WORK/cases"
if [ "${KICE_EXPECT_STALE_TIMER:-0}" = 1 ]; then "$WORK/cases" --expect-stale; else "$WORK/cases"; fi
