#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/matths-legacy-semantics.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
xcrun swiftc "$ROOT/Matths/MathAnswer.swift" "$ROOT/Matths/ProblemGenerator.swift" \
  "$ROOT/tests/LegacyGeneratorSemanticsCases.swift" -o "$TEST_DIR/cases"
"$TEST_DIR/cases"
