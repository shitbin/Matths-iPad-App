#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
app="$root/Matths/MatthsApp.swift"
auth="$root/Matths/AuthScreen.swift"
tokens="$root/Matths/DesignTokens.swift"
screens="$root/Matths/Screens.swift"
canvas="$root/Matths/SolutionCanvas.swift"
weekly="$root/Matths/WeeklyMockScreen.swift"

# 오답 검색·필터·펼침은 라우트 View 수명보다 긴 AppStore가 소유한다.
for field in wrongNoteExpanded wrongNoteFilterUnit wrongNoteFilterError wrongNoteQuery wrongNoteSortKey; do
  grep -Fq "@Published var $field" "$app"
done
if sed -n '/struct WrongNotesScreen/,/struct WrongNoteRow/p' "$screens" \
  | grep -Eq '@State private var (expanded|filterUnit|filterError|query|sortKey)'; then
  echo "WrongNotesScreen에 라우트 교체 시 사라지는 필터 상태가 남았습니다." >&2
  exit 1
fi
# 빈 오답 상태의 실제 설명·CTA가 iPhone 가로에서 장식 카드 두 장 뒤로 밀리지 않는다.
wrong_notes=$(sed -n '/struct WrongNotesScreen/,/struct WrongNoteRow/p' "$screens")
printf '%s\n' "$wrong_notes" | grep -Fq '@Environment(\.verticalSizeClass) private var verticalSizeClass'
printf '%s\n' "$wrong_notes" | grep -Fq 'private var compactHeight: Bool { verticalSizeClass == .compact }'
printf '%s\n' "$wrong_notes" | grep -Fq 'if !compactHeight {'
printf '%s\n' "$wrong_notes" | grep -Fq '.padding(.vertical, compactHeight ? Tokens.Space.s2 : Tokens.Space.s8)'

# 버튼 disabled 외형과 AA 상태 잉크.
grep -Fq '@Environment(\.isEnabled) private var isEnabled' "$tokens"
grep -Fq 'static let dangerInk' "$tokens"
grep -Fq 'isEnabled ? Tokens.actionPrimary : Tokens.line' "$tokens"

# 입력 자동완성·OTP·약관 원문·키보드 닫기.
grep -Fq '.textContentType(mode == .register ? .newPassword : .password)' "$auth"
grep -Fq '.textContentType(.oneTimeCode)' "$auth"
grep -Fq 'ToolbarItemGroup(placement: .keyboard)' "$auth"
grep -Fq 'destination: ServerAPI.baseURL.appendingPathComponent("terms")' "$auth"
grep -Fq 'destination: ServerAPI.baseURL.appendingPathComponent("privacy")' "$auth"
grep -Fq '.scrollDismissesKeyboard(.interactively)' "$weekly"
grep -Fq '.frame(width: 36, height: 44)' "$weekly"
grep -Fq '.frame(maxWidth: 140, minHeight: 44)' "$weekly"

# 권한 재동기화와 ViewThatFits 후보 교체 후 필기 도구 상태 보존.
grep -Fq 'func refreshNotificationAuthorization() async' "$app"
grep -Fq 'await store.refreshNotificationAuthorization()' "$app"
grep -Fq '@Binding var undoStack: [PKDrawing]' "$canvas"
grep -Fq 'undoStack: $noteUndoStack' "$screens"

echo "Active non-Arena iPad P1 remediation contracts passed"
