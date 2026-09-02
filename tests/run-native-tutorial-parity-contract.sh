#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
root_view="$root/Matths/RootView.swift"
profile="$root/Matths/ProfileScreen.swift"
app_store="$root/Matths/MatthsApp.swift"
local_notifications="$root/Matths/LocalNotifications.swift"
arena_screen="$root/Matths/GoatArenaScreen.swift"
weekly_mock="$root/Matths/WeeklyMockScreen.swift"
work=$(mktemp -d "${TMPDIR:-/tmp}/matths-tutorial-contract.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

awk '/private static let dashboardSteps:/,/private static let arenaSteps:/' \
  "$root_view" > "$work/dashboard"
awk '/private static let arenaSteps:/,/^    var body: some View/' \
  "$root_view" > "$work/arena"
awk '/private func startIfNeeded\(\) async/,/private static func argumentValue/' \
  "$root_view" > "$work/start"

dashboard_count=$(grep -c '\.init(id:' "$work/dashboard")
arena_count=$(grep -c '\.init(id:' "$work/arena")
[ "$dashboard_count" -eq 31 ] || {
  echo "FAIL: native dashboard tutorial must contain 31 mapped steps, found $dashboard_count" >&2
  exit 1
}
[ "$arena_count" -eq 23 ] || {
  echo "FAIL: native Arena tutorial must contain all 23 server steps, found $arena_count" >&2
  exit 1
}

for chapter in common unranked unranked_match ranked ranked_battle ranked_shop; do
  grep -Fq "\"$chapter\": [" "$work/arena" || {
    echo "FAIL: missing Arena tutorial chapter $chapter" >&2
    exit 1
  }
done

# Latest server contract deliberately returns autoChapter=null and
# shouldAutoStart=false. Native launch must mirror the web page/division lookup.
if grep -Fq 'arena.shouldAutoStart' "$work/start" \
    || grep -Fq 'arena.autoChapter' "$work/start"; then
  echo "FAIL: Arena start still depends on disabled server auto-start fields" >&2
  exit 1
fi
grep -Fq 'arena.activeDivision?.uppercased()' "$work/start"
grep -Fq 'case "SUB": pageChapter = "unranked"' "$work/start"
grep -Fq 'case "MAIN": pageChapter = "ranked"' "$work/start"
grep -Fq 'arena.chapters[chapter]?.status == "PENDING"' "$work/start"

# A profile restart is explicit intent: preserve its chapter and navigate to the
# screen where that chapter can actually be displayed.
grep -Fq '@Published var requestedArenaTutorialChapter: String? = nil' "$app_store"
grep -Fq 'store.requestedArenaTutorialChapter = chapter' "$profile"
grep -Fq 'store.route = chapter == "ranked_shop" ? .arenaShop : .rank' "$profile"
grep -Fq 'store.route = .home' "$profile"

# MainTabBar has six destinations. Spotlight geometry must share that route order
# instead of the old hard-coded five-column arithmetic.
grep -Fq '.home, .curriculum, .assess, .wrongNotes, .community, .rank' "$root_view"
grep -Fq 'Self.tutorialTabRoutes.firstIndex(of: route)' "$root_view"
grep -Fq 'Self.tutorialTabRoutes.count' "$root_view"
grep -Fq 'size.width - proxy.safeAreaInsets.trailing - 24' "$root_view"

# The web tutorial covers all major destinations. Native mapping may merge web-only
# pages, but it must not omit a real app tab or its top-level tools.
grep -Fq 'route: .community' "$work/dashboard"
grep -Fq 'spotlight: .tab(.community)' "$work/dashboard"
grep -Fq 'spotlight: .topAction(.chat)' "$work/dashboard"
grep -Fq 'route: .pro' "$work/dashboard"

# Keep an authenticated-state-independent visual fixture so phone and iPad
# layouts can be rendered in CI without mutating a real tutorial account.
grep -Fq 'argumentValue(after: "-tutorialFixture")' "$root_view"
grep -Fq 'argumentValue(after: "-tutorialStep")' "$root_view"
grep -Fq 'fixtureStepIndex(count:' "$root_view"
grep -Fq 'if consumedDebugFixture' "$root_view"
grep -Fq 'args.contains("-tutorialFixture")' "$app_store"

# Route changes are part of the tutorial itself. A live Arena defense or weekly
# mock deadline must not throw an iOS notification permission sheet over the
# coach card. Already-authorized scheduling remains allowed; only a new prompt
# is deferred until the tutorial has closed.
grep -Fq '@Published var isTutorialPresentationActive = false' "$app_store"
grep -Fq 'guard allowPermissionPrompt else { return }' "$local_notifications"
grep -Fq 'allowPermissionPrompt: !store.isTutorialPresentationActive' "$arena_screen"
grep -Fq 'allowPermissionPrompt: !store.isTutorialPresentationActive' "$weekly_mock"
grep -Fq 'store.isTutorialPresentationActive = true' "$root_view"
grep -Fq 'store.isTutorialPresentationActive = false' "$root_view"

# 튜토리얼은 눈으로만 모달이면 안 된다. VoiceOver가 dimmed 본문의 탭과 버튼으로
# 빠져나가지 못하도록 앱 본문을 숨기고 오버레이를 접근성 모달로 선언한다.
grep -Fq 'store.isTutorialPresentationActive' "$app_store"
grep -Fq 'private var presentationIsolatedRootContent: some View' "$app_store"
grep -Fq 'rootContent.accessibilityHidden(true)' "$app_store"
# 루트에는 active=true 분기만 허용한다. false 값을 포함한 상시 modifier는
# 일반 화면의 접근성 트리를 iOS 26에서 지우는 회귀를 만들었다.
[[ "$(grep -Fc '.accessibilityHidden(' "$app_store")" -eq 1 ]]
grep -Fq '.accessibilityAddTraits(.isModal)' "$root_view"

# The smallest supported iPhone has very little vertical room in landscape.
# Accessibility text must keep close/progress/next pinned on screen while only
# the explanatory copy scrolls; capping the user's font size is not acceptable.
grep -Fq '@Environment(\.dynamicTypeSize) private var dynamicTypeSize' "$root_view"
grep -Fq 'proxy.size.height < 500' "$root_view"
grep -Fq 'dynamicTypeSize.isAccessibilitySize' "$root_view"
grep -Fq '.scrollIndicators(.visible)' "$root_view"
grep -Fq '.fixedSize(horizontal: false,' "$root_view"
grep -Fq 'vertical: !dynamicTypeSize.isAccessibilitySize)' "$root_view"
grep -Fq '.frame(maxHeight: dynamicTypeSize.isAccessibilitySize ? maximumHeight : nil)' "$root_view"

echo "Native tutorial parity contract passed (dashboard=31, arena=23, chapters=6)"
