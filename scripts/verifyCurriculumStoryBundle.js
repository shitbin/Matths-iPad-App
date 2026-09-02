#!/usr/bin/env node

"use strict";

const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");

function fail(message) {
  throw new Error(message);
}

function readJson(file) {
  return JSON.parse(fs.readFileSync(file, "utf8"));
}

function digest(raw) {
  return crypto.createHash("sha256").update(raw).digest("hex");
}

function normalized(value) {
  return String(value || "").replace(/\s+/gu, " ").trim();
}

function containsStudioTag(value) {
  return /\[[^\]\n]{1,40}\]/u.test(String(value || ""));
}

function bundledFile(app, relativePath) {
  const candidates = [
    path.join(app, relativePath),
    path.join(app, path.basename(relativePath)),
  ];
  return candidates.find((file) => fs.existsSync(file));
}

function verifyCurriculumStoryBundle(app) {
  if (!app || !fs.existsSync(app) || !fs.statSync(app).isDirectory()) {
    fail("검증할 .app 번들이 없습니다.");
  }

  const policyPath = bundledFile(app, "curriculum-story-policy.json");
  const indexPath = bundledFile(app, "curriculum-stories-index.json");
  const authorityPath = bundledFile(app, "curriculum-v2.json");
  for (const [name, file] of [
    ["curriculum-story-policy.json", policyPath],
    ["curriculum-stories-index.json", indexPath],
    ["curriculum-v2.json", authorityPath],
  ]) {
    if (!file) fail(`필수 리소스가 없습니다: ${name}`);
  }

  const policy = readJson(policyPath);
  const index = readJson(indexPath);
  const authorityDocument = readJson(authorityPath);
  if (policy.schemaVersion !== "MATTHS_CURRICULUM_STORY_V1") {
    fail("story policy schema가 다릅니다.");
  }
  if (index.schemaVersion !== policy.schemaVersion || index.curriculumId !== policy.curriculumId) {
    fail("story index와 policy 버전이 다릅니다.");
  }
  if (authorityDocument.curriculumId !== policy.curriculumId) {
    fail("curriculum-v2와 story policy의 curriculumId가 다릅니다.");
  }
  if (JSON.stringify(index.providerPolicy) !== JSON.stringify(policy.providerPolicy)) {
    fail("story provider policy가 index와 다릅니다.");
  }
  if (!Array.isArray(index.shards) || index.shards.length !== 13) {
    fail("13과목 shard가 아닙니다.");
  }
  if (JSON.stringify(index.shards.map((item) => item.courseId))
      !== JSON.stringify(policy.courseIds)) {
    fail("13과목 shard 순서가 policy와 다릅니다.");
  }

  const authority = new Map();
  for (const course of authorityDocument.courses || []) {
    for (const unit of course.units || []) {
      for (const concept of unit.concepts || []) {
        authority.set(`${course.id}/${unit.id}/${concept.id}`, concept);
      }
    }
  }
  if (authority.size !== 220) fail(`curriculum-v2 정본이 ${authority.size}/220개입니다.`);

  const seenKeys = new Set();
  const seenConceptIDs = new Set();
  let published = 0;
  for (const shardIndex of index.shards) {
    if (!/^curriculum-stories\/[a-z0-9-]+\.json$/u.test(shardIndex.file)) {
      fail(`허용되지 않은 shard 경로입니다: ${shardIndex.file}`);
    }
    const shardPath = bundledFile(app, shardIndex.file);
    if (!shardPath) fail(`bundle에 shard가 없습니다: ${shardIndex.file}`);
    const raw = fs.readFileSync(shardPath);
    if (digest(raw) !== shardIndex.sha256) {
      fail(`${shardIndex.courseId} shard SHA-256 불일치`);
    }
    const shard = JSON.parse(raw.toString("utf8"));
    if (shard.schemaVersion !== policy.schemaVersion
        || shard.curriculumId !== policy.curriculumId
        || shard.courseId !== shardIndex.courseId
        || !Array.isArray(shard.stories)) {
      fail(`${shardIndex.courseId} shard 메타데이터 불일치`);
    }
    if (shard.stories.length !== shardIndex.storyCount
        || JSON.stringify(shard.stories.map((story) => story.conceptId))
          !== JSON.stringify(shardIndex.conceptIds)) {
      fail(`${shardIndex.courseId} storyCount/conceptIds 불일치`);
    }
    for (const story of shard.stories) {
      const key = `${story.courseId}/${story.unitId}/${story.conceptId}`;
      if (story.status !== "published") fail(`${key}가 published가 아닙니다.`);
      const studentProjectionText = [
        story.title,
        story.openingQuestion,
        ...(story.scenes || []).flatMap((scene) => [
          scene.title,
          scene.subtitle,
          scene.narration,
        ]),
      ];
      if (studentProjectionText.some(containsStudioTag)) {
        fail(`${key} 학생 projection에 studio 태그가 있습니다.`);
      }
      if (seenKeys.has(key) || seenConceptIDs.has(story.conceptId)) {
        fail(`${key}가 중복입니다.`);
      }
      const concept = authority.get(key);
      if (!concept) fail(`${key}가 curriculum-v2 정본에 없습니다.`);
      if (normalized(story.source?.standardCode) !== normalized(concept.standardCode)) {
        fail(`${key} 성취기준 코드가 정본과 다릅니다.`);
      }
      seenKeys.add(key);
      seenConceptIDs.add(story.conceptId);
      published += 1;
    }
  }

  if (published !== 220 || seenKeys.size !== 220) {
    fail(`published story가 ${published}/220개입니다.`);
  }
  const missing = [...authority.keys()].filter((key) => !seenKeys.has(key));
  if (missing.length) fail(`정본 story ${missing.length}개가 누락됐습니다.`);
  return {
    publishedStoryCount: published,
    expectedStoryCount: 220,
    shardCount: index.shards.length,
    sha256Verified: true,
  };
}

if (require.main === module) {
  try {
    const result = verifyCurriculumStoryBundle(process.argv[2]);
    process.stdout.write(
      `${result.publishedStoryCount}/${result.expectedStoryCount} published`
      + ` · ${result.shardCount} shards · SHA-256 일치`,
    );
  } catch (error) {
    process.stderr.write(`커리큘럼 번들 검증 실패: ${error.message}\n`);
    process.exit(1);
  }
}

module.exports = { verifyCurriculumStoryBundle };
