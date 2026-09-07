#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/matths-kice-study.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
xcrun swiftc -swift-version 6 \
  "$ROOT/Matths/ProtectedFileWriter.swift" "$ROOT/Matths/DebouncedSnapshotWriter.swift" \
  "$ROOT/Matths/PracticeWorkspaceDraft.swift" "$ROOT/Matths/KiceBank.swift" \
  "$ROOT/Matths/KiceStudyArchive.swift" "$ROOT/Matths/KiceStudyDefinition.swift" \
  "$ROOT/Matths/KiceStudyRepository.swift" "$ROOT/tests/KiceStudyArchiveCases.swift" \
  -o "$TEST_DIR/cases"
"$TEST_DIR/cases" "$ROOT/Matths/KiceBank/kice-index.json"
