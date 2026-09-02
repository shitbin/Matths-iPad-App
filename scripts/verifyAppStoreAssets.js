#!/usr/bin/env node

const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const metadataPath = path.join(root, "appstore", "metadata", "ko-KR.json");
const reviewNotesPath = path.join(root, "appstore", "review-notes-ko.md");
const infoPlistPath = path.join(root, "Info.plist");
const expectedFiles = [
  "01-home.png",
  "02-curriculum.png",
  "03-quick-practice.png",
  "04-wrong-notes.png",
  "05-goat-arena.png",
  "06-pro-report.png",
  "07-tutorial.png",
];

function fail(message) {
  console.error(`APPSTORE-ASSET FAIL: ${message}`);
  process.exitCode = 1;
}

function pngInfo(file) {
  const data = fs.readFileSync(file);
  const signature = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  if (data.length < 33 || !data.subarray(0, 8).equals(signature)) {
    throw new Error("PNG signature/IHDR is missing");
  }
  if (data.toString("ascii", 12, 16) !== "IHDR") {
    throw new Error("IHDR is not the first PNG chunk");
  }
  return {
    width: data.readUInt32BE(16),
    height: data.readUInt32BE(20),
    bitDepth: data[24],
    colorType: data[25],
  };
}

function verifyScreenshotSet(directory, width, height) {
  const screenshotDir = path.join(root, "appstore", directory);
  if (!fs.existsSync(screenshotDir)) {
    fail(`missing screenshot directory: ${screenshotDir}`);
    return;
  }
  const actualFiles = fs.readdirSync(screenshotDir).filter((name) => name.endsWith(".png")).sort();
  if (JSON.stringify(actualFiles) !== JSON.stringify(expectedFiles)) {
    fail(`expected ${expectedFiles.join(", ")}; found ${actualFiles.join(", ")}`);
  }

  for (const name of expectedFiles) {
    const file = path.join(screenshotDir, name);
    if (!fs.existsSync(file)) continue;
    try {
      const info = pngInfo(file);
      if (info.width !== width || info.height !== height) {
        fail(`${directory}/${name} is ${info.width}x${info.height}; expected ${width}x${height}`);
      }
      if (info.bitDepth !== 8 || info.colorType !== 2) {
        fail(`${directory}/${name} must be 8-bit RGB without alpha; bitDepth=${info.bitDepth}, colorType=${info.colorType}`);
      }
    } catch (error) {
      fail(`${directory}/${name}: ${error.message}`);
    }
  }
}

verifyScreenshotSet("screenshots-iphone-6.9-landscape", 2868, 1320);
verifyScreenshotSet("screenshots-ipad-13-landscape", 2752, 2064);

let metadata;
try {
  metadata = JSON.parse(fs.readFileSync(metadataPath, "utf8"));
} catch (error) {
  fail(`cannot read ${metadataPath}: ${error.message}`);
}

if (metadata) {
  const limits = { name: 30, subtitle: 30, promotionalText: 170, keywords: 100 };
  for (const [field, limit] of Object.entries(limits)) {
    const value = metadata[field];
    if (typeof value !== "string" || value.trim() === "") {
      fail(`metadata.${field} is required`);
      continue;
    }
    const length = Array.from(value).length;
    if (length > limit) fail(`metadata.${field} is ${length} characters; limit is ${limit}`);
  }

  if (typeof metadata.description !== "string" || metadata.description.trim().length < 300) {
    fail("metadata.description is missing or too short");
  }
  const standardEulaURL = "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/";
  if (!metadata.description.includes(standardEulaURL)) {
    fail("metadata.description must include the standard Apple EULA URL for auto-renewable subscriptions");
  }
  for (const field of ["supportURL", "marketingURL", "privacyPolicyURL"]) {
    try {
      const url = new URL(metadata[field]);
      if (url.protocol !== "https:" || url.hostname !== "www.matths.kr") {
        fail(`metadata.${field} must be an https://www.matths.kr URL`);
      }
    } catch {
      fail(`metadata.${field} is not a valid URL`);
    }
  }
  if (metadata.supportEmail !== "dltkddbs4553@matths.kr") {
    fail("metadata.supportEmail is not the current review contact");
  }
}

try {
  const reviewNotes = fs.readFileSync(reviewNotesPath, "utf8");
  for (const required of [
    "게시글 신고",
    "댓글 작성자를",
    "차단 관리",
    "익명 이름",
    "Sign in with Apple",
    "계정 탈퇴",
    "dltkddbs4553@matths.kr",
  ]) {
    if (!reviewNotes.includes(required)) {
      fail(`review notes must explain: ${required}`);
    }
  }
} catch (error) {
  fail(`cannot read ${reviewNotesPath}: ${error.message}`);
}

try {
  const infoPlist = fs.readFileSync(infoPlistPath, "utf8");
  if (!/<key>ITSAppUsesNonExemptEncryption<\/key>\s*<false\/>/.test(infoPlist)) {
    fail("Info.plist must declare ITSAppUsesNonExemptEncryption=false");
  }
} catch (error) {
  fail(`cannot read ${infoPlistPath}: ${error.message}`);
}

if (!process.exitCode) {
  console.log(`APPSTORE-ASSET PASS: ${expectedFiles.length * 2} screenshots, iPhone/iPad landscape RGB, metadata limits valid`);
}
