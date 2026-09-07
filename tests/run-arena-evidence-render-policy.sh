#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d "${TMPDIR:-/tmp}/matths-arena-render.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
xcrun swiftc "$root/Matths/ArenaEvidenceRenderPolicy.swift" "$root/tests/ArenaEvidenceRenderPolicyCases.swift" -o "$work/check"
"$work/check"
grep -Fq 'UIGraphicsImageRenderer(size: plan.pixels' "$root/Matths/GoatArenaMatchPlayScreen.swift"
grep -Fq 'image(from: plan.source, scale: plan.scale)' "$root/Matths/GoatArenaMatchPlayScreen.swift"
