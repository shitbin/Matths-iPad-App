#!/bin/sh
# 시험 타이머가 화면을 초당 한 번보다 자주 무효화하지 못하게 막는다.
#
# 막으려는 사고 (2026-08-21):
#   ExamTimer 가 elapsedMs 를 30fps 로 @Published 했다. 시험 화면 세 곳이 이
#   객체를 @StateObject 로 직접 들고 있어 body 전체가 초당 30번 재평가됐다.
#   화면에 나가는 값은 mm:ss 뿐이라 30틱 중 29틱은 같은 문자열을 다시 만드는
#   순수 낭비였다. 감독이 보고한 "아이패드에서 버튼 반응이 느리다"의 원인이다.
#
#   측정(iPad Pro 13" 시뮬, 20초, 응시 데이터 없는 빈 시험 화면):
#     수정 전 9.0% CPU  →  수정 후 0.6% CPU
#
# 지키는 계약 두 가지:
#   ① 발행되는 값은 초 단위다. 밀리초는 발행하지 않는다.
#   ② 값이 실제로 바뀐 틱에서만 발행한다. (@Published 는 같은 값을 넣어도
#      objectWillChange 를 보내므로, 이 가드가 곧 성능이다.)
#
# 실행: sh tests/run-exam-timer-publish-rate-contract.sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
timer="$root/Matths/ExamTimer.swift"

fail() { echo "FAIL: $1" >&2; exit 1; }

# ── ① 밀리초를 발행하지 않는다 ──────────────────────────────────────────────
grep -q '@Published private(set) var elapsedSeconds: Int' "$timer" \
  || fail "ExamTimer 가 초 단위 값을 발행하지 않습니다."
grep -qE '@Published[^\n]*elapsedMs' "$timer" \
  && fail "밀리초가 다시 @Published 됐습니다. 화면이 초당 수십 번 재평가됩니다."

# 정밀 경과는 함수여야 한다. 프로퍼티로 되돌리면 발행 대상이 되기 쉽다.
grep -q 'func exactElapsedMs() -> Int' "$timer" \
  || fail "exactElapsedMs() 가 없습니다. 제출 기록의 정밀도가 사라집니다."

# ── ② 값이 바뀐 틱에서만 발행한다 ───────────────────────────────────────────
# 주석에도 같은 낱말이 나오므로 코드 형태로 붙잡는다.
grep -q 'if seconds != elapsedSeconds { elapsedSeconds = seconds }' "$timer" \
  || fail "변화 가드가 없습니다. 같은 값을 다시 넣어도 화면은 무효화됩니다."

# ── ③ 화면은 밀리초를 관찰하지 않는다 ───────────────────────────────────────
if grep -rn 'timer\.elapsedMs' "$root/Matths"; then
  fail "화면이 아직 timer.elapsedMs 를 읽습니다."
fi

# ── ④ 제출·기록은 표시용 초가 아니라 정밀 경과를 쓴다 ───────────────────────
grep -q 'store.submitPaper(monotonicElapsed: Double(timer.exactElapsedMs()) / 1000)' \
  "$root/Matths/AssessmentPaperScreen.swift" \
  || fail "평가 제출이 정밀 경과를 쓰지 않습니다."
grep -q 'elapsedMs: timer.exactElapsedMs(),' "$root/Matths/KiceExamScreen.swift" \
  || fail "KICE 기록이 정밀 경과를 쓰지 않습니다."

# 데이터가 없는 복구 화면에서 가짜 시험 시간이 흐르거나 행동 없이 막히면 안 된다.
grep -q 'onAppear { syncTimerAvailability() }' "$root/Matths/KiceExamScreen.swift" \
  || fail "KICE 데이터 유실 상태에서도 타이머가 시작될 수 있습니다."
grep -q 'Button("평가센터로 돌아가기")' "$root/Matths/KiceExamScreen.swift" \
  || fail "KICE 데이터 유실 화면에 복구 행동이 없습니다."

# ── ⑤ 죽은 밀리초 표시가 되살아나지 않는다 ──────────────────────────────────
# displayMs 는 사용처가 0곳이면서 30fps 의 유일한 명분이었다.
grep -q 'var displayMs' "$timer" \
  && fail "displayMs 가 되살아났습니다. 쓰는 곳이 없다면 30fps 명분만 돌아옵니다."

echo "PASS: 시험 타이머는 초당 한 번만 화면을 무효화합니다."
