#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

profile="$root/Matths/ProfileScreen.swift"
auth="$root/Matths/AuthScreen.swift"
chat="$root/Matths/ChatScreen.swift"
quick="$root/Matths/QuickPracticeScreen.swift"
weekly="$root/Matths/WeeklyMockScreen.swift"
placement="$root/Matths/PlacementExamScreen.swift"
community="$root/Matths/CommunityScreen.swift"
arena_web="$root/Matths/ArenaWeb/ArenaWebScreen.swift"
notifications="$root/Matths/NotificationInboxScreen.swift"
evidence="$root/Matths/GoatArenaEvidencePanel.swift"
canvas="$root/Matths/SolutionCanvas.swift"

grep -Fq '.accessibilityLabel("코치 수위")' "$profile"
grep -Fq '.accessibilityLabel("복습 리마인더")' "$profile"
grep -Fq '.accessibilityLabel("화면 모션")' "$profile"
grep -Fq '.accessibilityLabel("왼손잡이 모드")' "$profile"
grep -Fq '.accessibilityLabel("AI 모델 9B 실험 모드")' "$profile"
grep -Fq '.accessibilityLabel("홈으로 돌아가기")' "$profile"
awk '/Label\("홈", systemImage: "chevron.left"\)/,/\.accessibilityLabel\("홈으로 돌아가기"\)/' "$profile" \
  | grep -Fq '.dynamicTypeSize(...DynamicTypeSize.xxxLarge)'
grep -Fq 'Link("고객지원", destination: ServerAPI.baseURL.appendingPathComponent("faq"))' "$profile"
grep -Fq '.accessibilityHint("브라우저에서 고객지원 페이지를 엽니다")' "$profile"
grep -Fq '.accessibilityLabel("로그인 또는 회원가입")' "$auth"
grep -Fq '.accessibilityLabel("보고 있는 문제 연결 해제")' "$chat"
grep -Fq '.accessibilityLabel("첨부한 풀이 사진 삭제")' "$chat"
python3 - "$chat" "$evidence" <<'PY'
from pathlib import Path
import sys

checks = (
    (Path(sys.argv[1]), 'accessibilityLabel("보고 있는 문제 연결 해제")'),
    (Path(sys.argv[1]), 'accessibilityLabel("첨부한 풀이 사진 삭제")'),
    (Path(sys.argv[2]), 'accessibilityLabel("\\(number)번 사진 삭제")'),
)
for path, marker in checks:
    source = path.read_text(encoding="utf-8")
    end = source.find(marker)
    if end < 0 or '.frame(width: 44, height: 44)' not in source[max(0, end - 700):end]:
        raise SystemExit(f"44pt destructive icon target missing before {marker} in {path.name}")
PY
[[ "$(grep -Fc '.frame(width: 44, height: 44)' "$canvas")" -ge 3 ]]
if grep -Fq '.frame(width: 40, height: 44)' "$canvas"; then
  echo "constrained solution-canvas controls must keep 44pt square targets" >&2
  exit 1
fi
grep -Fq 'ViewThatFits(in: .horizontal)' "$canvas"
grep -Fq 'constrainedActionsMenu' "$canvas"
grep -Fq '.accessibilityLabel("편집 동작 더 보기")' "$canvas"
grep -Fq '.accessibilityLabel("\(label), \(value)")' "$chat"
grep -Fq '.accessibilityHint("다운로드가 끝나면 AI 튜터가 자동으로 열립니다")' "$chat"
grep -Fq '.accessibilityLabel("퀵 연습 진행, 취약 개념 문제 받기, 40초 풀이, 정답률과 평균 속도 확인")' "$quick"
grep -Fq '.accessibilityLabel(MathText.plain(text))' "$root/Matths/ConceptScreenV2.swift"
grep -Fq '.accessibilityLabel("주간 공식 모의고사 진행, 회차 응시, 전국 기준 환산, 이번 주 대표 결과 확정")' "$weekly"
[[ "$(grep -Fc '.accessibilityElement(children: .contain)' "$weekly")" -ge 2 ]]
grep -Fq '.accessibilityLabel("시험 화면")' "$weekly"
grep -Fq '.accessibilityValue(pane.rawValue)' "$weekly"
grep -Fq '.accessibilityLabel("모의고사 답안 진행률")' "$weekly"
grep -Fq '"남은 시간 \(WeeklyMockFormat.clock(remaining ?? 0)), "' "$weekly"
grep -Fq '.accessibilityAddTraits(answer == key ? .isSelected : [])' "$weekly"
grep -Fq '.accessibilityLabel("\(number)번 단답")' "$weekly"
grep -Fq '.accessibilityAddTraits(selected(option) ? .isSelected : [])' "$weekly"
grep -Fq 'Text("\(row.isCorrect ? "정답" : "오답"), \(row.number)번' "$weekly"
[[ "$(grep -Fc 'closeLabel: "모의고사 센터로 돌아가기"' "$weekly")" -eq 2 ]]
grep -Fq '.accessibilityLabel(MathText.plain(question.prompt))' "$placement"
grep -Fq 'private var webContentObscured: Bool' "$community"
grep -Fq '.accessibilityHidden(webContentObscured)' "$community"
[[ "$(grep -Fc '.accessibilityAddTraits(.isModal)' "$community")" -ge 3 ]]
grep -Fq 'private func fittingOverlayCard<Content: View>' "$community"
grep -Fq 'ViewThatFits(in: .vertical)' "$community"
grep -Fq 'private var loginCardActions: some View' "$community"
grep -Fq 'ViewThatFits(in: .horizontal)' "$community"
grep -Fq 'model.updateAccessibility(size: dynamicTypeSize)' "$community"
grep -Fq 'WebContentAccessibility.configureHostedPage(' "$community"
grep -Fq 'private var webContentObscured: Bool' "$arena_web"
grep -Fq '.accessibilityHidden(webContentObscured)' "$arena_web"
[[ "$(grep -Fc '.accessibilityAddTraits(.isModal)' "$arena_web")" -ge 2 ]]
grep -Fq 'private func fittingOverlayCard<Content: View>' "$arena_web"
grep -Fq 'ViewThatFits(in: .vertical)' "$arena_web"
grep -Fq 'model.updateAccessibility(size: dynamicTypeSize)' "$arena_web"
grep -Fq 'WebContentAccessibility.configureHostedPage(' "$root/Matths/ArenaWeb/ArenaWebModel.swift"
grep -Fq 'webView.pageZoom = scale(for: size)' "$root/Matths/WebContentAccessibility.swift"
if sed -n '/static func configureHostedPage(/,/static func scale(/p' \
  "$root/Matths/WebContentAccessibility.swift" | grep -Fq 'bounces = false'; then
  echo "hosted page accessibility must preserve pull-to-refresh bounce" >&2
  exit 1
fi
awk '/private var emptyState:/,/\/\/ MARK: 목록/' "$notifications" \
  | grep -Fq '.accessibilityHidden(true)'
grep -Fq 'private var showsHeaderSummary: Bool { !inbox.notifications.isEmpty }' "$notifications"
[[ "$(grep -Fc 'if showsHeaderSummary {' "$notifications")" -eq 3 ]]

echo "Native settings, auth, tutor, and guest journey accessibility labels passed"
