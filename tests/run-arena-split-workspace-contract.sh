#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
match="$root/Matths/GoatArenaMatchPlayScreen.swift"
canvas="$root/Matths/SolutionCanvas.swift"
harness="$root/Matths/SizeHarness.swift"

require() {
  local needle="$1"
  local file="$2"
  if ! grep -Fq "$needle" "$file"; then
    echo "arena split workspace contract missing: $needle" >&2
    exit 1
  fi
}

# iPad와 iPhone 가로 작업대는 실제 가용 크기를 보고 분할/스크롤 fallback을 결정한다.
require 'GeometryReader { proxy in' "$match"
require 'size.width >= 744 && size.height >= 540' "$match"
require 'verticalSizeClass == .compact' "$match"
require 'size.width >= 700' "$match"
require 'size.height >= 260' "$match"
require 'splitWorkspace(size: proxy.size)' "$match"
require 'scrollingPlayView' "$match"
require 'workspaceQuestionColumn(height: workspaceHeight)' "$match"
require 'workspaceBoardColumn(' "$match"
require 'availableWorkspaceHeight' "$match"
require '? max(220, availableWorkspaceHeight)' "$match"

# 넓은 iPad의 좌우 작업대 자체에는 바깥 ScrollView를 다시 넣지 않는다.
split_body="$(awk '
  /private func splitWorkspace\(size:/ { inside=1 }
  /private var workspaceStatusBar:/ { inside=0 }
  inside { print }
' "$match")"
if grep -Fq 'ScrollView' <<<"$split_body"; then
  echo 'arena split workspace contract: split workspace must not contain ScrollView' >&2
  exit 1
fi

# 오른쪽 필기판은 남은 높이를 정확히 받고, 좁은 분할에서도 도구가 숨지 않는다.
require 'constrainedHeight: noteHeight' "$match"
require 'usesCompactToolbar: usesCompactToolbar' "$match"
require 'minimumConstrainedCanvasHeight: phoneLandscape ? 150 : 180' "$match"
require 'var constrainedHeight: CGFloat? = nil' "$canvas"
require 'var usesCompactToolbar: Bool = false' "$canvas"
require 'var minimumConstrainedCanvasHeight: CGFloat = 180' "$canvas"
require 'private var constrainedPencilToolbar: some View' "$canvas"

# 긴 발문·도형만 왼쪽 열에서 독립 스크롤하고, 선택지와 다음 문항은 고정한다.
question_body="$(awk '
  /private func workspaceQuestionColumn\(height:/ { inside=1 }
  /private func compactIntegrityWatermark/ { inside=0 }
  inside { print }
' "$match")"
grep -Fq 'ScrollView {' <<<"$question_body"
grep -Fq '.scrollBounceBehavior(.basedOnSize, axes: .vertical)' <<<"$question_body"
grep -Fq 'Text("문제 \(currentQuestionNumber)번")' <<<"$question_body"
grep -Fq 'minHeight: phoneLandscape ? 36 : nil' <<<"$question_body"
scroll_line=$(grep -n 'ScrollView {' <<<"$question_body" | head -1 | cut -d: -f1)
choices_line=$(grep -n 'if let choices = question.choices' <<<"$question_body" | head -1 | cut -d: -f1)
if [[ "$choices_line" -le "$scroll_line" ]]; then
  echo 'arena split workspace: answers must remain below the problem scroller' >&2
  exit 1
fi

# 경기 시작 로비의 핵심 행동은 iPhone 가로에서도 스크롤 아래로 사라지지 않는다.
require '.safeAreaInset(edge: .bottom, spacing: 0)' "$match"
require 'private var lobbyActions: some View' "$match"
require 'Label("지금 시작", systemImage: "play.fill")' "$match"
require 'Text("나중에 시작")' "$match"

# 시뮬레이터에서 서버 없이도 이 화면을 크기별로 캡을 수 있어야 한다.
require 'else if screenLabel == "match"' "$harness"
require 'GoatArenaMatchPlayScreen(' "$harness"

echo 'arena split workspace contract PASS'
