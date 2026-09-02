#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

verify() {
  file="$root/$1"
  shift
  grep -Fq 'static func dismantleUIView(_ web: WKWebView, coordinator: Coordinator)' "$file"
  grep -Fq 'web.stopLoading()' "$file"
  for handler in "$@"; do
    grep -Fq "userContentController.add(context.coordinator, name: \"$handler\")" "$file"
    grep -Fq "removeScriptMessageHandler(forName: \"$handler\")" "$file"
  done
}

verify Matths/CurriculumScenarioLessonView.swift lessonHeight
verify Matths/MathLabel.swift mathHeight
verify Matths/SolutionScenePlayerView.swift sceneHeight
verify Matths/HintWebView.swift hintHeight
verify Matths/ConceptScreenV2.swift lessonHeight
verify Matths/ProblemWebView.swift problemHeight choicePick
verify Matths/SheetExplainView.swift explainHeight
verify Matths/SolutionPlayerView.swift playerHeight
verify Matths/LessonWebView.swift lessonHeight lessonDebug quizResult
verify Matths/AssessmentPaperScreen.swift paperAnswer paperHeight

# UIKit dismiss는 MainActor API다. 중간 참조 객체가 actor 격리를 잃으면 Release
# whole-module 빌드에서 경고가 나고 다음 Swift 모드에서는 오류로 승격될 수 있다.
perl -0ne 'exit 0 if /@MainActor\s+private final class Dismisser/; exit 1' \
  "$root/Matths/ArenaWeb/ArenaWebPresenter.swift"

echo "Educational WKWebView message-handler lifecycle contracts passed"
