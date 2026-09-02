#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
grader="$ROOT/Matths/SheetGrader.swift"

# llama 토큰 콜백은 nonisolated 작업 스레드다. MainActor 소유 self.cancel을
# 콜백에서 다시 읽지 않고, 호출 시작 시 캡처한 thread-safe flag만 읽어야 한다.
grep -Fq 'let callCancel = cancel' "$grader"
grep -Fq 'return !callCancel.isSet' "$grader"
grep -Fq 'if callCancel.isSet { throw CancellationError() }' "$grader"

if grep -Eq 'self\?\.cancel\.isSet|self\.cancel\.isSet' "$grader"; then
  echo 'SheetGrader token callback crossed the MainActor cancellation boundary.' >&2
  exit 1
fi

echo 'Sheet grader cancellation generation contract passed.'
