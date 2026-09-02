#!/usr/bin/env node

"use strict";

const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const matths = path.join(root, "Matths");
const policy = require(path.join(matths, "curriculum-story-policy.json"));
const index = require(path.join(matths, "curriculum-stories-index.json"));
const curriculum = require(path.join(matths, "curriculum-v2.json"));
const expectedKinds = new Set(["intuition", "question", "misconception", "solution", "recall"]);
const aliases = policy.providerPolicy.studioTagAliases;
const tagPattern = /\[([^\]\n]{1,40})\]/gu;
const studentTagPattern = /\[[^\]\n]{1,40}\]/u;

function digest(value) {
  return crypto.createHash("sha256").update(value).digest("hex");
}

function normalize(value) {
  return String(value || "").replace(/\s+/gu, " ").trim();
}

function stripTags(value) {
  return normalize(String(value || "").replace(tagPattern, " "));
}

function chunks(value, maximum = 180) {
  const sentences = normalize(value).match(/[^.!?。！？…]+(?:[.!?。！？]+|…+|$)/gu) || [];
  const output = [];
  for (const sentence of sentences) {
    let remaining = normalize(sentence);
    while (remaining.length > maximum) {
      const window = remaining.slice(0, maximum + 1);
      const preferred = Math.max(window.lastIndexOf(", "), window.lastIndexOf("; "), window.lastIndexOf(" "));
      const breakAt = preferred >= Math.floor(maximum * 0.55) ? preferred + 1 : maximum;
      output.push(remaining.slice(0, breakAt).trim());
      remaining = remaining.slice(breakAt).trim();
    }
    if (remaining) output.push(remaining);
  }
  return output;
}

assert.equal(policy.schemaVersion, "MATTHS_CURRICULUM_STORY_V1");
assert.equal(index.schemaVersion, policy.schemaVersion);
assert.equal(index.shards.length, 13);
assert.equal(Object.keys(aliases).length, 6);
assert.equal(aliases["침착하게"], "warmly");

const catalog = new Map();
for (const shardIndex of index.shards) {
  const file = path.join(matths, shardIndex.file);
  const raw = fs.readFileSync(file, "utf8");
  assert.equal(digest(raw), shardIndex.sha256, `${shardIndex.courseId} SHA mismatch`);
  const shard = JSON.parse(raw);
  assert.equal(shard.courseId, shardIndex.courseId);
  assert.equal(shard.stories.length, shardIndex.storyCount);
  assert.deepEqual(shard.stories.map((story) => story.conceptId), shardIndex.conceptIds);
  for (const story of shard.stories) {
    assert.ok(!catalog.has(story.conceptId), `duplicate ${story.conceptId}`);
    catalog.set(story.conceptId, story);
  }
}

const curriculumConcepts = new Map();
for (const course of curriculum.courses) {
  for (const unit of course.units) {
    for (const concept of unit.concepts) {
      curriculumConcepts.set(concept.id, { courseId: course.id, unitId: unit.id, concept });
    }
  }
}
assert.equal(curriculumConcepts.size, 220);
const indexedStoryCount = index.shards.reduce((sum, shard) => sum + shard.storyCount, 0);
assert.equal(catalog.size, indexedStoryCount);
assert.equal(indexedStoryCount, 220, "iPad Release 정본은 220개 story를 모두 포함해야 합니다.");
assert.equal(catalog.size, 220, "iPad bundle에서 220개 story를 모두 읽어야 합니다.");

