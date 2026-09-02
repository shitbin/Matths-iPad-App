#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
api="$root/Matths/FaqAPI.swift"
screen="$root/Matths/FaqScreen.swift"
app="$root/Matths/MatthsApp.swift"
root_view="$root/Matths/RootView.swift"
demo="$root/Matths/DemoMode.swift"
fixture="$root/Matths/DemoFaqFixtures.swift"

for file in "$api" "$screen" "$app" "$root_view" "$demo" "$fixture"; do
  [ -f "$file" ] || { echo "FAIL: missing $file" >&2; exit 1; }
done

grep -Fq '"GET", "/api/v1/faq"' "$api"
grep -Fq 'authed: false' "$api"
grep -Fq 'value.schemaVersion == "FAQ_NATIVE_V1"' "$api"
for behavior in 'func load(' 'requestedFAQCode' 'viewport.size.height < 500' \
  'dynamicTypeSize.isAccessibilitySize' 'TextField("예: 로그인이 안 돼요"' \
  '문의 남기기' 'textSelection(.enabled)'; do
  grep -Fq "$behavior" "$screen" || { echo "FAIL: missing FAQ UI behavior $behavior" >&2; exit 1; }
done
grep -Fq 'route = .faq' "$app"
grep -Fq 'FaqScreen()' "$root_view"
grep -Fq 'GET /api/v1/faq' "$demo"
grep -Fq 'faq-error-409' "$fixture"

echo "native FAQ contract passed"
