#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/matths-kice-effects.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
python3 - "$ROOT" "$WORK" <<'PY'
from pathlib import Path
import sys
root, out = map(Path, sys.argv[1:])
source = (root / "Matths/WrongNoteStore.swift").read_text()
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
model = declaration("struct WrongNoteEntry:")
# Remove only the UI/problem adapter; persistence fields, Codable synthesis,
# receipt IDs and SRS functions remain the production declarations.
adapter = declaration("var asProblem:")
model = model.replace(adapter, "")
(out / "ProductionWrongNoteModel.swift").write_text("import Foundation\n" + model + "\n" + declaration("enum WrongNoteSRS"))
PY
swiftc -swift-version 6 "$WORK/ProductionWrongNoteModel.swift" \
  "$ROOT/Matths/KiceStudyArchive.swift" "$ROOT/Matths/ProtectedFileWriter.swift" \
  "$ROOT/Matths/KiceWrongNoteEffects.swift" "$ROOT/tests/KiceWrongNoteEffectsCases.swift" -o "$WORK/cases"
"$WORK/cases"
