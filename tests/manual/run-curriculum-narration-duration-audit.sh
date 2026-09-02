#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
binary=$(mktemp "${TMPDIR:-/tmp}/matths-curriculum-duration.XXXXXX")
trap 'rm -f -- "$binary"' EXIT HUP INT TERM

xcrun swiftc \
  "$root/Matths/CurriculumStory.swift" \
  "$root/tests/manual/CurriculumNarrationDurationAudit.swift" \
  -o "$binary"

"$binary" "$root"/Matths/curriculum-stories/*.json
