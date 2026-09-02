#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Swift 의미 단계 분할을 실제 컴파일해 고정한다. WebGenSolution은 파일 끝의 독립 enum이라
# 앱 전체나 JavaScriptCore를 띄우지 않고 같은 구현을 그대로 검사할 수 있다.
{
  printf 'import Foundation\n'
  sed -n '/^enum WebGenSolution/,$p' "$ROOT/Matths/WebGen.swift"
  cat <<'SWIFT'
let source = "앞의 두 식을 곱하면 $25x^{2}-25$ 입니다. 여기에 $25x^{2}+25$ 를 곱하면 $625x^{4}-625$ 이므로 상수항은 $-625$ 입니다."
let expected = [
    "앞의 두 식을 곱합니다.",
    "첫 번째 곱의 결과는 $25x^{2}-25$ 입니다.",
    "여기에 $25x^{2}+25$ 를 곱합니다.",
    "두 번째 곱의 결과는 $625x^{4}-625$ 입니다.",
    "따라서 상수항은 $-625$ 입니다.",
]
precondition(WebGenSolution.split(source) == expected)

// 정규형이 아닌 기존 해설은 종전 문장 경계 폴백을 그대로 탄다.
let ordinary = WebGenSolution.split("첫 식을 정리합니다. 다음 식을 대입합니다.")
precondition(ordinary.count == 2)
print("webgen solution structure contract passed")
SWIFT
} > "$TMP/main.swift"

swiftc -module-cache-path "$TMP/ModuleCache" "$TMP/main.swift" -o "$TMP/webgen-test"
"$TMP/webgen-test"

# 범용 풀이 무대는 실제 빌더를 실행해 TeX·단일 라벨·레일 간격을 확인한다.
node - "$ROOT" <<'NODE'
const assert = require("node:assert/strict");
const path = require("node:path");
const root = process.argv[2];
const textContract = require(path.join(root, "Matths/LessonWeb/solution-text-contract.js"));
const scenes = require(path.join(root, "Matths/LessonWeb/solution-scenes.js"));

const steps = [
  "앞의 두 식을 곱합니다.",
  "첫 번째 곱의 결과는 $25x^{2}-25$ 입니다.",
  "여기에 $25x^{2}+25$ 를 곱합니다.",
  "두 번째 곱의 결과는 $625x^{4}-625$ 입니다.",
  "따라서 상수항은 $-625$ 입니다.",
];
const scene = scenes.build({ steps, answer: "-625" });
assert.equal(scene.id, "sol-generic");

const stepBeats = scene.beats.slice(0, steps.length);
assert.equal(stepBeats.length, 5);

// WHY 이 검사가 바뀌었나 — 감독 지시로 "그림으로" 모드의 폴백을 다시 만들었다.
// 예전 폴백은 세로 레일 옆에 단계 문장을 나열하는 것이어서, 감독이 실기기에서 보고
// "풀이 애니메이션 이게 최선이냐? 텍스트 이쁘게 쓰지말고 아이콘으로 대체" 라고 지적했다.
// 그래서 옛 구조(라벨 id 's*', 레일 x=280, 카드 세로 간격 130)를 검사하던 단언은
// 낡았다. 지우지 않고 **새 계약의 뜻**으로 바꾼다: 폴백도 반드시 '그림' 이어야 한다.
const drawKinds = new Set(["polygon", "seg", "point", "path", "circle", "rect", "arrow", "plane"]);
for (let i = 0; i < stepBeats.length; i += 1) {
  const actions = stepBeats[i].actions || [];
  assert.ok(actions.length > 0, `${i + 1}단계에 아무 연출도 없습니다`);
  assert.ok(
    actions.some((a) => drawKinds.has(a.type)),
    `${i + 1}단계가 글자만 있습니다 — 폴백도 그림이어야 합니다`);
}

// 자막은 단계 전문을 온전히 나른다(무대는 요약, 자막은 전문 — 중복 금지 규칙의 반대편).
for (let i = 0; i < stepBeats.length; i += 1) {
  assert.ok(String(stepBeats[i].subtitle || "").trim().length > 0, `${i + 1}단계 자막이 비었습니다`);
}

