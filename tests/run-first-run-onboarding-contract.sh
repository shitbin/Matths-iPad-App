#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
onboarding="$root/Matths/FirstRunOnboarding.swift"
root_view="$root/Matths/RootView.swift"
app="$root/Matths/MatthsApp.swift"
profile="$root/Matths/ProfileScreen.swift"
coach="$root/Matths/CoachEngine.swift"

for file in "$onboarding" "$root_view" "$app" "$profile" "$coach"; do
  test -f "$file" || { echo "FAIL: missing onboarding source: $file" >&2; exit 1; }
done

# 첫 실행에는 장문의 기능 투어가 아니라 한 가지 공부 목적을 고르는 짧은 흐름만 뜬다.
grep -Fq 'struct FirstRunOnboardingOverlay: View' "$onboarding"
grep -Fq 'case newConcept' "$onboarding"
grep -Fq 'case weakness' "$onboarding"
grep -Fq 'case exam' "$onboarding"
grep -Fq 'case .newConcept: .curriculum' "$onboarding"
grep -Fq 'case .weakness: .wrongNotes' "$onboarding"
grep -Fq 'case .exam: .assess' "$onboarding"
grep -Fq '"첫 공부를 정해볼까요?"' "$onboarding"
grep -Fq '"홈부터 둘러보기"' "$onboarding"

# 교사·운영자는 학생의 공부 목적을 고르게 하지 않고 역할별 작업대로 바로 보낸다.
grep -Fq 'private var isStaffAccount: Bool' "$onboarding"
grep -Fq 'accountRole == "teacher" || accountRole == "admin"' "$onboarding"
grep -Fq 'if isStaffAccount && !dynamicTypeSize.isAccessibilitySize {' "$onboarding"
grep -Fq 'isStaffAccount ? .academy : selectedIntent.destination' "$onboarding"
grep -Fq 'case academy(role: String)' "$root_view"
grep -Fq 'guard !isStaffHome else { return }' "$root_view"
grep -Fq 'Button(admin ? "운영 작업대 열기" : "수업 작업대 열기")' "$root_view"

# 코치 기본값은 최신 웹과 같은 mild이며, 선택값과 튜토리얼 완료를 서버에 저장한 뒤 이동한다.
grep -Fq '@State private var selectedCoach: SpiceLevel = .mild' "$onboarding"
grep -Fq 'try await ServerAPI.updateCoachMode(selectedCoach.serverValue)' "$onboarding"
grep -Fq 'ServerAPI.updateDashboardTutorial(skipped ? "SKIP" : "COMPLETE")' "$onboarding"
grep -Fq 'store.route = skipped ? .home : (isStaffAccount ? .academy : selectedIntent.destination)' "$onboarding"
grep -Fq 'SpiceLevel(rawValue: raw ?? "") ?? .mild' "$coach"
grep -Fq 'var level: SpiceLevel = .mild' "$coach"

# 서버의 첫 실행 PENDING은 상세 31단계 투어를 자동으로 겹쳐 띄우지 않는다.
grep -Fq '@Published var requestedDashboardTutorial = false' "$app"
grep -Fq 'profile.dashboardTutorial?.shouldAutoStart == true' "$root_view"
grep -Fq '!store.requestedDashboardTutorial' "$root_view"
grep -Fq 'if store.requestedDashboardTutorial,' "$root_view"
grep -Fq 'store.requestedDashboardTutorial = true' "$profile"

# 작은 iPhone 가로모드와 큰 글씨에서는 설명부만 스크롤되고 행동 버튼은 고정된다.
grep -Fq 'proxy.size.height < 500' "$onboarding"
grep -Fq 'if compactHeight && !dynamicTypeSize.isAccessibilitySize' "$onboarding"
grep -Fq 'dynamicTypeSize.isAccessibilitySize ? .visible : .hidden' "$onboarding"
grep -Fq '.accessibilityAddTraits(.isModal)' "$onboarding"
grep -Fq 'store.isTutorialPresentationActive = true' "$onboarding"
grep -Fq 'store.isTutorialPresentationActive = false' "$onboarding"
grep -Fq 'arguments.contains("-firstRunFixture")' "$onboarding"
grep -Fq 'args.contains("-firstRunFixture")' "$app"

echo "First-run intent onboarding contract passed"
