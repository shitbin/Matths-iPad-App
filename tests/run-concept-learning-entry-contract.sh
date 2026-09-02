#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONCEPT="$ROOT/Matths/ConceptScreenV2.swift"
TIMELINE="$ROOT/Matths/CurriculumStoryTimeline.swift"

python3 - "$CONCEPT" "$TIMELINE" <<'PY'
from pathlib import Path
import re
import sys

concept = Path(sys.argv[1]).read_text()
timeline = Path(sys.argv[2]).read_text()

def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)

# iPad의 1280pt 작업대 안에서 900pt 헤더/탭 블록 자체를 가운데 둔다.
content = concept[
    concept.index("private func content(course:"):
    concept.index("private func conceptHeader(course:")
]
require(content.count(".frame(maxWidth: .infinity, alignment: .center)") == 2,
        "concept header and stage navigation must each center their 900pt block")

# 좌표 없이 개념 탭에 들어온 시작 화면은 activeStage 초기값(.explain) 때문에
# 가로 2열을 잃지 않는다. 첫 화면에서 개념 카드와 이어서 학습 CTA가 함께 보여야 한다.
require("private var startDashboardLayout: Bool" in concept,
        "concept start needs an independent compact-height layout decision")
start = concept[concept.index("private var conceptStart:"):concept.index("private func startIntro(")]
require("if startDashboardLayout" in start and "if dashboardLayout" not in start,
        "concept start must not reuse the lesson-stage dashboard gate")
require(start.index("startCard(course:") < start.index("startActions(concept:"),
        "concept start must keep the selected concept before its primary action")
require(start.count(".accessibilityElement(children: .contain)") == 2,
        "concept start columns must preserve column reading order for VoiceOver")
require(re.search(
    r"conceptHeader\([^\n]+\).*?"
    r"\.frame\(maxWidth: Tokens\.readableWidth, alignment: \.leading\).*?"
    r"\.frame\(maxWidth: \.infinity, alignment: \.center\)",
    content, re.S), "concept header lost its readable-width centered wrapper")
require(re.search(
    r"learningStageNavigation\(concept: concept\).*?"
    r"\.frame\(maxWidth: Tokens\.readableWidth, alignment: \.leading\).*?"
    r"\.frame\(maxWidth: \.infinity, alignment: \.center\)",
    content, re.S), "stage navigation lost its readable-width centered wrapper")

# 탐색은 학습 목표 다음에 바로 조작하고, 긴 핵심 정리는 그 뒤에 읽는다.
explore = concept[
    concept.index("private func explorationStage(concept:"):
    concept.index("private func explorationInteractiveCard(concept:")
]
goal = explore.index('SectionRule(title: "학습 목표")')
interactive = explore.index("explorationInteractiveCard(concept: concept)")
summary = explore.index('SectionRule(title: "핵심 정리, 약')
require(goal < interactive < summary,
        "exploration interaction must follow the goal and precede the summary")

# 연습 탭이 미달성 학생을 즉시 기존 출제 진입점으로 보내되,
# 해금/완료 학생에게 재시험을 강제하지 않는다.
require("selectLearningStage(stage, concept: concept)" in concept,
        "stage buttons must use the shared stage-selection path")
selection = concept[
    concept.index("private func selectLearningStage("):
    concept.index("private func explorationStage(concept:")
]
for literal in (
    "guard stage == .practice else { return }",
    "userCompleted == true",
    "!progress.masteryUnlocked(for: concept)",
    "startPractice(concept)",
):
    require(literal in selection, f"practice selection guard missing: {literal}")

practice = concept[
    concept.index("private func practiceSection(concept:"):
    concept.index("private func startPractice(")
]
require('Button("연습 이어가기")' in practice and "startPractice(concept)" in practice,
        "practice CTA/action rail must share startPractice")
require("store.startExam" not in practice and "store.startWebPractice" not in practice,
        "practiceSection must not duplicate native/web launch logic")
launcher = concept[
    concept.index("private func startPractice("):
    concept.index("private func completeSection(concept:")
]
require("usesWebGenerator(concept)" in launcher
        and "store.startWebPractice(concept)" in launcher
        and "store.startExam(types:" in launcher,
        "shared startPractice must preserve both existing launch paths")

# 음성 메뉴는 기존 전역 3상태를 사용하고 실제로 반영되는 HTML 모션에만 보인다.
for literal in (
    "@AppStorage(ConceptNarrationPreference.key)",
    "motionVideoURL == nil && hasMotionWebStage",
    "if showsNarrationVoiceMenu",
    "usesStackedNarrationHeader",
    "horizontalSizeClass == .compact",
    "dynamicTypeSize.isAccessibilitySize",
    "contentWidth < 600",
    "ForEach(ConceptNarrationVoice.allCases)",
    'accessibilityIdentifier("concept-narration-voice-menu")',
):
    require(literal in timeline, f"HTML narration menu contract missing: {literal}")

print("개념 학습 진입 계약 통과 (중앙 정렬 · 탐색 우선 · 탭 즉시 연습 · HTML 음성 메뉴)")
PY
