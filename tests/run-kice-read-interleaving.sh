#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/matths-kice-read.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
python3 - "$ROOT" "$WORK" <<'PY'
from pathlib import Path
import sys
root, out = map(Path, sys.argv[1:])
source = (root / "Matths/KiceStudyRepository.swift").read_text()
needle = "KiceStudyDisk.load(at: handle.url, slot: handle.slot)"
assert needle in source
# Instrument scheduling only: the hook reads the actual file before pausing;
# production repository state, writes, revision logic and return values remain.
(out / "TimedProductionRepository.swift").write_text(source.replace(needle, "KiceReadInterleaving.read(at: handle.url, slot: handle.slot)"))
PY
swiftc -swift-version 6 "$ROOT/Matths/ProtectedFileWriter.swift" "$ROOT/Matths/DebouncedSnapshotWriter.swift" \
  "$ROOT/Matths/PracticeWorkspaceDraft.swift" "$ROOT/Matths/KiceStudyArchive.swift" \
  "$WORK/TimedProductionRepository.swift" "$ROOT/tests/KiceReadInterleavingCases.swift" -o "$WORK/cases"
if [ "${KICE_EXPECT_STALE:-0}" = 1 ]; then "$WORK/cases" --expect-stale; else "$WORK/cases"; fi
