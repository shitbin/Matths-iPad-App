#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
api="$root/Matths/AdminPdfForensicsAPI.swift"; screen="$root/Matths/AdminPdfForensicsScreen.swift"; demo="$root/Matths/DemoMode.swift"; admin="$root/Matths/AdminAcademyScreen.swift"
for file in "$api" "$screen" "$root/Matths/DemoAdminPdfForensicsFixtures.swift" "$demo" "$admin"; do [ -f "$file" ] || { echo "FAIL missing $file" >&2; exit 1; }; done
for value in ADMIN_PDF_FORENSICS_NATIVE_V1 analyzeAdminPdfForensics forensicFile '50 * 1024 * 1024'; do grep -Fq "$value" "$api" || { echo "FAIL missing API $value" >&2; exit 1; }; done
for value in 'PDF·스크린샷 유출 추적' 'verticalSizeClass == .compact' '서명 검증' 'OCR' '판정 원칙' '서버 임시 파일은 결과 생성 직후 삭제'; do grep -Fq "$value" "$screen" || { echo "FAIL missing UI $value" >&2; exit 1; }; done
grep -Fq 'POST /api/v1/admin/pdf-forensics/analyze' "$demo"
grep -Fq '"PDF·스크린샷 유출 추적"' "$admin"
echo "native admin PDF forensics contract passed"
