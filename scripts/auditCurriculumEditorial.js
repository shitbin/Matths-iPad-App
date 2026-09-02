#!/usr/bin/env node

"use strict";

const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const curriculumPath = path.join(root, "Matths", "curriculum-v2.json");
const reportPath = path.join(root, "docs", "CURRICULUM_EDITORIAL_AUDIT.md");
const raw = fs.readFileSync(curriculumPath, "utf8");
const curriculum = JSON.parse(raw);
const errors = [];
const warnings = [];
const concepts = [];
const units = [];
const idOwners = new Map();

function text(value) {
  return typeof value === "string" ? value.trim() : "";
}

function addError(location, message) {
  errors.push({ location, message });
}

function registerID(id, owner) {
  const normalized = text(id);
  if (!normalized) {
    addError(owner, "ID가 비어 있습니다.");
    return;
  }
  if (idOwners.has(normalized)) {
    addError(owner, `ID가 ${idOwners.get(normalized)}와 중복됩니다: ${normalized}`);
    return;
  }
  idOwners.set(normalized, owner);
}

function validateOrdered(rows, location) {
  const orders = new Set();
  for (const row of rows) {
    if (!Number.isInteger(row.order) || row.order < 0) {
      addError(location, `${row.id || row.title || "항목"}의 order가 유효한 정수가 아닙니다.`);
    }
    if (orders.has(row.order)) {
      addError(location, `order ${row.order}가 중복됩니다.`);
    }
    orders.add(row.order);
  }
}

function assertRequired(value, location, label) {
  if (!text(value)) addError(location, `${label}이 비어 있습니다.`);
}

function findExactDuplicates(rows, valueForRow) {
  const buckets = new Map();
  for (const row of rows) {
    const value = text(valueForRow(row));
    if (!value) continue;
    if (!buckets.has(value)) buckets.set(value, []);
    buckets.get(value).push(row);
  }
  return [...buckets.entries()].filter(([, matches]) => matches.length > 1);
}

const categoryIDs = new Set((curriculum.categories || []).map((category) => category.id));
validateOrdered(curriculum.categories || [], "categories");
for (const category of curriculum.categories || []) {
  registerID(category.id, `category:${category.title || "제목 없음"}`);
  assertRequired(category.title, `category:${category.id}`, "제목");
}

validateOrdered(curriculum.courses || [], "courses");
for (const course of curriculum.courses || []) {
  const courseLocation = `course:${course.id || "ID 없음"}`;
  registerID(course.id, courseLocation);
  assertRequired(course.title, courseLocation, "과목명");
  if (!categoryIDs.has(course.category)) {
    addError(courseLocation, `존재하지 않는 category를 참조합니다: ${course.category}`);
  }
  validateOrdered(course.units || [], courseLocation);
  const unitIDs = new Set();
  for (const unit of course.units || []) {
    const unitLocation = `${course.id}/${unit.id || "ID 없음"}`;
    if (!text(unit.id)) addError(unitLocation, "ID가 비어 있습니다.");
    else if (unitIDs.has(unit.id)) addError(unitLocation, `같은 과목 안에서 단원 ID가 중복됩니다: ${unit.id}`);
    else unitIDs.add(unit.id);
    assertRequired(unit.title, unitLocation, "단원명");
    validateOrdered(unit.concepts || [], unitLocation);
    units.push({ course, unit });
    for (const concept of unit.concepts || []) {
      const location = `${course.id}/${unit.id}/${concept.id || "ID 없음"}`;
      registerID(concept.id, location);
      assertRequired(concept.title, location, "개념명");
      assertRequired(concept.standardCode, location, "성취기준 코드");
      assertRequired(concept.achievementStandard, location, "성취기준");
      if (!Array.isArray(concept.topics) || concept.topics.length === 0) {
        addError(location, "학습 주제가 없습니다.");
      }
      if (!Array.isArray(concept.scopeNotes) || concept.scopeNotes.length === 0) {
        warnings.push({
          title: "범위 메모 없음",
          locations: [location],
          reason: "성취기준과 학습 주제는 존재하며 별도 범위 제한이 없는 항목",
        });
      }
      if (!Array.isArray(concept.visualizationIdeas) || concept.visualizationIdeas.length === 0) {
        warnings.push({
          title: "시각화 아이디어 없음",
          locations: [location],
          reason: "강의 본문은 존재하며 시각 콘텐츠 편집 대기 항목",
        });
      }
      const duplicateTopics = findExactDuplicates(
        (concept.topics || []).map((topic) => ({ topic })),
        (row) => row.topic,
      );
      if (duplicateTopics.length > 0) addError(location, "같은 학습 주제가 중복됩니다.");

      const lesson = concept.lesson;
      if (!lesson) {
        addError(location, "강의 본문이 없습니다.");
      } else {
        if (!Number.isInteger(lesson.estimatedMinutes) || lesson.estimatedMinutes < 5 || lesson.estimatedMinutes > 30) {
          addError(location, `예상 시간이 5~30분 범위를 벗어납니다: ${lesson.estimatedMinutes}`);
        }
        assertRequired(lesson.summary, location, "강의 요약");
        assertRequired(lesson.keyTakeaway, location, "핵심 정리");
        if (!Array.isArray(lesson.steps) || lesson.steps.length < 3) {
          addError(location, "학습 단계가 3개 미만입니다.");
        } else {
          validateOrdered(lesson.steps, `${location}/steps`);
          for (const [index, step] of lesson.steps.entries()) {
            assertRequired(step.title, `${location}/step-${index + 1}`, "단계 제목");
            assertRequired(step.description, `${location}/step-${index + 1}`, "단계 설명");
          }
        }
      }

      const serialized = JSON.stringify(concept);
      if (/\b(?:TODO|TBD|LOREM IPSUM)\b|작성\s*중|준비\s*중/i.test(serialized)) {
        addError(location, "출시용 콘텐츠에 임시 문구가 남아 있습니다.");
      }
      if (/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/.test(serialized)) {
        addError(location, "제어 문자가 포함돼 있습니다.");
      }
      concepts.push({ course, unit, concept, location });
    }
  }
}

