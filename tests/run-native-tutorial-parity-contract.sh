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
[ "$dashboard_count" -ge 5 ] || {
  echo "FAIL: native dashboard tutorial must cover the current navigation, found $dashboard_count" >&2
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

# Real views, not a guessed six-column bar or screen fractions, own spotlight geometry.
node - "$root" "$work/dashboard" "$work/arena" <<'JS'
const fs=require('node:fs'); const [root,dashboardPath,arenaPath]=process.argv.slice(2);
const source=fs.readFileSync(root+'/Matths/RootView.swift','utf8');
const dashboard=fs.readFileSync(dashboardPath,'utf8'), arena=fs.readFileSync(arenaPath,'utf8');
for(const forbidden of ['spotlightRect(', 'tutorialTabRoutes', 'case contentTop', 'case contentMiddle', 'case contentBottom', 'home-coach'])
  if(source.includes(forbidden))throw Error('Guessed or nonexistent tutorial target remains: '+forbidden);
for(const id of ['todayPrimaryAction','learningCourses','weeklyMockEntry','quickPracticeStart','proEntry','tabLearning','tabRecords','tabMe','wrongNotes','topChat','communityBrowse','profileSettings'])
  if(!dashboard.includes('target: .'+id))throw Error('Missing actual native entry '+id);
for(const route of ['.home','.learn','.rank','.records','.me'])
  if(!dashboard.includes('route: '+route))throw Error('Missing current navigation '+route);
if(!source.includes('proxy[$0.bounds]')||!source.includes('clippingRects:')||!source.includes('resolution.frame'))
  throw Error('Spotlight is not resolved from actual/clipped bounds');
if(!source.includes('TutorialFocusRequestCenter.cancel(ownerID: previous.id)')||!source.includes('.onChange(of: proxy.size)'))
  throw Error('Scroll focus lacks owner cleanup or rotation refresh');
const anchors=fs.readdirSync(root+'/Matths').filter(x=>x.endsWith('.swift'))
  .map(x=>fs.readFileSync(root+'/Matths/'+x,'utf8')).join('\n');
for(const target of [...dashboard.matchAll(/target: \.(\w+)/g),...arena.matchAll(/target: \.(\w+)/g)].map(x=>x[1])){
  const navigation=fs.readFileSync(root+'/Matths/TutorialNavigationAnchor.swift','utf8');
  const viaNavigation=target.startsWith('tab')&&navigation.includes(': .'+target)&&navigation.includes('content.tutorialTarget(target)');
  if(!anchors.includes('.tutorialTarget(.'+target)&&!viaNavigation)throw Error('Unimplemented tutorial anchor '+target);
}
const arenaSource=fs.readFileSync(root+'/Matths/GoatArenaScreen.swift','utf8');
const compact=arenaSource.slice(arenaSource.indexOf('private func compactPrimaryAction('),arenaSource.indexOf('private func canInspectMatchedGame('));
const noCycle=compact.slice(compact.indexOf('} else if snapshot.cycle == nil {'),compact.indexOf('} else if let match = snapshot.activeMatch {'));
const placement=compact.slice(compact.indexOf('} else if snapshot.ranking.skill.status == "PLACEMENT_PENDING"'),compact.indexOf('} else if let cycle = snapshot.cycle,'));
if(noCycle.includes('.arenaMatchmaking')||placement.includes('.arenaMatchmaking'))throw Error('Non-match CTA mislabeled as matchmaking');
if(!noCycle.includes('.arenaEligibility')||!placement.includes('.placementEntry'))throw Error('Conditional CTA semantics lost');
if(!/id: "unranked-battle"[\s\S]*?target: \.arenaMatchmaking/.test(arena))throw Error('Reported Unranked step is not on actual match CTA');
console.log('Actual native target mapping and conditional Arena CTA checks passed');
JS

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
grep -Fq 'store.claimNativeTutorialPresentation(owner.id)' "$root_view"
grep -Fq 'store.releaseNativeTutorialPresentation(previous.id)' "$root_view"
grep -Fq 'guard nativeTutorialPresentationOwner == id else { return }' "$app_store"

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
grep -Fq '.fixedSize(horizontal: false, vertical: true)' "$root_view"
grep -Fq 'let panelWidth = shortHeight || sideBySide ? 320.0 : 620.0' "$root_view"
grep -Fq 'TutorialFocusGeometry.coachPlacement(' "$root_view"

echo "Native tutorial parity contract passed (dashboard=$dashboard_count, arena=$arena_count, chapters=6; actual anchors)"
