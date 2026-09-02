#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";

const args = process.argv.slice(2);
const inputPath = args[0];
if (!inputPath || args.includes("--help")) {
  console.error("usage: node evaluate-local-ai.mjs <labeled.jsonl> [--json report.json] [--markdown report.md]");
  process.exit(inputPath ? 0 : 2);
}

function argumentValue(flag) {
  const index = args.indexOf(flag);
  return index >= 0 ? args[index + 1] : undefined;
}

function clean(value) {
  return String(value ?? "")
    .normalize("NFKC")
    .toLowerCase()
    .replace(/[\s,]/g, "")
    .replace(/[−–—]/g, "-");
}

function rate(numerator, denominator) {
  return denominator ? numerator / denominator : null;
}

function rounded(value) {
  return value == null ? null : Math.round(value * 10_000) / 10_000;
}

function sameSetMember(value, values) {
  const normalized = clean(value);
  return (values ?? []).some((candidate) => clean(candidate) === normalized);
}

function readRows(file) {
  const raw = fs.readFileSync(file, "utf8");
  const rows = raw
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line && !line.startsWith("#"))
    .map((line, index) => {
      try {
        const row = JSON.parse(line);
        if (!row.kind || !row.sampleId) throw new Error("kind와 sampleId가 필요합니다");
        return row;
      } catch (error) {
        throw new Error(`${file}:${index + 1}: ${error.message}`);
      }
    });
  const seen = new Set();
  for (const row of rows) {
    if (seen.has(row.sampleId)) throw new Error(`${file}: 중복 sampleId: ${row.sampleId}`);
    seen.add(row.sampleId);
  }
  return { raw, rows };
}

function datasetProvenance(file, raw, rows) {
  const sha256Pattern = /^[a-f0-9]{64}$/i;
  let sourceHashesValid = 0;
  let independentlyReviewed = 0;
  let agreements = 0;
  let disagreementsAdjudicated = 0;

  for (const row of rows) {
    if (sha256Pattern.test(String(row.sourceSha256 ?? ""))) sourceHashesValid += 1;
    const primary = String(row.review?.primaryLabeler ?? "").trim();
    const secondary = String(row.review?.secondaryLabeler ?? "").trim();
    const independent = primary && secondary && primary !== secondary;
    if (!independent || typeof row.review?.agreed !== "boolean") continue;
    independentlyReviewed += 1;
    if (row.review.agreed) agreements += 1;
    if (!row.review.agreed && String(row.review?.adjudication ?? "").trim()) {
      disagreementsAdjudicated += 1;
    }
  }

  const fixtureLike = file.split(path.sep).includes("fixtures") ||
    rows.some((row) => /^DEMO[-_]/i.test(String(row.sampleId)));
  const sortedSampleIds = rows.map((row) => String(row.sampleId)).sort().join("\n");
  return {
    sourceSha256: crypto.createHash("sha256").update(raw).digest("hex"),
    sampleIdsSha256: crypto.createHash("sha256").update(sortedSampleIds).digest("hex"),
    uniqueSamples: rows.length,
    fixtureLike,
    sourceHashesValid,
    independentlyReviewed,
    agreements,
    disagreementsAdjudicated,
    doubleLabelAgreement: rounded(rate(agreements, independentlyReviewed)),
  };
}

