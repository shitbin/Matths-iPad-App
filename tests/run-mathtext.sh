#!/bin/bash
# 수식 표시 경로만 떼어 내 검사한다 (시뮬레이터도 기기도 필요 없다).
set -euo pipefail
cd "$(dirname "$0")/.."
TMP=$(mktemp -d)
cp Matths/MathText.swift "$TMP/"
# 파일명을 main.swift 로 둬야 최상위 문장이 허용된다(Swift 규칙)
cp tests/MathTextCases.swift "$TMP/main.swift"
( cd "$TMP" && swiftc -module-cache-path "$TMP/ModuleCache" -O MathText.swift main.swift -o t && ./t )
