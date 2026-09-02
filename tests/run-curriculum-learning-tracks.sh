#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

node - "$ROOT/Matths/curriculum-v2.json" <<'NODE'
const fs = require("fs");
const data = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const courses = new Map(data.courses.map((course) => [course.id, course]));
const conceptCourse = new Map();
for (const course of data.courses) {
  for (const unit of course.units) {
    for (const concept of unit.concepts) conceptCourse.set(concept.id, course.id);
  }
}
if (!Array.isArray(data.learningTracks) || data.learningTracks.length < 6) {
  throw new Error("추천 학습 코스는 최소 6개여야 합니다.");
}
const ids = new Set();
for (const track of data.learningTracks) {
  if (ids.has(track.id)) throw new Error(`중복 코스 id: ${track.id}`);
  ids.add(track.id);
  if (!courses.has(track.courseId)) throw new Error(`없는 과목: ${track.courseId}`);
  if (!Array.isArray(track.conceptIds) || track.conceptIds.length < 3 || track.conceptIds.length > 5) {
    throw new Error(`${track.id}: 개념은 3~5개여야 합니다.`);
  }
  for (const conceptId of track.conceptIds) {
    if (conceptCourse.get(conceptId) !== track.courseId) {
      throw new Error(`${track.id}: ${conceptId}가 지정 과목에 없습니다.`);
    }
  }
}
console.log(`curriculum learning tracks: ${data.learningTracks.length} verified`);
NODE

grep -q 'learningTracksSection(course: selectedCourse)' "$ROOT/Matths/CurriculumV2MapScreen.swift"
grep -q 'Text("추천 학습 코스")' "$ROOT/Matths/CurriculumV2MapScreen.swift"
grep -q 'Text(track.summary)' "$ROOT/Matths/CurriculumV2MapScreen.swift"
grep -q 'accessibilityLabel("추천 학습 경로' "$ROOT/Matths/CurriculumV2MapScreen.swift"
if grep -q '코스 시작")' "$ROOT/Matths/CurriculumV2MapScreen.swift"; then
  echo "learning track must remain guidance, not duplicate the current-learning CTA" >&2
  exit 1
fi

echo "curriculum learning-track UI contract passed"
