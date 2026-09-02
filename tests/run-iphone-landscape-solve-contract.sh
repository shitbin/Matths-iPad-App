#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
solve="$root/Matths/Screens.swift"
problems="$root/Matths/ProblemGenerator.swift"
app_store="$root/Matths/MatthsApp.swift"
work=$(mktemp -d "${TMPDIR:-/tmp}/matths-phone-landscape.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

awk '/private var phoneLandscapeWorkspace:/,/private var landscapeProblemPane:/' \
  "$solve" > "$work/workspace"

# iPhone 가로만 고정 작업대를 사용한다. compact width만 보면 iPhone 세로와
# iPad Split View까지 섞이므로 기기군과 vertical compact를 함께 확인해야 한다.
grep -Fq '@Environment(\.verticalSizeClass) private var verticalSizeClass' "$solve"
grep -Fq 'UIDevice.current.userInterfaceIdiom == .phone && verticalSizeClass == .compact' "$solve"
grep -Fq 'if usesPhoneLandscapeWorkspace' "$solve"

# 이 분기 안에는 바깥 ScrollView가 없어야 문제와 노트가 한 화면에서 고정된다.
# 장문/Dynamic Type fallback은 landscapeProblemPane 안에서 문제만 독립 스크롤하고,
# 채점 바는 그 바깥에 고정되어야 한다.
if grep -Fq 'ScrollView' "$work/workspace"; then
  echo "FAIL: iPhone landscape solve workspace must not use an outer ScrollView" >&2
  exit 1
fi
grep -Fq 'HStack(spacing: gutter)' "$work/workspace"
grep -Fq 'usableWidth * 0.44' "$work/workspace"
grep -Fq 'landscapeProblemPane' "$work/workspace"
grep -Fq 'landscapeNotePane(height: paneHeight)' "$work/workspace"
grep -Fq 'if keyboardVisible {' "$work/workspace"
grep -Fq '.frame(width: usableWidth, height: paneHeight)' "$work/workspace"
grep -Fq 'landscapeKeyboardProblemPane' "$work/workspace"
grep -Fq '.dynamicTypeSize(...DynamicTypeSize.xxxLarge)' "$work/workspace"
awk '/private var landscapeProblemPane:/,/private func landscapeNotePane/' \
  "$solve" > "$work/problem-pane"
grep -Fq 'ScrollView(.vertical)' "$work/problem-pane"
grep -Fq 'landscapeGradeBar' "$work/problem-pane"
scroll_line=$(grep -n 'ScrollView(.vertical)' "$work/problem-pane" | head -1 | cut -d: -f1)
grade_line=$(grep -n 'landscapeGradeBar' "$work/problem-pane" | head -1 | cut -d: -f1)
if [ "$grade_line" -le "$scroll_line" ]; then
  echo "FAIL: landscape grade bar must remain below and outside the problem scroller" >&2
  exit 1
fi

# 왼손잡이는 노트/문제 순서만 바꾸고 같은 고정 높이·도구 계약을 쓴다.
grep -Fq 'if store.leftHandedOn' "$work/workspace"
grep -Fq 'constrainedHeight: height' "$solve"
grep -Fq 'usesCompactToolbar: true' "$solve"
grep -Fq '.frame(maxWidth: .infinity, maxHeight: height, alignment: .top)' "$solve"
grep -Fq 'usesCompactLandscapeLayout: usesPhoneLandscapeWorkspace' "$solve"
grep -Fq 'private var landscapeGradeBar:' "$solve"
grep -Fq 'private var landscapeKeyboardProblemPane:' "$solve"
grep -Fq 'Text(problem.statement)' "$solve"
grep -Fq 'var needsMathTypesetting: Bool' "$problems"
grep -Fq 'text.contains("\\(")' "$problems"
grep -Fq 'text.contains("\\[")' "$problems"
grep -Fq 'problem.needsMathTypesetting' "$solve"
grep -Fq 'p.needsMathTypesetting' "$solve"
grep -Fq 'isTex: p.needsMathTypesetting' "$app_store"
grep -Fq 'UIResponder.keyboardWillShowNotification' "$solve"
grep -Fq 'UIResponder.keyboardWillHideNotification' "$solve"
grep -Fq '"-solveKeyboardFixture"' "$solve"

# Session routes remove the app shell, so their shared close/progress bar must
# own the iPhone landscape left/right safe areas itself.
grep -Fq '.safeAreaPadding(.horizontal, Tokens.Space.s4)' "$solve"
grep -Fq 'viewport.size.height < 500' "$solve"
grep -Fq 'if isCompactLandscape {' "$solve"
grep -Fq 'dynamicTypeSize.isAccessibilitySize ? 232 : 184' "$solve"
grep -Fq '.minimumScaleFactor(0.72)' "$solve"
grep -Fq 'height: viewport.size.height' "$solve"
grep -Fq 'recoveryActions' "$solve"

# 결과 설명이 길어도 iPhone 가로에서는 다음 문항/다시 풀기가 하단에 고정된다.
grep -Fq 'usesPhoneLandscapeStickyActions' "$solve"
grep -Fq 'if !usesPhoneLandscapeStickyActions' "$solve"
grep -Fq 'private func resultActionRow(grading: GradingResult)' "$solve"
grep -Fq '.safeAreaInset(edge: .bottom, spacing: 0)' "$solve"
grep -Fq '.dynamicTypeSize(...DynamicTypeSize.xxxLarge)' "$solve"
grep -Fq 'if !usesPhoneLandscapeStickyActions {' "$solve"

web="$root/Matths/LessonWeb/problem.html"
grep -Fq '.compact-landscape #choices' "$web"
grep -Fq 'grid-template-columns: repeat(2, minmax(0, 1fr))' "$web"
grep -Fq 'min-height: 44px' "$web"
grep -Fq 'data.compactLandscape' "$web"

echo "iPhone landscape fixed problem/note workspace contract passed"
