#!/usr/bin/env node

"use strict";

const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");

function option(name, fallback = "") {
  const index = process.argv.indexOf(name);
  if (index === -1) return fallback;
  if (!process.argv[index + 1]) throw new Error(`${name} 값이 필요합니다.`);
  return process.argv[index + 1];
}

const sourceArgument = process.argv.slice(2).find((value) => !value.startsWith("--") && value !== option("--output"));
if (!sourceArgument) throw new Error("vision-selftest.jsonl 경로가 필요합니다.");
const source = path.resolve(sourceArgument);
const output = path.resolve(option("--output", path.join(path.dirname(source), "vision-evidence.json")));
const raw = fs.readFileSync(source, "utf8");
const rows = raw
  .split(/\r?\n/)
  .filter(Boolean)
  .map((line, index) => {
    try {
      return JSON.parse(line);
    } catch {
      throw new Error(`${index + 1}번째 JSONL 행을 읽을 수 없습니다.`);
    }
  });

const forbiddenKeys = new Set(["image", "ocr", "account", "email", "userId", "error", "output", "prompt"]);
for (const [index, row] of rows.entries()) {
  for (const key of Object.keys(row)) {
    if (forbiddenKeys.has(key)) throw new Error(`${index + 1}번째 행에 비식별 허용 밖 필드가 있습니다: ${key}`);
  }
}

const latestLaunchIndex = rows.map((row) => row.event).lastIndexOf("launch");
if (latestLaunchIndex < 0) throw new Error("launch 이벤트가 없습니다.");
const run = rows.slice(latestLaunchIndex);
const launch = run.find((row) => row.event === "launch");
const load = run.find((row) => row.event === "load-complete");
const inference = run.find((row) => row.event === "vision-complete");
const failure = run.find((row) => row.event === "load-failed");
if (failure) throw new Error(`모델 로드가 실패했습니다: ${failure.tier || launch.tier || "tier 미상"}`);
if (!load) throw new Error("load-complete 이벤트가 없습니다.");
if (!inference) throw new Error("vision-complete 이벤트가 없습니다.");
if (load.visionReady !== true) throw new Error("비전 프로젝터가 준비되지 않았습니다.");

const tier = String(inference.tier || load.tier || launch.tier || "").trim();
const model = String(inference.model || load.model || launch.model || "").trim();
if (!tier || !model) throw new Error("tier 또는 model 식별자가 없습니다.");
for (const row of [load, inference]) {
  if (row.tier && row.tier !== tier) throw new Error("한 파일 안의 tier가 서로 다릅니다.");
  if (row.model && row.model !== model) throw new Error("한 파일 안의 model이 서로 다릅니다.");
}

function positive(row, key) {
  const value = Number(row[key]);
  if (!Number.isFinite(value) || value <= 0) throw new Error(`${row.event}.${key}가 양수가 아닙니다.`);
  return value;
}

const result = {
  schema: "MATTHS_VISION_DEVICE_EVIDENCE_V1",
  result: "PASS",
  tier,
  model,
  metrics: {
    loadMs: positive(load, "elapsedMs"),
    loadMinimumAvailableBytes: positive(load, "minimumAvailableBytes"),
    loadMaximumResidentBytes: positive(load, "maximumResidentBytes"),
    inferenceMs: positive(inference, "elapsedMs"),
    firstTokenMs: positive(inference, "firstTokenMs"),
    generatedTokens: positive(inference, "generatedTokens"),
    tokensPerSecond: positive(inference, "tokensPerSecond"),
    inferenceMinimumAvailableBytes: positive(inference, "minimumAvailableBytes"),
    inferenceMaximumResidentBytes: positive(inference, "maximumResidentBytes"),
  },
  source: {
    file: path.basename(source),
    lineCount: rows.length,
    sha256: crypto.createHash("sha256").update(raw).digest("hex"),
  },
};

fs.mkdirSync(path.dirname(output), { recursive: true });
fs.writeFileSync(output, `${JSON.stringify(result, null, 2)}\n`, "utf8");
console.log(`${tier} 실기 비전 증거 검증 통과: ${output}`);
