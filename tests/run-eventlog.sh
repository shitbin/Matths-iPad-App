#!/bin/bash
# 실행: ipad-app/tests/run-eventlog.sh
# 최근 7일 풀이·정답률·학습시간과 평가/기출 묶음 기록을 앱 밖에서 빠르게 검증한다.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
APP="$HERE/.."
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cp "$APP/Matths/EventLog.swift" "$WORK/EventLog.swift"
cp "$HERE/EventLogCases.swift" "$WORK/main.swift"
swiftc -parse-as-library -O "$WORK/EventLog.swift" "$WORK/main.swift" -o "$WORK/check"
"$WORK/check"
