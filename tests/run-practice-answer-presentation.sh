#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d "${TMPDIR:-/tmp}/matths-answer-presentation.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
xcrun swiftc "$root/Matths/PracticeAnswerPresentation.swift" "$root/tests/PracticeAnswerPresentationCases.swift" -o "$work/check"
"$work/check"
grep -Fq 'answerComparison(grading: grading)' "$root/Matths/Screens.swift"
grep -Fq 'choices[number - 1]' "$root/Matths/Screens.swift"
