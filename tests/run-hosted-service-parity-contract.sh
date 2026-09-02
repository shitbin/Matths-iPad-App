#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
hub="$root/Matths/ServiceHubScreen.swift"
community="$root/Matths/CommunityScreen.swift"
app="$root/Matths/MatthsApp.swift"
root_view="$root/Matths/RootView.swift"
notifications="$root/Matths/NotificationInboxScreen.swift"
server_api="$root/Matths/ServerAPI.swift"
academy="$root/Matths/AcademyScreen.swift"
teacher_academy="$root/Matths/TeacherAcademyScreen.swift"
teacher_classwork="$root/Matths/TeacherClassworkPanel.swift"
teacher_classes="$root/Matths/TeacherClassManagementPanel.swift"
teacher_students="$root/Matths/TeacherStudentManagementPanel.swift"
teacher_analytics="$root/Matths/TeacherAnalyticsPanel.swift"
teacher_setup="$root/Matths/TeacherAcademySetupPanel.swift"
teacher_profile="$root/Matths/TeacherAcademyProfilePanel.swift"
teacher_forensics="$root/Matths/TeacherAcademyForensicsPanel.swift"
admin_academy="$root/Matths/AdminAcademyScreen.swift"
admin_academy_explorer="$root/Matths/AdminAcademyExplorer.swift"
coach_suggestions="$root/Matths/CoachSuggestionsScreen.swift"
support="$root/Matths/SupportInquiryScreen.swift"
archive="$root/Matths/ArchiveLibraryScreen.swift"
study_hall="$root/Matths/StudyHallScreen.swift"
study_hall_api="$root/Matths/StudyHallAPI.swift"
store_catalog="$root/Matths/StoreCatalogScreen.swift"
store_catalog_api="$root/Matths/StoreCatalogAPI.swift"
faq="$root/Matths/FaqScreen.swift"
faq_api="$root/Matths/FaqAPI.swift"
demo_mode="$root/Matths/DemoMode.swift"
demo_account_fixtures="$root/Matths/DemoFixtures/DemoFixturesAccount.swift"
entitlements="$root/Matths/MatthsApp.entitlements"

for file in "$hub" "$community" "$app" "$root_view" "$notifications" "$server_api" "$academy" "$teacher_academy" "$teacher_classwork" "$teacher_classes" "$teacher_students" "$teacher_analytics" "$teacher_setup" "$teacher_profile" "$teacher_forensics" "$admin_academy" "$admin_academy_explorer" "$coach_suggestions" "$support" "$archive" "$study_hall" "$study_hall_api" "$store_catalog" "$store_catalog_api" "$faq" "$faq_api" "$demo_mode" "$demo_account_fixtures" "$entitlements"; do
  test -f "$file" || { echo "FAIL: missing hosted-service source: $file" >&2; exit 1; }
done

# 웹의 세션 전용 기능군은 역할 기반 허브에서 하나도 빠뜨리지 않는다.
for path in /my-academy /academy /admin /archive /store /coach-suggestions /contact /faq /parent/login; do
  grep -Fq "path: \"$path\"" "$hub" || {
    echo "FAIL: missing hosted service path $path" >&2
    exit 1
  }
done
grep -Fq 'case "admin": .admin' "$hub"
grep -Fq 'case "teacher": .teacherAcademy' "$hub"
grep -Fq 'default: .studentAcademy' "$hub"
grep -Fq 'var role: String? = nil' "$server_api"

