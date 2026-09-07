#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/matths-arena-drafts.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
xcrun swiftc -swift-version 6 \
  "$ROOT/Matths/ProtectedFileWriter.swift" "$ROOT/Matths/DebouncedSnapshotWriter.swift" \
  "$ROOT/Matths/ArenaDraftPersistence.swift" "$ROOT/Matths/ArenaLocalDrafts.swift" \
  "$ROOT/tests/ArenaDraftPersistenceCases.swift" -o "$TEST_DIR/cases"
"$TEST_DIR/cases"
