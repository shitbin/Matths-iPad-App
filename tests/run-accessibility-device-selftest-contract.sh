#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SELFTEST="$ROOT/Matths/AccessibilityDeviceSelfTest.swift"
APP="$ROOT/Matths/MatthsApp.swift"

grep -Fq '#if DEBUG' "$SELFTEST"
grep -Fq 'ProcessInfo.processInfo.arguments.contains("-accessibilityDeviceSelfTest")' "$SELFTEST"
grep -Fq 'MATTHS_ACCESSIBILITY_DEVICE_SELFTEST_V1' "$SELFTEST"
grep -Fq 'size: .accessibility5' "$SELFTEST"
grep -Fq 'zoomSupports200Percent' "$SELFTEST"
grep -Fq 'systemReduceMotionStopsMotion' "$SELFTEST"
grep -Fq 'userMotionPreferenceStopsMotion' "$SELFTEST"
grep -Fq 'AccessibilityDeviceSelfTest.runIfRequested()' "$APP"

echo 'Accessibility device WebKit self-test contract passed'