# 허브/포털은 별도 탭을 늘리지 않고 기존 홈과 프로필에서 들어간다.
grep -Fq 'case services, academy, coachSuggestions, support, archive, studyHall, storeCatalog, faq, hostedPortal' "$app"
grep -Fq 'func openHostedPortal(_ destination: HostedPortalDestination)' "$app"
grep -Fq 'destination == .studentAcademy' "$app"
grep -Fq 'case .services:    ServiceHubScreen()' "$root_view"
grep -Fq 'case .academy:' "$root_view"
grep -Fq 'AcademyScreen()' "$root_view"
grep -Fq 'HostedServicePortalScreen(destination: store.hostedPortalDestination)' "$root_view"
grep -Fq 'entry(title: "학원·서비스"' "$root_view"
grep -Fq 'requestedStoreProductSlug' "$app"
grep -Fq 'StoreCatalogScreen()' "$root_view"
grep -Fq 'ServerAPI.storeCatalog' "$store_catalog"
grep -Fq 'ServerAPI.storeProduct' "$store_catalog"
grep -Fq 'ServerAPI.downloadStoreProductFile' "$store_catalog"
grep -Fq 'ServerAPI.faq' "$faq"
grep -Fq 'FaqScreen()' "$root_view"

# 상세 알림과 같은 서버 유니버설 링크는 목록 첫 화면으로 뭉개지지 않는다.
grep -Fq 'static func fromInternalHref(_ rawHref: String)' "$hub"
grep -Fq 'static func fromDeepLink(_ url: URL)' "$hub"
grep -Fq 'HostedPortalDestination.fromInternalHref(item.href)' "$notifications"
grep -Fq 'store.openHostedPortal(destination)' "$notifications"
grep -Fq 'HostedPortalDestination.fromDeepLink(url)' "$app"
grep -Fq 'HostedPortalDestination.isTrustedServerURL(url)' "$app"
grep -Fq 'NotificationInboxScreen.nativeRoute(for: href)' "$app"
for route in /visual-learning /learning-flow /integrity/cases /account/private-mock-restriction /war-of-masters /nickname-change; do
  grep -Fq "\"$route\"" "$notifications" || {
    echo "FAIL: missing native web deep-link route $route" >&2
    exit 1
  }
done

# 앱 설치 기기에서 공개 유니버설 링크를 삼키지 않는다. 비밀번호 메일의 query token과
# 별도 학부모 세션 초대는 원래 URL 그대로 SFSafariViewController에 전달한다.
grep -Fq 'struct PublicServerWebDestination: Identifiable, Hashable' "$hub"
grep -Fq 'path == "/forgot-password/link"' "$hub"
grep -Fq 'path.hasPrefix("/parent/invite/")' "$hub"
grep -Fq 'static func parentPortal(path: String = "/parent/login")' "$hub"
grep -Fq 'PublicServerWebDestination.parentPortal(path: destination.path)' "$app"
grep -Fq 'openPublicWeb(parentDestination)' "$app"
grep -Fq 'let url: URL' "$hub"
grep -Fq 'PublicServerWebDestination.fromDeepLink(url)' "$app"
grep -Fq '.compactHeightSheet(item: $store.publicWebDestination)' "$app"
grep -Fq 'CommunitySafariView(url: destination.url)' "$app"
grep -Fq '<key>com.apple.developer.associated-domains</key>' "$entitlements"
grep -Fq '<string>applinks:www.matths.kr</string>' "$entitlements"
grep -Fq '<string>applinks:matths.kr</string>' "$entitlements"

# 앱 Bearer → 일회용 핸드오프 → 서버 세션 순서를 재사용하고, 결제 표면은 StoreKit으로 돌린다.
grep -Fq 'func start(signedIn: Bool, path: String = "/community")' "$community"
grep -Fq 'let handoff = try await ServerAPI.createCommerceHandoff(mode: "pricing")' "$community"
grep -Fq 'ServerAPI.isWebPurchasePath(trimmed)' "$community"
grep -Fq 'ServerAPI.isWebPurchaseSurface(url)' "$community"
grep -Fq '@Published var wantsNativeCommerce = false' "$community"
grep -Fq 'store.route = .commerce' "$hub"

