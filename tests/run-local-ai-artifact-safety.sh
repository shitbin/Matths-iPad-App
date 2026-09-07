#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/matths-ai-artifact-safety.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
xcrun swiftc -swift-version 6 \
  "$ROOT/Matths/LocalAIArtifactSafety.swift" \
  "$ROOT/tests/LocalAIArtifactSafetyCases.swift" \
  -o "$TEST_DIR/cases"
"$TEST_DIR/cases"
