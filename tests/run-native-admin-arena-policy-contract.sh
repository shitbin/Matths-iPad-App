#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
api="$root/Matths/AdminArenaPolicyAPI.swift"; screen="$root/Matths/AdminArenaPolicyScreen.swift"; demo="$root/Matths/DemoMode.swift"; admin="$root/Matths/AdminAcademyScreen.swift"
for file in "$api" "$screen" "$root/Matths/DemoAdminArenaPolicyFixtures.swift" "$demo" "$admin"; do [ -f "$file" ] || { echo "FAIL missing $file" >&2; exit 1; }; done
for value in ADMIN_ARENA_POLICY_NATIVE_V1 setAdminArenaMatchmaking setAdminLearningPrice setAdminMockPrice setAdminArenaShop createAdminUnrankedPolicy createAdminRankedPolicy activateAdminArenaPolicy retireAdminArenaPolicy; do grep -Fq "$value" "$api" || { echo "FAIL missing API $value" >&2; exit 1; }; done
for value in 'Arena 정책·가격' '신규 매치메이킹 일시정지' '상점 정책 편집' 'Unranked 정책 만들기' 'Ranked 정책 만들기' '30일 후 적용 예약' '티어별 일일 방어 상한' '페이백 점수' '티어 차이별 최소 예치'; do grep -Fq "$value" "$screen" || { echo "FAIL missing UI $value" >&2; exit 1; }; done
grep -Fq 'GET /api/v1/admin/arena-policies' "$demo"; grep -Fq '"Arena 정책·가격"' "$admin"
echo "native admin Arena policy contract passed"
