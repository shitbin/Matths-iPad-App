#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d "${TMPDIR:-/tmp}/matths-command-journal.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
xcrun swiftc -swift-version 6 "$root/Matths/ProtectedFileWriter.swift" "$root/Matths/GoatArenaCommandKeyJournal.swift" "$root/tests/GoatArenaCommandKeyJournalCases.swift" -o "$work/check"
"$work/check"
grep -Fq 'guard prepareCommandKeys() else { return }' "$root/Matths/GoatArenaMatchPlayScreen.swift"
grep -Fq 'clearCommandKeysAfterReceipt()' "$root/Matths/GoatArenaMatchPlayScreen.swift"
