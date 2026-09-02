#!/bin/sh
set -eu

fail() {
  echo "error: build provenance: $*" >&2
  exit 1
}

source_root=${SRCROOT:-}
target_build_dir=${TARGET_BUILD_DIR:-}
resource_path=${UNLOCALIZED_RESOURCES_FOLDER_PATH:-}
info_path=${INFOPLIST_PATH:-}
configuration=${CONFIGURATION:-Debug}

[ -n "$source_root" ] || fail 'SRCROOT가 없습니다.'
[ -n "$target_build_dir" ] || fail 'TARGET_BUILD_DIR이 없습니다.'
[ -n "$resource_path" ] || fail 'UNLOCALIZED_RESOURCES_FOLDER_PATH가 없습니다.'
[ -n "$info_path" ] || fail 'INFOPLIST_PATH가 없습니다.'

app="$target_build_dir/$resource_path"
info="$target_build_dir/$info_path"
[ -d "$app" ] || fail "앱 번들이 없습니다: $app"
[ -f "$info" ] || fail "Info.plist가 없습니다: $info"

node_bin=${NODE_BINARY:-}
if [ -z "$node_bin" ] || [ ! -x "$node_bin" ]; then
  node_bin=$(command -v node 2>/dev/null || true)
fi
if [ -z "$node_bin" ] || [ ! -x "$node_bin" ]; then
  for candidate in /opt/homebrew/bin/node /usr/local/bin/node; do
    if [ -x "$candidate" ]; then
      node_bin=$candidate
      break
    fi
  done
fi
[ -n "$node_bin" ] && [ -x "$node_bin" ] \
  || fail 'Node.js가 없어 rank asset provenance를 검증할 수 없습니다.'

if git -C "$source_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  source_commit=$(git -C "$source_root" rev-parse HEAD | tr '[:upper:]' '[:lower:]')
  source_tree=$(git -C "$source_root" rev-parse 'HEAD^{tree}' | tr '[:upper:]' '[:lower:]')
  if [ -z "$(git -C "$source_root" status --porcelain --untracked-files=normal)" ]; then
    source_clean=true
  else
    source_clean=false
  fi
  source_kind=git
  source_external_attestation=false
else
  source_commit=$(printf '%s' "${MATTHS_SOURCE_COMMIT:-}" | tr '[:upper:]' '[:lower:]')
  source_tree=$(printf '%s' "${MATTHS_SOURCE_TREE:-}" | tr '[:upper:]' '[:lower:]')
  source_clean=${MATTHS_SOURCE_CLEAN:-false}
  case "$source_commit" in
    *[!0-9a-f]*|'') fail 'git-less 빌드는 MATTHS_SOURCE_COMMIT Git object id가 필요합니다.' ;;
  esac
  case "$source_tree" in
    *[!0-9a-f]*|'') fail 'git-less 빌드는 MATTHS_SOURCE_TREE Git object id가 필요합니다.' ;;
  esac
  case ${#source_commit} in 40|64) ;; *) fail 'MATTHS_SOURCE_COMMIT 길이는 40 또는 64여야 합니다.' ;; esac
  case ${#source_tree} in 40|64) ;; *) fail 'MATTHS_SOURCE_TREE 길이는 40 또는 64여야 합니다.' ;; esac
  [ "$source_clean" = true ] \
    || fail 'git-less 빌드는 MATTHS_SOURCE_CLEAN=true의 명시적 선언이 필요합니다.'
  source_kind=external-parameters
  source_external_attestation=true
fi

case "$source_commit" in
  *[!0-9a-f]*|'') fail 'source commit 형식이 잘못됐습니다.' ;;
esac
case "$source_tree" in
  *[!0-9a-f]*|'') fail 'source tree 형식이 잘못됐습니다.' ;;
esac
case ${#source_commit} in 40|64) ;; *) fail 'source commit 길이는 40 또는 64여야 합니다.' ;; esac
case ${#source_tree} in 40|64) ;; *) fail 'source tree 길이는 40 또는 64여야 합니다.' ;; esac

if [ "$configuration" = Release ] && [ "$source_clean" != true ]; then
  fail 'Release는 dirty source tree에서 빌드할 수 없습니다.'
fi

"$node_bin" "$source_root/scripts/verifyRankPromotionBundle.js" \
  --app "$app" --source-root "$source_root" --assets-only \
  || fail '번들 rank MP4/manifest 검증에 실패했습니다.'

manifest="$app/RankMotion/rank-promotion-assets.json"
if [ ! -f "$manifest" ]; then
  manifest="$app/rank-promotion-assets.json"
fi
[ -f "$manifest" ] || fail '번들 rank asset manifest를 찾지 못했습니다.'
manifest_sha=$(/usr/bin/shasum -a 256 "$manifest" | /usr/bin/awk '{print $1}')

provenance="$app/MatthsBuildProvenance.plist"
/usr/bin/plutil -create xml1 "$provenance"
/usr/bin/plutil -insert SchemaVersion -string MATTHS_BUILD_PROVENANCE_V1 "$provenance"
/usr/bin/plutil -insert SourceCommit -string "$source_commit" "$provenance"
/usr/bin/plutil -insert SourceTree -string "$source_tree" "$provenance"
/usr/bin/plutil -insert SourceIdentityKind -string "$source_kind" "$provenance"
/usr/bin/plutil -insert SourceTrackedWorkingTreeClean -bool "$source_clean" "$provenance"
/usr/bin/plutil -insert SourceExternalAttestationRequired \
  -bool "$source_external_attestation" "$provenance"
/usr/bin/plutil -insert RankAssetManifestSHA256 -string "$manifest_sha" "$provenance"

set_string() {
  key=$1
  value=$2
  /usr/libexec/PlistBuddy -c "Delete :$key" "$info" >/dev/null 2>&1 || true
  /usr/libexec/PlistBuddy -c "Add :$key string $value" "$info"
}

set_bool() {
  key=$1
  value=$2
  /usr/libexec/PlistBuddy -c "Delete :$key" "$info" >/dev/null 2>&1 || true
  /usr/libexec/PlistBuddy -c "Add :$key bool $value" "$info"
}

set_string MatthsBuildProvenanceSchema MATTHS_BUILD_PROVENANCE_V1
set_string MatthsSourceCommit "$source_commit"
set_string MatthsSourceTree "$source_tree"
set_string MatthsSourceIdentityKind "$source_kind"
set_bool MatthsSourceTrackedWorkingTreeClean "$source_clean"
set_bool MatthsSourceExternalAttestationRequired "$source_external_attestation"
set_string MatthsRankAssetManifestSHA256 "$manifest_sha"

echo "build provenance embedded: $source_commit / $source_tree ($source_kind, clean=$source_clean)"
