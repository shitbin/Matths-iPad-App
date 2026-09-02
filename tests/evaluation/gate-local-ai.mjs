#!/usr/bin/env node

import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const args = process.argv.slice(2);
const reportPath = args[0] ? path.resolve(args[0]) : "";
const metadataPath = args[1] ? path.resolve(args[1]) : "";
function option(name, fallback = "") {
  const index = args.indexOf(name);
  return index >= 0 ? args[index + 1] : fallback;
}
const datasetPath = option("--dataset");
if (!reportPath || !metadataPath || !datasetPath) {
  console.error("usage: node gate-local-ai.mjs <report.json> <metadata.json> --dataset labeled.jsonl [--thresholds file] [--output file]");
  process.exit(2);
}

const thresholdPath = path.resolve(
  option("--thresholds", path.join(path.dirname(new URL(import.meta.url).pathname), "production-thresholds.json")),
);
const outputPath = option("--output");
const reportRaw = fs.readFileSync(reportPath, "utf8");
const metadataRaw = fs.readFileSync(metadataPath, "utf8");
const datasetRaw = fs.readFileSync(path.resolve(datasetPath), "utf8");
const report = JSON.parse(reportRaw);
const metadata = JSON.parse(metadataRaw);
const thresholds = JSON.parse(fs.readFileSync(thresholdPath, "utf8"));
const checks = [];

function get(object, keyPath) {
  return keyPath.split(".").reduce((value, key) => value?.[key], object);
}

function check(name, actual, operator, expected) {
  let pass = false;
  if (operator === ">=") pass = Number.isFinite(Number(actual)) && Number(actual) >= expected;
  if (operator === "<=") pass = Number.isFinite(Number(actual)) && Number(actual) <= expected;
  if (operator === "present") pass = typeof actual === "string" && actual.trim().length > 0;
  if (operator === "sha256") pass = /^[a-f0-9]{64}$/i.test(String(actual || ""));
  checks.push({ name, actual: actual ?? null, operator, expected: expected ?? null, pass });
}

if (report.schemaVersion !== "MATTHS_LOCAL_AI_EVAL_V1") {
  throw new Error(`지원하지 않는 평가 보고서입니다: ${report.schemaVersion}`);
}
for (const key of ["deviceModel", "osVersion", "quantization", "datasetVersion", "reviewerProtocol"]) {
  check(`metadata.${key}`, metadata[key], "present");
}
check("metadata.modelFileSha256", metadata.modelFileSha256, "sha256");
check("metadata.datasetSourceSha256", metadata.datasetSourceSha256, "sha256");
check("dataset.sourceSha256", report.dataset?.sourceSha256, "sha256");
check("dataset.sampleIdsSha256", report.dataset?.sampleIdsSha256, "sha256");
const actualDatasetSha256 = crypto.createHash("sha256").update(datasetRaw).digest("hex");
checks.push({
  name: "dataset.fileBinding",
  actual: actualDatasetSha256,
  operator: "===",
  expected: report.dataset?.sourceSha256 ?? null,
  pass: actualDatasetSha256 === report.dataset?.sourceSha256,
});
checks.push({
  name: "dataset.sourceBinding",
  actual: metadata.datasetSourceSha256 ?? null,
  operator: "===",
  expected: report.dataset?.sourceSha256 ?? null,
  pass: Boolean(metadata.datasetSourceSha256) && metadata.datasetSourceSha256 === report.dataset?.sourceSha256,
});
checks.push({
  name: "dataset.fixtureLike",
  actual: report.dataset?.fixtureLike ?? null,
  operator: "===",
  expected: false,
  pass: report.dataset?.fixtureLike === false,
});
const totalSamples = ["handwriting", "cheating", "gradingTutor"]
  .reduce((sum, group) => sum + Number(report[group]?.samples ?? 0), 0);
for (const key of ["uniqueSamples", "sourceHashesValid", "independentlyReviewed"]) {
  checks.push({
    name: `dataset.${key}`,
    actual: report.dataset?.[key] ?? null,
    operator: "===",
    expected: totalSamples,
    pass: Number(report.dataset?.[key]) === totalSamples,
  });
}
const disagreements = totalSamples - Number(report.dataset?.agreements ?? 0);
checks.push({
  name: "dataset.disagreementsAdjudicated",
  actual: report.dataset?.disagreementsAdjudicated ?? null,
  operator: "===",
  expected: disagreements,
  pass: Number(report.dataset?.disagreementsAdjudicated) === disagreements,
});
check(
  "dataset.doubleLabelAgreement",
  report.dataset?.doubleLabelAgreement,
  ">=",
  thresholds.minimum.doubleLabelAgreement,
);
for (const [group, minimum] of Object.entries(thresholds.minimumSamples)) {
  check(`${group}.samples`, report[group]?.samples, ">=", minimum);
}
for (const [key, minimum] of Object.entries(thresholds.minimum)) {
  if (key === "doubleLabelAgreement") continue;
  check(key, get(report, key), ">=", minimum);
}
for (const [key, maximum] of Object.entries(thresholds.maximum)) {
  check(key, get(report, key), "<=", maximum);
}

const result = {
  schemaVersion: "MATTHS_LOCAL_AI_PILOT_GATE_V1",
  result: checks.every((row) => row.pass) ? "PASS" : "FAIL",
  thresholds: thresholds.schemaVersion,
  source: {
    reportSha256: crypto.createHash("sha256").update(reportRaw).digest("hex"),
    metadataSha256: crypto.createHash("sha256").update(metadataRaw).digest("hex"),
  },
  checks,
};
const serialized = `${JSON.stringify(result, null, 2)}\n`;
if (outputPath) fs.writeFileSync(path.resolve(outputPath), serialized, "utf8");
else process.stdout.write(serialized);
if (result.result !== "PASS") process.exit(1);