for (const story of catalog.values()) {
  const source = curriculumConcepts.get(story.conceptId);
  assert.ok(source, `unknown concept ${story.conceptId}`);
  assert.equal(story.courseId, source.courseId);
  assert.equal(story.unitId, source.unitId);
  assert.equal(story.source.standardCode, source.concept.standardCode);
  assert.equal(story.status, "published");
  assert.ok(!studentTagPattern.test(story.title));
  assert.ok(!studentTagPattern.test(story.openingQuestion));
  assert.ok(story.estimatedSeconds >= 240 && story.estimatedSeconds <= 360);
  assert.equal(story.scenes.length, 5);
  assert.deepEqual(new Set(story.scenes.map((scene) => scene.kind)), expectedKinds);
  const narrationCharacters = story.scenes.reduce((sum, scene) => sum + scene.narration.length, 0);
  assert.ok(narrationCharacters >= 1400 && narrationCharacters <= 2600);

  for (const scene of story.scenes) {
    assert.ok(!studentTagPattern.test(scene.title));
    assert.ok(scene.subtitle.length >= 15 && scene.subtitle.length <= 100);
    assert.ok(scene.narration.length >= 240);
    assert.ok(!tagPattern.test(scene.subtitle));
    tagPattern.lastIndex = 0;
    assert.ok(!tagPattern.test(scene.narration));
    tagPattern.lastIndex = 0;
    const tags = [...scene.studioScript.matchAll(tagPattern)].map((match) => match[1]);
    assert.ok(tags.length > 0);
    assert.ok(tags.every((tag) => aliases[tag]));
    assert.equal(stripTags(scene.studioScript), normalize(scene.narration));
    assert.ok(chunks(scene.narration).every((chunk) => chunk.length <= 180));
  }
}

assert.ok([...catalog.values()].some((story) =>
  story.scenes.some((scene) => scene.studioScript.startsWith("[침착하게]"))));
assert.equal(curriculumConcepts.size - catalog.size, 0, "iPad story 누락은 출시를 닫아야 합니다.");

const timeline = fs.readFileSync(path.join(matths, "CurriculumStoryTimeline.swift"), "utf8");
const player = fs.readFileSync(path.join(matths, "CurriculumSpeechPlayer.swift"), "utf8");
const model = fs.readFileSync(path.join(matths, "CurriculumStory.swift"), "utf8");
assert.doesNotMatch(timeline, /studioScript|studioTagAliases/u);
assert.match(model, /studentProjection/u);
assert.match(model, /CurriculumStudioScriptCompiler/u);
assert.match(
  model,
  /let studentProjectionText = \[story\.title, story\.openingQuestion\][\s\S]*?\$0\.title[\s\S]*?\$0\.subtitle[\s\S]*?\$0\.narration[\s\S]*?CurriculumStudentProjectionTextGuard\.containsStudioTag/u,
);
assert.match(player, /AVSpeechSynthesisVoice[\s\S]*gender == \.female/u);
assert.match(player, /pauseSpeaking\(at: \.word\)/u);
assert.match(player, /continueSpeaking/u);
assert.match(player, /startWatchdog/u);
assert.match(player, /DataScope\.defaultsKey/u);
assert.match(player, /protocol CurriculumSpeechProviding/u);
assert.match(player, /let id: UUID/u);
assert.match(player, /activeRequestID/u);
assert.match(player, /accountSlot:/u);
assert.match(player, /capturedAccountSlot/u);
assert.match(player, /activeUtterance: AVSpeechUtterance\?/u);
assert.match(player, /activeUtterance === utterance/u);
assert.match(player, /notifyOthersOnDeactivation/u);
assert.match(player, /setActive\(\s*false/gu);
assert.match(player, /func pauseForInterruption\(\)[\s\S]*?provider\.stop\(\)/u);
assert.match(player, /curriculumSpeechProviderDidInterrupt[\s\S]*?provider\.stop\(\)/u);
assert.match(timeline, /scenePhase/u);
assert.match(timeline, /pauseForInterruption/u);
assert.match(timeline, /narrationCheckpointID/u);
assert.match(timeline, /player\.unload\(\)/u);
assert.match(timeline, /자동으로 만든 해설을 보여주지 않습니다/u);

console.log(
  `iPad curriculum story contract OK: ${indexedStoryCount}/220 published, 0 missing.`,
);
