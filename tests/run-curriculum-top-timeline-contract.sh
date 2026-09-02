#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
MAP="$ROOT/Matths/CurriculumV2MapScreen.swift"
TIMELINE="$ROOT/Matths/CurriculumStoryTimeline.swift"
CATALOG="$ROOT/Matths/curriculum-v2.json"

node - "$CATALOG" "$MAP" "$TIMELINE" <<'NODE'
"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");

const [catalogPath, mapPath, timelinePath] = process.argv.slice(2);
const catalog = JSON.parse(fs.readFileSync(catalogPath, "utf8"));
const map = fs.readFileSync(mapPath, "utf8");
const timeline = fs.readFileSync(timelinePath, "utf8");
const concepts = catalog.courses.flatMap((course) =>
  course.units.flatMap((unit) => unit.concepts),
);

assert.equal(catalog.courses.length, 13, "13과목 정본을 유지해야 합니다.");
assert.equal(concepts.length, 220, "220개념 정본을 유지해야 합니다.");

assert.match(map, /store\.progressV2\.continueConcept\(\)/,
  "기존 이어학습 우선순위를 그대로 사용해야 합니다.");
assert.equal(
  (map.match(/CurriculumStoryCatalog\.resolve\(/g) || []).length,
  1,
  "상단 target concept 한 개만 story resolve해야 합니다.",
);
assert.match(map, /CurriculumStoryCompactPreview\(model: timelinePreview\)/);
assert.match(map, /horizontalSizeClass == \.regular[\s\S]*geometry\.size\.width >= 760/,
  "iPhone landscape에 iPad split sidebar를 띄우면 안 됩니다.");

const compactStart = timeline.indexOf("struct CurriculumStoryCompactPreview: View");
assert.ok(compactStart >= 0, "compact preview 구현을 찾을 수 없습니다.");
const compact = timeline.slice(compactStart);
for (const contract of [
  "case current",
  "case next",
  "case locked",
  "case empty",
  "case completed",
  "오늘 이어갈 개념",
  "storyAvailable",
  "openingQuestion",
  "accessibilityReduceMotion",
  "transaction.animation = nil",
  "minHeight: 48",
  "lineLimit(nil)",
]) {
  assert.ok(timeline.includes(contract), `상단 기억선 계약 누락: ${contract}`);
}
assert.doesNotMatch(compact, /scene\.narration/,
  "compact preview에서 5분 narration 장문을 SwiftUI Text로 만들면 안 됩니다.");
assert.doesNotMatch(compact, /ForEach\(Array\(scenes\.enumerated\(\)\)/,
  "상단에서 5장면을 다시 펼치면 현재 개념 CTA가 중복됩니다.");
assert.doesNotMatch(map, /continueCard\(course:/,
  "현재 개념 CTA는 상단 카드 하나만 유지해야 합니다.");

console.log("Curriculum top timeline contract passed: one current-learning CTA, universal AX states");
NODE