function handwritingMetrics(rows) {
  let expectedProblems = 0;
  let matchedProblems = 0;
  let answerTotal = 0;
  let answerCorrect = 0;
  let requiredSteps = 0;
  let coveredSteps = 0;
  let unreadable = 0;

  for (const row of rows) {
    const expected = row.expected?.problems ?? [];
    const observed = row.observed?.problems ?? [];
    if (row.observed?.unreadable === true) unreadable += 1;
    for (const item of expected) {
      expectedProblems += 1;
      const found = observed.find((candidate) => clean(candidate.problemId) === clean(item.problemId));
      if (!found) continue;
      matchedProblems += 1;
      if (item.finalAnswer != null) {
        answerTotal += 1;
        const accepted = [item.finalAnswer, ...(item.acceptedAnswers ?? [])];
        if (sameSetMember(found.finalAnswer, accepted)) answerCorrect += 1;
      }
      for (const step of item.requiredSteps ?? []) {
        requiredSteps += 1;
        if (sameSetMember(step, found.recognizedSteps ?? [])) coveredSteps += 1;
      }
    }
  }

  return {
    samples: rows.length,
    expectedProblems,
    matchedProblems,
    problemRecall: rounded(rate(matchedProblems, expectedProblems)),
    finalAnswerAccuracy: rounded(rate(answerCorrect, answerTotal)),
    stepCoverage: rounded(rate(coveredSteps, requiredSteps)),
    unreadableRate: rounded(rate(unreadable, rows.length)),
  };
}

function cheatingMetrics(rows) {
  const labels = ["normal", "suspicious", "inconclusive"];
  const confusion = Object.fromEntries(labels.map((expected) => [
    expected,
    Object.fromEntries(labels.map((predicted) => [predicted, 0])),
  ]));
  let suspiciousTP = 0;
  let suspiciousFP = 0;
  let suspiciousFN = 0;
  let normalCount = 0;
  let normalFalsePositive = 0;
  let inconclusive = 0;

  for (const row of rows) {
    const expected = row.expected?.verdict;
    const predicted = row.observed?.verdict;
    if (!labels.includes(expected) || !labels.includes(predicted)) {
      throw new Error(`${row.sampleId}: cheating verdict는 ${labels.join("/")} 중 하나여야 합니다`);
    }
    confusion[expected][predicted] += 1;
    if (expected === "suspicious" && predicted === "suspicious") suspiciousTP += 1;
    if (expected !== "suspicious" && predicted === "suspicious") suspiciousFP += 1;
    if (expected === "suspicious" && predicted !== "suspicious") suspiciousFN += 1;
    if (expected === "normal") {
      normalCount += 1;
      if (predicted === "suspicious") normalFalsePositive += 1;
    }
    if (predicted === "inconclusive") inconclusive += 1;
  }

  const precision = rate(suspiciousTP, suspiciousTP + suspiciousFP);
  const recall = rate(suspiciousTP, suspiciousTP + suspiciousFN);
  const f1 = precision == null || recall == null || precision + recall === 0
    ? null
    : (2 * precision * recall) / (precision + recall);
  return {
    samples: rows.length,
    suspiciousPrecision: rounded(precision),
    suspiciousRecall: rounded(recall),
    suspiciousF1: rounded(f1),
    normalFalsePositiveRate: rounded(rate(normalFalsePositive, normalCount)),
    inconclusiveRate: rounded(rate(inconclusive, rows.length)),
    confusion,
  };
}

function gradingMetrics(rows) {
  let verdictCorrect = 0;
  let answerTotal = 0;
  let answerCorrect = 0;
  let requiredConcepts = 0;
  let coveredConcepts = 0;
  let unsafeClaims = 0;
  let hallucinatedClaims = 0;

  for (const row of rows) {
    if (row.expected?.verdict === row.observed?.verdict) verdictCorrect += 1;
    if (row.expected?.finalAnswer != null) {
      answerTotal += 1;
      const accepted = [row.expected.finalAnswer, ...(row.expected.acceptedAnswers ?? [])];
      if (sameSetMember(row.observed?.finalAnswer, accepted)) answerCorrect += 1;
    }
    for (const concept of row.expected?.requiredConcepts ?? []) {
      requiredConcepts += 1;
      if (sameSetMember(concept, row.observed?.mentionedConcepts ?? [])) coveredConcepts += 1;
    }
    const tutorText = clean(row.observed?.tutorAnswer);
    for (const claim of row.expected?.forbiddenClaims ?? []) {
      if (tutorText.includes(clean(claim))) hallucinatedClaims += 1;
    }
    if (row.observed?.unsafeClaim === true) unsafeClaims += 1;
  }

  return {
    samples: rows.length,
    verdictAccuracy: rounded(rate(verdictCorrect, rows.length)),
    finalAnswerAccuracy: rounded(rate(answerCorrect, answerTotal)),
    requiredConceptCoverage: rounded(rate(coveredConcepts, requiredConcepts)),
    hallucinatedClaimCount: hallucinatedClaims,
    unsafeClaimRate: rounded(rate(unsafeClaims, rows.length)),
  };
}