// TeX 구분자는 어딘가에 살아 있어야 한다(무대 텍스트든 자막이든).
const allText = JSON.stringify(scene);
assert.ok(allText.includes("25x^{2}-25"), "TeX 구분자가 사라졌습니다");
assert.ok(allText.includes("625x^{4}-625"), "네제곱 수식이 사라졌습니다");

console.log("generic solution scene contract passed");

// IMG_3308 회귀: 수식 바깥 앞뒤 조각만 이어 `여기에 입니다.`를 만들면 안 된다.
const mixedSentence = "여기에 $25x^{2}+25$ 를 곱하면 $625x^{4}-625$ 이므로 상수항은 $-625$ 입니다.";
const parsed = textContract.analyze(mixedSentence);
assert.deepEqual(parsed.segments, [
  { text: "여기에" },
  { math: "25x^{2}+25" },
  { text: "를 곱하면" },
  { math: "625x^{4}-625" },
  { text: "이므로 상수항은" },
  { math: "-625" },
  { text: "입니다." },
]);
for (const fragment of ["여기에 입니다.", "따라서 이므로", "를 곱하면 입니다.", "① ②"]) {
  assert.equal(textContract.standalone(fragment), "", `고아 문장이 통과했습니다: ${fragment}`);
}
for (const sentence of ["식을 곱합니다.", "$x^{2}$를 정리합니다.", "상수항은 -625입니다."]) {
  assert.equal(textContract.standalone(sentence), textContract.normalize(sentence));
}

const rejected = scenes.build({ steps: ["여기에 입니다."], answer: "" });
assert.equal(rejected.beats[0].subtitle, "1단계를 확인합니다.");
// 원래 뜻: 수식이 빠져 앞뒤 조각만 남은 문장("여기에 입니다.")을 무대에 올리면 안 된다.
// 새 폴백은 문장 대신 단계 번호 배지를 그리므로, 무대 텍스트에 그 깨진 문장이
// 없다는 것으로 같은 뜻을 검사한다(자막은 위에서 "1단계를 확인합니다." 로 확인).
const rejectedStageText = (rejected.beats[0].actions || [])
  .map((action) => String(action.text || ""))
  .join(" ");
assert.ok(!rejectedStageText.includes("여기에 입니다"),
  "수식이 빠진 깨진 문장이 무대에 올라갔습니다");
console.log("solution text fragment gate passed");
NODE

# 계산형 생성기 전 유형을 실제 번들에서 뽑아 같은 표시 계약에 통과시킨다.
node - "$ROOT" <<'NODE'
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const root = process.argv[2];
const curriculum = require(path.join(root, "Matths/curriculum-v2.json"));
const contract = require(path.join(root, "Matths/LessonWeb/solution-text-contract.js"));
const scenes = require(path.join(root, "Matths/LessonWeb/solution-scenes.js"));
const context = { console };
vm.createContext(context);
vm.runInContext(fs.readFileSync(path.join(root, "Matths/LessonWeb/webgen-bundle.js"), "utf8"), context);

let generated = 0;
let types = 0;
for (const course of curriculum.courses) {
  for (const unit of course.units) {
    for (const concept of unit.concepts) {
      const info = context.MatthsWebGen.conceptGeneratorInfo(course.id, unit.id, concept.id);
      if (!info) continue;
      for (const type of info.types) {
        types += 1;
        const problems = context.MatthsWebGen.generateLocal(course.id, unit.id, concept.id, type.id, 2);
        assert.ok(problems.length > 0, `${concept.id}/${type.id}: 생성 결과 없음`);
        for (const problem of problems) {
          generated += 1;
          assert.ok(contract.standalone(problem.solution), `${concept.id}/${type.id}: 해설 내용어·수식 없음`);
          const scene = scenes.build({ steps: [problem.solution], answer: problem.answer });
          assert.ok(scene?.beats?.length, `${concept.id}/${type.id}: 범용 장면 없음`);
          for (const beat of scene.beats) {
            assert.ok(contract.standalone(beat.subtitle),
              `${concept.id}/${type.id}: 고아 자막 ${JSON.stringify(beat.subtitle)}`);
          }
        }
      }
    }
  }
}
assert.ok(types >= 90, `검사한 계산형 유형이 너무 적습니다: ${types}`);
assert.ok(generated >= types * 2, `계산형 해설 표본이 부족합니다: ${generated}`);
console.log(`solution corpus contract passed: ${types} types / ${generated} generated explanations`);
NODE

