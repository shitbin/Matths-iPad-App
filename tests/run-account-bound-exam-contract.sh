#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
weekly="$ROOT/Matths/WeeklyMockScreen.swift"
placement="$ROOT/Matths/PlacementExamScreen.swift"
scope="$ROOT/Matths/DataScope.swift"

# 시험 초안 키는 응답 완료 시점의 전역 슬롯이 아니라 화면 시작 때 캡처한 슬롯을
# 사용해야 한다. 그렇지 않으면 계정 전환 직후 이전 학생의 답안을 새 슬롯에 쓴다.
grep -Fq 'static func defaultsKey(_ base: String, for slot: String)' "$scope"
grep -Fq 'DataScope.defaultsKey("matths.weeklyMock.draft.\(examId)", for: accountSlot)' "$weekly"
grep -Fq 'DataScope.defaultsKey("matths.placement.draft.\(attemptId)", for: accountSlot)' "$placement"

# 읽기·저장·제출·만료·파일 다운로드와 소명/이의제기까지 네트워크 응답을 적용하기
# 전에 화면 소유 계정이 여전히 현재 계정인지 검사한다.
weekly_guards=$(grep -Fc 'guard accountSlot == DataScope.slot' "$weekly")
placement_guards=$(grep -Fc 'guard accountSlot == DataScope.slot' "$placement")
if (( weekly_guards < 20 )); then
  echo "Weekly Mock account ownership guards regressed: $weekly_guards" >&2
  exit 1
fi
if (( placement_guards < 10 )); then
  echo "Placement account ownership guards regressed: $placement_guards" >&2
  exit 1
fi

grep -Fq 'WeeklyMockIntegrityScreen(accountSlot: accountSlot)' "$weekly"
grep -Fq 'WeeklyMockObjectionScreen(accountSlot: accountSlot)' "$weekly"
grep -Fq 'WeeklyMockSelectionView(selection: selection, accountSlot: accountSlot)' "$weekly"

echo "Account-bound exam response and draft contracts passed."
