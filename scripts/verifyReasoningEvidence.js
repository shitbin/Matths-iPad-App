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

const outputOption = option("--output");
const sourceArgument = process.argv.slice(2)
  .find((value) => !value.startsWith("--") && value !== outputOption);
if (!sourceArgument) throw new Error("reasoning-selftest.jsonl 경로가 필요합니다.");
const source = path.resolve(sourceArgument);
const output = path.resolve(outputOption || path.join(path.dirname(source), "reasoning-evidence.json"));
const raw = fs.readFileSync(source, "utf8");
const rows = raw.split(/\r?\n/).filter(Boolean).map((line, index) => {
  try {
    return JSON.parse(line);
  } catch {
    throw new Error(`${index + 1}번째 JSONL 행을 읽을 수 없습니다.`);
  }
});

const forbiddenKeys = new Set(["image", "ocr", "account", "email", "userId", "error", "output", "prompt"]);
for (const [index, row] of rows.entries()) {
  for (const key of Object.keys(row)) {
    if (forbiddenKeys.has(key)) {
      throw new Error(`${index + 1}번째 행에 비식별 허용 밖 필드가 있습니다: ${key}`);
    }
  }
}

const latestLaunchIndex = rows.map((row) => row.event).lastIndexOf("launch");
if (latestLaunchIndex < 0) throw new Error("launch 이벤트가 없습니다.");
const run = rows.slice(latestLaunchIndex);
const launch = run.find((row) => row.event === "launch");
const load = run.find((row) => row.event === "load-complete");
const inference = run.find((row) => row.event === "reasoning-complete");
const language = run.find((row) => row.event === "reasoning-language");
const failure = run.find((row) => row.event === "load-failed" || row.event === "reasoning-failed");
if (failure) throw new Error(`로컬 추론이 실패했습니다: ${failure.tier || launch.tier || "tier 미상"}`);
if (!load) throw new Error("load-complete 이벤트가 없습니다.");
if (!inference) throw new Error("reasoning-complete 이벤트가 없습니다.");
if (!language) throw new Error("reasoning-language 이벤트가 없습니다.");
if (language.koreanOutputClean !== true) {
  throw new Error("학생 화면에 노출할 한국어 출력 품질 검사가 실패했습니다.");
}

const tier = String(inference.tier || load.tier || launch.tier || "").trim();
const model = String(inference.model || load.model || launch.model || "").trim();
if (!tier || !model) throw new Error("tier 또는 model 식별자가 없습니다.");
const supportedReasoningTiers = new Map([
  ["deepseek7B", "deepseek-r1"],
  ["ling3-q3", "ling-3.0"],
]);
const expectedModelFragment = supportedReasoningTiers.get(tier);
if (!expectedModelFragment || !model.toLowerCase().includes(expectedModelFragment)) {
  throw new Error(`지원하는 로컬 추론 실기 증거가 아닙니다: ${tier || "tier 미상"}`);
}

function positive(row, key) {
  const value = Number(row[key]);
  if (!Number.isFinite(value) || value <= 0) {
    throw new Error(`${row.event}.${key}가 양수가 아닙니다.`);
  }
  return value;
}

const result = {
  schema: "MATTHS_REASONING_DEVICE_EVIDENCE_V1",
  result: "PASS",
  tier,
  model,
  metrics: {
    loadMs: positive(load, "elapsedMs"),
    loadMinimumAvailableBytes: positive(load, "minimumAvailableBytes"),
    loadMaximumResidentBytes: positive(load, "maximumResidentBytes"),
    reasoningMs: positive(inference, "elapsedMs"),
    firstTokenMs: positive(inference, "firstTokenMs"),
    generatedTokens: positive(inference, "generatedTokens"),
    tokensPerSecond: positive(inference, "tokensPerSecond"),
    reasoningMinimumAvailableBytes: positive(inference, "minimumAvailableBytes"),
    reasoningMaximumResidentBytes: positive(inference, "maximumResidentBytes"),
    koreanOutputClean: true,
  },
  source: {
    file: path.basename(source),
    lineCount: rows.length,
    sha256: crypto.createHash("sha256").update(raw).digest("hex"),
  },
};

fs.mkdirSync(path.dirname(output), { recursive: true });
fs.writeFileSync(output, `${JSON.stringify(result, null, 2)}\n`, "utf8");
console.log(`${tier} 실기 수학 추론 증거 검증 통과: ${output}`);
