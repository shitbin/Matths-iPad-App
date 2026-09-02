#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TIMELINE="$ROOT/Matths/CurriculumStoryTimeline.swift"
MOTION="$ROOT/Matths/CurriculumMotionLessonView.swift"
SCENARIO="$ROOT/Matths/CurriculumScenarioLessonView.swift"
STORY="$ROOT/Matths/CurriculumStory.swift"
STORY_DATA="$ROOT/Matths/curriculum-stories/common-math-1.json"
STORY_DATA_2="$ROOT/Matths/curriculum-stories/common-math-2.json"
STORY_DATA_3="$ROOT/Matths/curriculum-stories/algebra.json"
STORY_DATA_4="$ROOT/Matths/curriculum-stories/calculus-1.json"
STORY_DATA_5="$ROOT/Matths/curriculum-stories/probability-statistics.json"
STORY_DATA_6="$ROOT/Matths/curriculum-stories/calculus-2.json"
GEOMETRY_DATA="$ROOT/Matths/curriculum-stories/geometry.json"
PRACTICAL_DATA="$ROOT/Matths/curriculum-stories/practical-statistics.json"
ECONOMICS_DATA="$ROOT/Matths/curriculum-stories/economics-math.json"
AI_DATA="$ROOT/Matths/curriculum-stories/ai-math.json"
CULTURE_DATA="$ROOT/Matths/curriculum-stories/math-and-culture.json"
RESEARCH_DATA="$ROOT/Matths/curriculum-stories/math-research-project.json"
VOCATIONAL_DATA="$ROOT/Matths/curriculum-stories/vocational-math.json"
CONCEPT="$ROOT/Matths/ConceptScreenV2.swift"
COACH="$ROOT/Matths/CoachEngine.swift"
APP="$ROOT/Matths/MatthsApp.swift"
SCREENS="$ROOT/Matths/Screens.swift"

grep -Fq 'concept: concept' "$CONCEPT"
grep -Fq 'private enum ConceptLearningStage' "$CONCEPT"
grep -Fq 'case explain, explore, practice' "$CONCEPT"
grep -Fq 'concept-learning-stage-navigation' "$CONCEPT"
# WHY 바뀌었나: 감독이 실기기에서 "개념학습에서 코드애니메이션이 끝나면 탐색 탭으로
# 넘어가야하는데 연습문제 풀기로 가는 버그" 라고 지적했다. 예전 코드는 강의가 끝나면
# 곧장 .practice 로 보냈고 이 검사는 그 버그를 계약으로 굳히고 있었다.
# 지금은 finishLesson() 이 .explore 로 보낸다(중복 호출 방어 포함). 그 두 가지를 검사한다.
grep -Fq 'onLessonCompleted: finishLesson' "$CONCEPT"
grep -Fq 'activeStage = .explore' "$CONCEPT"
grep -Fq 'guard activeStage == .explain else { return }' "$CONCEPT"
grep -Fq 'CurriculumMotionLessonView(' "$TIMELINE"
grep -Fq 'onLessonCompleted: onLessonCompleted' "$TIMELINE"
grep -Fq 'visualizationIdeas: concept.visualizationIdeas' "$TIMELINE"
if grep -Fq 'DisclosureGroup(' "$TIMELINE"; then
  echo "full curriculum story timeline must not expose five textbook accordions" >&2
  exit 1
fi

# 설명 단계 시각 영역 계약(추가) — 위 세 리터럴은 폴백 분기가 그대로 보존하므로
# 기존 단언은 하나도 고치지 않았다. 아래는 새로 생긴 두 갈래를 고정한다.
#  · 시나리오 분기가 사라지면 러닝타임의 90%가 다시 정지화면 + TTS 로 돌아간다.
#  · 폴백 분기가 사라지면 모션 OFF 사용자가 완결된 정적 그림 대신
#    "첫 프레임 + 재생 버튼" 을 받는다(scenario-player.js 의 MATTHS_MOTION 분기).
grep -Fq 'CurriculumScenarioLessonView(' "$TIMELINE"
grep -Fq 'WebMotion.allowed(userEnabled: userMotionEnabled, reduceMotion: reduceMotion)' "$TIMELINE"
grep -Fq 'LessonWebView.hasLesson(conceptID: conceptID)' "$SCENARIO"
grep -Fq '.sp-caption { display: none !important; }' "$SCENARIO"
grep -Fq 'motion.check' "$SCENARIO"
grep -Fq 'onLessonCompleted()' "$SCENARIO"

