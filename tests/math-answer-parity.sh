#!/bin/bash
# 실행:  ipad-app/tests/math-answer-parity.sh
#
# **앱의 채점기가 레포와 같은 답을 내는지** 대조한다.
#
# 왜 이 형태인가: 앱(Swift)과 웹(JS)이 각자 채점하면 같은 학생 답이 화면마다
# 다르게 채점된다. 실제로 그랬다 — 앱에는 수식 파서가 아예 없어서
# sqrt(2)·2π·3^2 가 전부 오답이었고, 쉼표 구분자도 서로 달랐다(전각 vs ASCII).
# 그래서 규칙을 글로 맞추는 대신 **같은 입력을 양쪽에 넣어 결과를 비교**한다.
#
# 케이스를 추가할 때는 tests/math-answer-cases.json 만 고치면 된다.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
APP="$HERE/.."
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
# 레포 위치. 없으면 알려진 후보를 훑고, 그래도 없으면 임시로 클론한다.
# (예전엔 /private/tmp/Matths-new 하나만 보고 있어서, 그 폴더가 지워지자
#  테스트가 "레포를 찾지 못했다" 로 죽었다 — 스크립트가 환경에 묶여 있었다.)
REPO="${MATTHS_REPO:-}"
if [ -z "$REPO" ]; then
  for cand in /private/tmp/Matths-fresh /private/tmp/Matths-new "$HOME/Desktop/matths-sprint/webrepo-applied"; do
    [ -f "$cand/services/mathAnswerService.js" ] && REPO="$cand" && break
  done
fi
if [ -z "$REPO" ]; then
  REPO="$WORK/repo"
  echo "레포를 찾지 못해 임시로 클론한다…"
  git clone --depth 1 -q https://github.com/is4553807/Matths.git "$REPO" || true
fi
if [ ! -f "$REPO/services/mathAnswerService.js" ]; then
  echo "레포를 찾지 못했다: $REPO"
  echo "  MATTHS_REPO=<경로> 로 지정하거나 git clone 해 두어라."
  exit 2
fi

CASES="$HERE/math-answer-cases.json"

# ── 레포(JS) 기준값 ────────────────────────────────────────────────
node -e '
const m = require(process.argv[1] + "/services/mathAnswerService.js");
const cs = JSON.parse(require("fs").readFileSync(process.argv[2], "utf8"));
console.log(JSON.stringify(cs.map(([a, b]) => m.answersEquivalent(a, b))));
' "$REPO" "$CASES" > "$WORK/repo.json"

# ── 앱(Swift) 결과 ────────────────────────────────────────────────
cp "$APP/Matths/MathAnswer.swift" "$WORK/"
python3 - "$CASES" > "$WORK/main.swift" <<'PY'
import json, sys
cs = json.load(open(sys.argv[1]))
def q(s): return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'
print("import Foundation")
print("let cases: [(String,String)] = [")
for a, b in cs: print(f"  ({q(a)}, {q(b)}),")
print("]")
print('print("[" + cases.map { MathAnswer.answersEquivalent($0.0, $0.1) ? "true" : "false" }.joined(separator: ",") + "]")')
PY
swiftc -O "$WORK/MathAnswer.swift" "$WORK/main.swift" -o "$WORK/check" 2>/dev/null
"$WORK/check" > "$WORK/swift.json"

# ── 대조 ──────────────────────────────────────────────────────────
python3 - "$CASES" "$WORK/repo.json" "$WORK/swift.json" <<'PY'
import json, sys
cs = json.load(open(sys.argv[1]))
r = json.load(open(sys.argv[2]))
s = json.load(open(sys.argv[3]))
bad = [(cs[i], r[i], s[i]) for i in range(len(r)) if r[i] != s[i]]
for (a, b), rv, sv in bad:
    print(f"  ✗ {a!r} vs {b!r} — 레포 {rv} / 앱 {sv}")
print(f"\n케이스 {len(r)}개 · 불일치 {len(bad)}개")
print("전부 일치 — 앱과 웹이 같은 답을 채점한다" if not bad else "차이 있음")
sys.exit(1 if bad else 0)
PY
