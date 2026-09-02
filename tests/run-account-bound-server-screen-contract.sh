#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
quick="$ROOT/Matths/QuickPracticeScreen.swift"
rank="$ROOT/Matths/RankArenaScreen.swift"

# 서버 응답을 기다리는 화면은 요청 시작 계정과 현재 계정이 모두 같을 때만
# 문제·채점 결과·개인 순위를 화면에 적용해야 한다.
grep -Fq '@State private var accountSlot = DataScope.slot' "$quick"
grep -Fq '@State private var operationID = UUID()' "$quick"
grep -Fq '@State private var statsRequestID = UUID()' "$quick"
grep -Fq 'DataScope.didSwitchNotification' "$quick"
grep -Fq 'operationID == requestID && accountSlot == slot && DataScope.slot == slot' "$quick"
grep -Fq 'ownerSlot == accountSlot,' "$quick"
grep -Fq 'ownerSlot == DataScope.slot,' "$quick"
grep -Fq 'statsRequestID == requestID' "$quick"

# 문제 요청·제출·마감의 성공과 실패 모두 같은 소유권 게이트를 통과해야 한다.
quick_operation_guards=$(grep -Fc 'guard ownsOperation(requestID, slot: ownerSlot)' "$quick")
if (( quick_operation_guards < 6 )); then
  echo "Quick Practice account/request guards regressed: $quick_operation_guards" >&2
  exit 1
fi

grep -Fq '@State private var accountSlot = DataScope.slot' "$rank"
grep -Fq 'DataScope.didSwitchNotification' "$rank"
grep -Fq 'loadID == requestID && accountSlot == slot && DataScope.slot == slot' "$rank"
grep -Fq 'loadGuestPreview(requestID: requestID, accountSlot: ownerSlot)' "$rank"

rank_load_guards=$(grep -Fc 'guard ownsLoad(requestID, slot: ownerSlot)' "$rank")
if (( rank_load_guards < 8 )); then
  echo "Rank Arena account/request guards regressed: $rank_load_guards" >&2
  exit 1
fi

echo "Account-bound Quick Practice and Rank Arena response contracts passed."