grep -Fq '지금 볼 곳' "$MOTION"
grep -Fq 'pencil.tip' "$MOTION"
grep -Fq 'Color(red: 1, green: 0.89, blue: 0.48)' "$MOTION"
grep -Fq '순한맛으로 다시' "$MOTION"
grep -Fq '매운맛 핵심' "$MOTION"
if grep -Fq 'Button("이해했어요")' "$MOTION"; then
  echo "motion lesson must ask the check directly without a meaningless confirmation gate" >&2
  exit 1
fi
if grep -Fq 'Button(sceneIndex < scenes.count - 1 ? "다음 장면"' "$MOTION"; then
  echo "correct answers must advance automatically instead of adding a next-step tap" >&2
  exit 1
fi
grep -Fq 'scheduleAdvance()' "$MOTION"
grep -Fq '다음 장면으로 이어집니다.' "$MOTION"
grep -Fq 'onLessonCompleted()' "$MOTION"
grep -Fq 'misses >= 2' "$MOTION"
grep -Fq '지금 장면에서 가장 먼저 확인할 것은 무엇인가요?' "$MOTION"
grep -Fq 'CurriculumMotionCanvas' "$MOTION"
grep -Fq 'scene.motion' "$MOTION"
grep -Fq 'current.beats' "$MOTION"
grep -Fq 'Task.sleep(for: .milliseconds(currentBeat.durationMs))' "$MOTION"
grep -Fq 'guided-connect' "$MOTION"
grep -Fq 'guided-verify' "$MOTION"
grep -Fq '초점·준선' "$MOTION"
grep -Fq 'stripParticle' "$MOTION"
grep -Fq 'quoteWithParticle' "$MOTION"
if grep -Fq "‘\(focus)’과 연결된" "$MOTION"; then
  echo "guided motion must select Korean particles from the actual focus token" >&2
  exit 1
fi
grep -Fq 'guard !reduceMotion, beatIndex < current.beats.count - 1' "$MOTION"
if grep -Fq 'guard current.authored, !reduceMotion' "$MOTION"; then
  echo "generic curriculum scenes must animate three guided beats" >&2
  exit 1