const courseIDs = new Set((curriculum.courses || []).map((course) => course.id));
const courseByID = new Map((curriculum.courses || []).map((course) => [course.id, course]));
for (const course of curriculum.courses || []) {
  for (const prerequisite of course.prerequisites || []) {
    if (!courseIDs.has(prerequisite)) {
      addError(`course:${course.id}`, `존재하지 않는 선수 과목입니다: ${prerequisite}`);
    }
    if (prerequisite === course.id) {
      addError(`course:${course.id}`, "자기 자신을 선수 과목으로 참조합니다.");
    }
  }
}

function visitCourse(courseID, visiting = new Set(), visited = new Set()) {
  if (visited.has(courseID)) return;
  if (visiting.has(courseID)) {
    addError(`course:${courseID}`, "선수 과목 관계에 순환이 있습니다.");
    return;
  }
  visiting.add(courseID);
  for (const prerequisite of courseByID.get(courseID)?.prerequisites || []) {
    if (courseByID.has(prerequisite)) visitCourse(prerequisite, visiting, visited);
  }
  visiting.delete(courseID);
  visited.add(courseID);
}
const visitedCourses = new Set();
for (const course of curriculum.courses || []) visitCourse(course.id, new Set(), visitedCourses);

const conceptByID = new Map(concepts.map((row) => [row.concept.id, row]));
for (const track of curriculum.learningTracks || []) {
  if (!courseIDs.has(track.courseId)) addError(`track:${track.id}`, `과목이 없습니다: ${track.courseId}`);
  for (const conceptID of track.conceptIds || []) {
    const row = conceptByID.get(conceptID);
    if (!row) addError(`track:${track.id}`, `개념이 없습니다: ${conceptID}`);
    else if (row.course.id !== track.courseId) {
      addError(`track:${track.id}`, `${conceptID}가 지정 과목 ${track.courseId}에 속하지 않습니다.`);
    }
  }
}

for (const [value, rows] of findExactDuplicates(concepts, (row) => row.concept.lesson?.summary)) {
  addError(rows[0].location, `강의 요약이 ${rows.length}개 개념에서 완전히 같습니다: ${value.slice(0, 40)}…`);
}
for (const [value, rows] of findExactDuplicates(concepts, (row) => row.concept.lesson?.keyTakeaway)) {
  addError(rows[0].location, `핵심 정리가 ${rows.length}개 개념에서 완전히 같습니다: ${value.slice(0, 40)}…`);
}
for (const [title, rows] of findExactDuplicates(concepts, (row) => row.concept.title)) {
  const courseSet = new Set(rows.map((row) => row.course.id));
  if (courseSet.size === 1) {
    addError(rows[0].location, `같은 과목 안에서 개념명이 중복됩니다: ${title}`);
  } else {
    warnings.push({
      title,
      locations: rows.map((row) => `${row.course.title} / ${row.unit.title}`),
      reason: "과목명이 함께 표시되는 교과 간 심화 반복",
    });
  }
}

