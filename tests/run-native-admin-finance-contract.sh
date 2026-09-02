#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
api="$root/Matths/AdminFinanceAPI.swift"
screen="$root/Matths/AdminFinanceScreen.swift"
demo="$root/Matths/DemoMode.swift"
entry="$root/Matths/AdminAcademyScreen.swift"

for file in "$api" "$screen" "$demo" "$entry" "$root/Matths/DemoAdminFinanceFixtures.swift"; do
  test -f "$file" || { echo "missing native admin finance file: $file" >&2; exit 1; }
done

for path in \
  '/api/v1/admin/finance' \
  '/api/v1/admin/finance/withdrawals' \
  '/api/v1/admin/finance/other-unpaid-costs' \
  '/api/v1/admin/refunds' \
  '/calculate' \
  '/complete' \
  '/reject' \
  '/api/v1/admin/paybacks' \
  '/resend-email'; do
  rg -q -F "$path" "$api" || { echo "missing API path: $path" >&2; exit 1; }
done

for behavior in \
  'ADMIN_FINANCE_NATIVE_V1' \
  'confirmationDialog("최종 처리할까요?"' \
  '실제 송금 완료 기록' \
  'PG 수수료 준비금 설정 전이라 사업자 출금이 잠겨 있습니다.' \
  'verticalSizeClass == .compact && !dynamicTypeSize.isAccessibilitySize'; do
  rg -q -F "$behavior" "$screen" "$api" || { echo "missing native finance behavior: $behavior" >&2; exit 1; }
done

rg -q -F 'DemoAdminFinanceFixtures.finance' "$demo"
rg -q -F '"재무·환불·페이백"' "$entry"
if rg -q 'WKWebView|SFSafariViewController|SafariView' "$screen"; then
  echo "admin finance screen must stay native" >&2
  exit 1
fi

echo "native admin finance contract passed"
