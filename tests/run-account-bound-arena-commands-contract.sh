#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
main="$ROOT/Matths/GoatArenaMainMatchSheet.swift"
arena="$ROOT/Matths/GoatArenaScreen.swift"
play="$ROOT/Matths/GoatArenaMatchPlayScreen.swift"
evidence="$ROOT/Matths/GoatArenaEvidencePanel.swift"
scope="$ROOT/Matths/DataScope.swift"

# 학습일 예치/초대 명령은 시작 계정과 실행 세대를 캡처한다.
grep -Fq '@State private var accountSlot = DataScope.slot' "$main"
grep -Fq '@State private var lifecycleID = UUID()' "$main"
grep -Fq 'DataScope.didSwitchNotification' "$main"
grep -Fq 'lifecycleID == id && accountSlot == slot && DataScope.slot == slot' "$main"
grep -Fq '요청을 완료하지 못했습니다. 인터넷 연결을 확인한 뒤 다시 시도해 주세요.' "$main"

# 멱등 재시도 파일을 응답 시점 전역 슬롯이 아닌 원래 계정 슬롯에서만 다룬다.
grep -Fq 'DataScope.url("goat-arena-main-create-command.json", for: accountSlot)' "$main"
grep -Fq 'GoatArenaMainCommandStore.load(accountSlot: ownerSlot)' "$main"
grep -Fq 'GoatArenaMainCommandStore.save(command, accountSlot: ownerSlot)' "$main"
clear_count=$(grep -Fc 'GoatArenaMainCommandStore.clear(accountSlot: ownerSlot)' "$main")
if (( clear_count < 2 )); then
  echo "Ranked command receipts no longer clear the original account slot: $clear_count" >&2
  exit 1
fi

# 서버 응답 뒤 현재 학생 화면을 바꾸는 모든 주요 분기에 소유권 검문이 있어야 한다.
owner_guard_count=$(grep -Fc 'guard owns(ownerLifecycleID, slot: ownerSlot)' "$main")
if (( owner_guard_count < 9 )); then
  echo "Ranked command ownership guards regressed: $owner_guard_count" >&2
  exit 1
fi

echo 'Account-bound Ranked command and retry contracts passed.'

# Unranked 자동 배정도 snapshot을 받은 계정과 같은 계정일 때만 결과를 연다.
grep -Fq 'let ownerSlot = loadedAccountSlot' "$arena"
grep -Fq 'let commandID = subMatchCommandId' "$arena"
grep -Fq 'loadedAccountSlot == ownerSlot' "$arena"
grep -Fq 'subMatchCommandId == commandID' "$arena"
grep -Fq 'subMatchCommandId = UUID().uuidString' "$arena"

# 저장된 과거 Arena 스냅샷은 상태 설명에만 사용하고 수락·거절 권한으로
# 승격하지 않는다. 경기 시작과 초대 응답 모두 fresh 서버 응답을 요구한다.
grep -Fq 'private var hasFreshSnapshot: Bool' "$arena"
grep -Fq 'case .fresh = loadedContent.freshness' "$arena"
fresh_defender_guard_count=$(grep -Fc '!hasFreshSnapshot' "$arena")
if (( fresh_defender_guard_count < 2 )); then
  echo "Cached Arena invitation actions became interactive: $fresh_defender_guard_count" >&2
  exit 1
fi

echo 'Account-bound Unranked matchmaking contract passed.'

# 서버 증거 업로드는 요청 시작 계정의 초안·파일과 묶이고, 계정 전환 뒤 늦게
# 돌아온 응답이 새 계정 검토 큐나 화면을 갱신해서는 안 된다.
grep -Fq 'accountSlot: accountSlot' "$play"
grep -Fq 'DataScope.didSwitchNotification' "$play"
grep -Fq 'let ownerSlot = accountSlot' "$evidence"
grep -Fq 'uploadOperationID == operationID' "$evidence"
grep -Fq 'DataScope.slot == ownerSlot' "$evidence"
grep -Fq 'DataScope.url(fileName, for: accountSlot)' "$evidence"
grep -Fq 'DataScope.url(' "$evidence"
grep -Fq 'for: accountSlot)' "$evidence"
grep -Fq '"goat-arena-evidence-drafts.json"' "$scope"
grep -Fq '파일을 열지 못했습니다. 사진 접근 권한과 파일 상태를 확인해 주세요.' "$evidence"
grep -Fq '기기의 저장 공간을 확인한 뒤 다시 시도해 주세요.' "$evidence"
grep -Fq '같은 제출 버튼을 다시 눌러 주세요.' "$evidence"

response_guard=$(grep -Fc 'uploadOperationID == operationID else { return }' "$evidence")
if (( response_guard < 2 )); then
  echo "Evidence success/error ownership guards regressed: $response_guard" >&2
  exit 1
fi

echo 'Account-bound Arena evidence upload contract passed.'
