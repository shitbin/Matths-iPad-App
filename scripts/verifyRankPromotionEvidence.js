#!/usr/bin/env node
"use strict";

const fs = require("node:fs");
const path = require("node:path");
const { verifyRankPromotionBundle } = require("./verifyRankPromotionBundle");

const filename = process.argv[2];
if (!filename) throw new Error("rank promotion evidence JSON 경로가 필요합니다.");
const report = JSON.parse(fs.readFileSync(filename, "utf8"));
const expectedTiers = [
  "BRONZE", "SILVER", "GOLD", "PLATINUM", "EMERALD",
  "DIAMOND", "MASTER", "GRANDMASTER", "CHALLENGER",
];

function option(name) {
  const index = process.argv.indexOf(name);
  if (index < 0 || !process.argv[index + 1]) return "";
  return process.argv[index + 1];
}

if (report.schemaVersion === "MATTHS_RANK_PROMOTION_PIPELINE_PREWARM_V1") {
  if (report.result !== "PASS") throw new Error("pipeline prewarm 결과가 PASS가 아닙니다.");
  if (!Array.isArray(report.renderedTiers)
      || report.renderedTiers.join(",") !== expectedTiers.join(",")
      || new Set(report.renderedTiers).size !== expectedTiers.length) {
    throw new Error("pipeline prewarm 티어 순서·고유성이 다릅니다.");
  }
  if (report.audioPlaybackSuppressed !== true
      || report.accessibilityHidden !== true
      || report.hitTestingDisabled !== true) {
    throw new Error("pipeline prewarm 격리 증거가 없습니다.");
  }
  const numericFields = [
    "durationMs", "initialResidentBytes", "peakResidentBytes",
    "finalResidentBytes", "peakResidentDeltaBytes",
  ];
  for (const field of numericFields) {
    if (!Number.isFinite(report[field]) || report[field] < 0) {
      throw new Error(`${field}: 유효한 음이 아닌 수가 아닙니다.`);
    }
  }
  if (report.durationMs > 3_000) throw new Error("pipeline prewarm이 3초를 넘었습니다.");
  if (report.peakResidentDeltaBytes > 128 * 1024 * 1024) {
    throw new Error("pipeline prewarm resident memory 증가가 128MiB를 넘었습니다.");
  }
  const expectedDelta = Math.max(0, report.peakResidentBytes - report.initialResidentBytes);
  if (report.peakResidentDeltaBytes !== expectedDelta) {
    throw new Error("pipeline prewarm resident memory delta가 숫자와 다릅니다.");
  }
  console.log(`Rank promotion pipeline prewarm evidence PASS: ${filename}`);
  process.exit(0);
}

if (report.schemaVersion !== "MATTHS_RANK_PROMOTION_PERFORMANCE_V2") {
  throw new Error("schemaVersion 불일치");
}
const appOption = option("--app");
const sourceRootOption = option("--source-root");
if (!appOption || !sourceRootOption) {
  throw new Error("V2 성능 증거는 --app <Matths.app> --source-root <repo> 교차검증이 필요합니다.");
}
const bundle = verifyRankPromotionBundle(path.resolve(appOption), {
  sourceRoot: path.resolve(sourceRootOption),
  requireCleanSource: true,
});
if (report.serverSyncSuppressed !== true) throw new Error("서버 동기화 억제 증거가 없습니다.");
if (report.reduceMotionEnabled !== false) throw new Error("동작 줄이기가 켜진 계측은 모션 성능 증거가 아닙니다.");
if (report.provenanceVerified !== true) throw new Error("self-test provenance 검증이 PASS가 아닙니다.");
if (report.sourceCommit !== bundle.source.commit
    || report.sourceTree !== bundle.source.tree
    || report.sourceIdentityKind !== bundle.source.identityKind
    || report.sourceTrackedWorkingTreeClean !== bundle.source.trackedWorkingTreeClean
    || report.sourceExternalAttestationRequired !== bundle.source.externalAttestationRequired) {
  throw new Error("self-test source identity가 실제 번들과 다릅니다.");
}
if (report.appExecutableSHA256 !== bundle.executable.sha256) {
  throw new Error("self-test executable SHA-256이 실제 앱 바이너리와 다릅니다.");
}
if (report.rankAssetManifestSHA256 !== bundle.rankPromotion.manifestSha256) {
  throw new Error("self-test rank manifest SHA-256이 실제 번들과 다릅니다.");
}
const sourceProvenance = bundle.rankPromotion.sourceProvenance;
if (report.rankAssetSourceStatus !== sourceProvenance.status
    || report.rankAssetApprovedSource !== sourceProvenance.approvedSource
    || report.rankAssetExternalAttestationRequired
      !== sourceProvenance.externalAttestationRequired) {
  throw new Error("self-test rank asset 출처 상태가 실제 manifest와 다릅니다.");
}
if (report.rankAssetSourceStatus !== "verified-git-origin"
    || report.rankAssetApprovedSource !== true
    || report.rankAssetExternalAttestationRequired !== false
    || report.releaseEvidenceEligible !== true) {
  throw new Error("검증된 Git 원본의 출처·Release 적격 상태가 다릅니다.");
}
if (!Array.isArray(report.rankAssets)
    || report.rankAssets.length !== bundle.rankPromotion.assets.length
    || report.rankAssets.some((row, index) => {
      const actual = bundle.rankPromotion.assets[index];
      return row.tierCode !== actual.tierCode
        || row.filename !== actual.filename
        || row.sha256 !== actual.sha256
        || row.sizeBytes !== actual.sizeBytes;
    })) {
  throw new Error("self-test 티어별 MP4 SHA-256이 실제 번들과 다릅니다.");
}
if (!Array.isArray(report.tiers) || report.tiers.length !== expectedTiers.length) {
  throw new Error("9티어 계측이 아닙니다.");
}
if (report.tiers.map((row) => row.tierCode).join(",") !== expectedTiers.join(",")) {
  throw new Error("티어 순서 또는 코드가 다릅니다.");
}
for (const row of report.tiers) {
  if (row.durationSeconds < 7 || row.callbackCount < 180) {
    throw new Error(`${row.tierCode}: 계측 시간이 부족합니다.`);
  }
  const expectedPass = row.dropRatio <= 0.05 && row.maxFrameMs <= 100;
  if (row.passed !== expectedPass) throw new Error(`${row.tierCode}: 판정과 숫자가 다릅니다.`);
}
const expectedResult = report.tiers.every((row) => row.passed) ? "PASS" : "FAIL";
if (report.result !== expectedResult) throw new Error("전체 판정과 티어 판정이 다릅니다.");
console.log(`Rank promotion evidence ${report.result}: ${filename}`);
