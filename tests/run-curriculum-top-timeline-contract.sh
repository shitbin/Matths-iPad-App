#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
MAP="$ROOT/Matths/CurriculumV2MapScreen.swift"
TIMELINE="$ROOT/Matths/CurriculumStoryTimeline.swift"
CATALOG="$ROOT/Matths/curriculum-v2.json"

node - "$CATALOG" "$MAP" "$TIMELINE" "$ROOT/Matths/ConceptScreenV2.swift" "$ROOT/Matths/MatthsApp.swift" <<'NODE'
"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");

const [catalogPath, mapPath, timelinePath, conceptPath, storePath] = process.argv.slice(2);
const catalog = JSON.parse(fs.readFileSync(catalogPath, "utf8"));
const map = fs.readFileSync(mapPath, "utf8");
const timeline = fs.readFileSync(timelinePath, "utf8");
const conceptScreen = fs.readFileSync(conceptPath, "utf8");
const store = fs.readFileSync(storePath, "utf8");
const concepts = catalog.courses.flatMap((course) =>
  course.units.flatMap((unit) => unit.concepts),
);

assert.equal(catalog.courses.length, 13, "13과목 정본을 유지해야 합니다.");
assert.equal(concepts.length, 220, "220개념 정본을 유지해야 합니다.");

assert.doesNotMatch(map, /CurriculumStoryCompactPreview|topTimelinePreview|storyPreviewCard|store\.nextLearningConcept/,
  "과목 선택 화면은 학습 홈의 거대한 이어가기/모션 preview를 다시 렌더하면 안 됩니다.");
assert.match(map, /Text\("과목과 단원"\)/);
const scroll = map.slice(map.indexOf("private func courseScroll("), map.indexOf("private var pageHeader:"));
assert.ok(scroll.indexOf("compactCoursePicker") < scroll.indexOf("unitSection("), "과목 선택이 단원 목록보다 먼저 보여야 합니다.");
assert.ok(scroll.indexOf("unitSection(") < scroll.indexOf("learningTracksSection("), "보조 추천 경로가 단원 선택을 밀어내면 안 됩니다.");
assert.match(map, /DisclosureGroup\(isExpanded: \$showsLearningTracks\)/);
assert.match(map, /courseOverviewColumn/);
assert.match(map, /horizontalSizeClass == \.regular[\s\S]*geometry\.size\.width >= 760/,
  "iPhone landscape에 iPad split sidebar를 띄우면 안 됩니다.");
assert.match(map, /store\.openConceptV2\(concept\.id\)/, "개념 행의 실제 강의 진입은 유지해야 합니다.");
assert.match(store, /func openConceptV2\([\s\S]*selectedConceptV2ID = id[\s\S]*route = \.concept/);
assert.match(conceptScreen, /case \.explain:[\s\S]*CurriculumStoryTimeline\([\s\S]*CurriculumStoryCatalog\.resolve\(/,
  "모션 preview 제거는 실제 개념 강의 진입을 삭제하는 작업이 아닙니다.");
assert.match(timeline, /CurriculumMotionLessonView\(/, "실제 강의의 모션 기능을 유지해야 합니다.");
console.log("Curriculum entry contract passed: course-first map without duplicate hero; concept route, full lecture/motion and optional learning tracks retained");
NODE
