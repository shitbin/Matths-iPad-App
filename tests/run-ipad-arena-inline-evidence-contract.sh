#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MATCH="$ROOT/Matths/GoatArenaMatchPlayScreen.swift"
API="$ROOT/Matths/ServerAPI.swift"

for file in "$MATCH" "$API"; do
  test -f "$file" || { echo "missing inline evidence source: $file" >&2; exit 1; }
done

# iPad 경기는 종이 풀이를 경기 뒤 다시 촬영시키지 않는다. 옛 수동 사진 패널을
# MatchPlay에서 참조하는 순간 출시 요구사항이 깨지므로 실행 경로에 이름조차 없어야 한다.
if grep -Fq 'GoatArenaEvidencePanel(' "$MATCH"; then
  echo "iPad match play must not present the legacy one-minute photo upload" >&2
  exit 1
fi

# 현재 문항의 풀이판 원본·preview를 revision과 멱등키로 저장하고, 서버가 승인한
# revision/hash 없이는 다음 문항을 열지 않는다.
grep -Fq 'saveGoatArenaSolutionBoard(' "$MATCH"
grep -Fq 'guard let boardRevision = solutionBoardSavedRevisions[question.slot]' "$MATCH"
grep -Fq 'let boardSha256 = solutionBoardSavedHashes[question.slot]' "$MATCH"
grep -Fq 'boardRevision: boardRevision' "$MATCH"
grep -Fq 'boardSha256: boardSha256' "$MATCH"
grep -Fq 'advanceGoatArenaQuestion(' "$MATCH"
grep -Fq '"X-Matths-Evidence-Mode": "INLINE_BOARD_V1"' "$API"
grep -Fq '/solution-boards/current' "$API"

# 마지막 문항 또는 timeout 뒤 서버가 EVIDENCE_REQUIRED를 잠시 반환해도 별도 화면으로
# 보내지 않고 저장된 다섯 풀이판을 정본 증거로 자동 확정한 뒤 상태를 다시 읽는다.
[[ "$(grep -Fc 'response.attempt.status == "EVIDENCE_REQUIRED"' "$MATCH")" -ge 2 ]]
[[ "$(grep -Fc 'finalizeGoatArenaSolutionBoards(' "$MATCH")" -ge 2 ]]
grep -Fq '/solution-boards/finalize' "$API"
grep -Fq '별도 사진 제출은 필요하지 않습니다.' "$MATCH"

# 약 1초 debounce 자동 저장과 계정 슬롯 검증은 재접속·계정 전환 시 증거 혼입을 막는다.
grep -Fq 'milliseconds(900)' "$MATCH"
grep -Fq 'guard accountIsCurrent' "$MATCH"

echo "iPad Arena inline evidence contract passed"
