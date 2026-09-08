#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
MAP="$ROOT/Matths/CurriculumV2MapScreen.swift"
MODEL="$ROOT/Matths/CurriculumV2.swift"
CATALOG="$ROOT/Matths/curriculum-v2.json"

node - "$CATALOG" "$MAP" "$MODEL" <<'NODE'
"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");

const [catalogPath, mapPath, modelPath] = process.argv.slice(2);
const catalog = JSON.parse(fs.readFileSync(catalogPath, "utf8"));
const map = fs.readFileSync(mapPath, "utf8");
const model = fs.readFileSync(modelPath, "utf8");
const concepts = catalog.courses.flatMap((course) =>
  course.units.flatMap((unit) => unit.concepts),
);

// 정본 범위와 학습 시간은 UI 작업 중 절대 축소하거나 다시 정의하지 않는다.
assert.equal(catalog.courses.length, 13, "13과목 정본이 유지되어야 합니다.");
assert.equal(concepts.length, 220, "220개념 정본이 유지되어야 합니다.");
assert.ok(
  concepts.every((concept) => Number.isInteger(concept.lesson?.estimatedMinutes)
    && concept.lesson.estimatedMinutes > 0),
  "220개념 모두 편집된 예상 학습 시간을 가져야 합니다.",
);

// 기존 ProgressV2 규칙: 개념은 3상태뿐이고 학습 진입 잠금은 없다.
assert.match(model, /enum ConceptStatusV2[\s\S]*case notStarted, inProgress, completed/);
assert.doesNotMatch(model, /enum ConceptStatusV2[\s\S]*case[^\n]*locked/);
assert.match(model, /min\(90, Int\(\(topicPart \+ typePart\)\.rounded\(\)\)\)/);

for (const contract of [
  "geometry.size.width <= 360",
  "dynamicTypeSize.isAccessibilitySize",
  "accessibilityReduceMotion",
  ".scrollBounceBehavior(.basedOnSize, axes: .vertical)",
  "transaction.animation = nil",
  "현재 학습",
  "학습 완료",
  "학습 가능",
  "이용 확인 필요",
  "권장 선수 과목",
  "권장 선수 개념",
  "평가 잠김",
  "잠금 이유",
  "estimatedMinutes ?? 15",
  "assessmentGateProjection(for: course)",
]) {
  assert.ok(map.includes(contract), `커리큘럼 상태 projection 계약 누락: ${contract}`);
}
assert.match(map, /AssessCatalog\.course\(selectedCourse\.id\) != nil[\s\S]*CourseAssessmentSection\(courseID: selectedCourse\.id\)/,
  "존재하는 단계 평가만 선택한 과목 상세에서 제공해야 합니다.");
assert.ok(map.includes(".tutorialTarget(.courseConcepts, when: unit.id == course.units.first?.id)") && map.includes(".tutorialTarget(.courseAssessments)") && map.includes(".tutorialViewport()"),
  "과목 개념/단계평가 튜토리얼은 실제 화면 앵커와 viewport를 사용해야 합니다.");
const unitStart = map.indexOf("private func unitSection(");
const unitRows = map.indexOf("ForEach(Array(unit.concepts.enumerated())", unitStart);
assert.ok(unitStart >= 0 && unitRows > unitStart);
assert.ok(map.slice(unitStart, unitRows).includes(".tutorialTarget(.courseConcepts, when:"),
  "개념 튜토리얼은 거대한 목록 전체가 아닌 첫 실제 단원 헤더를 강조해야 합니다.");

assert.ok(
  (map.match(/\.lineLimit\(nil\)/g) || []).length >= 6,
  "긴 한국어 제목과 설명은 줄 수 제한 없이 표시해야 합니다.",
);

const rowStart = map.indexOf("private func conceptRow(");
const rowEnd = map.indexOf("private func conceptCopy(", rowStart);
assert.ok(rowStart >= 0 && rowEnd > rowStart, "개념 행 구현을 찾을 수 없습니다.");
const conceptRow = map.slice(rowStart, rowEnd);
assert.match(conceptRow, /store\.openConceptV2\(concept\.id\)/);
assert.match(conceptRow, /\.disabled\(!CurriculumV2\.canStudy\(concept\.id\)\)/, "서버 공개 정책이 개념 진입에도 적용되어야 합니다.");
assert.match(conceptRow, /minHeight:\s*72/, "개념 행 터치 목표가 44pt보다 커야 합니다.");

console.log("Curriculum map projection contract passed: 13 courses, 220 concepts, unlocked learning, adaptive states");
NODE
