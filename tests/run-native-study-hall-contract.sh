#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
api="$root/Matths/StudyHallAPI.swift"
screen="$root/Matths/StudyHallScreen.swift"
app="$root/Matths/MatthsApp.swift"
root_view="$root/Matths/RootView.swift"
demo="$root/Matths/DemoMode.swift"

for file in "$api" "$screen" "$app" "$root_view" "$demo"; do
  [ -f "$file" ] || { echo "FAIL: missing $file" >&2; exit 1; }
done

for path in \
  '/api/v1/study-hall"' \
  '/api/v1/study-hall/content/\(contentID)' \
  '/files/\(asset.id)'; do
  grep -Fq "$path" "$api" || { echo "FAIL: missing API path $path" >&2; exit 1; }
done

for rule in \
  'value == "STUDY_HALL_NATIVE_V1"' \
  'validateAuthorizedResponse' \
  'DataScope.slot' \
  'isExcludedFromBackup = true'; do
  grep -Fq "$rule" "$api" || { echo "FAIL: missing transport rule $rule" >&2; exit 1; }
done

for behavior in \
  'func selectTab' 'func open(' 'func save()' 'func submit()' 'func download(' \
  '최종 제출할까요?' '제출 후에는 답안을 바꿀 수 없고' \
  'asset.kind == "SOLUTION_PDF"' 'content.progress.status != "SUBMITTED"' \
  'viewport.size.height < 500' 'viewport.safeAreaInsets.leading' \
  'dynamicTypeSize.isAccessibilitySize' 'compactHeightSheet'; do
  grep -Fq "$behavior" "$screen" || { echo "FAIL: missing UI rule $behavior" >&2; exit 1; }
done

grep -Fq 'case services, academy, coachSuggestions, support, archive, studyHall, storeCatalog, faq, hostedPortal' "$app"
grep -Fq 'requestedStudyHallContentID' "$app"
grep -Fq 'route = .studyHall' "$app"
grep -Fq 'StudyHallScreen()' "$root_view"
grep -Fq 'GET /api/v1/study-hall' "$demo"
grep -Fq '/api/v1/study-hall/content/{contentId}' "$demo"

echo "native study hall contract passed"
