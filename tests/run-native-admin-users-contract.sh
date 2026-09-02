#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
api="$root/Matths/AdminUsersAPI.swift"
screen="$root/Matths/AdminUsersScreen.swift"
activity_screen="$root/Matths/AdminUserActivityScreen.swift"
fixture="$root/Matths/DemoAdminUsersFixtures.swift"
demo="$root/Matths/DemoMode.swift"
admin="$root/Matths/AdminAcademyScreen.swift"
root_view="$root/Matths/RootView.swift"

for file in "$api" "$screen" "$activity_screen" "$fixture" "$demo" "$admin" "$root_view"; do
  [ -f "$file" ] || { echo "FAIL: missing $file" >&2; exit 1; }
done

for route in '/api/v1/admin/users' '/api/v1/admin/parents' '/api/v1/admin/sanctions' '/api/v1/admin/audit-log'; do
  grep -Fq "$route" "$api" || { echo "FAIL: missing native user route $route" >&2; exit 1; }
  grep -Fq "$route" "$demo" || { echo "FAIL: missing demo user route $route" >&2; exit 1; }
done

grep -Fq '/api/v1/admin/users/\(userID)/activity' "$api"
grep -Fq '/api/v1/admin/users/\(userID)/assessments' "$api"
grep -Fq '/api/v1/admin/users/{userId}/activity' "$demo"
grep -Fq '/api/v1/admin/users/{userId}/assessments/{attemptId}' "$demo"

for behavior in adminUsers adminUser adminParent adminSanctions adminAudit \
  requestAdminNicknameChange sendAdminUserNotification sendAdminUserEmail sendAdminPasswordReset \
  updateAdminUserRole updateAdminUserAccountStatus updateAdminUserWarnings updateAdminUserPackage \
  withdrawAdminUser updateAdminParentStatus updateAdminParentChildNotifications unlinkAdminParentChild \
  adminUserActivity adminUserAssessment AdminAssessmentQuestion AdminUserActivityItem \
  ADMIN_USERS_NATIVE_V1; do
  grep -Fq "$behavior" "$api" || { echo "FAIL: missing native user behavior $behavior" >&2; exit 1; }
done

for behavior in '전체 활동·평가 원본 기록' 'case learning, problems, quick, assessments' '문항별 답안' 'answerChanges' \
  'verticalSizeClass == .compact' '문항·제출 답안 보기'; do
  grep -Fq "$behavior" "$activity_screen" || { echo "FAIL: missing user activity UI behavior $behavior" >&2; exit 1; }
done

for behavior in 'case users = "사용자"' 'case sanctions = "제재"' 'case audit = "감사"' \
  'verticalSizeClass == .compact' 'TextField("이름·이메일 검색"' 'Label("관리 작업"' \
  'case .parentNotifications' 'case .withdraw' '계정삭제' 'accessibilityElement(children: .combine)'; do
  grep -Fq "$behavior" "$screen" || { echo "FAIL: missing native user UI behavior $behavior" >&2; exit 1; }
done

grep -Fq '"사용자·제재 관리"' "$admin"
grep -Fq 'contains("-adminUsers")' "$root_view"
grep -Fq 'contains("-adminSanctions")' "$root_view"
grep -Fq 'contains("-adminAudit")' "$root_view"
grep -Fq 'demo-parent-1' "$fixture"

echo "native admin users contract passed"
