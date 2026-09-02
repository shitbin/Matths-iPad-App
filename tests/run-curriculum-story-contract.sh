#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
binary=$(mktemp "${TMPDIR:-/tmp}/matths-curriculum-story.XXXXXX")
player_binary=$(mktemp "${TMPDIR:-/tmp}/matths-curriculum-player.XXXXXX")
trap 'rm -f -- "$binary" "$player_binary"' EXIT HUP INT TERM

node "$root/tests/CurriculumStoryContract.js"
xcrun swiftc \
  "$root/Matths/CurriculumStory.swift" \
  "$root/tests/CurriculumStoryCases.swift" \
  -o "$binary"
"$binary"

xcrun swiftc \
  "$root/Matths/DataScope.swift" \
  "$root/Matths/CurriculumStory.swift" \
  "$root/Matths/CurriculumSpeechPlayer.swift" \
  "$root/tests/CurriculumSpeechPlayerCases.swift" \
  -o "$player_binary"
"$player_binary"
