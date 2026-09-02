#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
shop="$ROOT/Matths/ArenaShopScreen.swift"
scope="$ROOT/Matths/DataScope.swift"

# 금전성 요청의 디스크 키는 응답 시점 전역 슬롯이 아니라 요청 시작 계정에 귀속한다.
grep -Fq 'static func url(_ name: String, for capturedSlot: String)' "$scope"
grep -Fq '"arena-shop-purchase-intents.json"' "$scope"
grep -Fq 'DataScope.url(fileName, for: accountSlot)' "$shop"
grep -Fq 'accountSlot: pendingPurchase.accountSlot' "$shop"
grep -Fq 'accountSlot: ownerSlot' "$shop"

# 조회·구매·분석의 늦은 응답은 계정 슬롯과 요청 세대가 모두 같을 때만 표시한다.
grep -Fq '@State private var accountSlot = DataScope.slot' "$shop"
grep -Fq 'DataScope.didSwitchNotification' "$shop"
grep -Fq 'requestID == id && accountSlot == slot && DataScope.slot == slot' "$shop"
grep -Fq 'guard requestID == nextID, accountSlot == DataScope.slot else { return }' "$shop"
grep -Fq '인터넷 연결을 확인한 뒤 상점을 다시 불러와 주세요.' "$shop"
grep -Fq '상점 정보를 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.' "$shop"

ownership_guards=$(grep -Fc 'guard ownsRequest(nextID, slot: ownerSlot)' "$shop")
if (( ownership_guards < 6 )); then
  echo "Arena shop account/request guards regressed: $ownership_guards" >&2
  exit 1
fi

echo "Account-bound Arena commerce and analysis contracts passed."
