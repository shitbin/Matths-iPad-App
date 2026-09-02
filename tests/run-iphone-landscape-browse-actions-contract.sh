#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SHOP="$ROOT/Matths/ArenaShopScreen.swift"
CHAT="$ROOT/Matths/ChatScreen.swift"
PAPER="$ROOT/Matths/AssessmentPaperScreen.swift"
SCREENS="$ROOT/Matths/Screens.swift"
ARENA_WEB="$ROOT/Matths/ArenaWeb/ArenaWebScreen.swift"
COMMUNITY="$ROOT/Matths/CommunityScreen.swift"
ADMIN_ACADEMY="$ROOT/Matths/AdminAcademyExplorer.swift"
TEACHER_CLASSES="$ROOT/Matths/TeacherClassManagementPanel.swift"
TEACHER_CLASSWORK="$ROOT/Matths/TeacherClassworkPanel.swift"
TEACHER_ACADEMY="$ROOT/Matths/TeacherAcademyScreen.swift"
TEACHER_FORENSICS="$ROOT/Matths/TeacherAcademyForensicsPanel.swift"
PRO="$ROOT/Matths/ProScreen.swift"
CHAT_EVIDENCE="$ROOT/Matths/GoatArenaEvidencePanel.swift"
GRADER_LOG="$ROOT/Matths/GraderLogScreen.swift"

for file in "$SHOP" "$CHAT" "$PAPER" "$SCREENS" "$ARENA_WEB" "$COMMUNITY" \
            "$ADMIN_ACADEMY" "$TEACHER_CLASSES" "$TEACHER_CLASSWORK" \
            "$TEACHER_ACADEMY" "$TEACHER_FORENSICS" "$PRO" "$CHAT_EVIDENCE" "$GRADER_LOG"; do
  test -f "$file" || { echo "missing landscape browse source: $file" >&2; exit 1; }
done

for file in "$PRO" "$CHAT" "$CHAT_EVIDENCE" "$GRADER_LOG"; do
  if grep -q '\.sheet(' "$file"; then
    echo "remaining compact-height page sheet: $file" >&2
    exit 1
  fi
done

# 반 일정·담임 이전·출결 보정·주차 수업 편집은 세로가 짧은 iPhone 가로에서
# page sheet로 열지 않는다. 폼 스크롤과 sheet 닫기 제스처가 충돌하지 않게 전체
# 화면을 쓰고, 각 NavigationStack의 취소·저장 버튼으로 빠져나온다.
[[ "$(grep -c '\.compactHeightSheet' "$ADMIN_ACADEMY")" -ge 7 ]]
[[ "$(grep -c '\.compactHeightSheet' "$TEACHER_CLASSES")" -ge 2 ]]
[[ "$(grep -c '\.compactHeightSheet' "$TEACHER_CLASSWORK")" -ge 2 ]]
grep -q '.frame(width: dynamicTypeSize.isAccessibilitySize ? nil : 120)' "$TEACHER_CLASSWORK"
grep -q 'private var panelHeader: some View' "$TEACHER_CLASSES"
grep -q '.frame(width: 120)' "$TEACHER_CLASSES"
if grep -Eq '\.sheet\((isPresented: \$shows(Rename|Contract)Editor|item: \$(operationsClass|homeroomClass|attendanceRecord))' "$ADMIN_ACADEMY"; then
  echo "admin academy editors must not use compact-height page sheets" >&2
  exit 1
fi

# RootView가 이미 상단 앱 바를 제공하므로 본문 화면에 NavigationStack을 겹치지 않는다.
python3 - "$SHOP" <<'PY'
import sys
source = open(sys.argv[1], encoding="utf-8").read()
body = source[source.index("    var body: some View {"):source.index("    private var screenControls")]
if "NavigationStack" in body or ".navigationTitle" in body or ".toolbar(" in body:
    raise SystemExit("ArenaShopScreen body must not add nested navigation chrome")
PY
grep -q 'if compactHeight' "$SHOP"
grep -q 'private var compactHeader' "$SHOP"
grep -q 'frame(width: 44, height: 44)' "$SHOP"
grep -q 'GOAT Arena로 돌아가기' "$SHOP"
grep -q '상점 새로고침' "$SHOP"

