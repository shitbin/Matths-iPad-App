#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
grep -Fq 'const toolOutputMaxBytes = 64 * 1024 * 1024;' \
  "$root/scripts/createReleaseAuditEvidence.js"
work="$(mktemp -d /tmp/matths-release-audit.XXXXXX)"
cleanup_work() {
  # APFS/metadata helpers can briefly recreate a file while the large fixture is
  # being removed. Retry the exact mktemp target so a successful contract does
  # not become flaky during cleanup.
  rm -rf "$work" 2>/dev/null || {
    sleep 1
    rm -rf "$work"
  }
}
trap cleanup_work EXIT
source_root="$work/source"
mkdir -p "$source_root/Matths/RankMotion" "$source_root/scripts"
cp "$root/Matths/RankMotion/rank-promotion-assets.json" \
  "$source_root/Matths/RankMotion/"
cp "$root/scripts/verifyRankPromotionBundle.js" "$source_root/scripts/"
git -C "$source_root" init -q
git -C "$source_root" config user.email release-audit@example.invalid
git -C "$source_root" config user.name 'Release Audit Test'
printf '%s\n' candidate > "$source_root/README.md"
printf '%s\n' .DS_Store > "$source_root/.gitignore"
git -C "$source_root" add .
git -C "$source_root" commit -qm candidate
app="$work/Matths.app"
mkdir -p "$app/RankMotion"
cp "$root/Matths/RankMotion/rank-promotion-assets.json" "$app/RankMotion/"
for video in "$root"/Matths/RankMotion/*.mp4; do cp "$video" "$app/RankMotion/"; done
cp "$root/Matths/curriculum-story-policy.json" "$app/"
cp "$root/Matths/curriculum-stories-index.json" "$app/"
cp "$root/Matths/curriculum-v2.json" "$app/"
for shard in "$root"/Matths/curriculum-stories/*.json; do
  cp "$shard" "$app/"
done
printf '%s\n' 'release binary https://www.matths.kr' > "$app/Matths"
cat > "$app/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>kr.matths.app</string>
<key>CFBundleURLTypes</key><array><dict><key>CFBundleURLSchemes</key><array><string>matths</string></array></dict></array>
</dict></plist>
PLIST
printf '%s\n' '<?xml version="1.0"?><plist version="1.0"><dict/></plist>' > "$app/PrivacyInfo.xcprivacy"
SRCROOT="$source_root" TARGET_BUILD_DIR="$work" \
UNLOCALIZED_RESOURCES_FOLDER_PATH=Matths.app INFOPLIST_PATH=Matths.app/Info.plist \
CONFIGURATION=Release /bin/sh "$root/scripts/embed-build-provenance.sh"
printf '%s\n' '** BUILD SUCCEEDED **' > "$work/build.log"
cat > "$work/lipo" <<'SH'
#!/bin/sh
echo arm64
SH
chmod +x "$work/lipo"

MATTHS_LIPO="$work/lipo" node "$root/scripts/createReleaseAuditEvidence.js" \
  --app "$app" --build-log "$work/build.log" --output "$work/audit.json" \
  --assets excluded --signing unsigned --source-root "$source_root"
grep -Fq '"schemaVersion": "MATTHS_IPAD_RELEASE_AUDIT_V2"' "$work/audit.json"
grep -Fq '"appStoreEligible": false' "$work/audit.json"
grep -Eq '"commit": "[0-9a-f]{40}"' "$work/audit.json"
grep -Eq '"tree": "[0-9a-f]{40}"' "$work/audit.json"
grep -Fq '"trackedWorkingTreeClean": true' "$work/audit.json"
grep -Fq '"publishedStoryCount": 220' "$work/audit.json"
grep -Fq '"shardCount": 13' "$work/audit.json"
grep -Fq '"sha256Verified": true' "$work/audit.json"
grep -Fq '"status": "verified-git-origin"' "$work/audit.json"
grep -Fq '"approvedSource": true' "$work/audit.json"
grep -Fq '"externalAttestationRequired": false' "$work/audit.json"
grep -Fq '"repository": "https://github.com/is4553807/Matths-Official.git"' "$work/audit.json"
grep -Fq '"commit": "2b4e518f670d96e5c85128504faedb38456874ef"' "$work/audit.json"

printf '%s\n' '** ARCHIVE SUCCEEDED **' > "$work/archive.log"
MATTHS_LIPO="$work/lipo" node "$root/scripts/createReleaseAuditEvidence.js" \
  --app "$app" --build-log "$work/archive.log" --output "$work/archive-audit.json" \
  --assets excluded --signing unsigned --source-root "$source_root"
grep -Fq '"result": "PASS"' "$work/archive-audit.json"

touch "$app/embedded.mobileprovision"
cat > "$work/codesign" <<'SH'
#!/bin/sh
exit 0
SH
cat > "$work/security" <<'SH'
#!/bin/sh
while [ "$#" -gt 0 ]; do
  if [ "$1" = "-o" ]; then
    cp "$MATTHS_PROFILE" "$2"
    exit 0
  fi
  shift
done
exit 1
SH
chmod +x "$work/codesign" "$work/security"

cat > "$work/development.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Entitlements</key><dict><key>get-task-allow</key><true/></dict>
<key>ProvisionedDevices</key><array><string>DEVICE</string></array>
</dict></plist>
PLIST
MATTHS_LIPO="$work/lipo" MATTHS_CODESIGN="$work/codesign" \
MATTHS_SECURITY="$work/security" MATTHS_PROFILE="$work/development.plist" \
node "$root/scripts/createReleaseAuditEvidence.js" \
  --app "$app" --build-log "$work/build.log" --output "$work/development.json" \
  --assets compiled --signing signed --source-root "$source_root"
grep -Fq '"signing": "development"' "$work/development.json"
grep -Fq '"appStoreEligible": false' "$work/development.json"

cat > "$work/distribution.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Entitlements</key><dict><key>get-task-allow</key><false/></dict>
</dict></plist>
PLIST
mkdir -p "$work/ipa/Payload"
cp -R "$app" "$work/ipa/Payload/Matths.app"
(cd "$work/ipa" && /usr/bin/zip -qry "$work/Matths.ipa" Payload)
source_status=$(git -C "$source_root" status --porcelain --untracked-files=normal)
if [ -n "$source_status" ]; then
  echo "Release audit fixture source became dirty: $source_status" >&2
  exit 1
fi
MATTHS_LIPO="$work/lipo" MATTHS_CODESIGN="$work/codesign" \
MATTHS_SECURITY="$work/security" MATTHS_PROFILE="$work/distribution.plist" \
node "$root/scripts/createReleaseAuditEvidence.js" \
  --app "$app" --build-log "$work/build.log" --output "$work/distribution.json" \
  --assets compiled --signing signed --signed-archive "$work/Matths.ipa" \
  --source-root "$source_root"
grep -Fq '"signing": "app-store-distribution"' "$work/distribution.json"
grep -Fq '"appStoreBinaryEligible": true' "$work/distribution.json"
grep -Fq '"appStoreEligible": true' "$work/distribution.json"
grep -Fq '"signing": "app-store-distribution"' "$work/distribution.json"
grep -Fq '"file": "Matths.ipa"' "$work/distribution.json"
grep -Eq '"sha256": "[0-9a-f]{64}"' "$work/distribution.json"
grep -Eq '"executableSha256": "[0-9a-f]{64}"' "$work/distribution.json"
grep -Eq '"rankAssetManifestSha256": "[0-9a-f]{64}"' "$work/distribution.json"

cp "$app/Matths" "$work/Matths-binary"
printf x >> "$app/Matths"
if MATTHS_LIPO="$work/lipo" MATTHS_CODESIGN="$work/codesign" \
  MATTHS_SECURITY="$work/security" MATTHS_PROFILE="$work/distribution.plist" \
  node "$root/scripts/createReleaseAuditEvidence.js" \
    --app "$app" --build-log "$work/build.log" --output "$work/mismatched-ipa.json" \
    --assets compiled --signing signed --signed-archive "$work/Matths.ipa" \
    --source-root "$source_root" >/dev/null 2>&1; then
  echo '다른 executable의 IPA가 Release 감사를 통과했습니다.' >&2
  exit 1
fi
cp "$work/Matths-binary" "$app/Matths"

if MATTHS_LIPO="$work/lipo" MATTHS_CODESIGN="$work/codesign" \
  MATTHS_SECURITY="$work/security" MATTHS_PROFILE="$work/distribution.plist" \
  node "$root/scripts/createReleaseAuditEvidence.js" \
    --app "$app" --build-log "$work/build.log" --output "$work/missing-ipa.json" \
    --assets compiled --signing signed --source-root "$source_root" >/dev/null 2>&1; then
  echo 'IPA 없는 App Store 배포 감사가 통과했습니다.' >&2
  exit 1
fi

cp "$app/common-math-1.json" "$work/common-math-1.json"
printf '\n' >> "$app/common-math-1.json"
if MATTHS_LIPO="$work/lipo" node "$root/scripts/createReleaseAuditEvidence.js" \
  --app "$app" --build-log "$work/build.log" --output "$work/tampered-curriculum.json" \
  --assets excluded --signing unsigned --source-root "$source_root" >/dev/null 2>&1; then
  echo '변조된 커리큘럼 shard가 Release 감사 증거를 통과했습니다.' >&2
  exit 1
fi
cp "$work/common-math-1.json" "$app/common-math-1.json"

cp "$app/RankMotion/silver-rank-up.v6.mp4" "$work/silver.mp4"
printf x >> "$app/RankMotion/silver-rank-up.v6.mp4"
if MATTHS_LIPO="$work/lipo" node "$root/scripts/createReleaseAuditEvidence.js" \
  --app "$app" --build-log "$work/build.log" --output "$work/tampered-rank.json" \
  --assets excluded --signing unsigned --source-root "$source_root" >/dev/null 2>&1; then
  echo '변조된 rank MP4가 Release 감사를 통과했습니다.' >&2
  exit 1
fi
cp "$work/silver.mp4" "$app/RankMotion/silver-rank-up.v6.mp4"

printf '%s\n' 'trycloudflare.com' >> "$app/Matths"
if MATTHS_LIPO="$work/lipo" node "$root/scripts/createReleaseAuditEvidence.js" \
  --app "$app" --build-log "$work/build.log" --output "$work/fail.json" \
  --assets excluded --signing unsigned --source-root "$source_root" >/dev/null 2>&1; then
  echo '임시 서버 주소가 Release 감사에 통과했습니다.' >&2
  exit 1
fi

echo 'iPad Release audit evidence contract passed'
