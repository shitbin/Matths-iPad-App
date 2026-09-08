#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/matths-tutorial-focus.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT HUP INT TERM
xcrun swiftc -swift-version 5 "$ROOT/Matths/TutorialFocus.swift" "$ROOT/tests/TutorialFocusCases.swift" -o "$TEST_DIR/cases"
"$TEST_DIR/cases"
# Type-check the actual SwiftUI preference + UIKit scrolling bridge against the
# minimum deployment SDK. This is compilation proof, not a simulator screenshot.
SDK_PATH="$(xcrun --sdk iphonesimulator --show-sdk-path)"
xcrun swiftc -swift-version 5 -target arm64-apple-ios17.0-simulator -sdk "$SDK_PATH" -typecheck \
  "$ROOT/Matths/TutorialFocus.swift" "$ROOT/Matths/TutorialTargets.swift"
echo "Tutorial target preference and real UIScrollView bridge: iOS 17 SDK typecheck PASS"
