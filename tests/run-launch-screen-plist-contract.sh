#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
info="$repo_root/Info.plist"
project="$repo_root/Matths.xcodeproj/project.pbxproj"

plutil -lint "$info" >/dev/null

# A native-resolution iPhone/iPad launch requires UILaunchScreen to be a
# dictionary. Keep it explicitly empty: Xcode 26's generation setting can
# otherwise produce UILaunchScreen.UILaunchScreen in the built plist.
python3 - "$info" <<'PY'
import plistlib
import sys

with open(sys.argv[1], "rb") as handle:
    info = plistlib.load(handle)

launch = info.get("UILaunchScreen")
if launch != {}:
    raise SystemExit(f"UILaunchScreen must be an empty dictionary, got: {launch!r}")
PY

if grep -Fq 'INFOPLIST_KEY_UILaunchScreen_Generation = YES;' "$project"; then
  echo 'automatic launch-screen generation must stay disabled' >&2
  exit 1
fi

count="$(grep -Fc 'INFOPLIST_KEY_UILaunchScreen_Generation = NO;' "$project")"
if [[ "$count" -ne 2 ]]; then
  echo "expected Debug and Release launch-screen generation settings, found $count" >&2
  exit 1
fi

echo 'launch screen plist contract: PASS'
