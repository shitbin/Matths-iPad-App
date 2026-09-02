#!/usr/bin/env node

"use strict";

const crypto = require("node:crypto");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const { verifyCurriculumStoryBundle } = require("./verifyCurriculumStoryBundle");
const { verifyRankPromotionBundle } = require("./verifyRankPromotionBundle");
const repoRoot = path.resolve(__dirname, "..");
// 실제 arm64 Release 바이너리에는 Swift 메타데이터와 로컬 모델 심볼이 많아
// `strings` 출력이 Node spawnSync 기본 1 MiB를 넘는다. 작은 계약 fixture에서는
// 드러나지 않지만 실 IPA 감사가 ENOBUFS로 중단되므로 도구 출력 상한을 명시한다.
const toolOutputMaxBytes = 64 * 1024 * 1024;

function option(name, fallback = "") {
  const index = process.argv.indexOf(name);
  if (index < 0) return fallback;
  if (!process.argv[index + 1]) throw new Error(`${name} 값이 필요합니다.`);
  return process.argv[index + 1];
}

function sha256(filename) {
  return crypto.createHash("sha256").update(fs.readFileSync(filename)).digest("hex");
}

function run(command, args) {
  const result = spawnSync(command, args, {
    encoding: "utf8",
    maxBuffer: toolOutputMaxBytes,
  });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`${command} ${args.join(" ")} 실패\n${result.stderr || result.stdout}`);
  return String(result.stdout || "").trim();
}

function sourceIdentity(root) {
  return {
    commit: run("git", ["-C", root, "rev-parse", "HEAD"]),
    tree: run("git", ["-C", root, "rev-parse", "HEAD^{tree}"]),
    trackedWorkingTreeClean:
      run("git", ["-C", root, "status", "--porcelain", "--untracked-files=no"]) === "",
  };
}

function walk(directory) {
  const files = [];
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const filename = path.join(directory, entry.name);
    if (entry.isDirectory()) files.push(...walk(filename));
    else if (entry.isFile()) files.push(filename);
  }
  return files;
}

function readPlist(filename) {
  const converted = run("/usr/bin/plutil", ["-convert", "json", "-o", "-", filename]);
  return JSON.parse(converted);
}

function optionalPlistExtract(filename, key, format = "raw") {
  const result = spawnSync(
    "/usr/bin/plutil",
    ["-extract", key, format, "-o", "-", filename],
    { encoding: "utf8" });
  if (result.error) throw result.error;
  if (result.status !== 0) return null;
  return String(result.stdout || "").trim();
}

function inspectSigning(app) {
  const codesign = process.env.MATTHS_CODESIGN || "/usr/bin/codesign";
  run(codesign, ["--verify", "--deep", "--strict", app]);

  const embedded = path.join(app, "embedded.mobileprovision");
  if (!fs.existsSync(embedded)) {
    throw new Error("서명된 앱에 embedded.mobileprovision이 없습니다.");
  }

  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), "matths-provision-"));
  const decoded = path.join(temporary, "profile.plist");
  try {
    const security = process.env.MATTHS_SECURITY || "/usr/bin/security";
    run(security, ["cms", "-D", "-i", embedded, "-o", decoded]);
    const deviceJSON = optionalPlistExtract(decoded, "ProvisionedDevices", "json");
    const devices = deviceJSON ? JSON.parse(deviceJSON) : [];
    const deviceBound = Array.isArray(devices) && devices.length > 0;
    const allDevices = optionalPlistExtract(decoded, "ProvisionsAllDevices") === "true";
    const debugAllowed = optionalPlistExtract(
      decoded, "Entitlements.get-task-allow") === "true";

    if (debugAllowed) return "development";
    if (deviceBound) return "ad-hoc";
    if (allDevices) return "enterprise";
    return "app-store-distribution";
  } finally {
    fs.rmSync(temporary, { recursive: true, force: true });
  }
}