# 학생의 반복 학원 행동은 웹뷰가 아니라 Bearer API와 네이티브 화면이 소유한다.
for path in /api/v1/academy/student /api/v1/academy/student/join-code /api/v1/academy/student/join /api/v1/academy/student/leave /api/v1/academy/student/attendance/check-in; do
  grep -Fq "\"$path\"" "$server_api" || {
    echo "FAIL: missing native academy API $path" >&2
    exit 1
  }
done
for behavior in 'ServerAPI.academyDashboard()' 'ServerAPI.academyWeek(weekID)' 'ServerAPI.checkInAcademyAttendance' 'ServerAPI.downloadAcademyFile' 'store.openConceptV2(concept.conceptId)'; do
  grep -Fq "$behavior" "$academy" || {
    echo "FAIL: missing native academy behavior $behavior" >&2
    exit 1
  }
done
grep -Fq 'verticalSizeClass == .compact' "$academy"
grep -Fq 'else if compactLandscape {' "$academy"
if grep -Fq 'Button("학원 서비스 전체")' "$academy"; then
  echo "FAIL: native student academy must not loop back through its own portal" >&2
  exit 1
fi

# 교사는 승인·학생 상세·일괄 명단·반 배정·출결·주차 과제·반·초대를 네이티브에서 처리한다.
for path in /api/v1/academy/teacher /api/v1/academy/teacher/setup /api/v1/academy/teacher/analytics /api/v1/academy/teacher/requests/ /api/v1/academy/teacher/students/ /api/v1/academy/teacher/invites /api/v1/academy/teacher/attendance; do
  grep -Fq "$path" "$server_api" || {
    echo "FAIL: missing native teacher academy API $path" >&2
    exit 1
  }
done
for behavior in 'ServerAPI.teacherAcademyDashboard()' 'ServerAPI.reviewAcademyStudent' 'ServerAPI.assignAcademyStudent' 'ServerAPI.removeAcademyStudent' 'ServerAPI.createAcademyInvite' 'ServerAPI.revokeAcademyInvite' 'ServerAPI.teacherAcademyAttendance' 'ServerAPI.saveTeacherAcademyAttendance' 'ServerAPI.regenerateTeacherAttendanceCode'; do
  grep -Fq "$behavior" "$teacher_academy" || {
    echo "FAIL: missing native teacher academy behavior $behavior" >&2
    exit 1
  }
done
for behavior in 'ServerAPI.reviewAcademyStaff' 'ServerAPI.revokeAcademyStaff'; do
  grep -Fq "$behavior" "$teacher_academy" || {
    echo "FAIL: missing native teacher staff behavior $behavior" >&2
    exit 1
  }
done
grep -Fq 'TeacherAcademyScreen()' "$root_view"
grep -Fq 'destination == .teacherAcademy && role == "teacher"' "$app"
grep -Fq 'case attendance = "출결"' "$teacher_academy"
grep -Fq 'case classwork = "과제"' "$teacher_academy"
grep -Fq 'case staff = "선생님"' "$teacher_academy"
if grep -Fq 'Button("웹 고급 관리")' "$teacher_academy"; then
  echo "FAIL: teacher academy still exposes redundant hosted management" >&2
  exit 1
fi
grep -Fq 'attendanceStatusMenu' "$teacher_academy"
grep -Fq 'TextField("메모(선택)"' "$teacher_academy"
grep -Fq 'ShareLink(item: "Matths 출석 코드:' "$teacher_academy"
grep -Fq 'verticalSizeClass == .compact' "$teacher_academy"
grep -Fq 'body: nil, authed: true, query: query' "$server_api"
grep -Fq 'listContainer(refreshesAttendance: true)' "$teacher_academy"
grep -Fq 'attendanceDateKey == requestedDateKey' "$teacher_academy"
grep -Fq 'dynamicTypeSize.isAccessibilitySize' "$teacher_academy"
grep -Fq '.pickerStyle(.menu)' "$teacher_academy"
grep -Fq 'GridItem(.adaptive(minimum: 120)' "$teacher_academy"
grep -Fq '"-teacherAttendanceFixture"' "$teacher_academy"
grep -Fq 'DemoAccountFixtures.teacherAttendanceRoster' "$demo_mode"
grep -Fq 'DemoAccountFixtures.teacherAttendanceSession' "$demo_mode"
grep -Fq 'static let teacherAttendanceRoster' "$demo_account_fixtures"
grep -Fq 'static let teacherAttendanceEmpty' "$demo_account_fixtures"
grep -Fq 'Button("출결부 다시 불러오기")' "$teacher_academy"
for path in '/api/v1/academy/teacher/classes/' '/classwork/weeks' '/files/' '/remove' '/delete'; do
  grep -Fq "$path" "$server_api" || {
    echo "FAIL: missing native teacher classwork API fragment $path" >&2
    exit 1
  }