fi
grep -Fq 'drawBeatCopy' "$MOTION"
grep -Fq 'sceneID: current.source.id' "$MOTION"
grep -Fq 'drawComplexPlane' "$MOTION"
grep -Fq 'drawIntersectionPlot' "$MOTION"
grep -Fq 'drawNumberLine' "$MOTION"
grep -Fq 'drawCountingTree' "$MOTION"
grep -Fq 'drawPermutationSlots' "$MOTION"
grep -Fq 'drawCombinationGroups' "$MOTION"
grep -Fq 'drawMatrixGrid' "$MOTION"
grep -Fq 'drawCoordinateGeometryScene' "$MOTION"
grep -Fq 'coordinateGeometrySceneIDs' "$MOTION"
grep -Fq 'drawSetsPropositionsScene' "$MOTION"
grep -Fq 'setsPropositionsSceneIDs' "$MOTION"
grep -Fq 'drawFunctionsGraphsScene' "$MOTION"
grep -Fq 'functionsGraphsSceneIDs' "$MOTION"
grep -Fq 'drawAlgebraPowerExponentScene' "$MOTION"
grep -Fq 'algebraPowerExponentSceneIDs' "$MOTION"
grep -Fq 'drawAlgebraLogFunctionScene' "$MOTION"
grep -Fq 'algebraLogFunctionSceneIDs' "$MOTION"
grep -Fq 'drawAlgebraTrigonometryScene' "$MOTION"
grep -Fq 'algebraTrigonometrySceneIDs' "$MOTION"
grep -Fq 'drawAlgebraSequenceScene' "$MOTION"
grep -Fq 'algebraSequenceSceneIDs' "$MOTION"
grep -Fq 'drawCalculusOneScene' "$MOTION"
grep -Fq 'calculusOneSceneIDs' "$MOTION"
grep -Fq 'drawCalculusLimitApproach' "$MOTION"
grep -Fq 'drawCalculusDerivativeDefinition' "$MOTION"
grep -Fq 'drawCalculusDerivativeGraph' "$MOTION"
grep -Fq 'drawCalculusAntiderivative' "$MOTION"
grep -Fq 'drawCalculusAccumulation' "$MOTION"
grep -Fq 'drawCalculusAreaMotion' "$MOTION"
grep -Fq 'drawProbabilityStatisticsScene' "$MOTION"
grep -Fq 'probabilityStatisticsSceneIDs' "$MOTION"
grep -Fq 'drawProbabilityCounting' "$MOTION"
grep -Fq 'drawProbabilitySets' "$MOTION"
grep -Fq 'drawProbabilityConditional' "$MOTION"
grep -Fq 'drawProbabilityDistribution' "$MOTION"
grep -Fq 'drawProbabilityNormal' "$MOTION"
grep -Fq 'drawProbabilityInference' "$MOTION"
grep -Fq 'drawGeometryCourseConic' "$MOTION"
grep -Fq 'drawGeometryCourseSpace' "$MOTION"
grep -Fq 'drawGeometryCourseVector' "$MOTION"
grep -Fq 'geometryCourseSceneIDs.contains(sceneID)' "$MOTION"
grep -Fq 'drawPracticalStatisticsScene' "$MOTION"
grep -Fq 'drawPracticalInquiry' "$MOTION"
grep -Fq 'drawPracticalDataDesign' "$MOTION"
grep -Fq 'drawPracticalDescriptive' "$MOTION"
grep -Fq 'drawPracticalDistribution' "$MOTION"
grep -Fq 'drawPracticalInterval' "$MOTION"
grep -Fq 'drawPracticalHypothesis' "$MOTION"
grep -Fq 'practicalStatisticsSceneIDs.contains(sceneID)' "$MOTION"
grep -Fq 'drawEconomicsMathScene' "$MOTION"
grep -Fq 'drawEconomicsFinance' "$MOTION"
grep -Fq 'drawEconomicsMarket' "$MOTION"
grep -Fq 'drawEconomicsLinearMatrix' "$MOTION"
grep -Fq 'drawEconomicsMarginal' "$MOTION"
grep -Fq 'economicsMathSceneIDs.contains(sceneID)' "$MOTION"
grep -Fq 'drawAiMathScene' "$MOTION"
grep -Fq 'drawAiLearning' "$MOTION"
grep -Fq 'drawAiText' "$MOTION"
grep -Fq 'drawAiImage' "$MOTION"
grep -Fq 'drawAiPrediction' "$MOTION"
grep -Fq 'drawAiInquiry' "$MOTION"
grep -Fq 'aiMathSceneIDs.contains(sceneID)' "$MOTION"
grep -Fq 'drawMathCultureScene' "$MOTION"
grep -Fq 'drawCultureArt' "$MOTION"
grep -Fq 'drawCultureLeisure' "$MOTION"
grep -Fq 'drawCultureSociety' "$MOTION"
grep -Fq 'drawCultureEnvironment' "$MOTION"
grep -Fq 'mathCultureSceneIDs.contains(sceneID)' "$MOTION"
grep -Fq 'drawMathResearchScene' "$MOTION"
grep -Fq 'drawResearchFoundation' "$MOTION"
grep -Fq 'drawResearchMethod' "$MOTION"
grep -Fq 'drawResearchExecution' "$MOTION"
grep -Fq 'mathResearchSceneIDs.contains(sceneID)' "$MOTION"
grep -Fq 'drawVocationalMathScene' "$MOTION"
grep -Fq 'drawVocationalNumber' "$MOTION"
grep -Fq 'drawVocationalRelation' "$MOTION"
grep -Fq 'drawVocationalGeometry' "$MOTION"
grep -Fq 'drawVocationalData' "$MOTION"
grep -Fq 'vocationalMathSceneIDs.contains(sceneID)' "$MOTION"
grep -Fq 'sceneID.hasPrefix("complex-")' "$MOTION"
grep -Fq 'sceneID.hasPrefix("simlinear-")' "$MOTION"
grep -Fq 'sceneID.hasPrefix("counting-")' "$MOTION"
grep -Fq 'sceneID.hasPrefix("permutation-")' "$MOTION"
grep -Fq 'sceneID.hasPrefix("combination-")' "$MOTION"
grep -Fq 'sceneID.hasPrefix("matrix-")' "$MOTION"
grep -Fq 'current.checkPrompt' "$MOTION"
grep -Fq 'case equation, blocks, graph, geometry, plot' "$MOTION"
grep -Fq '@Environment(\.accessibilityReduceMotion)' "$MOTION"
grep -Fq 'frame(maxWidth: .infinity, minHeight: 48)' "$MOTION"