# 모델 미설치 상태의 핵심 행동은 스크롤 카드가 아니라 고정 하단 행동에도 있어야 한다.
grep -q 'if showsSetupActionBar' "$CHAT"
grep -q 'private var setupActionBar' "$CHAT"
grep -q 'Button { ModelDownloader.shared.start() }' "$CHAT"
grep -q 'private var compactTutorSetupCopy' "$CHAT"

# 오래된 딥링크나 동기화 경합으로 응시가 사라져도 막다른 빈 상태에 가두지 않는다.
grep -q '다른 기기에서 종료됐거나 저장된 응시 정보가 갱신됐을 수 있습니다' "$PAPER"
grep -q 'Button("평가센터로 돌아가기")' "$PAPER"
grep -q '.onChange(of: hasActiveAttempt)' "$PAPER"
grep -q 'else if store.currentAttempt?.submittedAt != nil' "$PAPER"
grep -q '.alert("아직 답하지 않은 문항이 있습니다. 제출할까요?"' "$PAPER"
grep -q 'Button("계속 풀기", role: .cancel)' "$PAPER"
grep -q '.onChange(of: attempt.submittedAt)' "$PAPER"
grep -q 'proxy.scrollTo(Self.paperTopAnchor, anchor: .top)' "$PAPER"
grep -q 'private static let paperTopAnchor = "assessment-paper-top"' "$PAPER"
grep -q '"\\(score) / 100점, \\(passed ? "통과" : "재응시"), "' "$PAPER"
if grep -q 'Text(timer.display)' "$PAPER"; then
  echo "missing or submitted assessment must not display a running elapsed timer" >&2
  exit 1
fi

# 오답노트의 오늘 복습 CTA는 가로 첫 화면에서 카드 아래로 밀려나지 않는다.
grep -q 'CompactHeightColumns(spacing: Tokens.Space.s5, stackedSpacing: Tokens.Space.s3)' "$SCREENS"
grep -q 'Text("예상 시간 약 \\(dueAll.count \* 4)분")' "$SCREENS"
grep -q 'Button("복습 시작")' "$SCREENS"

# 교사 출결은 반·날짜·저장이 한 화면에 남고, 작업대의 이상적 폭이 Dynamic Island
# 안전영역 밖으로 팽창하지 않아야 한다. 양쪽 인셋을 각각 사용해야 회전 방향도 안전하다.
grep -q 'let compactWorkWidth = max(' "$TEACHER_ACADEMY"
grep -q '.frame(width: compactWorkWidth, alignment: .topLeading)' "$TEACHER_ACADEMY"
grep -q 'viewport.safeAreaInsets.leading + 12' "$TEACHER_ACADEMY"
grep -q 'viewport.safeAreaInsets.trailing + 12' "$TEACHER_ACADEMY"
grep -q 'else if compactLandscape {' "$TEACHER_ACADEMY"
grep -q '.frame(width: compactLandscape ? 144 : nil, alignment: .leading)' "$TEACHER_ACADEMY"
grep -q '.frame(minWidth: compactLandscape ? 72 : 92, minHeight: 44)' "$TEACHER_ACADEMY"
grep -q 'Button(compactLandscape ? "코드 분석" : "추적 코드 분석")' "$TEACHER_FORENSICS"
grep -q '.accessibilityLabel("추적 코드 분석")' "$TEACHER_FORENSICS"

# Safari·Quick Look의 일반 page sheet는 iPhone 가로에서 세로 공간을 더 줄이고,
# 첨부 미리보기는 swipe-down 외 닫기 동선도 없어질 수 있다. 가로에서는 전체 화면을
# 쓰되 두 Quick Look 모두 내비게이션 바의 명시적 닫기 버튼을 제공한다.
for file in "$ARENA_WEB" "$COMMUNITY"; do
  grep -q '.compactHeightSheet(item: $model.externalDestination)' "$file"
  grep -q '.compactHeightSheet(item: $model.previewFile)' "$file"
  grep -q 'title: "닫기"' "$file"
  grep -q '#selector(Coordinator.closePreview)' "$file"
  if grep -q '.sheet(item: $model.externalDestination)' "$file" || \
     grep -q '.sheet(item: $model.previewFile)' "$file"; then
    echo "browser and file preview must not use a compact-height page sheet: $file" >&2
    exit 1
  fi
done

echo "iPhone landscape browse actions contract passed"