done
for behavior in 'ServerAPI.teacherAcademyClasswork' 'ServerAPI.saveTeacherAcademyClassWeek' 'ServerAPI.removeTeacherAcademyClassWeekFile' 'ServerAPI.deleteTeacherAcademyClassWeek' 'ServerAPI.downloadTeacherAcademyFile'; do
  grep -Fq "$behavior" "$teacher_classwork" || {
    echo "FAIL: missing native teacher classwork behavior $behavior" >&2
    exit 1
  }
done
grep -Fq 'TeacherClassworkPanel(classes: dashboard.classes)' "$teacher_academy"
grep -Fq 'static let teacherClasswork' "$demo_account_fixtures"
grep -Fq 'DemoAccountFixtures.teacherClasswork' "$demo_mode"
grep -Fq 'allowsMultipleSelection: true' "$teacher_classwork"
grep -Fq 'CommunityFilePreview(url: url)' "$teacher_classwork"
grep -Fq '/api/v1/academy/teacher/staff/' "$server_api"
grep -Fq 'staffPendingCount' "$server_api"
grep -Fq 'staffList(dashboard)' "$teacher_academy"
for behavior in 'ServerAPI.createTeacherAcademyClass' 'ServerAPI.updateTeacherAcademyClass' 'ServerAPI.archiveTeacherAcademyClass' 'ServerAPI.restoreTeacherAcademyClass'; do
  grep -Fq "$behavior" "$teacher_academy" || {
    echo "FAIL: missing native teacher class behavior $behavior" >&2
    exit 1
  }
done
for behavior in 'ServerAPI.addTeacherAcademyClassCoTeacher' 'ServerAPI.removeTeacherAcademyClassCoTeacher' 'ServerAPI.transferTeacherAcademyClassHomeroom'; do
  grep -Fq "$behavior" "$teacher_academy" || {
    echo "FAIL: missing native class teacher assignment behavior $behavior" >&2
    exit 1
  }
done
grep -Fq 'TeacherClassManagementPanel(dashboard: dashboard, model: model)' "$teacher_academy"
grep -Fq 'case classes = "반"' "$teacher_academy"
grep -Fq 'canManage' "$server_api"
grep -Fq 'startTeacherManagement' "$teacher_classes"
grep -Fq '담임 이전' "$teacher_classes"
for path in '/api/v1/academy/teacher/students"' '/api/v1/academy/teacher/students/\(membershipID)' '/api/v1/academy/teacher/students/bulk'; do
  grep -Fq "$path" "$server_api" || {
    echo "FAIL: missing native teacher student management API $path" >&2
    exit 1
  }
done
for behavior in 'ServerAPI.teacherAcademyStudents' 'ServerAPI.teacherAcademyStudentDetail' 'ServerAPI.bulkManageAcademyStudents'; do
  grep -Fq "$behavior" "$teacher_students" || {
    echo "FAIL: missing native teacher student management behavior $behavior" >&2
    exit 1
  }
