#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/matths-private-write.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
xcrun swiftc -swift-version 6 \
  "$ROOT/Matths/ProtectedFileWriter.swift" \
  "$ROOT/tests/ProtectedFileWriterCases.swift" -o "$TEST_DIR/cases"
"$TEST_DIR/cases"
# Build the actual iOS branch as well: host compatibility must never downgrade
# .completeFileProtection to after-first-unlock or remove the atomic option.
grep -Fq 'try data.write(to: destination, options: [.atomic, .completeFileProtection])' "$ROOT/Matths/ProtectedFileWriter.swift"
SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"
xcrun swiftc -swift-version 6 -sdk "$SDK" -target arm64-apple-ios17.0-simulator \
  -typecheck "$ROOT/Matths/ProtectedFileWriter.swift"
echo 'iOS complete-protection branch typecheck: PASS'
