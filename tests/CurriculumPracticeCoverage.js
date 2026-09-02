"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.resolve(__dirname, "..");
const curriculum = require(path.join(root, "Matths/curriculum-v2.json"));
const webgenSource = fs.readFileSync(
  path.join(root, "Matths/LessonWeb/webgen-bundle.js"),
  "utf8",
);
const fallbackSource = fs.readFileSync(
  path.join(root, "Matths/CurriculumConceptCheckGenerator.swift"),
  "utf8",
);
const appSource = fs.readFileSync(
  path.join(root, "Matths/MatthsApp.swift"),
  "utf8",
);
const assessmentSource = fs.readFileSync(
  path.join(root, "Matths/AssessmentV2.swift"),
  "utf8",
);
const rootViewSource = fs.readFileSync(
  path.join(root, "Matths/RootView.swift"),
  "utf8",
);
const mapSource = fs.readFileSync(
  path.join(root, "Matths/CurriculumV2MapScreen.swift"),
  "utf8",
);
const profileSource = fs.readFileSync(
  path.join(root, "Matths/ProfileScreen.swift"),
  "utf8",
);
const screensSource = fs.readFileSync(
  path.join(root, "Matths/Screens.swift"),
  "utf8",
);
const webGenSwiftSource = fs.readFileSync(
  path.join(root, "Matths/WebGen.swift"),
  "utf8",
);
const curriculumSwiftSource = fs.readFileSync(
  path.join(root, "Matths/CurriculumV2.swift"),
  "utf8",
);
const conceptScreenSource = fs.readFileSync(
  path.join(root, "Matths/ConceptScreenV2.swift"),
  "utf8",
);
const legacyProgressSource = fs.readFileSync(
  path.join(root, "Matths/CurriculumStore.swift"),
  "utf8",
);

const context = { console };
vm.createContext(context);
vm.runInContext(webgenSource, context);

assert.equal(typeof context.MatthsWebGen?.conceptGeneratorInfo, "function");

const fallbackTypeIds = [
  "curriculum-summary",
  "curriculum-key-takeaway",
  "curriculum-step-purpose",
  "curriculum-achievement-standard",
  "curriculum-step-sequence",
];

let total = 0;
let specialized = 0;
let native = 0;
let fallback = 0;

for (const course of curriculum.courses) {
  for (const unit of course.units) {
    for (const concept of unit.concepts) {
      total += 1;
      const info = context.MatthsWebGen.conceptGeneratorInfo(
        course.id,
        unit.id,
        concept.id,
      );

      if (info) {
        specialized += 1;
        continue;
      }
      if (concept.legacy?.generatorTypes?.length) {
        native += 1;
        continue;
      }

      fallback += 1;
      assert.ok(concept.lesson?.summary, `${concept.id}: 강의 요약 누락`);
      assert.ok(concept.lesson?.keyTakeaway, `${concept.id}: 핵심 정리 누락`);
      assert.ok(concept.lesson?.steps?.length, `${concept.id}: 학습 단계 누락`);
      assert.ok(concept.achievementStandard, `${concept.id}: 성취기준 누락`);
    }
  }
}