done
grep -Fq 'TeacherStudentManagementPanel(initialMembershipID: focusedStudentID)' "$teacher_academy"
grep -Fq 'verticalSizeClass == .compact' "$teacher_students"
grep -Fq 'selectedIDs.count < 20' "$teacher_students"
grep -Fq '학생 학습 기록을 불러오는 중입니다' "$teacher_students"
grep -Fq '학부모 공유용 요약' "$teacher_students"
grep -Fq 'DemoAccountFixtures.teacherStudentPage' "$demo_mode"
grep -Fq 'DemoAccountFixtures.teacherStudentDetail' "$demo_mode"
grep -Fq 'static let teacherStudentPage' "$demo_account_fixtures"
grep -Fq 'static let teacherStudentDetail' "$demo_account_fixtures"
grep -Fq 'static let teacherStudentEmptyPage' "$demo_account_fixtures"
grep -Fq '"-teacherStudentsFixture") == "error"' "$demo_mode"
grep -Fq '"-teacherStudentsFixture") == "empty"' "$demo_mode"
grep -Fq 'model.section == .students' "$teacher_academy"
grep -Fq 'private func shortPeriod' "$teacher_students"
grep -Fq 'case overview = "현황"' "$teacher_academy"
grep -Fq 'TeacherAnalyticsPanel(classes: dashboard.classes)' "$teacher_academy"
grep -Fq 'ServerAPI.teacherAcademyAnalytics' "$teacher_analytics"
grep -Fq 'verticalSizeClass == .compact' "$teacher_analytics"
grep -Fq '지금 확인할 학생' "$teacher_analytics"
grep -Fq '반 수학 지도' "$teacher_analytics"
grep -Fq 'DemoAccountFixtures.teacherAnalytics' "$demo_mode"
grep -Fq 'static let teacherAnalytics' "$demo_account_fixtures"
grep -Fq 'static let teacherAnalyticsEmpty' "$demo_account_fixtures"
grep -Fq '"-teacherAnalyticsFixture") == "error"' "$demo_mode"
grep -Fq '"-teacherAnalyticsFixture") == "empty"' "$demo_mode"
grep -Fq '|| model.section == .forensics' "$teacher_academy"
grep -Fq 'TeacherAcademySetupPanel(setup: setup, model: model)' "$teacher_academy"
grep -Fq 'error.code == "ACADEMY_SETUP_REQUIRED"' "$teacher_academy"
for behavior in 'ServerAPI.teacherAcademySetup' 'ServerAPI.createTeacherAcademy' 'ServerAPI.requestTeacherAcademyJoin' 'ServerAPI.cancelTeacherAcademyJoin'; do
  grep -Fq "$behavior" "$teacher_academy" "$teacher_setup" || {
    echo "FAIL: missing native teacher academy setup behavior $behavior" >&2
    exit 1
  }
done
grep -Fq '새 학원 만들기' "$teacher_setup"
grep -Fq '기존 학원 들어가기' "$teacher_setup"
grep -Fq '승인 전에는 학생 정보가 공개되지 않습니다' "$teacher_setup"
grep -Fq '"-teacherSetupFixture"' "$teacher_academy"
grep -Fq 'DemoAccountFixtures.teacherSetupChoice' "$demo_mode"
grep -Fq 'static let teacherSetupPendingAcademy' "$demo_account_fixtures"
grep -Fq 'static let teacherSetupPendingJoin' "$demo_account_fixtures"
grep -Fq 'static let teacherSetupRejected' "$demo_account_fixtures"
grep -Fq '/api/v1/academy/teacher/profile-image' "$server_api"
grep -Fq 'updateTeacherAcademyProfileImage' "$server_api"
grep -Fq 'removeTeacherAcademyProfileImage' "$server_api"
grep -Fq '사진 선택 및 자르기' "$teacher_profile"
grep -Fq '일반 선생님은 대표 사진을 변경할 수 없습니다' "$teacher_profile"
grep -Fq 'section != .settings || dashboard.isOwner' "$teacher_academy"
grep -Fq 'ProfilePhotoCropPicker' "$teacher_academy"
grep -Fq '/api/v1/academy/teacher/forensics' "$server_api"
grep -Fq 'analyzeTeacherAcademyForensicsCode' "$server_api"
grep -Fq 'analyzeTeacherAcademyForensicsFile' "$server_api"
grep -Fq 'TeacherAcademyForensicsPanel()' "$teacher_academy"
grep -Fq '전체 회원이나 다른 학원·반은 검색하지 않습니다' "$teacher_forensics"
grep -Fq '분석 직후 서버 임시 파일 삭제' "$teacher_forensics"
grep -Fq 'static let teacherForensicsResult' "$demo_account_fixtures"

