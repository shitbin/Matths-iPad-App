#!/usr/bin/env node

"use strict";

const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");

const requirements = new Map([
  ["install-launch", ["device-log"]],
  ["google-existing-account", ["video"]],
  ["google-new-account", ["video"]],
  ["google-cancel-retry", ["video"]],
  ["protected-recording-mirroring", ["video"]],
  ["screenshot-watermark-integrity", ["screenshot", "device-log"]],
  ["stuck-point-cross-device", ["video", "device-log"]],
  ["split-view-320", ["video"]],
  ["stage-manager-resize", ["video"]],
  ["keyboard-pencil-toolbar", ["video"]],
  ["voiceover-order", ["video"]],
  ["dynamic-type-ax5", ["video"]],
  ["webview-zoom-200", ["video"]],
  ["reduce-motion-runtime", ["video"]],
  ["placement-rank-badge", ["video", "device-log"]],
  ["nine-tier-motion-sound", ["video", "device-log"]],
  ["arena-cross-platform", ["video", "device-log"]],
  ["curriculum-long-title-lock-time", ["video"]],
  ["account-progress-reset-roundtrip", ["video", "device-log"]],
  ["math-typesetting-voiceover", ["video"]],
  ["background-jetsam-recovery", ["video", "device-log"]],
  ["model-download-resume-storage", ["video", "device-log"]],
]);
const allowedTypes = new Set(["device-log", "screenshot", "video"]);

function option(name, fallback = "") {
  const index = process.argv.indexOf(name);
  if (index < 0) return fallback;
  if (!process.argv[index + 1]) throw new Error(`${name} 값이 필요합니다.`);
  return process.argv[index + 1];
}

function sha256(filename) {
  return crypto.createHash("sha256").update(fs.readFileSync(filename)).digest("hex");
}

function safeFile(root, relative) {
  const resolvedRoot = path.resolve(root);
  const resolved = path.resolve(resolvedRoot, String(relative || ""));
  if (!resolved.startsWith(`${resolvedRoot}${path.sep}`)) {
    throw new Error(`세션 폴더 밖 파일은 허용하지 않습니다: ${relative}`);
  }
  return resolved;
}

function validateMetadata(session) {
  for (const key of ["deviceModel", "osVersion", "appVersion", "appBuild", "reviewer"]) {
    if (!String(session[key] || "").trim()) throw new Error(`${key}가 없습니다.`);
  }
  if (!/^\d{4}-\d{2}-\d{2}T/.test(String(session.observedAt || ""))) {
    throw new Error("observedAt이 없습니다.");
  }
  if (session.synthetic === true) throw new Error("합성 증거는 실기 증거로 사용할 수 없습니다.");
}

function validate(session, root) {
  if (session.schemaVersion !== "MATTHS_IPAD_DEVICE_QA_SESSION_V1") {
    throw new Error(`지원하지 않는 세션 스키마입니다: ${session.schemaVersion}`);
  }
  validateMetadata(session);
  const scenarios = Array.isArray(session.scenarios) ? session.scenarios : [];
  const byId = new Map();
  for (const row of scenarios) {
    if (byId.has(row.id)) throw new Error(`시나리오 ID가 중복됩니다: ${row.id}`);
    byId.set(row.id, row);
  }
  const verified = [];
  for (const [id, requiredTypes] of requirements) {
    const row = byId.get(id);
    if (!row) throw new Error(`필수 실기 시나리오가 없습니다: ${id}`);
    if (row.result !== "PASS") throw new Error(`${id}: PASS가 아닙니다.`);
    if (!String(row.notes || "").trim()) throw new Error(`${id}: 관찰 기록이 없습니다.`);
    if (!Array.isArray(row.artifacts) || row.artifacts.length === 0) {
      throw new Error(`${id}: 증거 파일이 없습니다.`);
    }
    const seenTypes = new Set();
    const artifacts = row.artifacts.map((artifact, index) => {
      if (!allowedTypes.has(artifact.type)) {
        throw new Error(`${id}.artifacts[${index}]: 허용하지 않는 종류입니다.`);
      }
      if (!/^[a-f0-9]{64}$/i.test(String(artifact.sha256 || ""))) {
        throw new Error(`${id}.artifacts[${index}]: SHA-256이 없습니다.`);
      }
      const filename = safeFile(root, artifact.file);
      if (!fs.existsSync(filename) || !fs.statSync(filename).isFile()) {
        throw new Error(`${id}: 증거 파일이 없습니다: ${artifact.file}`);
      }
      const actual = sha256(filename);
      if (actual !== artifact.sha256.toLowerCase()) {
        throw new Error(`${id}: 증거 파일이 변경됐습니다: ${artifact.file}`);
      }
      seenTypes.add(artifact.type);
      return { type: artifact.type, file: artifact.file, sha256: actual };
    });
    for (const requiredType of requiredTypes) {
      if (!seenTypes.has(requiredType)) throw new Error(`${id}: ${requiredType} 증거가 없습니다.`);
    }
    verified.push({ id, result: "PASS", artifacts });
  }
  return {
    schemaVersion: "MATTHS_IPAD_DEVICE_QA_EVIDENCE_V1",
    result: "PASS",
    generatedAt: new Date().toISOString(),
    device: {
      model: session.deviceModel,
      osVersion: session.osVersion,
      appVersion: session.appVersion,
      appBuild: session.appBuild,
    },
    observedAt: session.observedAt,
    reviewer: session.reviewer,
    scenarioCount: verified.length,
    scenarios: verified,
    source: {
      file: path.basename(session.__sourceFile || "session.json"),
      sha256: session.__sourceSha256 || "",
    },
  };
}

function template() {
  return {
    schemaVersion: "MATTHS_IPAD_DEVICE_QA_SESSION_V1",
    deviceModel: "",
    osVersion: "",
    appVersion: "",
    appBuild: "",
    observedAt: "",
    reviewer: "",
    synthetic: false,
    scenarios: [...requirements].map(([id, types]) => ({
      id,
      result: "PENDING",
      notes: "",
      artifacts: types.map((type) => ({ type, file: "", sha256: "" })),
    })),
  };
}

if (require.main === module) {
  try {
    const templateOutput = option("--write-template");
    if (templateOutput) {
      const output = path.resolve(templateOutput);
      fs.mkdirSync(path.dirname(output), { recursive: true });
      fs.writeFileSync(output, `${JSON.stringify(template(), null, 2)}\n`, "utf8");
      console.log(`iPad 실기 세션 템플릿: ${output}`);
      process.exit(0);
    }
    const input = process.argv.slice(2).find((value, index, all) =>
      !value.startsWith("--") && all[index - 1] !== "--output");
    if (!input) throw new Error("session.json 경로가 필요합니다.");
    const source = path.resolve(input);
    const raw = fs.readFileSync(source, "utf8");
    const session = JSON.parse(raw);
    session.__sourceFile = source;
    session.__sourceSha256 = crypto.createHash("sha256").update(raw).digest("hex");
    const output = path.resolve(option("--output", path.join(path.dirname(source), "device-evidence.json")));
    const result = validate(session, path.dirname(source));
    fs.writeFileSync(output, `${JSON.stringify(result, null, 2)}\n`, "utf8");
    console.log(`iPad 실기 증거 검증 통과: ${output}`);
  } catch (error) {
    console.error(`iPad 실기 증거 검증 실패: ${error.message}`);
    process.exit(1);
  }
}

module.exports = { requirements, sha256, template, validate };
