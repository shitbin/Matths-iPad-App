#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SELFTEST="$ROOT/Matths/WindowEnvironmentSelfTest.swift"
APP="$ROOT/Matths/MatthsApp.swift"
HARNESS="$ROOT/Matths/SizeHarness.swift"

grep -Fq '#if DEBUG' "$SELFTEST"
grep -Fq 'MATTHS_WINDOW_ENVIRONMENT_SELFTEST_V1' "$SELFTEST"
grep -Fq 'window-environment-selftest.json' "$SELFTEST"
grep -Fq 'UIResponder.keyboardDidShowNotification' "$SELFTEST"
grep -Fq 'preferredStyle: .actionSheet' "$SELFTEST"
grep -Fq 'splitViewEvidenceEligible: functionalPassed && compactWidth && compactTrait' "$SELFTEST"
grep -Fq 'ProcessInfo.processInfo.arguments.contains("-windowEnvironmentSelfTest")' "$APP"
grep -Fq '이 하네스가 확인해 주는 것은 레이아웃뿐이다.' "$HARNESS"

echo 'Window, keyboard, popover runtime self-test contract passed'