function inspectSignedArchive(filename, { sourceRoot, auditedBundle }) {
  if (!filename || !fs.existsSync(filename) || !fs.statSync(filename).isFile()) {
    throw new Error("App Store 제출용 IPA가 없습니다. --signed-archive <Matths.ipa>가 필요합니다.");
  }
  const header = fs.readFileSync(filename).subarray(0, 4);
  if (header[0] !== 0x50 || header[1] !== 0x4b) {
    throw new Error("App Store 제출용 archive가 ZIP/IPA 형식이 아닙니다.");
  }
  const entries = run("/usr/bin/unzip", ["-Z1", filename]).split("\n").filter(Boolean);
  const appEntries = entries.filter((entry) => /^Payload\/[^/]+\.app\/$/.test(entry));
  if (appEntries.length !== 1) {
    throw new Error("IPA에는 Payload 아래 .app 하나만 있어야 합니다.");
  }
  const appPrefix = appEntries[0];
  for (const required of ["Info.plist", "embedded.mobileprovision"]) {
    if (!entries.includes(`${appPrefix}${required}`)) {
      throw new Error(`IPA에 ${appPrefix}${required}가 없습니다.`);
    }
  }
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), "matths-signed-archive-"));
  try {
    run("/usr/bin/unzip", ["-q", filename, "-d", temporary]);
    const archivedApp = path.join(temporary, appPrefix);
    const archivedBundle = verifyRankPromotionBundle(archivedApp, {
      sourceRoot,
      requireCleanSource: true,
    });
    if (archivedBundle.executable.sha256 !== auditedBundle.executable.sha256) {
      throw new Error("IPA executable이 감사한 .app executable과 다릅니다.");
    }
    if (archivedBundle.rankPromotion.manifestSha256
        !== auditedBundle.rankPromotion.manifestSha256) {
      throw new Error("IPA rank manifest가 감사한 .app manifest와 다릅니다.");
    }
    const archivedAssets = archivedBundle.rankPromotion.assets;
    const auditedAssets = auditedBundle.rankPromotion.assets;
    if (archivedAssets.length !== auditedAssets.length
        || archivedAssets.some((asset, index) =>
          asset.sha256 !== auditedAssets[index].sha256
          || asset.filename !== auditedAssets[index].filename
          || asset.tierCode !== auditedAssets[index].tierCode)) {
      throw new Error("IPA rank MP4가 감사한 .app rank MP4와 다릅니다.");
    }
    if (archivedBundle.source.commit !== auditedBundle.source.commit
        || archivedBundle.source.tree !== auditedBundle.source.tree) {
      throw new Error("IPA source identity가 감사한 .app과 다릅니다.");
    }
    return {
      file: path.basename(filename),
      sha256: sha256(filename),
      sizeBytes: fs.statSync(filename).size,
      appPath: appPrefix,
      executableSha256: archivedBundle.executable.sha256,
      rankAssetManifestSha256: archivedBundle.rankPromotion.manifestSha256,
      sourceCommit: archivedBundle.source.commit,
      sourceTree: archivedBundle.source.tree,
    };
  } finally {
    fs.rmSync(temporary, { recursive: true, force: true });
  }
}

