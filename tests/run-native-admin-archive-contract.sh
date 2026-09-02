#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
api="$root/Matths/AdminArchiveAPI.swift"
screen="$root/Matths/AdminArchiveScreen.swift"
fixture="$root/Matths/DemoAdminArchiveFixtures.swift"
demo="$root/Matths/DemoMode.swift"
admin="$root/Matths/AdminAcademyScreen.swift"
for file in "$api" "$screen" "$fixture" "$demo" "$admin"; do [ -f "$file" ] || { echo "FAIL missing $file" >&2; exit 1; }; done
for behavior in adminArchive createAdminArchiveFolder updateAdminArchiveFolder pinAdminArchiveFolder deleteAdminArchiveFolder uploadAdminArchive deleteAdminArchiveItems moveAdminArchiveItems restoreAdminArchiveItem purgeAdminArchiveItem ADMIN_ARCHIVE_NATIVE_V1; do grep -Fq "$behavior" "$api" || { echo "FAIL missing API $behavior" >&2; exit 1; }; done
for behavior in '자료실 관리' 'case files = "자료", trash = "휴지통"' '파일 선택 (최대 20개)' '등록 후 회원에게 공지' '파일 원본 영구 삭제' 'verticalSizeClass == .compact'; do grep -Fq "$behavior" "$screen" || { echo "FAIL missing UI $behavior" >&2; exit 1; }; done
grep -Fq 'GET /api/v1/admin/archive' "$demo"
grep -Fq '/api/v1/admin/archive/trash/{itemId}/purge' "$demo"
grep -Fq '"자료실·배포 파일"' "$admin"
echo "native admin archive contract passed"
