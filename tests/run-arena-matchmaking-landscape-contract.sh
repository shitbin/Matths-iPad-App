#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
layout="$root/Matths/CompactHeightColumns.swift"
arena="$root/Matths/GoatArenaScreen.swift"
maker="$root/Matths/GoatArenaMainMatchSheet.swift"
shop="$root/Matths/ArenaShopScreen.swift"

# 긴 커스텀 시트는 iPhone 가로에서 닫기 제스처와 세로 스크롤을 경쟁시키지 않는다.
grep -Fq 'private struct CompactHeightBooleanSheet' "$layout"
grep -Fq 'verticalSizeClass == .compact' "$layout"
grep -Fq 'content.fullScreenCover(' "$layout"
grep -Fq 'content.sheet(' "$layout"

for state in showsRulebook showsLeaderboard showsArenaWebMenu showsMainMatchMaker; do
  grep -Fq ".compactHeightSheet(isPresented: \$$state" "$arena"
done

# 연결 실패·로그인 필요 상태도 가로에서 안내문 아래에 복구 버튼을 밀어 내지 않는다.
# 상태/제목과 설명/행동을 남는 가로 폭에 나눠 첫 화면에서 다시 시도할 수 있어야 한다.
[[ "$(grep -Fc 'CompactHeightColumns(spacing: Tokens.Space.s5, stackedSpacing: Tokens.Space.s5)' "$arena")" -eq 2 ]]
grep -Fq 'heroButton("로그인하기")' "$arena"
grep -Fq 'heroButton("다시 시도")' "$arena"

# 방어자 MATCHED 기록만 남고 응답 가능한 초대가 함께 오지 않은 상태도 내부 구현
# 문구로 막지 않는다. 좁은 가로와 iPad 상세 양쪽에서 같은 화면의 재확인 동선을 둔다.
grep -Fq 'needsDefenderResponseRefresh(snapshot)' "$arena"
grep -Fq 'defenderResponseRefreshButton' "$arena"
grep -Fq '"최신 경기 상태 다시 확인"' "$arena"
grep -Fq '수락 또는 거절 버튼이 보이지 않으면 최신 경기 상태를 다시 확인하세요.' "$arena"
if grep -Fq '저장된 과거 화면에서는 응답 버튼이 열리지 않습니다.' "$arena"; then
  echo 'GOAT Arena 방어자 복구 상태에 내부 저장 구현 문구가 남아 있습니다.' >&2
  exit 1
fi

# 학생이 누르는 최종 확인창에는 서버 상태 전환이나 reason code 같은 구현 용어를
# 노출하지 않고, 수락·거절 뒤 실제로 일어나는 일과 전달 범위만 설명한다.
grep -Fq '수락하면 경기 준비가 완료됩니다.' "$arena"
grep -Fq '선택한 거절 사유만 전달됩니다.' "$arena"
if grep -Fq '거절 사유 코드만 서버에 전달' "$arena"; then
  echo 'GOAT Arena 거절 확인창에 내부 reason code 표현이 남아 있습니다.' >&2
  exit 1
fi
if grep -Fq '고정 사유 코드' "$arena"; then
  echo 'GOAT Arena 사용자 안내에 내부 decline reason code 표현이 남아 있습니다.' >&2
  exit 1
fi

# Ranked 신청은 남는 가로 폭을 상태/선택 2열로 쓰고, 제출 CTA를 항상 고정한다.
grep -Fq 'private var compactHeight: Bool' "$maker"
grep -Fq 'private var narrowWidth: Bool' "$maker"
grep -Fq 'CompactHeightColumns(' "$maker"
grep -Fq 'statusColumn' "$maker"
grep -Fq 'actionColumn' "$maker"
grep -Fq 'compactModeButton' "$maker"
grep -Fq 'targetButton(target, compact: true)' "$maker"
grep -Fq '.safeAreaInset(edge: .bottom, spacing: 0)' "$maker"
grep -Fq 'submitButton(selectedTarget).frame(maxWidth: 360)' "$maker"
grep -Fq '이미 보낸 요청의 결과를 다시 확인하므로 경기가 중복으로 만들어지지 않습니다.' "$maker"
if grep -Fq '같은 요청 번호로 결과를 다시 확인' "$maker"; then
  echo 'GOAT Arena 이전 요청 안내에 내부 idempotency 표현이 남아 있습니다.' >&2
  exit 1
fi
grep -Fq '요청을 안전하게 저장하지 못했습니다. 기기 저장 공간을 확인하고 다시 시도해 주세요.' "$maker"

# 상점도 첫 화면에서 잔액만 차지하지 않고 실제 판매 항목을 보여준다. 다만 접근성
# 글자 크기에서는 요약을 억지로 한 줄에 누르지 않고 읽을 수 있는 원래 지갑으로 돌아간다.
grep -Fq 'if compactHeight && !dynamicTypeSize.isAccessibilitySize' "$shop"
grep -Fq 'compactWallet(shop)' "$shop"
grep -Fq 'private func compactWallet(' "$shop"

echo 'arena matchmaking landscape contract passed'
