#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
api="$root/Matths/AdminArenaAPI.swift"; screen="$root/Matths/AdminArenaScreen.swift"; fixture="$root/Matths/DemoAdminArenaFixtures.swift"; demo="$root/Matths/DemoMode.swift"; admin="$root/Matths/AdminAcademyScreen.swift"
for file in "$api" "$screen" "$fixture" "$demo" "$admin"; do [ -f "$file" ] || { echo "FAIL missing $file" >&2; exit 1; }; done
for behavior in adminArenaDashboard reviewAdminArenaMatch requestAdminArenaEvidence reviewAdminArenaCase rebuildAdminArenaRanking runAdminArenaMaintenance downloadAdminArenaRankingCSV downloadAdminArenaEvidence ADMIN_ARENA_NATIVE_V1; do grep -Fq "$behavior" "$api" || { echo "FAIL missing API $behavior" >&2; exit 1; }; done
for behavior in 'GOAT Arena 운영' 'case live = "실시간"' 'case history = "기록"' 'case integrity = "검토"' 'case audit = "감사"' 'case ranking = "랭킹"' '.seconds(15)' '추가 소명 요청' '경기 최종 판정' '계정 무결성 판정' '랭킹 재계산' 'CSV 내보내기' 'verticalSizeClass == .compact'; do grep -Fq "$behavior" "$screen" || { echo "FAIL missing UI $behavior" >&2; exit 1; }; done
grep -Fq 'GET /api/v1/admin/arena' "$demo"; grep -Fq '/api/v1/admin/arena/integrity/{caseId}/review' "$demo"; grep -Fq '"GOAT Arena 운영"' "$admin"
echo "native admin arena contract passed"
