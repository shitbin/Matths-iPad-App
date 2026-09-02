#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

python3 - "$ROOT" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
app = (root / "Matths/MatthsApp.swift").read_text()
assessment = (root / "Matths/AssessmentV2.swift").read_text()
screens = (root / "Matths/Screens.swift").read_text()
root_view = (root / "Matths/RootView.swift").read_text()


def section(source: str, start: str, end: str) -> str:
    begin = source.find(start)
    if begin < 0:
        raise AssertionError(f"missing section start: {start}")
    finish = source.find(end, begin + len(start))
    if finish < 0:
        raise AssertionError(f"missing section end: {end}")
    return source[begin:finish]


# 오답노트의 "미리 복습"은 예정일 전 항목을 넘긴다. 명시 id를 다시 isDue로
# 거르면 버튼은 보여도 세션이 시작되지 않는다.
review = section(app, "func startReview(ids:", "func abandonExam()")
assert "if let ids" in review
assert "selected = wrongNotes.filter(\\.isDue)" in review
assert "isDue &&" not in review

# 넘긴 id 순서가 곧 출제 순서여야 한다. 종전 구현은 Set 멤버십으로 걸러서 배열
# 순서를 버리고 wrongNotes 적재 순서를 따라갔고, 그래서 화면에서 정렬을 바꿔도
# 복습 큐는 늘 같은 순서였다 — 감독이 "코스 마냥 주어진 순서" 라고 지적한 것이다.
assert "ids.compactMap" in review, "복습 큐는 호출부가 준 순서를 그대로 따라야 한다"
assert "requested.contains" not in review, "Set 멤버십 필터는 넘긴 순서를 버린다"

# 졸업(복습 완료)한 오답은 덩어리 복습에서 되살아나지 않되, 학생이 한 문제를
# 지목하면(오답노트 행의 "다시 풀기") 열려야 한다. 무조건 막으면 그 버튼이
# 아무 반응 없는 죽은 버튼이 된다.
assert "includingMastered" in review
assert "includingMastered || !$0.isMastered" in review
assert 'store.startReview(ids: [note.id], includingMastered: true)' in screens

# 평가센터의 "이어서 응시"와 새 회차 시작은 같은 단일 진입 함수를 탄다.
# 기존 미제출 회차를 확인하기 전에 PaperFactory.make를 호출하면 답안을 잃는다.
paper = section(app, "func startPaper(scope:", "func setPaperAnswer(")
resume_index = paper.index("attemptsV2.openAttempt(scopeKey: scopeKey)")
make_index = paper.index("PaperFactory.make(")
assert resume_index < make_index
assert "currentAttemptID = open.id" in paper
assert "route = .paper" in paper

assert "func openAttempt(scopeKey: String)" in assessment
assert "lhs.answers.filter" in assessment and "rhs.answers.filter" in assessment
assert "store.attemptsV2.openAttempt(scopeKey: key) != nil" in screens

# WebGen 문항은 생성 시드와 기록 시드가 같아야 재현 가능하다.
web_practice = section(app, "func startWebPractice(_ concept:", "func recordKice(")
assert re.search(r"let seed = UInt64\(", web_practice)
assert re.search(r"practiceProblems\([\s\S]*?seed: seed", web_practice)
assert "startExam(problems: problems, seed: seed)" in web_practice
assert "seed: lastExamSeed" not in web_practice

# 이미 조립된 문항 세트도 첫 문항부터 durationMs를 기록한다.
prebuilt = section(app, "func startExam(problems:", "func startReview(ids:")
assert "solveStartedAt = examStartedAt" in prebuilt

# 구현된 퀵 연습 route가 숨은 딥링크로만 남지 않도록 평가센터에 명시적 네이티브
# 진입점이 있어야 한다. 채점 Pro 진입은 함께 유지한다.
assessment_screen = section(screens, "struct AssessmentScreen: View", "private struct WeeklyMockEntryCard")
assert 'title: "퀵 연습"' in assessment_screen
assert "store.route = .quickPractice" in assessment_screen
assert 'title: "채점 Pro"' in assessment_screen
assert "store.route = .pro" in assessment_screen

# Route enum의 모든 학습 경로가 실제 RootView 화면에 명시적으로 매핑되어야 한다.
# default HomeScreen에 조용히 떨어지는 새 route는 빈/오동작 CTA와 같다.
for route in (
    "home", "curriculum", "concept", "solve", "result", "assess",
    "weeklyMock", "wrongNotes", "rank", "arenaShop", "placement", "pro",
    "profile", "kice", "paper", "chat", "quickPractice",
):
    if f"case .{route}" not in root_view:
        raise AssertionError(f"RootView route mapping missing: {route}")

print("learning flow CTA contract passed")
PY