grep -Fq 'struct CurriculumMotionDirective: Codable, Equatable' "$STORY"
grep -Fq 'issues.append(contentsOf: validateMotion(scene.motion))' "$STORY"
grep -Fq 'motion: scene.motion' "$STORY"
node - "$STORY_DATA" "$STORY_DATA_2" "$STORY_DATA_3" "$STORY_DATA_4" "$STORY_DATA_5" "$STORY_DATA_6" "$GEOMETRY_DATA" "$PRACTICAL_DATA" "$ECONOMICS_DATA" "$AI_DATA" "$CULTURE_DATA" "$RESEARCH_DATA" "$VOCATIONAL_DATA" "$MOTION" <<'NODE'
const assert = require("node:assert/strict");
const fs = require("node:fs");
const allStories = [
  ...require(process.argv[2]).stories,
  ...require(process.argv[3]).stories,
  ...require(process.argv[4]).stories,
  ...require(process.argv[5]).stories,
  ...require(process.argv[6]).stories,
  ...require(process.argv[7]).stories,
];
const geometryStories = require(process.argv[8]).stories;
const practicalStories = require(process.argv[9]).stories;
const economicsStories = require(process.argv[10]).stories;
const aiStories = require(process.argv[11]).stories;
const cultureStories = require(process.argv[12]).stories;
const researchStories = require(process.argv[13]).stories;
const vocationalStories = require(process.argv[14]).stories;
const motionSource = fs.readFileSync(process.argv[15], "utf8");
const geometrySceneIDs = geometryStories.flatMap((story) => story.scenes.map((scene) => scene.id));
assert.equal(geometryStories.length, 14);
assert.equal(geometrySceneIDs.length, 70);
for (const sceneID of geometrySceneIDs) {
  assert.ok(motionSource.includes(`"${sceneID}"`), `missing native geometry scene route: ${sceneID}`);
}
const practicalSceneIDs = practicalStories.flatMap((story) => story.scenes.map((scene) => scene.id));
assert.equal(practicalStories.length, 13);
assert.equal(practicalSceneIDs.length, 65);
for (const sceneID of practicalSceneIDs) {
  assert.ok(motionSource.includes(`"${sceneID}"`), `missing native practical statistics scene route: ${sceneID}`);
}
const economicsSceneIDs = economicsStories.flatMap((story) => story.scenes.map((scene) => scene.id));
assert.equal(economicsStories.length, 18);
assert.equal(economicsSceneIDs.length, 90);
for (const sceneID of economicsSceneIDs) {
  assert.ok(motionSource.includes(`"${sceneID}"`), `missing native economics math scene route: ${sceneID}`);
}
const aiSceneIDs = aiStories.flatMap((story) => story.scenes.map((scene) => scene.id));
assert.equal(aiStories.length, 15);
assert.equal(aiSceneIDs.length, 75);
for (const sceneID of aiSceneIDs) {
  assert.ok(motionSource.includes(`"${sceneID}"`), `missing native AI math scene route: ${sceneID}`);
}
const cultureSceneIDs = cultureStories.flatMap((story) => story.scenes.map((scene) => scene.id));
assert.equal(cultureStories.length, 16);
assert.equal(cultureSceneIDs.length, 80);
for (const sceneID of cultureSceneIDs) {
  assert.ok(motionSource.includes(`"${sceneID}"`), `missing native math-and-culture scene route: ${sceneID}`);
}
const researchSceneIDs = researchStories.flatMap((story) => story.scenes.map((scene) => scene.id));
assert.equal(researchStories.length, 10);
assert.equal(researchSceneIDs.length, 50);
for (const sceneID of researchSceneIDs) {
  assert.ok(motionSource.includes(`"${sceneID}"`), `missing native math-research scene route: ${sceneID}`);
}
const vocationalSceneIDs = vocationalStories.flatMap((story) => story.scenes.map((scene) => scene.id));
assert.equal(vocationalStories.length, 18);
assert.equal(vocationalSceneIDs.length, 90);
for (const sceneID of vocationalSceneIDs) {
  assert.ok(motionSource.includes(`"${sceneID}"`), `missing native vocational-math scene route: ${sceneID}`);
}
const algebraConcepts = new Set([
  "algebra-01-01", "algebra-01-02", "algebra-01-03", "algebra-01-04",
  "algebra-01-05", "algebra-01-06", "algebra-01-07", "algebra-01-08",
  "algebra-02-01", "algebra-02-02", "algebra-02-03",
  "algebra-03-01", "algebra-03-02", "algebra-03-03", "algebra-03-04",
  "algebra-03-05", "algebra-03-06", "algebra-03-07",
]);
const stories = allStories.filter((story) => [
  "polynomials",
  "equations-and-inequalities",
  "counting",
  "matrices",
  "coordinate-geometry",
  "sets-and-propositions",
  "functions-and-graphs",
].includes(story.unitId) || algebraConcepts.has(story.conceptId) || ["calculus-1", "calculus-2", "probability-statistics"].includes(story.courseId));
assert.deepEqual(stories.slice(0, 3).map((story) => story.conceptId), [
  "polynomial-arithmetic",
  "identity-remainder-theorem",
  "polynomial-factorization",
]);
assert.equal(stories.filter((story) => story.unitId === "polynomials").length, 3);
assert.equal(stories.filter((story) => story.unitId === "equations-and-inequalities").length, 11);
assert.equal(stories.filter((story) => story.courseId === "common-math-1" && story.unitId === "counting").length, 3);
assert.equal(stories.filter((story) => story.unitId === "matrices").length, 2);
assert.equal(stories.filter((story) => story.unitId === "coordinate-geometry").length, 7);
assert.equal(stories.filter((story) => story.unitId === "sets-and-propositions").length, 8);
assert.equal(stories.filter((story) => story.unitId === "functions-and-graphs").length, 5);
assert.equal(stories.filter((story) => algebraConcepts.has(story.conceptId)).length, 18);
assert.equal(stories.filter((story) => story.courseId === "calculus-1").length, 20);
assert.equal(stories.filter((story) => story.courseId === "calculus-2").length, 23);
assert.equal(stories.filter((story) => story.courseId === "probability-statistics").length, 16);
assert.equal(stories.length, 116);
assert.equal(stories.flatMap((story) => story.scenes).length, 580);
const authoredStories = [...stories, ...geometryStories, ...practicalStories, ...economicsStories, ...aiStories, ...cultureStories, ...researchStories, ...vocationalStories];
assert.equal(authoredStories.length, 220);
assert.equal(authoredStories.flatMap((story) => story.scenes).length, 1100);
for (const story of authoredStories) {
  for (const scene of story.scenes) {
    assert.equal(scene.motion.version, 1);
    assert.ok(scene.motion.beats.length >= 3);
    assert.equal(scene.motion.check.choices.length, 3);
    assert.ok(scene.motion.check.answerIndex >= 0 && scene.motion.check.answerIndex < 3);
  }
}
NODE

