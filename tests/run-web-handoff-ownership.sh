#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/matths-web-owner.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
xcrun swiftc -swift-version 6 "$ROOT/Matths/MatthsServiceURLPolicy.swift" "$ROOT/Matths/WebHandoffOwnership.swift" \
  "$ROOT/tests/WebHandoffOwnershipCases.swift" -o "$TEST_DIR/cases"
"$TEST_DIR/cases"
for model in "$ROOT/Matths/CommunityScreen.swift" "$ROOT/Matths/ArenaWeb/ArenaWebModel.swift"; do
  grep -Fq 'ownership.owns(context.ticket, slot: DataScope.slot, viewIdentity: ObjectIdentifier(webView))' "$model"
  grep -Fq 'context.view === webView' "$model"
  grep -Fq 'createCommerceHandoff(mode: "pricing", authorization: authorization)' "$model"
  grep -Fq 'guard isCurrent(context) else { return }' "$model"
  grep -Fq 'guard webView === self.webView else { decisionHandler(.cancel); return }' "$model"
  grep -Fq 'requestTask?.cancel()' "$model"
done
