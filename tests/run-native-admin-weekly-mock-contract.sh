#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
api="$root/Matths/AdminWeeklyMockAPI.swift"
screen="$root/Matths/AdminWeeklyMockScreen.swift"
fixture="$root/Matths/DemoAdminWeeklyMockFixtures.swift"
demo="$root/Matths/DemoMode.swift"
admin="$root/Matths/AdminAcademyScreen.swift"
for file in "$api" "$screen" "$fixture" "$demo" "$admin"; do [ -f "$file" ] || { echo "FAIL missing $file" >&2; exit 1; }; done
for behavior in adminWeeklyMockDashboard adminWeeklyMockDetail requestAdminMockIntegrityEvidence reviewAdminMockIntegrity correctAdminMockAnswers deleteAdminWeeklyMock adminWeeklyMockObjection rejectAdminWeeklyMockObjection acceptAdminWeeklyMockObjection ADMIN_WEEKLY_MOCK_NATIVE_V1; do grep -Fq "$behavior" "$api" || { echo "FAIL missing API $behavior" >&2; exit 1; }; done
for behavior in 'case exams = "회차·응시"' '풀이과정 소명 자료 요청' '정답 정정·전체 재채점' '공정성 소명 검토' '문항별 채점' '전체 이벤트 로그' '이의신청 인용' '최종 처리할까요?' 'verticalSizeClass == .compact'; do grep -Fq "$behavior" "$screen" || { echo "FAIL missing UI $behavior" >&2; exit 1; }; done
grep -Fq 'GET /api/v1/admin/weekly-mock-exams' "$demo"
grep -Fq '/api/v1/admin/weekly-mock-objections/{objectionId}' "$demo"
grep -Fq '"주간 모의고사 운영"' "$admin"
echo "native admin weekly mock contract passed"
