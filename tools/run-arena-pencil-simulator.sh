#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
DEVICE_ID="${1:?Provide a booted iOS Simulator UUID (not a physical device)}"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/matths-arena-pencil-run.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
node - "$ROOT" "$TEST_DIR" <<'JS'
const fs=require('node:fs'); const [root,out]=process.argv.slice(2);
const source=fs.readFileSync(root+'/Matths/GoatArenaMatchPlayScreen.swift','utf8');
const change=source.indexOf('    private func solutionDrawingChanged(');
const install=source.indexOf('    @MainActor\n    private func installSolutionDrawing(',change);
const end=source.indexOf('    @MainActor\n    private func restoreSolutionBoardsFromServer(',install);
if(!(change>=0&&install>change&&end>install)) throw Error('Review production drawing method boundaries');
fs.writeFileSync(out+'/drawing.swift','import Foundation\nimport PencilKit\n@MainActor extension BoardInstallHarness {\n'+
source.slice(change,end)+'\nfunc exerciseInstall() { installSolutionDrawing(for: 1) }\nfunc exerciseChange(_ drawing: PKDrawing) { solutionDrawingChanged(drawing) }\n}\n');
JS
SIMULATOR_SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"
xcrun swiftc -swift-version 5 -sdk "$SIMULATOR_SDK" -target arm64-apple-ios17.0-simulator \
  "$ROOT/Matths/ProtectedFileWriter.swift" "$ROOT/Matths/DebouncedSnapshotWriter.swift" \
  "$ROOT/Matths/ArenaDraftPersistence.swift" "$ROOT/Matths/ArenaLocalDrafts.swift" \
  "$ROOT/tests/ArenaPencilDrawingSimulatorCases.swift" "$TEST_DIR/drawing.swift" -o "$TEST_DIR/cases"
xcrun simctl spawn "$DEVICE_ID" "$TEST_DIR/cases"
