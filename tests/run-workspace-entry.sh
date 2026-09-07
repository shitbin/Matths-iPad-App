#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d "${TMPDIR:-/tmp}/matths-workspace-entry.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
awk '/enum StudentDestination/ {exit} {print}' "$root/Matths/ProductNavigation.swift" > "$work/Workspace.swift"
xcrun swiftc "$work/Workspace.swift" "$root/tests/WorkspaceEntryCases.swift" -o "$work/check"
"$work/check"
grep -Fq 'AppStore.slotKey("matths.workspace.v2")' "$root/Matths/MatthsApp.swift"
grep -Fq 'workspacePreferenceLoaded = false' "$root/Matths/MatthsApp.swift"
grep -Fq 'WorkspacePicker(compact: true, showsAccountActions: true)' "$root/Matths/LearningFlowScreens.swift"
grep -Fq 'Button("내 계정과 설정", systemImage: "person.crop.circle")' "$root/Matths/LearningFlowScreens.swift"
