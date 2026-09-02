#!/usr/bin/env bash
set -euo pipefail

# 문항 난이도 계약 (2026-08-16)
#
# 왜 이 검사가 있나:
#   ProblemGenerator 는 풀이 절차를 6~9단계로 제대로 설계해 뒀는데, 대입하는 수치가
#   전부 한 자리라 학생이 절차를 밟지 않고 암산으로 답을 찍었다. 실측했더니
#   pick(범위) 호출 37건 중 36건(97%)이 한 자리였다. 원인은 문항 구조가 아니라 수치 폭이다.
#
#   그래서 수치를 넓히는데, 무작정 넓히면 정답이 분수·무리수로 새거나
#   계산이 노가다가 된다. 이 검사는 "넓힌 값이 되돌아가지 않았는가" 와
#   "정수성을 지키는 보정 코드가 살아 있는가" 를 같이 못박는다.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT/Matths/ProblemGenerator.swift"

test -f "$SOURCE"

# ── extremum: a, b 를 한 자리 끝까지 넓혔다.
#    p = -3(a+b)/2 가 정수로 남으려면 합이 짝수여야 하므로 보정이 반드시 함께 있어야 한다.
grep -Fq 'let a = rng.pick((-9)...(-1))' "$SOURCE"
grep -Fq 'var b = rng.pick(1...9)' "$SOURCE"
grep -Fq 'if (a + b) % 2 != 0 { b += 1 }' "$SOURCE"
grep -Fq 'if b <= a { b = a + 2 }' "$SOURCE"

# ── logEq: c 를 두 자리로. base·k 는 건드리지 않는다(진수가 네 자리를 넘으면
#    난이도가 아니라 피로도만 올라간다).
grep -Fq 'let c = rng.pick(11...49)' "$SOURCE"
grep -Fq 'let k = rng.pick(2...4)' "$SOURCE"
grep -Fq 'let base = rng.choose([2, 3, 5])' "$SOURCE"

# ── counting: n 상한 10 은 의도값이다. 10P5 = 30240 이 손셈의 한계다.
grep -Fq 'let n = rng.pick(6...10)' "$SOURCE"
grep -Fq 'let r = rng.pick(2...5)' "$SOURCE"

# ── 2차 배치 (2026-08-16): 임의 정수에서 정답이 정수로 남는 유형만 넓혔다.
#    vieta       α²+β² = S²−2P — 임의 정수 안전. 다만 "두 근" 이라 했으니
#                판별식 S²−4P ≥ 0 을 지켜야 발제문과 어긋나지 않는다.
#    polyExpand  a+b, a·b — 안전
#    complexMul  ac−bd, ad+bc — 안전
#    statMean    a·m+b — 안전
#    statVar     a²·v — 안전. b 는 답에 안 들어가는 미끼라 같이 키워야 급소가 시험된다.
grep -Fq 'let s = rng.pick(7...23)' "$SOURCE"
grep -Fq 'let p = rng.pick(3...max(4, (s * s) / 4))' "$SOURCE"
grep -Fq 'let a = rng.pick(3...19)' "$SOURCE"
grep -Fq 'let a = rng.pick(3...14), b = rng.pick(3...14)' "$SOURCE"
grep -Fq 'let m = rng.pick(8...24)' "$SOURCE"
grep -Fq 'let v = rng.pick(6...24)' "$SOURCE"

# ── 3차 배치 (2026-08-16)
#    integral     ∫₀^a(2x+b)dx = a²+ab — 임의 정수 안전
#    seqBlockSum  p 는 짝수여야 q = 2p−1 이 정수다. 2배 보정을 반드시 유지한다.
#    quadDisc     b 는 짝수여야 b²/4 가 정수다. 2배 보정을 반드시 유지한다.
grep -Fq 'let a = rng.pick(4...14)' "$SOURCE"
grep -Fq 'let p = 2 * rng.pick(3...12)' "$SOURCE"
grep -Fq 'let b = 2 * rng.pick(3...11)' "$SOURCE"

# ── 4차 배치 (2026-08-16)
#    circleDist  거리 정수성은 피타고라스 트리플이 보장한다 — 큰 트리플 추가
#    statBinom   n = den²·m 구조라 m 을 키워도 E, V 가 정수
#    diceProb    분모 36 고정이라 합의 범위를 전 구간으로 넓혀도 답이 안 지저분해진다
grep -Fq '(12, 35, 37)' "$SOURCE"
grep -Fq '(7, 24, 25)' "$SOURCE"
grep -Fq 'let n = den * den * m' "$SOURCE"
grep -Fq 'let s = rng.pick(2...12)' "$SOURCE"

# ── 손대지 않기로 한 유형 (의도적 보존)
#    expLaw     이미 세 자리 답이 나온다. 지수를 더 키우면 난이도가 아니라 자릿수만 는다.
#    statNormal 정규분포표에 있는 z 값만 써야 한다. 넓히면 학생이 표에서 못 찾는다.
#    statSample 같은 이유 + 표본크기 제곱근이 정수로 떨어져야 한다.
grep -Fq 'let k = rng.pick(1...3)' "$SOURCE"

# ── 되돌림 감시: 넓히기 전의 좁은 범위가 되살아나면 실패시킨다.
#    변수 선언까지 포함해 대조한다. 범위 문자열만 보면 다른 유형이 정당하게 쓰는
#    같은 범위(예: 다른 case 의 rng.pick(1...4))까지 걸려 오탐이 난다.
for narrow in 'let a = rng.pick((-4)...(-1))' 'var b = rng.pick(1...4)' 'let n = rng.pick(5...9)' \
              'let s = rng.pick(3...7)' 'let a = rng.pick(1...6)' \
              'let v = rng.pick(2...6)' 'let a = rng.pick(1...4), b = rng.pick(1...4)' \
              'let a = rng.pick(2...5)' 'let p = 2 * rng.pick(3...6)' 'let b = 2 * rng.pick(2...4)' \
              'let m = rng.pick(1...3)' 'let s = rng.pick(5...9)'; do
  if grep -Fq "$narrow" "$SOURCE"; then
    echo "문항 수치가 좁은 범위로 되돌아갔습니다: $narrow" >&2
    exit 1
  fi
done

# ── 채점·진도 규칙은 손대지 않는다는 약속. 생성기가 정답 문자열을 그 자리에서
#    계산하는 구조 자체는 유지돼야 한다(규칙을 바꾸지 않고 문항만 바꾼다).
grep -Fq 'answer: "\(answer)"' "$SOURCE"

echo "문항 난이도 계약 통과 — 14 / 17개 유형 (expLaw·statNormal·statSample 는 의도적 보존)"
