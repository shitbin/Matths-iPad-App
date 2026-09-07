#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/matths-sheet-weak-types.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
xcrun swiftc "$ROOT/Matths/MathAnswer.swift" "$ROOT/Matths/ProblemGenerator.swift" \
  "$ROOT/Matths/SheetWeakTypePolicy.swift" "$ROOT/tests/SheetWeakTypePolicyCases.swift" -o "$TEST_DIR/cases"
"$TEST_DIR/cases"
grep -Fq 'SheetWeakTypePolicy.resolve(items: items.map {' "$ROOT/Matths/SheetGrader.swift"
if grep -Fq 'let fromItems = items.compactMap(\.typeKey)' "$ROOT/Matths/SheetGrader.swift"; then
  echo 'Ungrounded all-item weak-type merge reappeared' >&2
  exit 1
fi
