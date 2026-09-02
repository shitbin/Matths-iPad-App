#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
arena="$root/Matths/ArenaWeb/ArenaWebPresenter.swift"
live="$root/Matths/LiveActivitySelfTest.swift"

# NotificationCenter의 블록 옵저버 토큰을 콜백 지역 변수로 캡처하면
# Swift 6 Sendable 검사에서 캡처 후 변경/non-Sendable 경고가 다시 생긴다.
if grep -Fq 'var token: NSObjectProtocol?' "$arena" "$live"; then
  echo "FAIL: one-shot observer token must be actor-isolated, not closure-captured" >&2
  exit 1
fi

grep -Fq 'private static var keyWindowObserver: NSObjectProtocol?' "$arena"
grep -Fq 'private static var activeObserver: NSObjectProtocol?' "$live"
grep -Fq 'keyWindowObserver = nil' "$arena"
grep -Fq 'activeObserver = nil' "$live"
grep -Fq '@MainActor' "$arena"
grep -Fq '@MainActor' "$live"

echo "one-shot observer concurrency contract passed"
