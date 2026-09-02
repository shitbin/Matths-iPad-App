#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
api="$root/Matths/AdminDataAnalysisAPI.swift"
screen="$root/Matths/AdminDataAnalysisScreen.swift"
fixture="$root/Matths/DemoAdminDataAnalysisFixtures.swift"
demo="$root/Matths/DemoMode.swift"
admin="$root/Matths/AdminAcademyScreen.swift"
for file in "$api" "$screen" "$fixture" "$demo" "$admin"; do [ -f "$file" ] || { echo "FAIL missing $file" >&2; exit 1; }; done
for value in ADMIN_DATA_ANALYSIS_NATIVE_V1 adminDataAnalysis rebuildAdminDataAnalysis '/api/v1/admin/data-analysis'; do grep -Fq "$value" "$api" || { echo "FAIL missing API $value" >&2; exit 1; }; done
for value in '운영 지표' '원장에서 다시 집계' 'verticalSizeClass == .compact' '출시 전 가정 비교' '분자' '분모' '표본'; do grep -Fq "$value" "$screen" || { echo "FAIL missing UI $value" >&2; exit 1; }; done
grep -Fq 'GET /api/v1/admin/data-analysis' "$demo"
grep -Fq '"월별 운영 지표"' "$admin"
echo "native admin data analysis contract passed"
