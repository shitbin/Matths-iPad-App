#!/usr/bin/env bash
set -euo pipefail

# 손글씨 피드백 회귀 계약:
# - 음성 끄기를 존재하지 않는 효과음 모드로 설명하지 않는다.
# - 900pt 탐색/연습 블록은 넓은 iPad에서 가운데 놓인다.
# - 학습 주제 체크박스를 표시하지 않는다.
# - 유형 수는 요구치를 넘겨 표시하지 않고 상태별 primary CTA는 하나다.
# - 진도 링 숫자에는 % 단위가 붙는다.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VOICE="$ROOT/Matths/ConceptNarrationVoice.swift"
PROFILE="$ROOT/Matths/ProfileScreen.swift"
VIDEO="$ROOT/Matths/ConceptMotionVideo.swift"
CONCEPT="$ROOT/Matths/ConceptScreenV2.swift"

python3 - "$VOICE" "$PROFILE" "$VIDEO" "$CONCEPT" <<'PY'
from pathlib import Path
import sys

voice = Path(sys.argv[1]).read_text()
profile = Path(sys.argv[2]).read_text()
video = Path(sys.argv[3]).read_text()
concept = Path(sys.argv[4]).read_text()

def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)

for literal in (
    'case .off: "음성 끄기"',
    'case .female: "여성"',
    'case .male: "남성"',
):
    require(literal in voice, f"음성 메뉴 라벨 계약 누락: {literal}")
require("효과음만" not in voice + profile + video,
        "독립 효과음이 없는데 효과음 전용 모드로 안내하고 있습니다")
require("끄거나 성우를 고릅니다" in profile,
        "프로필 음성 설명이 실제 세 상태를 설명하지 않습니다")

ring = concept[concept.index("struct ProgressRing:"):
               concept.index("private enum ConceptLearningStage")]
for literal in (
    "private var displayedPercent: Int { min(100, max(0, percent)) }",
    'Text("\\(displayedPercent)%")',
    '.accessibilityValue("\\(displayedPercent)퍼센트")',
):
    require(literal in ring, f"진도 링 표시 계약 누락: {literal}")

content = concept[concept.index("private func content(course:"):
                  concept.index("private func conceptHeader(course:")]
require("alignment: effectiveStage == .explain ? .leading : .center" in content,
        "900pt 탐색·연습 블록이 넓은 작업대의 중앙에 놓이지 않습니다")

explore = concept[concept.index("private func explorationStage(concept:"):
                  concept.index("private func explorationInteractiveCard(concept:")]
require("TopicCheckRow(" not in explore,
        "탐색 화면에 학습 주제 체크박스 목록이 다시 노출됐습니다")
require("학습 주제, 진도의 30%" not in explore,
        "제거한 학습 주제 진도 섹션이 다시 노출됐습니다")

practice = concept[concept.index("private func practiceSection(concept:"):
                   concept.index("private func startPractice(")]
for literal in (
    "let credited = min(got, required)",
    '"유형 학습 \\(credited)/\\(required)"',
    "required - credited",
    'Button("연습 이어가기")',
    "if completed",
    "else if unlocked",
):
    require(literal in practice, f"연습 상태 표시 계약 누락: {literal}")
require('\\(got)/\\(required)' not in practice,
        "원시 정답 유형 수를 표시해 6/5 같은 초과 수치가 다시 생깁니다")
require("진도의 60%" not in practice,
        "연습 섹션 제목이 내부 진도 가중치를 사용자 점수처럼 노출합니다")

complete = concept[concept.index("private func completeSection(concept:"):
                   concept.index("private func showsCompletionSection")]
require("else if unlocked" in complete,
        "완료 CTA가 유형 게이트가 닫힌 상태에도 나타납니다")
require(".disabled(!unlocked)" not in complete,
        "비활성 완료 CTA가 연습 CTA와 같은 화면에 다시 경쟁합니다")
require("90%" not in complete,
        "내부 진도 cap이 사용자에게 설명 없는 점수처럼 노출됩니다")
require(concept.count("showsCompletionSection(for: concept)") == 2,
        "세로 본문과 가로 action rail의 완료 CTA 표시 조건이 갈라졌습니다")

print("개념 표시 상태 계약 통과 (음성 · 중앙 정렬 · 체크목록 제거 · capped 유형 · 단일 CTA · 진도 단위)")
PY
