#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

# 이 목록은 고정 allowlist 다 — 새 교육 WebView 를 여기 추가하지 않으면
# 접근성 주입을 통째로 빠뜨려도 어떤 테스트도 잡지 못한다.
# CurriculumScenarioLessonView 는 설명 단계 시각 영역(시나리오 플레이어)이라 추가한다.
for file in \
  AssessmentPaperScreen.swift \
  HintWebView.swift \
  SheetExplainView.swift \
  SolutionPlayerView.swift \
  SolutionScenePlayerView.swift \
  LottieWebView.swift \
  LessonWebView.swift \
  CurriculumScenarioLessonView.swift \
  ProblemWebView.swift \
  MathLabel.swift
do
  count=$(grep -c 'WebContentAccessibility' "$root/Matths/$file")
  if [ "$count" -lt 2 ]; then
    echo "FAIL: $file에 초기 주입과 환경 변경 갱신이 모두 필요합니다." >&2
    exit 1
  fi
done

if grep -n 'scrollView.isScrollEnabled = false' \
  "$root/Matths/AssessmentPaperScreen.swift" \
  "$root/Matths/HintWebView.swift" \
  "$root/Matths/SheetExplainView.swift" \
  "$root/Matths/SolutionPlayerView.swift" \
  "$root/Matths/SolutionScenePlayerView.swift" \
  "$root/Matths/LottieWebView.swift" \
  "$root/Matths/LessonWebView.swift" \
  "$root/Matths/CurriculumScenarioLessonView.swift" \
  "$root/Matths/ProblemWebView.swift" \
  "$root/Matths/MathLabel.swift"
then
  echo "FAIL: 교육 WebView의 확대·확대 후 이동을 함께 막으면 안 됩니다." >&2
  exit 1
fi

for file in \
  AssessmentPaperScreen.swift \
  HintWebView.swift \
  SheetExplainView.swift \
  SolutionPlayerView.swift \
  SolutionScenePlayerView.swift \
  LottieWebView.swift \
  LessonWebView.swift \
  CurriculumScenarioLessonView.swift \
  ProblemWebView.swift \
  MathLabel.swift
do
  grep -q 'WebContentAccessibility.configure(web)' "$root/Matths/$file"
  grep -q '@AppStorage(WebMotion.preferenceKey)' "$root/Matths/$file"
  grep -q 'userMotionEnabled: userMotionEnabled' "$root/Matths/$file"
done

grep -q 'maximumZoomScale = 4' "$root/Matths/WebContentAccessibility.swift"
grep -q 'pinchGestureRecognizer?.isEnabled = true' "$root/Matths/WebContentAccessibility.swift"
grep -q 'window.MATTHS_ACCESSIBILITY.userMotionEnabled !== false' "$root/Matths/WebContentAccessibility.swift"
grep -q '!window.MATTHS_ACCESSIBILITY.reduceMotion' "$root/Matths/WebContentAccessibility.swift"
grep -q 'window.MATTHS_MOTION === false' "$root/Matths/WebContentAccessibility.swift"
if grep -q 'window.MATTHS_MOTION = !window.MATTHS_ACCESSIBILITY.reduceMotion' \
  "$root/Matths/WebContentAccessibility.swift"
then
  echo "FAIL: 앱 화면 모션 설정을 시스템 값으로 덮어쓰면 안 됩니다." >&2
  exit 1
fi
grep -q 'static let preferenceKey = "matths.motion"' "$root/Matths/WebMotion.swift"
grep -q 'userEnabled && !reduceMotion' "$root/Matths/WebMotion.swift"
grep -q 'window.dispatchEvent(new Event('\''resize'\''))' "$root/Matths/WebContentAccessibility.swift"

if grep -R -n -E 'maximum-scale=1|user-scalable=no' "$root/Matths/LessonWeb"; then
  echo "FAIL: 교육 WebView에서 사용자 확대를 막으면 안 됩니다." >&2
  exit 1
fi

for file in \
  paper.html hint.html explain.html solution-player.html solution-scene.html \
  lesson.html problem.html mathline.html
do
  grep -q -- '--content-scale' "$root/Matths/LessonWeb/$file"
done

grep -q 'matthsAccessibilityChanged' "$root/Matths/LessonWeb/lottie.html"
grep -q 'matthsAccessibilityChanged' "$root/Matths/LessonWeb/hint.html"
grep -q 'matthsAccessibilityChanged' "$root/Matths/LessonWeb/solution-player.html"
grep -q 'matthsAccessibilityChanged' "$root/Matths/LessonWeb/scenario-player.js"
grep -q 'window.MATTHS_MOTION === false' "$root/Matths/LessonWeb/lottie.html"
grep -q 'window.MATTHS_MOTION === false' "$root/Matths/LessonWeb/hint.html"
grep -q 'window.MATTHS_MOTION === false' "$root/Matths/LessonWeb/scenario-player.js"
grep -q 'window.MATTHS_MOTION !== false' "$root/Matths/LessonWeb/solution-player.html"
grep -q 'reduce-motion' "$root/Matths/LessonWeb/solution-player.html"
grep -q 'reduce-motion' "$root/Matths/LessonWeb/solution-scene.html"

# 홈은 ViewThatFits가 압축 가능한 HStack을 "맞는다"고 오판할 수 있다.
# 접근성 글자 크기에서는 날짜·통계·상태를 명시적으로 세로 배치해야 한다.
native_ax_branches=$(grep -c 'dynamicTypeSize.isAccessibilitySize' "$root/Matths/RootView.swift")
if [ "$native_ax_branches" -lt 4 ]; then
  echo "FAIL: 홈의 AX5 세로 배치 계약이 빠졌습니다." >&2
  exit 1
fi

echo "all 10 educational WebView, motion preference, and native AX layout contracts passed"