# 운영자는 승인·반려뿐 아니라 전체 학원 검색과 구성원·반·초대·출결 상태도
# Bearer API와 아이폰 가로 분할 화면에서 확인한다.
for path in /api/v1/academy/admin /api/v1/academy/admin/list /api/v1/academy/admin/applications/; do
  grep -Fq "$path" "$server_api" || {
    echo "FAIL: missing native admin academy API $path" >&2
    exit 1
  }
done
for behavior in 'ServerAPI.adminAcademyDashboard()' 'ServerAPI.reviewAcademyApplication'; do
  grep -Fq "$behavior" "$admin_academy" || {
    echo "FAIL: missing native admin academy behavior $behavior" >&2
    exit 1
  }
done
grep -Fq 'AdminAcademyScreen()' "$root_view"
grep -Fq 'destination == .admin && role == "admin"' "$app"
grep -Fq 'AdminAcademyExplorer' "$admin_academy"
grep -Fq 'ServerAPI.adminAcademyList' "$admin_academy_explorer"
grep -Fq 'ServerAPI.adminAcademyDetail' "$admin_academy_explorer"
grep -Fq 'ServerAPI.updateAdminAcademyProfile' "$admin_academy_explorer"
grep -Fq 'ServerAPI.updateAdminAcademyContract' "$admin_academy_explorer"
for behavior in \
  'ServerAPI.updateAdminAcademyStaff' \
  'ServerAPI.transferAdminAcademyOwner' \
  'ServerAPI.updateAdminAcademyStudent' \
  'ServerAPI.assignAdminAcademyStudentClass' \
  'ServerAPI.updateAdminAcademyClass' \
  'ServerAPI.updateAdminAcademyClassOperations' \
  'ServerAPI.transferAdminAcademyClassHomeroom' \
  'ServerAPI.updateAdminAcademyProfileImage' \
  'ServerAPI.removeAdminAcademyProfileImage' \
  'ServerAPI.downloadAdminAcademyFile' \
  'ServerAPI.updateAdminAcademyInvite' \
  'ServerAPI.regenerateAdminAcademyAttendanceCode' \
  'ServerAPI.updateAdminAcademyAttendance'; do
  grep -Fq "$behavior" "$admin_academy_explorer" || {
    echo "FAIL: missing native admin academy mutation $behavior" >&2
    exit 1
  }
done
grep -Fq '/api/v1/academy/admin/\(academyID)/profile' "$server_api"
grep -Fq '/api/v1/academy/admin/\(academyID)/profile-image' "$server_api"
grep -Fq '/api/v1/academy/admin/\(academyID)/weeks/\(weekID)/files/\(file.id)' "$server_api"
grep -Fq '/api/v1/academy/admin/\(academyID)/contract' "$server_api"
for path in \
  '/api/v1/academy/admin/\(academyID)/staff/\(staffID)' \
  '/api/v1/academy/admin/\(academyID)/owner' \
  '/api/v1/academy/admin/\(academyID)/students/\(membershipID)' \
  '/api/v1/academy/admin/\(academyID)/students/\(membershipID)/class' \
  '/api/v1/academy/admin/\(academyID)/classes/\(classID)' \
  '/api/v1/academy/admin/\(academyID)/classes/\(classID)/operations' \
  '/api/v1/academy/admin/\(academyID)/classes/\(classID)/homeroom' \
  '/api/v1/academy/admin/\(academyID)/invites/\(inviteID)' \
  '/api/v1/academy/admin/\(academyID)/attendance/sessions/\(sessionID)/regenerate-code' \
  '/api/v1/academy/admin/\(academyID)/attendance/\(attendanceID)'; do
  grep -Fq "$path" "$server_api" || {
    echo "FAIL: missing native admin academy mutation API $path" >&2
    exit 1
  }
