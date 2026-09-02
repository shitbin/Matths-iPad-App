#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
api="$root/Matths/AdminOperationsAPI.swift"
screen="$root/Matths/AdminOperationsScreen.swift"
admin="$root/Matths/AdminAcademyScreen.swift"
root_view="$root/Matths/RootView.swift"
teacher="$root/Matths/TeacherAcademyScreen.swift"
demo="$root/Matths/DemoMode.swift"
fixture="$root/Matths/DemoAdminOperationsFixtures.swift"

for file in "$api" "$screen" "$admin" "$root_view" "$teacher" "$demo" "$fixture"; do
  [ -f "$file" ] || { echo "FAIL: missing $file" >&2; exit 1; }
done

for route in '/api/v1/admin/operations' '/api/v1/admin/todos' '/api/v1/admin/inquiries' '/api/v1/admin/announcements'; do
  grep -Fq "$route" "$api" || { echo "FAIL: missing native admin route $route" >&2; exit 1; }
  grep -Fq "$route" "$demo" || { echo "FAIL: missing demo admin route $route" >&2; exit 1; }
done

for behavior in 'adminOperationsDashboard' 'adminOperationsTodos' 'setAdminTodo' \
  'adminOperationsInquiries' 'replyToAdminInquiry' 'updateAdminInquiryStatus' \
  'adminOperationsAnnouncements' 'createAdminAnnouncement' 'setAdminAnnouncementPublished' \
  'ADMIN_OPERATIONS_NATIVE_V1'; do
  grep -Fq "$behavior" "$api" || { echo "FAIL: missing admin API behavior $behavior" >&2; exit 1; }
done

for behavior in 'verticalSizeClass == .compact' 'case todos = "할 일"' 'case inquiries = "문의"' 'case announcements = "공지"' \
  'TextEditor(text: $message)' '답변 이메일을 실제로 전송할까요?' '상태 변경' \
  '완료 처리' '다시 열기' '새 공지' '저장하고 공개' 'accessibilityElement(children: .combine)'; do
  grep -Fq "$behavior" "$screen" || { echo "FAIL: missing admin UI behavior $behavior" >&2; exit 1; }
done
grep -Fq 'contains("-adminAnnouncements")' "$screen"
grep -Fq 'contains("-adminInquiries")' "$screen"

grep -Fq 'AdminOperationsScreen { showsOperations = false }' "$admin"
grep -Fq '"문의·운영 할 일"' "$admin"
grep -Fq 'contains("-adminOperations")' "$root_view"
if grep -Fq 'Button("웹 고급 관리")' "$teacher"; then
  echo "FAIL: teacher academy still exposes redundant hosted management" >&2
  exit 1
fi
grep -Fq 'demo-inquiry-1' "$fixture"

echo "native admin operations contract passed"
