#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd); api="$root/Matths/AdminOperationsGuideAPI.swift"; screen="$root/Matths/AdminOperationsGuideScreen.swift"; demo="$root/Matths/DemoMode.swift"; admin="$root/Matths/AdminAcademyScreen.swift"
for file in "$api" "$screen" "$root/Matths/DemoAdminOperationsGuideFixtures.swift" "$demo" "$admin"; do [ -f "$file" ] || { echo "FAIL missing $file" >&2; exit 1; }; done
for value in ADMIN_OPERATIONS_GUIDE_NATIVE_V1 adminOperationsGuide schemaCategories storageMatrix retentionPolicies schedulers incidentPlaybook operatingWorkflows environmentConfiguration; do grep -Fq "$value" "$api" || { echo "FAIL missing API $value" >&2; exit 1; }; done
for value in '관리자 운영 매뉴얼' '매일 확인' '표준 절차' '저장·보존' '자동·장애' 'DB 스키마' '비밀값 표시 원칙' '장애 대응 순서' '필드 정의' '인덱스·TTL'; do grep -Fq "$value" "$screen" || { echo "FAIL missing UI $value" >&2; exit 1; }; done
grep -Fq 'GET /api/v1/admin/operations-guide' "$demo"; grep -Fq '"운영 매뉴얼·DB 스키마"' "$admin"
echo "native admin operations guide contract passed"
