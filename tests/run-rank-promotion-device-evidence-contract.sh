#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
source_file="$root/Matths/RankPromotionPerformanceSelfTest.swift"

grep -q 'rankPromotionPerformanceSelfTest' "$source_file"
grep -q 'CADisplayLink' "$source_file"
grep -q 'RankTier.allCases' "$source_file"
grep -q 'RankPromotionPipelinePrewarmState.waitUntilReady' "$source_file"
grep -q 'serverSyncSuppressed: true' "$source_file"
grep -q 'MATTHS_RANK_PROMOTION_PERFORMANCE_V2' "$source_file"
grep -q 'appExecutableSHA256' "$source_file"
grep -q 'rankAssetManifestSHA256' "$source_file"
grep -q 'rank-promotion-performance.json' "$source_file"
grep -q 'RankPromotionPerformanceSelfTest.runIfRequested' "$root/Matths/MatthsApp.swift"

work=$(mktemp -d /tmp/matths-rank-promotion-evidence.XXXXXX)
trap 'rm -rf "$work"' EXIT
source_root="$work/source"
app="$work/Matths.app"
mkdir -p "$source_root/Matths/RankMotion" "$source_root/scripts" "$app/RankMotion"
cp "$root/Matths/RankMotion/rank-promotion-assets.json" "$source_root/Matths/RankMotion/"
cp "$root/scripts/verifyRankPromotionBundle.js" "$source_root/scripts/"
cp "$root/Matths/RankMotion/rank-promotion-assets.json" "$app/RankMotion/"
printf '%s\n' .DS_Store > "$source_root/.gitignore"
for video in "$root"/Matths/RankMotion/*.mp4; do cp "$video" "$app/RankMotion/"; done
cat > "$app/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Matths</string>
<key>CFBundleIdentifier</key><string>kr.matths.app</string>
</dict></plist>
PLIST
printf '%s\n' 'fixture executable' > "$app/Matths"
git -C "$source_root" init -q
git -C "$source_root" config user.email evidence-contract@example.invalid
git -C "$source_root" config user.name 'Evidence Contract'
git -C "$source_root" add .
git -C "$source_root" commit -qm fixture
SRCROOT="$source_root" TARGET_BUILD_DIR="$work" \
UNLOCALIZED_RESOURCES_FOLDER_PATH=Matths.app INFOPLIST_PATH=Matths.app/Info.plist \
CONFIGURATION=Debug /bin/sh "$root/scripts/embed-build-provenance.sh"

node - "$root" "$app" "$source_root" "$work/pass.json" <<'NODE'
const fs = require("node:fs");
const path = require("node:path");
const [root, app, sourceRoot, output] = process.argv.slice(2);
const { verifyRankPromotionBundle } = require(path.join(root, "scripts/verifyRankPromotionBundle"));
const bundle = verifyRankPromotionBundle(app, { sourceRoot });
const tiers = ["BRONZE", "SILVER", "GOLD", "PLATINUM", "EMERALD", "DIAMOND", "MASTER", "GRANDMASTER", "CHALLENGER"];
const report = {
  schemaVersion: "MATTHS_RANK_PROMOTION_PERFORMANCE_V2",
  result: "PASS",
  reduceMotionEnabled: false,
  serverSyncSuppressed: true,
  sourceCommit: bundle.source.commit,
  sourceTree: bundle.source.tree,
  sourceIdentityKind: bundle.source.identityKind,
  sourceTrackedWorkingTreeClean: bundle.source.trackedWorkingTreeClean,
  sourceExternalAttestationRequired: bundle.source.externalAttestationRequired,
  appExecutableSHA256: bundle.executable.sha256,
  rankAssetManifestSHA256: bundle.rankPromotion.manifestSha256,
  rankAssetSourceStatus: bundle.rankPromotion.sourceProvenance.status,
  rankAssetApprovedSource: bundle.rankPromotion.sourceProvenance.approvedSource,
  rankAssetExternalAttestationRequired: bundle.rankPromotion.sourceProvenance.externalAttestationRequired,
  rankAssets: bundle.rankPromotion.assets,
  provenanceVerified: true,
  releaseEvidenceEligible: true,
  tiers: tiers.map((tierCode) => ({ tierCode, durationSeconds: 7.4, callbackCount: 440, dropRatio: 0.01, maxFrameMs: 25, passed: true })),
};
fs.writeFileSync(output, JSON.stringify(report));
NODE
node "$root/scripts/verifyRankPromotionEvidence.js" "$work/pass.json" \
  --app "$app" --source-root "$source_root"

cat > "$work/prewarm.json" <<'JSON'
{"schemaVersion":"MATTHS_RANK_PROMOTION_PIPELINE_PREWARM_V1","result":"PASS","durationMs":950,"initialResidentBytes":100000000,"peakResidentBytes":122000000,"finalResidentBytes":121000000,"peakResidentDeltaBytes":22000000,"renderedTiers":["BRONZE","SILVER","GOLD","PLATINUM","EMERALD","DIAMOND","MASTER","GRANDMASTER","CHALLENGER"],"audioPlaybackSuppressed":true,"accessibilityHidden":true,"hitTestingDisabled":true}
JSON
node "$root/scripts/verifyRankPromotionEvidence.js" "$work/prewarm.json"

node -e 'const fs=require("fs");const p=process.argv[1];const r=JSON.parse(fs.readFileSync(p));r.peakResidentDeltaBytes=134217729;fs.writeFileSync(p,JSON.stringify(r))' "$work/prewarm.json"
if node "$root/scripts/verifyRankPromotionEvidence.js" "$work/prewarm.json" >/dev/null 2>&1; then
  echo '과도한 prewarm memory가 검증을 통과했습니다.' >&2
  exit 1
fi

cp "$work/pass.json" "$work/original-pass.json"
node -e 'const fs=require("fs");const p=process.argv[1];const r=JSON.parse(fs.readFileSync(p));r.tiers[8].dropRatio=.2;fs.writeFileSync(p,JSON.stringify(r))' "$work/pass.json"
if node "$root/scripts/verifyRankPromotionEvidence.js" "$work/pass.json" \
  --app "$app" --source-root "$source_root" >/dev/null 2>&1; then
  echo '불일치 성능 판정이 검증을 통과했습니다.' >&2
  exit 1
fi
cp "$work/original-pass.json" "$work/pass.json"

printf x >> "$app/Matths"
if node "$root/scripts/verifyRankPromotionEvidence.js" "$work/pass.json" \
  --app "$app" --source-root "$source_root" >/dev/null 2>&1; then
  echo '다른 executable의 성능 증거가 검증을 통과했습니다.' >&2
  exit 1
fi
printf '%s\n' 'fixture executable' > "$app/Matths"

node -e 'const fs=require("fs");const p=process.argv[1];const r=JSON.parse(fs.readFileSync(p));r.rankAssets[0].sha256="0".repeat(64);fs.writeFileSync(p,JSON.stringify(r))' "$work/pass.json"
if node "$root/scripts/verifyRankPromotionEvidence.js" "$work/pass.json" \
  --app "$app" --source-root "$source_root" >/dev/null 2>&1; then
  echo '다른 tier SHA-256의 성능 증거가 검증을 통과했습니다.' >&2
  exit 1
fi

echo 'Rank promotion device evidence contract passed'