grep -Fq 'struct CoachGuidance: Equatable' "$COACH"
# 단계명은 화면 칩 한 곳만 소유하며 엔진 본문에는 중복 접두사가 없다.
grep -Fq '"관찰", stripOwnedPrefix' "$SCREENS"
grep -Fq '"점검", stripOwnedPrefix' "$SCREENS"
grep -Fq '"다음", stripOwnedPrefix' "$SCREENS"
! grep -Fq 'observation: "관찰:' "$COACH"
! grep -Fq 'reason: "점검 순서:' "$COACH"
! grep -Fq 'nextAction: "다음 행동:' "$COACH"
grep -Fq 'diagnosticPlan' "$COACH"
grep -Fq 'submissionShape' "$COACH"
grep -Fq '분모를 전체가 아니라 조건이 주어진 표본공간' "$COACH"
grep -Fq '표준오차에서 표본크기의 제곱근' "$COACH"
grep -Fq '0/0 꼴이라 변형이 필요한지' "$COACH"
grep -Fq '위 함수 − 아래 함수' "$COACH"
grep -Fq '학생의 실제 사고 원인을 단정하지 않는다' "$COACH"
grep -Fq 'coachGuidance = coach.guidance' "$APP"
grep -Fq 'CoachMessageBubble' "$SCREENS"
if grep -Eq 'CoachBubble\(line:' "$SCREENS"; then
  echo "result screen must not center a random coach line" >&2
  exit 1
fi