done
grep -Fq '운영 일시중지' "$admin_academy_explorer"
grep -Fq '계약 만료일 변경' "$admin_academy_explorer"
grep -Fq '원장 권한을 이전할까요?' "$admin_academy_explorer"
grep -Fq '학생 배정이 해제되고 예정 출결 세션과 연결된 초대가 취소됩니다.' "$admin_academy_explorer"
grep -Fq '아직 시작하지 않은 기존 회차는 취소되고 새 일정으로 다시 생성됩니다.' "$admin_academy_explorer"
grep -Fq '기존 담임을 보조 선생님으로 유지' "$admin_academy_explorer"
grep -Fq '출결 코드를 재발급할까요?' "$admin_academy_explorer"
grep -Fq '운영자 보정은 이전 상태와 함께 출결 감사 이력에 영구 기록됩니다.' "$admin_academy_explorer"
grep -Fq '최근 감사 이력' "$admin_academy_explorer"
grep -Fq 'case analytics = "통계"' "$admin_academy_explorer"
grep -Fq 'case classwork = "수업"' "$admin_academy_explorer"
grep -Fq '확인이 필요한 학생' "$admin_academy_explorer"
grep -Fq '담임 변경 이력' "$admin_academy_explorer"
grep -Fq '반 생명주기 이력' "$admin_academy_explorer"
grep -Fq 'verticalSizeClass == .compact' "$admin_academy_explorer"
grep -Fq 'case staff = "직원"' "$admin_academy_explorer"
grep -Fq 'case attendance = "출결"' "$admin_academy_explorer"
grep -Fq 'verticalSizeClass == .compact' "$admin_academy"

# 코치 의견함은 기존 Bearer API를 네이티브 UI가 직접 사용한다. 학생은 작성과 상태 확인,
# 운영자는 검수와 반려 사유 전달까지 앱을 벗어나지 않고 끝낸다.
grep -Fq '/api/v1/coach-suggestions' "$server_api"
for behavior in 'ServerAPI.coachSuggestionBoard()' 'ServerAPI.createCoachSuggestion' 'ServerAPI.moderateCoachSuggestion'; do
  grep -Fq "$behavior" "$coach_suggestions" || {
    echo "FAIL: missing native coach suggestion behavior $behavior" >&2
    exit 1
  }
done
grep -Fq 'CoachSuggestionsScreen()' "$root_view"
grep -Fq 'route = .coachSuggestions' "$app"
grep -Fq 'verticalSizeClass == .compact' "$coach_suggestions"

# 일반 지원문의는 Bearer API에서 접수·상태 확인을 끝낸다. 결제·환불은 문의 API로
# 우회하지 않고 StoreKit 결제 화면으로 분리해 App Store 정책 표면을 유지한다.
grep -Fq '/api/v1/support/inquiries' "$server_api"
for behavior in 'ServerAPI.supportDashboard()' 'ServerAPI.createSupportInquiry'; do
  grep -Fq "$behavior" "$support" || {
    echo "FAIL: missing native support behavior $behavior" >&2
    exit 1
  }
done
grep -Fq 'SupportInquiryScreen()' "$root_view"
grep -Fq 'route = .support' "$app"
grep -Fq 'verticalSizeClass == .compact' "$support"
grep -Fq 'store.route = .commerce' "$support"