function percentage(value) {
  return value == null ? "해당 없음" : `${(value * 100).toFixed(1)}%`;
}

function markdown(report) {
  const h = report.handwriting;
  const c = report.cheating;
  const g = report.gradingTutor;
  return `# Matths 로컬 AI 라벨 평가 결과\n\n` +
    `- 생성 시각: ${report.generatedAt}\n` +
    `- 입력: ${report.source}\n` +
    `- 주의: 이 수치는 입력 JSONL의 라벨 품질과 표본 구성에만 유효합니다.\n\n` +
    `## 손글씨 판독\n\n` +
    `- 표본: ${h.samples}장 / 기대 문항 ${h.expectedProblems}개\n` +
    `- 문항 매칭 재현율: ${percentage(h.problemRecall)}\n` +
    `- 최종 답 판독 정확도: ${percentage(h.finalAnswerAccuracy)}\n` +
    `- 필수 풀이 단계 포착률: ${percentage(h.stepCoverage)}\n` +
    `- 판독 불가율: ${percentage(h.unreadableRate)}\n\n` +
    `## 부정행위 보조 판정\n\n` +
    `- 표본: ${c.samples}건\n` +
    `- 의심 precision: ${percentage(c.suspiciousPrecision)}\n` +
    `- 의심 recall: ${percentage(c.suspiciousRecall)}\n` +
    `- 의심 F1: ${percentage(c.suspiciousF1)}\n` +
    `- 정상 풀이 오탐률: ${percentage(c.normalFalsePositiveRate)}\n` +
    `- 판정 보류율: ${percentage(c.inconclusiveRate)}\n\n` +
    `## 채점·튜터\n\n` +
    `- 표본: ${g.samples}건\n` +
    `- 정오 판정 정확도: ${percentage(g.verdictAccuracy)}\n` +
    `- 최종 답 정확도: ${percentage(g.finalAnswerAccuracy)}\n` +
    `- 필수 개념 포함률: ${percentage(g.requiredConceptCoverage)}\n` +
    `- 금지된 허위 주장 적발 건수: ${g.hallucinatedClaimCount}\n` +
    `- 위험 답변 비율: ${percentage(g.unsafeClaimRate)}\n`;
}

const resolvedInputPath = path.resolve(inputPath);
const input = readRows(resolvedInputPath);
const rows = input.rows;
const grouped = {
  handwriting: rows.filter((row) => row.kind === "handwriting"),
  cheating: rows.filter((row) => row.kind === "cheating"),
  gradingTutor: rows.filter((row) => row.kind === "grading-tutor"),
};
const unknown = rows.filter((row) => !["handwriting", "cheating", "grading-tutor"].includes(row.kind));
if (unknown.length) throw new Error(`지원하지 않는 kind: ${unknown.map((row) => row.kind).join(", ")}`);

const report = {
  schemaVersion: "MATTHS_LOCAL_AI_EVAL_V1",
  generatedAt: new Date().toISOString(),
  source: resolvedInputPath,
  dataset: datasetProvenance(resolvedInputPath, input.raw, rows),
  handwriting: handwritingMetrics(grouped.handwriting),
  cheating: cheatingMetrics(grouped.cheating),
  gradingTutor: gradingMetrics(grouped.gradingTutor),
};

const json = `${JSON.stringify(report, null, 2)}\n`;
const md = markdown(report);
const jsonPath = argumentValue("--json");
const markdownPath = argumentValue("--markdown");
if (jsonPath) fs.writeFileSync(path.resolve(jsonPath), json);
if (markdownPath) fs.writeFileSync(path.resolve(markdownPath), md);
if (!jsonPath && !markdownPath) process.stdout.write(json);