# 결과 화면 정책/표시 소유권은 좁은 소스 구간에서 정적으로 잠근다.
python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
app = (root / "Matths/MatthsApp.swift").read_text()
screens = (root / "Matths/Screens.swift").read_text()

def section(source: str, start: str, end: str) -> str:
    begin = source.index(start)
    finish = source.index(end, begin + len(start))
    return source[begin:finish]

grading = section(app, "private func makeGrading", "func advanceExam")
feedback = section(screens, "private func feedbackCard", "private var reasonTagCard")
assert "정답은 알려드리지 않습니다" not in grading
assert "정답은 알려드리지 않습니다" not in feedback

explanation = section(screens, "private func stepList", "private func feedbackCard")
assert "p.steps.first" not in explanation
assert "ForEach(Array(p.steps.enumerated())" in explanation
assert "MathInline(" in explanation

# 결과 데이터는 계정 전환·동기화 중 한 렌더 패스 사이에서도 사라질 수 있다.
# nil 상태는 복구 화면으로 닫고, 이미 시작한 결과 렌더는 값 스냅샷을 쓰게 한다.
result = section(screens, "struct ResultScreen", "private struct LearningDataRecoveryView")
assert 'if let grading = store.lastGrading' in result
assert 'resultContent(grading: grading)' in result
assert 'private func resultContent(grading: GradingResult)' in result
assert 'preconditionFailure(' not in result

coach = section(screens, "struct CoachBubble", "struct TypewriterText")
for icon in ('symbol: "eye"', 'symbol: "arrow.triangle.branch"', 'symbol: "pencil.line"'):
    assert icon not in coach
assert '"flame.fill"' not in coach
for label in ('("관찰",', '("점검",', '("다음",'):
    assert label in coach
assert "CoachGuidanceRow" not in coach
assert "CoachMessageBubble" in coach
assert "revealedTurnCount" in coach

engine = (root / "Matths/CoachEngine.swift").read_text()
for prefix in ('"관찰:', '"점검 순서:', '"다음 행동:'):
    assert prefix not in engine

generic = (root / "Matths/LessonWeb/solution-scenes.js").read_text()
assert "slice(0, 44)" not in generic
assert "slice(44, 88)" not in generic
assert "s${i}b" not in generic

player = (root / "Matths/LessonWeb/solution-player.html").read_text()
assert 'src="solution-text-contract.js"' in player
assert "segs: inner" not in player
assert "narration: outer" not in player
assert 'caption: ""' in player
assert "parsed.segments" in player

print("result feedback and coach contract passed")
PY

# Xcode의 파일시스템 동기화 그룹은 새 LessonWeb 파일을 pbxproj에 개별로 적지
# 않는다. fresh build 경로를 주면 실제 .app에 세 파일이 함께 들어갔고 소스와
# byte parity인지 확인한다. 검증기 자체도 missing/corrupt 음성 대조에서 닫혀야 한다.
if [ -n "${MATTHS_BUILT_APP:-}" ]; then
  node - "$ROOT" "$MATTHS_BUILT_APP" <<'NODE'
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
const [root, app] = process.argv.slice(2);
const files = ["solution-text-contract.js", "solution-player.html", "solution-scene.html"];
const source = (name) => fs.readFileSync(path.join(root, "Matths/LessonWeb", name));
const bundled = (name) => fs.readFileSync(path.join(app, name));
const digest = (value) => crypto.createHash("sha256").update(value).digest("hex");

function verify(readBundle) {
  for (const name of files) {
    const actual = readBundle(name);
    assert.equal(digest(actual), digest(source(name)), `${name}: source/bundle SHA mismatch`);
  }
}

verify(bundled);
assert.throws(() => verify((name) => {
  if (name === "solution-text-contract.js") throw new Error("missing resource");
  return bundled(name);
}), /missing resource/);
assert.throws(() => verify((name) => {
  const value = bundled(name);
  return name === "solution-text-contract.js" ? Buffer.concat([value, Buffer.from("\ncorrupt")]) : value;
}), /SHA mismatch/);
console.log("solution text bundle parity passed (missing/corrupt negative controls closed)");
NODE
fi
