#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
coach="$root/Matths/CoachEngine.swift"
tutor="$root/Matths/AITutor.swift"
chat="$root/Matths/ChatScreen.swift"
messages="$root/Matths/coach-messages.json"

grep -Fq 'case mild, spicy, silent' "$coach"
! grep -Eq '\.hell|지옥맛|손은 장식|덜 한심|인간으로 복구|코치 빡침|카롤리나 리퍼| SHU' "$coach"
! grep -Eq 'case \.hell|강하게 도발' "$tutor"
# 단언의 목적은 "학습 온도를 SHU 가 아닌 순화된 한국어 라벨로 보여 준다" 이다.
# 라벨의 가운뎃점을 걷어내면서 문구만 '학습 온도 · 안정' → '학습 온도 안정' 으로 갱신했다.
grep -Fq '학습 온도 안정' "$coach"
grep -Fq '극한의 뜻을 그래프로 설명해줘' "$chat"
grep -Fq '이 풀이에서 처음 틀린 단계를 찾아줘' "$chat"

# 진단 경로는 랜덤 대사를 뽑지 않는다.
# 예전 guidance() 는 `let line = correct ? onCorrect() : onWrong()` 로 한 줄을
# 뽑아 놓고 "비어 있지 않은가" 게이트로만 쓰고 버렸다. 상태 전이는
# registerOutcome() 이 맡고, 대사 풀은 톤 프리뷰·마무리 멘트 전용이다.
! grep -Fq 'correct ? onCorrect() : onWrong()' "$coach"
grep -Fq 'mutating func registerOutcome(correct: Bool)' "$coach"

node - "$messages" <<'NODE'
const fs = require('node:fs');
const file = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const modes = Object.keys(file.modes).sort();
if (JSON.stringify(modes) !== JSON.stringify(['mild', 'silent', 'spicy'])) {
  throw new Error(`코치 모드 정본 불일치: ${modes.join(', ')}`);
}
for (const [mode, value] of Object.entries(file.modes)) {
  for (const key of ['correct', 'incorrect', 'unanswered']) {
    if (!Array.isArray(value.messages[key]) || value.messages[key].length < 1) {
      throw new Error(`${mode}.${key} 문구가 비었습니다.`);
    }
  }
}
NODE

# 코치가 실제로 만들어 내는 문장을 돌려서 확인한다.
# grep 만으로는 "학생 답이 진단에 들어갔는가" 를 볼 수 없다.
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cp "$coach" "$work/CoachEngine.swift"
cp "$root/tests/CoachGuidanceCases.swift" "$work/main.swift"
swiftc -parse-as-library -O "$work/CoachEngine.swift" "$work/main.swift" -o "$work/check"
"$work/check"

echo "Coach mode parity and minor-safe copy contract passed"