# Arena 규칙·경제 보호.
#
# 2026-08-17: "파일이 바뀌었는가" 에서 "규칙이 바뀌었는가" 로 바꾼다.
# 종전 검사는 diff 가 있기만 하면 실패시켰다. 그래서 특수문자 정리(→ 를 "에서 …로",
# · 를 , 로) 처럼 **표시 문자열만 고친 변경**도 규칙 침범으로 잡혔고, 그 상태가
# 오래 남아 다른 진짜 회귀를 가려 왔다.
#
# 지켜야 할 것은 Arena 의 숫자와 정책이다. 그래서 문자열 리터럴을 걷어낸 뒤
# 남는 코드에서 숫자와 정책 식별자를 뽑아 커밋본과 대조한다.
# 표시 문구는 마음껏 고치되, 상수나 정책 이름이 하나라도 달라지면 실패한다.
for arena_file in \
  "$ROOT/Matths/ArenaMatchView.swift" \
  "$ROOT/Matths/ArenaShopScreen.swift"; do
  [[ -f "$arena_file" ]] || continue
  git -C "$ROOT" diff --quiet -- "$arena_file" && continue
  rel="${arena_file#$ROOT/}"
  if ! git -C "$ROOT" show "HEAD:$rel" > /tmp/arena_head.swift 2>/dev/null; then
    echo "Arena 파일의 커밋본을 읽지 못했습니다: $rel" >&2
    exit 1
  fi
  if ! python3 - "$arena_file" /tmp/arena_head.swift <<'PYEOF'
import re, sys

# 문자열 리터럴을 통째로 지운다 — 그 안의 조사·구분점·화살표는 표시 문구일 뿐이다.
# 다만 문자열 안의 보간식 \(...) 은 코드이므로 남긴다.
def skeleton(path):
    src = open(path, encoding="utf-8").read()
    src = re.sub(r'//[^\n]*', '', src)                      # 주석 제거
    # 같은 서버 값을 좁은 화면에 다시 배치하는 순수 표시 helper는 경제 규칙이
    # 아니다. 함수 이름부터 닫는 중괄호까지 제거하되, 구매/차감 함수는 이 목록에
    # 넣지 않는다. 새 helper를 허용하려면 이 테스트와 전용 레이아웃 계약을 함께
    # 바꿔야 하므로 경제 코드를 UI라는 이름으로 우회할 수 없다.
    def strip_view_helper(source, name):
        match = re.search(r'\bprivate\s+func\s+' + re.escape(name) + r'\s*\(', source)
        if not match:
            return source
        opening = source.find('{', match.start())
        if opening < 0:
            return source
        depth = 0
        for index in range(opening, len(source)):
            if source[index] == '{':
                depth += 1
            elif source[index] == '}':
                depth -= 1
                if depth == 0:
                    return source[:match.start()] + source[index + 1:]
        return source
    src = strip_view_helper(src, 'compactWallet')
    kept = []
    def strip_literal(m):
        inner = m.group(1)
        kept.extend(re.findall(r'\\\(([^()]*)\)', inner))  # 보간식만 보존
        return '""'
    src = re.sub(r'"((?:[^"\\]|\\.)*)"', strip_literal, src)
    # 터치 영역·간격·불투명도·한 줄 축소 같은 SwiftUI 표현 수치는 경제 규칙이
    # 아니다. iPhone 가로 레이아웃을 고칠 때 44pt 프레임만 추가해도 실패하면
    # 이 보호막 때문에 접근성 회귀를 고칠 수 없다. 표시 전용 호출의 줄만 숫자
    # 비교에서 제외하고, 정책 식별자는 아래에서 이전처럼 파일 전체를 비교한다.
    presentation = re.compile(
        r'\b(?:HStack|VStack|ZStack|LazyVGrid|LazyHGrid)\s*\(|'
        r'\.(?:frame|padding|opacity|lineLimit|minimumScaleFactor|font|'
        r'cornerRadius|offset|animation)\s*\('
    )
    numeric_src = "\n".join(line for line in src.splitlines() if not presentation.search(line))
    body = numeric_src + "\n" + "\n".join(kept)
    nums = re.findall(r'(?<![\w.])\d+(?:\.\d+)?', body)
    policy_body = src + "\n" + "\n".join(kept)
    policy = re.findall(r'\b(?:payback|refund|stake|tier|Tier|ranked|Ranked|'
                        r'available|Available|purchase|Purchase|settle|Settle)\w*', policy_body)
    return sorted(nums), sorted(policy)

now, head = skeleton(sys.argv[1]), skeleton(sys.argv[2])
if now == head:
    sys.exit(0)
if now[0] != head[0]:
    print("숫자 상수가 바뀌었습니다", file=sys.stderr)
if now[1] != head[1]:
    print("정책 식별자가 바뀌었습니다", file=sys.stderr)
sys.exit(1)
PYEOF
  then
    echo "Arena 규칙이 바뀌었습니다: $arena_file" >&2
    echo "  Arena 규칙·경제·정산은 변경 대상이 아닙니다. 표시 문구만 고쳐야 합니다." >&2
    exit 1
  fi
done

echo "Curriculum motion lesson and diagnostic coach contract passed."