assert.equal(total, 220);
// 서버 정본과 재생성한 WebGen 번들이 공통수학Ⅰ·Ⅱ 36개념까지 계산형
// 생성기로 포함한다. 숫자가 줄면 번들이 과거판으로 되돌아간 것이다.
assert.equal(specialized, 93);
assert.equal(native, 0);
assert.equal(fallback, 127);
assert.equal(
  curriculum.courses.flatMap((course) => course.units)
    .flatMap((unit) => unit.concepts)
    .filter((concept) => concept.visualizationIdeas?.length > 0).length,
  220,
  "모든 개념에 네이티브 탐색 자료가 있어야 합니다.",
);
for (const typeId of fallbackTypeIds) {
  assert.match(fallbackSource, new RegExp(`"${typeId}"`));
}
assert.match(
  appSource,
  /startWebPractice[\s\S]*includeCurriculumChecks:\s*true/,
  "개념 연습은 강의 기반 확인 문제를 허용해야 합니다.",
);
assert.doesNotMatch(
  conceptScreenSource,
  /학습할 개념을 선택해 주세요/,
  "개념 탭은 빈 선택 안내가 아니라 실제 다음 학습을 보여줘야 합니다.",
);
for (const contract of [
  "다음 학습",
  "store.progressV2.continueConcept()",
  "concept.lesson?.estimatedMinutes ?? 15",
  "이번에 잡을 핵심",
  "13과목 학습 지도 보기",
]) {
  assert.ok(
    conceptScreenSource.includes(contract),
    `개념 시작 화면 계약 누락: ${contract}`,
  );
}
assert.doesNotMatch(
  assessmentSource,
  /includeCurriculumChecks:\s*true/,
  "개념 확인 문제를 평가시험의 계산 숙련도 문항으로 섞으면 안 됩니다.",
);
assert.match(
  assessmentSource,
  /generatedPerConcept[\s\S]*plan\.count \* 2[\s\S]*count: generatedPerConcept/,
  "얇은 문제은행 범위도 계산형 후보를 충분히 요청해 10·20·40문항을 채워야 합니다.",
);
assert.match(
  rootViewSource,
  /CurriculumV2MapScreen\(\)/,
  "커리큘럼 탭은 13과목 v2 지도를 열어야 합니다.",
);
assert.doesNotMatch(
  rootViewSource,
  /CurriculumMapScreen\(\)/,
  "학생 진입 경로가 구 5과목 지도에 남아 있으면 안 됩니다.",
);
assert.doesNotMatch(
  rootViewSource,
  /ConceptScreen\(\)/,
  "학생 개념 진입 경로가 구 5과목 화면으로 떨어지면 안 됩니다.",
);
assert.doesNotMatch(
  screensSource,
  /struct ConceptScreen:\s*View/,
  "사용하지 않는 구 개념 화면을 제품 소스에 함께 유지하면 안 됩니다.",
);
assert.match(screensSource, /openRelevantConceptV2/);
assert.match(screensSource, /selectedCourseV2ID = course\.courseId/);
assert.doesNotMatch(appSource, /selectedConceptID|examSourceConceptID/);
assert.doesNotMatch(legacyProgressSource, /struct ConceptData|enum Curriculum\s*\{/);
assert.match(
  rootViewSource,
  /case firstConcept\(course: CourseV2, concept: ConceptV2\)/,
  "홈의 첫 학습 CTA도 v2 커리큘럼을 사용해야 합니다.",
);
assert.match(
  rootViewSource,
  /store\.openConceptV2\(concept\.id\)/,
  "홈 CTA는 v2 개념 화면을 열어야 합니다.",
);
assert.match(mapSource, /CurriculumV2\.data\.courses/);
assert.match(mapSource, /geometry\.size\.width >= 760/);
assert.match(mapSource, /dynamicTypeSize\.isAccessibilitySize/);
assert.match(profileSource, /CurriculumV2\.data\.courses/);
assert.doesNotMatch(
  profileSource,
  /completedConceptIDs\.count/,
  "프로필 완료 개념 수가 구 67개념 진도를 읽으면 안 됩니다.",
);
assert.match(
  webGenSwiftSource,
  /keyPrefix == "web" \? typeId/,
  "전문 WebGen 유형은 웹과 같은 typeId로 진도를 적립해야 합니다.",
);
assert.match(
  curriculumSwiftSource,
  /canonicalTypeId\(/,
  "구 web- 진도는 저장·동기화 경계에서 정규화해야 합니다.",
);
assert.doesNotMatch(
  curriculumSwiftSource,
  /map\s*\{\s*"web-/,
  "신규 진도 마이그레이션이 구 web- 접두사를 다시 만들면 안 됩니다.",
);
assert.match(
  conceptScreenSource,
  /else\s*\{[\s\S]*GenericConceptExplorer\(concept:\s*concept\)/,
  "전문 시각 모듈이 없는 개념도 02·03 탐색 단계를 제공해야 합니다.",
);
assert.match(conceptScreenSource, /concept\.visualizationIdeas/);
assert.match(conceptScreenSource, /frame\(maxWidth:\s*\.infinity,\s*minHeight:\s*44\)/);
assert.doesNotMatch(conceptScreenSource, /시각 강의는 준비 중/);

console.log(
  `iPad curriculum practice coverage passed: ${total} concepts ` +
  `(${specialized} web, ${native} native, ${fallback} authored checks)`,
);
