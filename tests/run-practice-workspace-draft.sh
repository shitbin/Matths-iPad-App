#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/matths-practice-draft.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
xcrun swiftc -swift-version 6 \
  "$ROOT/Matths/ProtectedFileWriter.swift" \
  "$ROOT/Matths/DebouncedSnapshotWriter.swift" \
  "$ROOT/Matths/PracticeWorkspaceDraft.swift" \
  "$ROOT/Matths/PracticeWorkspaceDraftRepository.swift" \
  "$ROOT/tests/PracticeWorkspaceDraftCases.swift" -o "$TEST_DIR/cases"
"$TEST_DIR/cases"
