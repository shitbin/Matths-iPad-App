#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d /tmp/matths-auth-landing.XXXXXX)
trap 'rm -rf "$work"' EXIT HUP INT TERM
swiftc "$root/Matths/AuthLandingGeometry.swift" "$root/tests/AuthLandingGeometryCases.swift" -o "$work/cases"
"$work/cases"
if rg -n 'showsSampleLesson|SampleLessonScreen|로그인 전에 30초 체험하기|30초 수학 체험' "$root/Matths" --glob '*.swift'; then
  echo 'FAIL: removed pre-login sample surface remains reachable or defined' >&2
  exit 1
fi
rg -Fq 'AuthLandingLayout(viewportHeight: geo.size.height, compact: compactHeight)' "$root/Matths/AuthScreen.swift"
rg -Fq 'brandCenterY' "$root/Matths/AuthScreen.swift"
rg -Fq 'PrimaryBrandIdentity()' "$root/Matths/AuthScreen.swift"
echo 'Auth brand and sample-removal contract passed'
