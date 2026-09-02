#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd); api="$root/Matths/AdminProblemBankAPI.swift"; screen="$root/Matths/AdminProblemBankScreen.swift"; demo="$root/Matths/DemoMode.swift"; admin="$root/Matths/AdminAcademyScreen.swift"
for file in "$api" "$screen" "$root/Matths/DemoAdminProblemBankFixtures.swift" "$demo" "$admin"; do [ -f "$file" ] || { echo "FAIL missing $file" >&2; exit 1; }; done
for value in ADMIN_PROBLEM_BANK_NATIVE_V1 adminProblemBanks syncAdminProblemTypes reviseAdminProblemType createAdminTierProblemType createAdminProblemData updateAdminProblemData activateAdminProblemData; do grep -Fq "$value" "$api" || { echo "FAIL missing API $value" >&2; exit 1; }; done
for value in '문제 유형·Arena 데이터' '서버 생성기 검산·동기화' '설정 새 리비전' '새 초안 만들기' '검산 후 적용' '유형별 출제 데이터' '난이도별 유형 · 최소 5개' 'T1~T9 문제 카탈로그' 'JavaScript 코드를 저장·실행하지 않습니다'; do grep -Fq "$value" "$screen" || { echo "FAIL missing UI $value" >&2; exit 1; }; done
grep -Fq 'GET /api/v1/admin/problem-banks' "$demo"; grep -Fq '"문제 유형·Arena 데이터"' "$admin"
echo "native admin problem bank contract passed"
