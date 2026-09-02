#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d /tmp/matths-rank-provenance.XXXXXX)
trap 'rm -rf "$work"' EXIT

source_root="$work/source"
app="$work/Matths.app"
mkdir -p "$source_root/Matths/RankMotion" "$source_root/scripts" "$app/RankMotion"
cp "$root/Matths/RankMotion/rank-promotion-assets.json" "$source_root/Matths/RankMotion/"
cp "$root/scripts/verifyRankPromotionBundle.js" "$source_root/scripts/"
cp "$root/Matths/RankMotion/rank-promotion-assets.json" "$app/RankMotion/"
printf '%s\n' fixture > "$source_root/README.md"
printf '%s\n' .DS_Store > "$source_root/.gitignore"
for video in "$root"/Matths/RankMotion/*.mp4; do
  cp "$video" "$app/RankMotion/"
done

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
git -C "$source_root" config user.email provenance-contract@example.invalid
git -C "$source_root" config user.name 'Provenance Contract'
git -C "$source_root" add .
git -C "$source_root" commit -qm fixture

SRCROOT="$source_root" TARGET_BUILD_DIR="$work" \
UNLOCALIZED_RESOURCES_FOLDER_PATH=Matths.app INFOPLIST_PATH=Matths.app/Info.plist \
CONFIGURATION=Debug /bin/sh "$root/scripts/embed-build-provenance.sh"
node "$root/scripts/verifyRankPromotionBundle.js" \
  --app "$app" --source-root "$source_root"

cp "$app/Info.plist" "$work/Info.plist"
/usr/libexec/PlistBuddy -c \
  'Set :MatthsSourceTree 0000000000000000000000000000000000000000' "$app/Info.plist"
if node "$root/scripts/verifyRankPromotionBundle.js" \
  --app "$app" --source-root "$source_root" >/dev/null 2>&1; then
  echo '변조된 Info.plist source identity가 provenance 검증을 통과했습니다.' >&2
  exit 1
fi
cp "$work/Info.plist" "$app/Info.plist"

cp "$app/MatthsBuildProvenance.plist" "$work/MatthsBuildProvenance.plist"
/usr/libexec/PlistBuddy -c \
  'Set :RankAssetManifestSHA256 0000000000000000000000000000000000000000000000000000000000000000' \
  "$app/MatthsBuildProvenance.plist"
if node "$root/scripts/verifyRankPromotionBundle.js" \
  --app "$app" --source-root "$source_root" >/dev/null 2>&1; then
  echo '변조된 build provenance manifest hash가 검증을 통과했습니다.' >&2
  exit 1
fi
cp "$work/MatthsBuildProvenance.plist" "$app/MatthsBuildProvenance.plist"

cp "$app/RankMotion/bronze-rank-up.v6.mp4" "$work/bronze.mp4"
printf x >> "$app/RankMotion/bronze-rank-up.v6.mp4"
if node "$root/scripts/verifyRankPromotionBundle.js" \
  --app "$app" --source-root "$source_root" >/dev/null 2>&1; then
  echo '변조된 rank MP4가 provenance 검증을 통과했습니다.' >&2
  exit 1
fi
cp "$work/bronze.mp4" "$app/RankMotion/bronze-rank-up.v6.mp4"

cp "$app/RankMotion/rank-promotion-assets.json" "$work/manifest.json"
node -e 'const fs=require("fs");const p=process.argv[1];const j=JSON.parse(fs.readFileSync(p));j.sourceProvenance.commit="0".repeat(40);fs.writeFileSync(p,JSON.stringify(j));' \
  "$app/RankMotion/rank-promotion-assets.json"
if node "$root/scripts/verifyRankPromotionBundle.js" \
  --app "$app" --source-root "$source_root" >/dev/null 2>&1; then
  echo '변조된 원본 commit의 rank manifest가 provenance 검증을 통과했습니다.' >&2
  exit 1
fi
cp "$work/manifest.json" "$app/RankMotion/rank-promotion-assets.json"

mv "$app/RankMotion/rank-promotion-assets.json" "$work/missing-manifest.json"
if node "$root/scripts/verifyRankPromotionBundle.js" \
  --app "$app" --source-root "$source_root" >/dev/null 2>&1; then
  echo 'rank manifest 누락 번들이 provenance 검증을 통과했습니다.' >&2
  exit 1
fi
mv "$work/missing-manifest.json" "$app/RankMotion/rank-promotion-assets.json"

printf '%s\n' dirty >> "$source_root/README.md"
SRCROOT="$source_root" TARGET_BUILD_DIR="$work" \
UNLOCALIZED_RESOURCES_FOLDER_PATH=Matths.app INFOPLIST_PATH=Matths.app/Info.plist \
CONFIGURATION=Debug /bin/sh "$root/scripts/embed-build-provenance.sh"
if node "$root/scripts/verifyRankPromotionBundle.js" \
  --app "$app" --source-root "$source_root" >/dev/null 2>&1; then
  echo 'dirty Debug 빌드가 provenance 증거로 통과했습니다.' >&2
  exit 1
fi
if SRCROOT="$source_root" TARGET_BUILD_DIR="$work" \
  UNLOCALIZED_RESOURCES_FOLDER_PATH=Matths.app INFOPLIST_PATH=Matths.app/Info.plist \
  CONFIGURATION=Release /bin/sh "$root/scripts/embed-build-provenance.sh" \
  >/dev/null 2>&1; then
  echo 'dirty source Release 빌드가 provenance gate를 통과했습니다.' >&2
  exit 1
fi
git -C "$source_root" checkout -q -- README.md
SRCROOT="$source_root" TARGET_BUILD_DIR="$work" \
UNLOCALIZED_RESOURCES_FOLDER_PATH=Matths.app INFOPLIST_PATH=Matths.app/Info.plist \
CONFIGURATION=Debug /bin/sh "$root/scripts/embed-build-provenance.sh"
git -C "$source_root" commit -q --allow-empty -m 'different source identity'
if node "$root/scripts/verifyRankPromotionBundle.js" \
  --app "$app" --source-root "$source_root" >/dev/null 2>&1; then
  echo '다른 source commit의 번들이 provenance 검증을 통과했습니다.' >&2
  exit 1
fi

gitless="$work/gitless"
mkdir -p "$gitless/Matths/RankMotion" "$gitless/scripts"
cp "$root/Matths/RankMotion/rank-promotion-assets.json" "$gitless/Matths/RankMotion/"
cp "$root/scripts/verifyRankPromotionBundle.js" "$gitless/scripts/"
if SRCROOT="$gitless" TARGET_BUILD_DIR="$work" \
  UNLOCALIZED_RESOURCES_FOLDER_PATH=Matths.app INFOPLIST_PATH=Matths.app/Info.plist \
  CONFIGURATION=Debug /bin/sh "$root/scripts/embed-build-provenance.sh" \
  >/dev/null 2>&1; then
  echo 'source identity 없는 git-less 빌드가 통과했습니다.' >&2
  exit 1
fi

MATTHS_SOURCE_COMMIT=1111111111111111111111111111111111111111 \
MATTHS_SOURCE_TREE=2222222222222222222222222222222222222222 \
MATTHS_SOURCE_CLEAN=true SRCROOT="$gitless" TARGET_BUILD_DIR="$work" \
UNLOCALIZED_RESOURCES_FOLDER_PATH=Matths.app INFOPLIST_PATH=Matths.app/Info.plist \
CONFIGURATION=Debug /bin/sh "$root/scripts/embed-build-provenance.sh"
test "$(/usr/libexec/PlistBuddy -c 'Print :SourceIdentityKind' \
  "$app/MatthsBuildProvenance.plist")" = external-parameters
test "$(/usr/libexec/PlistBuddy -c 'Print :SourceExternalAttestationRequired' \
  "$app/MatthsBuildProvenance.plist")" = true

echo 'Rank promotion provenance contract passed'
