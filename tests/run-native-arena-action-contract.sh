#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
screen="$root/Matths/GoatArenaScreen.swift"
api="$root/Matths/ServerAPI.swift"

# 운영 서버가 버전을 선언한 경우에만 실서버 네이티브 명령을 연다. 구버전/롤백
# 서버는 capability가 달라 첫 404 전에 웹 동선으로 물러나야 한다.
grep -Fq 'loadedContent?.snapshot.capabilities.challengeCommands == "ARENA_MATCH_V1"' "$screen"
grep -Fq 'guard !arenaCommandsUnavailable else { return false }' "$screen"

# 상대 찾기·초대 응답·증거 사진·로컬 검토가 모두 Bearer API를 사용한다.
grep -Fq '"/api/v1/goat-arena/matches/sub"' "$api"
grep -Fq '"/api/v1/goat-arena/matches/\(matchId)/accept"' "$api"
grep -Fq '"/api/v1/goat-arena/matches/\(matchId)/decline"' "$api"
grep -Fq '"/api/v1/goat-arena/matches/\(matchId)/evidence"' "$api"
grep -Fq '"/api/v1/goat-arena/matches/\(matchId)/evidence/client-review"' "$api"

main_sheet="$root/Matths/GoatArenaMainMatchSheet.swift"
grep -Fq '"/api/v1/goat-arena/matches/main/options"' "$main_sheet"
grep -Fq '"/api/v1/goat-arena/matches/main/upward"' "$main_sheet"
grep -Fq '"/api/v1/goat-arena/matches/main/invitations"' "$main_sheet"
grep -Fq '"/api/v1/goat-arena/matches/main/invitations/\(invitationId)/cancel"' "$main_sheet"
grep -Fq 'GoatArenaMainCommandStore.save' "$main_sheet"
grep -Fq 'GoatArenaMainCommandStore.clear' "$main_sheet"

# 수락·거절은 동일 명령 키를 디스크에 먼저 보존하고 성공 뒤에만 지운다.
grep -Fq 'GoatArenaDefenderCommandStore.prepare' "$screen"
grep -Fq 'GoatArenaDefenderCommandStore.clear' "$screen"
grep -Fq 'await load()' "$screen"

# 더 보기 메뉴는 이미 있는 네이티브 알림함·순위표·상점·룰북을 웹으로 중복
# 연결하지 않는다. Ranked 대전 관리와 페이백 계좌도 네이티브 시트다.
grep -Fq 'onOpenNotifications' "$screen"
grep -Fq 'onOpenLeaderboard' "$screen"
grep -Fq 'onOpenRulebook' "$screen"
grep -Fq 'onOpenArenaShop' "$screen"
grep -Fq 'onOpenRankedMatchmaker' "$screen"
grep -Fq 'onOpenFriendlyMatchmaker' "$screen"
grep -Fq 'onOpenPaybackAccount' "$screen"
grep -Fq 'GoatArenaPaybackAccountSheet()' "$screen"
for duplicate in '.mailbox' '.rankings' '.shop' '.rulesUnranked' '.rulesRanked' '.unrankedChallenge' '.rankedBattle' '.profile'; do
  if grep -F 'Row(destination:' "$screen" | grep -Fq "$duplicate"; then
    echo "Arena 더 보기 메뉴가 네이티브 기능을 웹으로 중복 연결합니다: $duplicate" >&2
    exit 1
  fi
done

payback="$root/Matths/GoatArenaPaybackAccountSheet.swift"
grep -Fq '"/api/v1/goat-arena/profile/payback-account"' "$payback"
grep -Fq '"/api/v1/goat-arena/profile/payback-account/confirm"' "$payback"
grep -Fq 'accountNumber.filter(\.isNumber)' "$payback"
grep -Fq 'clearSensitiveDraft()' "$payback"
grep -Fq 'CompactHeightColumns(' "$payback"

friendly="$root/Matths/GoatArenaFriendlyMatchSheet.swift"
grep -Fq '"/api/v1/goat-arena/matches/main/friendly"' "$friendly"
grep -Fq '"/api/v1/goat-arena/matches/main/friendly/invitations"' "$friendly"
grep -Fq '"/api/v1/goat-arena/matches/main/friendly/invitations/\(invitationId)/respond"' "$friendly"
grep -Fq '"/api/v1/goat-arena/matches/main/friendly/invitations/\(invitationId)/cancel"' "$friendly"
grep -Fq 'CompactHeightColumns(' "$friendly"
grep -Fq '양쪽에서 수수료' "$friendly"

echo 'Native Arena matchmaking, invitation, evidence, and client review contracts passed.'