if ((curriculum.courses || []).length !== 13) {
  addError("curriculum", `과목 수가 13이 아닙니다: ${(curriculum.courses || []).length}`);
}
if (concepts.length !== 220) addError("curriculum", `개념 수가 220이 아닙니다: ${concepts.length}`);

const courseRows = (curriculum.courses || []).map((course) => {
  const courseConcepts = concepts.filter((row) => row.course.id === course.id);
  const minutes = courseConcepts.reduce(
    (sum, row) => sum + Number(row.concept.lesson?.estimatedMinutes || 0),
    0,
  );
  return {
    title: course.title,
    unitCount: (course.units || []).length,
    conceptCount: courseConcepts.length,
    minutes,
    prerequisiteNames: (course.prerequisites || []).map((id) => courseByID.get(id)?.title || id),
  };
});

const digest = crypto.createHash("sha256").update(raw).digest("hex");
const reportLines = [
  "# 13과목·220개념 편집 품질 감사",
  "",
  `데이터 정본: \`Matths/curriculum-v2.json\` (SHA-256 \`${digest}\`)`,
  "",
  `판정: **${errors.length === 0 ? "통과" : "실패"}** · 오류 ${errors.length}건 · 맥락 확인 ${warnings.length}건`,
  "",
  "## 전체 집계",
  "",
  `- 과목 ${(curriculum.courses || []).length}개`,
  `- 단원 ${units.length}개`,
  `- 개념 ${concepts.length}개`,
  `- 강의 본문 ${concepts.filter((row) => row.concept.lesson).length}개`,
  `- 총 권장 학습 시간 ${courseRows.reduce((sum, row) => sum + row.minutes, 0)}분`,
  "- 검사 범위: ID·순서·필수 본문·성취기준·주제 중복·예상 시간·선수 과목 DAG·학습 트랙·임시 문구·본문 완전 중복",
  "",
  "## 과목별 집계",
  "",
  "| 과목 | 단원 | 개념 | 권장 시간 | 선수 과목 |",
  "|---|---:|---:|---:|---|",
  ...courseRows.map(
    (row) => `| ${row.title} | ${row.unitCount} | ${row.conceptCount} | ${row.minutes}분 | ${row.prerequisiteNames.join(" · ") || "없음"} |`,
  ),
  "",
  "## 맥락 확인 항목",
  "",
];

if (warnings.length === 0) {
  reportLines.push("없음");
} else {
  reportLines.push("자동 실패로 단정할 수 없는 선택 필드와 교과 간 반복 제목도 숨기지 않고 확인 대상으로 남긴다.", "");
  reportLines.push("| 개념명 | 위치 | 판정 근거 |", "|---|---|---|");
  for (const warning of warnings) {
    reportLines.push(`| ${warning.title} | ${warning.locations.join("<br>")} | ${warning.reason} |`);
  }
}

reportLines.push("", "## 오류", "");
if (errors.length === 0) {
  reportLines.push("없음");
} else {
  for (const error of errors) reportLines.push(`- \`${error.location}\`: ${error.message}`);
}
reportLines.push(
  "",
  "## 별도 검증 경계",
  "",
  "이 보고서는 데이터 편집 계약을 검사한다. 실제 수학적 참·거짓, 학생 난이도, 화면에서의 긴 제목 줄바꿈은 자동 통과로 간주하지 않는다. 연습 출제 경로는 `run-curriculum-practice-coverage.sh`, 실제 폭·접근성은 iPad 실기 캡처로 별도 검증한다.",
  "",
);

const report = `${reportLines.join("\n")}\n`;
if (process.argv.includes("--check")) {
  const current = fs.existsSync(reportPath) ? fs.readFileSync(reportPath, "utf8") : "";
  if (current !== report) {
    console.error("커리큘럼 편집 감사 보고서가 현재 데이터와 다릅니다. 스크립트를 다시 실행하세요.");
    process.exit(1);
  }
} else {
  fs.writeFileSync(reportPath, report, "utf8");
}

if (errors.length > 0) {
  for (const error of errors) console.error(`${error.location}: ${error.message}`);
  process.exit(1);
}
console.log(`Curriculum editorial audit passed: ${concepts.length} concepts, ${warnings.length} contextual title checks`);
