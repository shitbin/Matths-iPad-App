#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
api="$root/Matths/AdminStoreAPI.swift"
screen="$root/Matths/AdminStoreScreen.swift"
fixture="$root/Matths/DemoAdminStoreFixtures.swift"
demo="$root/Matths/DemoMode.swift"
admin="$root/Matths/AdminAcademyScreen.swift"
for file in "$api" "$screen" "$fixture" "$demo" "$admin"; do [ -f "$file" ] || { echo "FAIL missing $file" >&2; exit 1; }; done
for behavior in adminStoreDashboard saveAdminStudyHallContent archiveAdminStudyHallContent saveAdminStoreProduct deleteAdminStoreProduct createAdminStoreCategory updateAdminStoreCategory reorderAdminStoreCategories deleteAdminStoreCategory ADMIN_STORE_NATIVE_V1; do grep -Fq "$behavior" "$api" || { echo "FAIL missing API $behavior" >&2; exit 1; }; done
for behavior in '수험관·상점 운영' 'case hall = "수험관", products = "상품", categories = "카테고리"' '답지 JSON 파일 선택' '파일 실제 형식' '상품·파일 영구 삭제' '노출 순서는 사용자 상점' 'verticalSizeClass == .compact'; do grep -Fq "$behavior" "$screen" || { echo "FAIL missing UI $behavior" >&2; exit 1; }; done
grep -Fq 'GET /api/v1/admin/store' "$demo"
grep -Fq '/api/v1/admin/store/products/{productId}/delete' "$demo"
grep -Fq '"수험관·상점 운영"' "$admin"
echo "native admin store contract passed"