# 자료실은 폴더 목록과 파일 다운로드를 Bearer API로 끝낸다. 잠긴 폴더는 서버가
# 권한을 다시 검사하며, PDF는 기존 개인 워터마크 다운로드를 그대로 쓴다.
for path in /api/v1/archive /api/v1/archive/items/; do
  grep -Fq "$path" "$server_api" || {
    echo "FAIL: missing native archive API $path" >&2
    exit 1
  }
done
for behavior in 'ServerAPI.archiveDashboard' 'ServerAPI.downloadArchiveItem'; do
  grep -Fq "$behavior" "$archive" || {
    echo "FAIL: missing native archive behavior $behavior" >&2
    exit 1
  }
done
grep -Fq 'ArchiveLibraryScreen()' "$root_view"
grep -Fq 'route = .archive' "$app"
grep -Fq 'verticalSizeClass == .compact' "$archive"
grep -Fq 'store.route = .commerce' "$archive"

# 수험관은 더 이상 세션 웹뷰가 아니라 정본 서비스를 재사용하는 Bearer 네이티브 화면이다.
for behavior in 'ServerAPI.studyHall(' 'ServerAPI.studyHallContent' 'ServerAPI.saveStudyHallAnswers' 'ServerAPI.submitStudyHallAnswers' 'ServerAPI.downloadStudyHallAsset'; do
  grep -Fq "$behavior" "$study_hall" || {
    echo "FAIL: missing native study hall behavior $behavior" >&2
    exit 1
  }
done
grep -Fq 'route = .studyHall' "$app"
grep -Fq 'StudyHallScreen()' "$root_view"
grep -Fq 'viewport.size.height < 500' "$study_hall"

# iPhone 가로 첫 화면에는 역할별 주 기능과 나머지 7개 목적지가 동시에 보여야 한다.
grep -Fq 'verticalSizeClass == .compact && !dynamicTypeSize.isAccessibilitySize' "$hub"
grep -Fq 'private var compactLandscapeLayout: some View' "$hub"
grep -Fq 'count: 3' "$hub"
grep -Fq 'minHeight: 190' "$hub"
grep -Fq 'minHeight: 58' "$hub"

# WKWebView 자체가 스크롤을 소유한다. RootView의 바깥 ScrollView에 다시 감싸면 높이가 0이 된다.
python3 - "$root_view" <<'CHECK'
import sys
source = open(sys.argv[1], encoding="utf-8").read()
special = source.index('} else if store.route == .hostedPortal {')
outer = source.index('ScrollView {', special)
portal = source.index('HostedServicePortalScreen(destination: store.hostedPortalDestination)', special)
if not special < portal < outer:
    raise SystemExit('FAIL: hosted portal must render before RootView outer ScrollView')
CHECK

python3 - "$root_view" <<'CHECK'
import sys
source = open(sys.argv[1], encoding="utf-8").read()
special = source.index('} else if store.route == .academy {')
outer = source.index('ScrollView {', special)
screen = source.index('roleAcademyScreen', special)
if not special < screen < outer:
    raise SystemExit('FAIL: native academy screen must render before RootView outer ScrollView')
CHECK

python3 - "$root_view" <<'CHECK'
import sys
source = open(sys.argv[1], encoding="utf-8").read()
special = source.index('} else if store.route == .support {')
outer = source.index('ScrollView {', special)
screen = source.index('SupportInquiryScreen()', special)
if not special < screen < outer:
    raise SystemExit('FAIL: native support screen must render before RootView outer ScrollView')
CHECK

python3 - "$root_view" <<'CHECK'
import sys
source = open(sys.argv[1], encoding="utf-8").read()
special = source.index('} else if store.route == .archive {')
outer = source.index('ScrollView {', special)
screen = source.index('ArchiveLibraryScreen()', special)
if not special < screen < outer:
    raise SystemExit('FAIL: native archive screen must render before RootView outer ScrollView')
CHECK

echo "Hosted web-service parity contract passed"
