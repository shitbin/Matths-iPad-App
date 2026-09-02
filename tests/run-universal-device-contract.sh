#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d "${TMPDIR:-/tmp}/matths-universal-contract.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

project="$root/Matths.xcodeproj/project.pbxproj"
info_plist="$root/Info.plist"
root_view="$root/Matths/RootView.swift"
canvas="$root/Matths/SolutionCanvas.swift"
quick_practice="$root/Matths/QuickPracticeScreen.swift"
placement_exam="$root/Matths/PlacementExamScreen.swift"
goat_arena="$root/Matths/GoatArenaScreen.swift"

# WHY: 예전에는 프로젝트 전체의 'TARGETED_DEVICE_FAMILY = "1,2";' 개수를 2로 셌다.
# 위젯 확장(kr.matths.app.widget)이 생기면서 같은 줄이 4개가 되어 앱 타깃은 멀쩡한데
# 검사만 실패했다. 개수 대신 **앱 타깃(kr.matths.app)의 빌드 설정 블록** 안에서만
# 값을 확인한다 — 위젯이 몇 개 더 붙어도 계약의 뜻(앱이 Debug·Release 모두 유니버설)은
# 그대로고, 앱 타깃이 iPad 를 잃으면 여전히 잡힌다.
app_family=$(awk '
  /^\t\t[0-9A-F]+ \/\* .* \*\/ = \{$/ { block = ""; inblock = 1 }
  inblock { block = block $0 "\n" }
  /^\t\t\};$/ {
    if (inblock && block ~ /isa = XCBuildConfiguration;/ \
        && block ~ /PRODUCT_BUNDLE_IDENTIFIER = kr\.matths\.app;/) {
      if (block ~ /TARGETED_DEVICE_FAMILY = "1,2";/) universal++
      else other++
    }
    inblock = 0
  }
  END { print universal + 0 "/" other + 0 }
' "$project")
if [ "$app_family" != "2/0" ]; then
  echo "FAIL: 앱 타깃(kr.matths.app)은 Debug와 Release 모두 iPhone·iPad 유니버설이어야 합니다." >&2
  echo "      (유니버설/그외 빌드설정 블록 = $app_family)" >&2
  exit 1
fi

grep -Fq 'INFOPLIST_KEY_UIRequiresFullScreen = NO;' "$project"
[[ "$(grep -Fc 'INFOPLIST_KEY_UIApplicationSceneManifest_Generation = NO;' "$project")" -eq 2 ]]
/usr/libexec/PlistBuddy -c 'Print :UIApplicationSceneManifest:UIApplicationSupportsMultipleScenes' \
  "$info_plist" | grep -Fxq false
grep -Fq 'INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";' "$project"
grep -Fq 'INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";' "$project"

grep -Fq '@Environment(\.verticalSizeClass)' "$root_view"
grep -Fq 'safeAreaInset(edge: .top' "$root_view"
grep -Fq 'safeAreaInset(edge: .bottom' "$root_view"
grep -Fq 'ViewThatFits(in: .horizontal)' "$root_view"
grep -Fq 'tabRow(showTitles: true)' "$root_view"
grep -Fq 'tabRow(showTitles: false)' "$root_view"
grep -Fq 'accessibilityLabel(accessibilityLabel(for: item))' "$root_view"
grep -Fq 'if !keyboardVisible { bottomChrome }' "$root_view"
grep -Fq 'keyboardVisible && verticalSizeClass == .compact' "$root_view"

# 퀵 연습 가로 화면은 문제/메모/답/제출을 한 화면에 두되, 메모판을 단순 장식처럼
# 얕게 만들지 않는다. 제목은 도구막대에 합쳐 76pt 필기 면을 확보한다.
grep -Fq 'toolbarTitle: "풀이 메모"' "$root/Matths/QuickPracticeScreen.swift"
grep -Fq 'private var landscapeNoteCanvasHeight: CGFloat {' "$root/Matths/QuickPracticeScreen.swift"
grep -A2 -F 'private var landscapeNoteCanvasHeight: CGFloat {' "$root/Matths/QuickPracticeScreen.swift" \
    | grep -Fq '76'

# iPhone 가로는 horizontalSizeClass가 compact여도 본문 폭이 700pt를 넘는다.
# 홈 두 칸 후보를 size class로 미리 탈락시키면 미션 카드 오른쪽이 비고 주간 기록이
# 아래 스크롤로 밀린다. 실제 폭 판정은 ViewThatFits만 맡긴다.
grep -Fq '.frame(minWidth: Self.twoColumnMinWidth' "$root_view"
if grep -A3 -F 'private var usesTwoColumnBody: Bool {' "$root_view" \
    | grep -Fq 'hSize == .regular'; then
  echo 'FAIL: iPhone landscape home must use actual width for two columns' >&2
  exit 1
fi

grep -Fq 'deviceClass == .phone || allowsFinger' "$canvas"
grep -Fq 'drawingPolicy = allowsFingerDrawing ? .anyInput : .pencilOnly' "$canvas"
grep -Fq 'accessibilityTraits.insert(.allowsDirectInteraction)' "$canvas"
grep -Fq 'accessibilityIdentifier = "solutionCanvas"' "$canvas"
# Split-workspace layout supplies an exact constrained height when available and
# falls back to the device-class minimum otherwise. Keep the contract aligned
# with that responsive implementation instead of the retired one-argument frame.
grep -Fq 'minHeight: constrainedCanvasHeight == nil ? canvasMinimumHeight : nil' "$canvas"

# iPhone 가로의 퀵 연습도 일반 풀이 화면과 같은 정보 배치를 지킨다. 발제문 아래로
# 메모·답·제출을 세로로 밀어 다시 스크롤을 요구하는 회귀를 막는다.
grep -Fq 'isShort && phase == .solving && !dynamicTypeSize.isAccessibilitySize' "$quick_practice"
grep -Fq 'HStack(alignment: .top, spacing: Tokens.Space.s4)' "$quick_practice"
grep -Fq 'toolbarTitle: "풀이 메모"' "$quick_practice"
grep -A2 -F 'private var landscapeNoteCanvasHeight: CGFloat {' "$quick_practice" \
    | grep -Fq '76'
grep -Fq 'Self.deviceClass == .phone ? Tokens.Space.s2 : Tokens.Space.s3' "$quick_practice"
grep -Fq 'height: landscapeNoteCanvasHeight' "$quick_practice"
grep -Fq '.card(padding: landscapeSolvingCardPadding)' "$quick_practice"
grep -Fq 'if showsStatsBelowPrimary { statsCard }' "$quick_practice"
grep -Fq '.keyboardType(.numbersAndPunctuation)' "$quick_practice"
grep -Fq 'if !answerFocused' "$quick_practice"

# 배치고사 가로 화면은 30문항 탐색 줄 아래에서도 5개 선택지와 이동 버튼을 한 화면에
# 유지한다. 짧은 높이에 일반 카드의 20~24pt 세로 여백을 되살리지 못하게 한다.
grep -Fq 'spacing: shortHeight ? Tokens.Space.s3 : Tokens.Space.s6' "$placement_exam"
grep -Fq '.padding(shortHeight ? Tokens.Space.s3' "$placement_exam"

# Arena 가로 첫 화면의 상태 카드에서 이름/티어만 보이고 핵심 수치가 아래로 밀리는
# 회귀를 막는다. 짧은 높이는 학생/티어와 MMR/자리/사이클을 좌우로 나눈다.
# Pro Max 가로는 horizontal regular이므로 vertical compact도 압축 정보구조로
# 들어가야 한다. 이 분기가 사라지면 CTA가 다시 첫 화면 아래로 밀린다.
grep -Fq 'horizontalSizeClass == .compact || verticalSizeClass == .compact' "$goat_arena"
grep -Fq 'if isShortViewport && !dynamicTypeSize.isAccessibilitySize {' "$goat_arena"
grep -Fq 'compactCycleOrEmpty(snapshot)' "$goat_arena"
grep -Fq 'spacing: isShortViewport ? Tokens.Space.s3 : Tokens.Space.s6' "$goat_arena"
grep -Fq 'if !isShortViewport {' "$goat_arena"
grep -Fq 'AnyView(compactArenaBody)' "$goat_arena"
grep -Fq 'AnyView(regularArenaBody)' "$goat_arena"
grep -Fq 'private func shortCompactStatusContent(_ snapshot: Snapshot) -> AnyView' "$goat_arena"
grep -Fq 'private var shortCompactHeader: some View' "$goat_arena"
grep -Fq 'shortIdentityTier(snapshot)' "$goat_arena"
grep -Fq 'shortCycleSummary(snapshot)' "$goat_arena"

# 유니버설 앱의 사용자 문구가 iPhone에서도 현재 기기를 iPad라고 부르면 안 된다.
# 주석과 개발 문서는 허용하고, 실제 문자열 리터럴만 검사한다.
if rg -n '"[^"\n]*(이 iPad|iPad가 필요|iPad에서는|iPadOS가)[^"\n]*"' \
    "$root/Matths" --glob '*.swift'; then
  echo "FAIL: iPhone에 노출될 수 있는 iPad 전용 사용자 문구가 남아 있습니다." >&2
  exit 1
fi

xcrun swiftc \
  "$root/Matths/UniversalLayoutPolicy.swift" \
  "$root/tests/UniversalLayoutPolicyCases.swift" \
  -o "$work/universal-layout-policy"
"$work/universal-layout-policy"

echo "Universal target, orientation, safe-area, input, and accessibility contracts passed"