function main() {
  const app = path.resolve(option("--app"));
  const buildLog = path.resolve(option("--build-log"));
  const output = path.resolve(option("--output"));
  const assets = option("--assets");
  const signing = option("--signing");
  const signedArchiveOption = option("--signed-archive");
  const sourceRoot = path.resolve(option("--source-root", repoRoot));
  if (!["compiled", "excluded"].includes(assets)) throw new Error("--assets compiled|excluded가 필요합니다.");
  if (!["signed", "unsigned"].includes(signing)) throw new Error("--signing signed|unsigned가 필요합니다.");
  if (!fs.statSync(app).isDirectory()) throw new Error(".app 폴더가 없습니다.");
  const binary = path.join(app, "Matths");
  const infoFile = path.join(app, "Info.plist");
  const privacyFile = path.join(app, "PrivacyInfo.xcprivacy");
  for (const filename of [binary, infoFile, privacyFile, buildLog]) {
    if (!fs.existsSync(filename)) throw new Error(`필수 Release 파일이 없습니다: ${filename}`);
  }
  const buildText = fs.readFileSync(buildLog, "utf8");
  if (!buildText.includes("** BUILD SUCCEEDED **")
      && !buildText.includes("** ARCHIVE SUCCEEDED **")) {
    throw new Error("Release build 또는 archive 성공 기록이 없습니다.");
  }

  const lipo = process.env.MATTHS_LIPO || "/usr/bin/lipo";
  const stringsTool = process.env.MATTHS_STRINGS || "/usr/bin/strings";
  const architectures = run(lipo, ["-archs", binary]).split(/\s+/).filter(Boolean);
  if (!architectures.includes("arm64")) throw new Error("Release 바이너리에 arm64가 없습니다.");
  const binaryStrings = run(stringsTool, [binary]);
  const forbidden = [
    "mongodb", "mongodb+srv", "API_TOKEN_SECRET", "EMAIL_API_KEY", "SECRET=",
    "서버 주소 (개발용)", "기록 보기 (디버그)", "개발 서버 미리보기 코드",
    "trycloudflare.com", "ngrok", "loca.lt", "localhost", "127.0.0.1",
  ].filter((needle) => binaryStrings.includes(needle));
  if (forbidden.length) throw new Error(`Release 바이너리 금칙 문자열: ${forbidden.join(", ")}`);
  if (!binaryStrings.includes("https://www.matths.kr")) throw new Error("운영 서버 주소가 Release 바이너리에 없습니다.");
  if (binaryStrings.includes("https://matths.kr")) throw new Error("구 apex 운영 주소가 Release 바이너리에 남아 있습니다.");

  const bundledFiles = walk(app);
  const curriculumStories = verifyCurriculumStoryBundle(app);
  const kice = bundledFiles.filter((filename) =>
    /(?:mopyeong|suneung).*\.pdf$|kice-index\.json$/i.test(path.basename(filename)));
  if (kice.length) throw new Error(`KICE 내부 자료가 Release 번들에 있습니다: ${kice.join(", ")}`);
  const info = readPlist(infoFile);
  if (info.CFBundleIdentifier !== "kr.matths.app") throw new Error("Release bundle ID가 다릅니다.");
  const schemes = (info.CFBundleURLTypes || []).flatMap((row) => row.CFBundleURLSchemes || []);
  if (!schemes.includes("matths")) throw new Error("matths OAuth callback scheme이 Release에 없습니다.");
  const signingKind = signing === "signed" ? inspectSigning(app) : "unsigned";
  const rankPromotion = verifyRankPromotionBundle(app, {
    sourceRoot,
    requireCleanSource: true,
  });

  const appStoreBinaryEligible = assets === "compiled"
    && signingKind === "app-store-distribution";
  const rankAssetSourceAttested = rankPromotion.rankPromotion.sourceProvenance.approvedSource === true
    && rankPromotion.rankPromotion.sourceProvenance.externalAttestationRequired === false;
  const appStoreEligible = appStoreBinaryEligible && rankAssetSourceAttested;
  const signedArchive = appStoreBinaryEligible
    ? inspectSignedArchive(path.resolve(signedArchiveOption), {
      sourceRoot,
      auditedBundle: rankPromotion,
    })
    : null;
  const report = {
    schemaVersion: "MATTHS_IPAD_RELEASE_AUDIT_V2",
    result: "PASS",
    generatedAt: new Date().toISOString(),
    source: sourceIdentity(sourceRoot),
    appStoreEligible,
    auditLimitations: [
      ...(assets === "excluded" ? ["asset catalog excluded because sandbox cannot access Simulator runtime"] : []),
      ...(signing === "unsigned" ? ["unsigned build; signed archive still required"] : []),
      ...(signingKind === "development" ? ["development provisioning profile; App Store distribution signing still required"] : []),
      ...(signingKind === "ad-hoc" ? ["ad-hoc provisioning profile; App Store distribution signing still required"] : []),
      ...(signingKind === "enterprise" ? ["enterprise provisioning profile; App Store distribution signing still required"] : []),
      ...(!rankAssetSourceAttested
        ? ["rank MP4 web origin is unknown; separate external source attestation required"]
        : []),
    ],
    build: {
      configuration: "Release",
      assets,
      signing: signingKind,
      architectures,
      appStoreBinaryEligible,
    },
    signedArchive,
    bundle: {
      identifier: info.CFBundleIdentifier,
      callbackSchemes: schemes,
      apiBaseURL: "https://www.matths.kr",
      kiceResourceCount: 0,
      privacyManifestSha256: sha256(privacyFile),
      executableSha256: rankPromotion.executable.sha256,
      fileCount: bundledFiles.length,
      curriculumStories,
      rankPromotion: rankPromotion.rankPromotion,
    },
    buildLog: { file: path.basename(buildLog), sha256: sha256(buildLog) },
  };
  fs.mkdirSync(path.dirname(output), { recursive: true });
  const packagedBuildLog = path.join(path.dirname(output), path.basename(buildLog));
  if (path.resolve(packagedBuildLog) !== path.resolve(buildLog)) {
    fs.copyFileSync(buildLog, packagedBuildLog);
  }
  fs.writeFileSync(output, `${JSON.stringify(report, null, 2)}\n`, "utf8");
  console.log(`iPad Release 감사 증거 통과: ${output}`);
  if (!appStoreEligible) console.log("주의: 이 결과는 App Store 제출 가능 배포 서명 증거가 아닙니다.");
}

try {
  main();
} catch (error) {
  console.error(`iPad Release 감사 실패: ${error.message}`);
  process.exit(1);
}
